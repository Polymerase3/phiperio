#' @title Convert legacy Carlos-style input to a modern **phip_data** object
#'
#' @description
#' `convert_legacy()` ingests the original three-file PhIP-Seq input
#' (binary *exist* matrix, *samples* metadata, optional *timepoints* map).
#' Paths can be supplied directly or via a single YAML config; explicit
#' arguments always override the YAML.  The function normalises the chosen
#' DuckDB storage, validates every file, and returns a ready-to-use
#' `phip_data` object.
#'
#' @details
#' Input files are validated in two stages:
#' * **Fast-fail** checks (paths, extensions, and required arguments) run during
#'   path resolution.
#' * **Data validation** (required columns, uniqueness, value ranges, etc.) is
#'   centralized in `validate_phip_data()`.
#'
#' @param exist_file       Path to the **exist** CSV (peptide x sample binary
#'   matrix). *Required unless given in `config_yaml`.*
#' @param fold_change_file       Path to the **fold_change** CSV (peptide x
#'   sample numeric matrix). *Required unless given in `config_yaml`.*
#' @param input_file,hit_file    Paths to the **raw_counts** CSV (peptide x
#'   sample integer matrix). *Required unless given in `config_yaml`.*
#' @param samples_file     Path to the **samples** CSV (sample metadata).
#'   *Required unless given in `config_yaml`.*
#' @param timepoints_file  Path to the **timepoints** CSV (subject <-> sample
#'   mapping). Optional for cross-sectional data.
#' @param extra_cols       Character vector of extra metadata columns to retain.
#' @param output_dir       *Deprecated.* Ignored with a warning.
#' @param peptide_library logical, defining if the `peptide_library` is to be
#'    downloaded from the official `phiperio` GitHub
#' @param config_yaml      Optional YAML file containing any of the above
#'   parameters (see example).
#' @param n_cores Integer >= 1. Number of CPU threads DuckDB may use while
#'   reading and writing files.
#'
#' @param materialise_table Logical. If `FALSE` the result is registered as a
#'   **view**; if `TRUE` the table is fully **materialised** and stored on disk,
#'   trading higher load time and storage for faster repeated queries.
#' @return A validated `phip_data` object whose `data_long` slot is backed by a
#'   DuckDB connection.
#'
#' @examples
#' ## 1. Direct-path usage (package example files)
#' ext <- system.file("extdata", package = "phiperio")
#' pd <- convert_legacy(
#'   exist_file = file.path(ext, "exist.csv"),
#'   samples_file = file.path(ext, "samples_meta.csv"),
#'   timepoints_file = file.path(ext, "samples2ind_timepoints.csv"),
#'   peptide_library = FALSE
#' )
#'
#' ## 2. YAML-driven usage (explicit args override YAML)
#' pd <- convert_legacy(
#'   config_yaml = file.path(ext, "config.yaml"),
#'   peptide_library = FALSE
#' )
#'
#'
#' @export

convert_legacy <- function(
  exist_file = NULL,
  fold_change_file = NULL,
  samples_file = NULL,
  input_file = NULL,
  hit_file = NULL,
  timepoints_file = NULL,
  extra_cols = NULL,
  output_dir = NULL, # hard deprecation
  peptide_library = TRUE,
  n_cores = 8,
  materialise_table = TRUE,
  config_yaml = NULL
) {
  #' @importFrom rlang .data

  # ------------------------------------------------------------------
  # 1. arg checks
  # ------------------------------------------------------------------
  chk::chk_numeric(n_cores)
  chk::chk_flag(materialise_table)

  # ------------------------------------------------------------------
  # 2. resolving the paths to absolute
  # ------------------------------------------------------------------
  cfg <- .ph_resolve_paths(
    exist_file = exist_file,
    fold_change_file = fold_change_file,
    samples_file = samples_file,
    input_file = input_file,
    hit_file = hit_file,
    timepoints_file = timepoints_file,
    extra_cols = extra_cols,
    output_dir = output_dir,
    peptide_library = peptide_library,
    config_yaml = config_yaml,
    n_cores = n_cores,
    materialise_table = materialise_table
  )

  # ------------------------------------------------------------------
  # 3. prepare the metadata
  # ------------------------------------------------------------------
  meta_list <- .ph_legacy_prepare_metadata(
    cfg$samples_file,
    cfg$timepoints_file,
    cfg$extra_cols
  )

  # ------------------------------------------------------------------
  # 4. create the phip_data object (DuckDB)
  # ------------------------------------------------------------------
  con <- .ph_legacy_read_duckdb_backend(cfg, meta_list)

  ## duckdb-specific code
  long <- dplyr::tbl(con, "final_long")

  # returning the phip_data object
  create_data(
    data_long = long,
    peptide_library = cfg$peptide_library,
    meta = list(con = con)
  )
}

#' @title Build legacy tables in DuckDB for conversion
#'
#' @description `.ph_legacy_read_duckdb_backend()` loads legacy CSV/parquet
#' inputs into temporary DuckDB tables, reshapes them into a long format, and
#' prepares the final tables used by `convert_legacy()`.
#'
#' @param cfg Named list of resolved file paths and options from
#'   `.ph_resolve_paths()`.
#' @param meta List of preprocessed metadata tables from
#'   `.ph_legacy_prepare_metadata()`.
#'
#' @return A DuckDB DBI connection containing the temporary and final tables
#'   needed for the legacy conversion.
#'
#' @details
#' - No rows are collected into R; all transformations are executed in DuckDB.
#' - The caller is responsible for closing the returned connection.
#'
#' @keywords internal
.ph_legacy_read_duckdb_backend <- function(cfg,
                                           meta) {

  cache_dir <- withr::local_tempdir("phiperio_cache") # optional name-prefix
  duckdb_file <- file.path(cache_dir, "phip_cache.duckdb")

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = duckdb_file)

  q <- function(x) DBI::dbQuoteString(con, x)
  qi <- function(x) DBI::dbQuoteIdentifier(con, x)

  ## file reader based on the file extension (.csv/.parquet)
  ## returns a character string (SQL query)
  duckdb_load_sql <- function(path, table_name, header = TRUE) {
    if (is.null(path)) {
      return(NULL)
    } # fallback to NULL

    ext <- paste0(
      tolower(strsplit(basename(path), "\\.", fixed = FALSE)[[1]][-1]),
      collapse = "."
    )

    is_parquet <- grepl("^parq(uet)?(\\.|$)|^pq(\\.|$)", ext)
    reader_fun <- if (is_parquet) "parquet_scan" else "read_csv_auto"
    qpath <- sprintf("'%s'", gsub("'", "''", path))

    if (reader_fun == "parquet_scan") {
      sprintf(
        "CREATE TEMP TABLE %s AS SELECT * FROM parquet_scan(%s);",
        table_name, qpath
      )
    } else {
      hdr_flag <- if (isTRUE(header)) "HEADER=TRUE" else "HEADER=FALSE"
      sprintf(
        "CREATE TEMP TABLE %s AS SELECT * FROM read_csv_auto(%s,%s);",
        table_name, qpath, hdr_flag
      )
    }
  }

  # -----------------------------------------------------------------------
  # 1. OPTIONAL MATRICES ---------------------------------------------------
  load_and_unpivot <- function(file, wide_name, long_name, value_col) {
    if (is.null(file)) {
      return(NULL)
    }
    DBI::dbExecute(con, duckdb_load_sql(file, wide_name))

    first_col <- DBI::dbGetQuery(
      con,
      sprintf(
        "SELECT column_name
                 FROM duckdb_columns()
                WHERE table_name = '%s'
             ORDER BY column_index LIMIT 1;",
        wide_name
      )
    )$column_name

    samp_cols <- DBI::dbGetQuery(
      con,
      sprintf(
        "SELECT column_name
                 FROM duckdb_columns()
                WHERE table_name = '%s' AND column_name <> '%s'
             ORDER BY column_index;",
        wide_name, first_col
      )
    )$column_name

    DBI::dbExecute(
      con,
      sprintf(
        "CREATE TEMP TABLE %s AS
           SELECT %s AS peptide_id, sample_id, %s
             FROM %s
             UNPIVOT (%s FOR sample_id IN (%s));",
        long_name, qi(first_col), value_col, wide_name, value_col,
        paste(qi(samp_cols), collapse = ", ")
      )
    )
    long_name
  }

  ## create a list of matrices (or actually names, as the tables are registered
  ## in the temporary duckdb dir)
  long_tbls <- list(
    tbl_counts = load_and_unpivot(
      cfg$exist_file, "counts_wide",
      "counts_long", "exist"
    ),
    tbl_fc = load_and_unpivot(
      cfg$fold_change_file, "fold_change_wide",
      "fold_change_long", "fold_change"
    ),
    tbl_inp = load_and_unpivot(
      cfg$input_file, "input_wide",
      "input_long", "input_count"
    ),
    tbl_hit = load_and_unpivot(
      cfg$hit_file, "hit_wide",
      "hit_long", "hit_count"
    )
  )

  ## remove the NULLs
  long_tbls <- Filter(Negate(is.null), long_tbls)

  stopifnot(length(long_tbls) > 0) # at least one matrix must be present

  base_tbl <- long_tbls[[1]]

  ## ensure `counts` exists and is the base -------------------------------
  DBI::dbExecute(
    con,
    sprintf("CREATE TEMP TABLE final_long AS SELECT * FROM %s;", base_tbl)
  )

  ## join additional matrices --------------------------------------------
  for (tbl in long_tbls[-1]) {
    value_col <- DBI::dbGetQuery(
      con,
      sprintf(
        "SELECT column_name
                 FROM duckdb_columns()
                WHERE table_name = '%s'
                  AND column_name NOT IN ('peptide_id','sample_id')
             LIMIT 1;",
        tbl
      )
    )$column_name

    DBI::dbExecute(
      con,
      sprintf(
        "CREATE OR REPLACE TEMP TABLE final_long AS
           SELECT f.*, t.%s
             FROM final_long f
             LEFT JOIN %s t USING (peptide_id, sample_id);",
        qi(value_col), tbl
      )
    )

    ## clean after merging --> removing unnecessary large tables, everything is
    ## in final_long now
    DBI::dbExecute(con, sprintf("DROP TABLE %s;", tbl))
  }

  # -----------------------------------------------------------------------
  # 2. samples metadata ----------------------------------------------------
  duckdb::duckdb_register(con, "samples_raw", meta$samples)

  first_col_samples <- DBI::dbGetQuery(
    con,
    "SELECT column_name
       FROM duckdb_columns()
      WHERE table_name = 'samples_raw'
   ORDER BY column_index LIMIT 1;"
  )$column_name

  DBI::dbExecute(
    con,
    sprintf(
      "CREATE TEMP TABLE samples2 AS
         SELECT %s AS sample_id, * EXCLUDE (%s)
           FROM samples_raw;",
      qi(first_col_samples), qi(first_col_samples)
    )
  )

  DBI::dbExecute(
    con,
    "CREATE OR REPLACE TEMP TABLE final_long AS
       SELECT f.*, s.* EXCLUDE sample_id
         FROM final_long f
         LEFT JOIN samples2 s USING (sample_id);"
  )

  # -----------------------------------------------------------------------

  invisible(con)
}

#' @title Read CSV/TSV/Parquet with delimiter sniffing
#'
#' @description `.ph_auto_read_file()` loads delimited text or parquet files,
#' detecting the delimiter for text inputs and using duckdb and DBI for parquet.
#'
#' @param path Character scalar. Path to a CSV/TSV or parquet file.
#' @param ... Additional arguments passed to the underlying reader.
#'
#' @return A data.frame containing the parsed file contents.
#'
#'
#' @keywords internal
.ph_auto_read_file <- function(path,
                               ...) {
  base <- basename(path)

  ext <- strsplit(base, "\\.", fixed = FALSE)[[1]][-1]
  ext <- paste0(tolower(ext), collapse = ".")

  ## ------------------------------------------------------------------ ##
  ##                1.  PARQUET branch                                  ##
  ## ------------------------------------------------------------------ ##
  if (ext %in% c("parquet", "parq", "pq")) {

    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
    on.exit(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE),
            add = TRUE)

    tbl_name <- paste0("ph_tmp_parquet_", format(Sys.time(), "%Y%m%d_%H%M%S"))
    tbl_q <- DBI::dbQuoteIdentifier(con, tbl_name)
    path_q <- DBI::dbQuoteString(con, path)
    DBI::dbExecute(
      con,
      sprintf(
        "CREATE TABLE %s AS
           SELECT * FROM parquet_scan(%s);",
        tbl_q, path_q
      )
    )
    DBI::dbReadTable(con, tbl_name)
  } else {
    ## ------------------------------------------------------------------ ##
    ##                2.  CSV / TSV branch (original)                     ##
    ## ------------------------------------------------------------------ ##
    hdr <- readLines(path, n = 1L, warn = FALSE)

    n_comma <- lengths(regmatches(hdr, gregexpr(",", hdr, fixed = TRUE)))
    n_semi <- lengths(regmatches(hdr, gregexpr(";", hdr, fixed = TRUE)))
    sep <- if (n_semi > n_comma) ";" else ","

    utils::read.csv(path,
                    header = TRUE,
                    sep = sep,
                    check.names = FALSE,
                    stringsAsFactors = FALSE,
                    ...
    )
  }
}

#' @title Prepare sample metadata for legacy import
#'
#' @description Reads the `samples_file` and `timepoints_file`, and merges
#'   them when present to add a subject identifier and timepoint variable.
#'
#' @param samples_file      Absolute path to the samples CSV/Parquet.
#' @param timepoints_file   Absolute path to timepoints CSV/Parquet, or `NULL`.
#' @param extra_cols        Character vector of extra metadata columns to keep.
#'
#' @return A list with elements `samples`, `timepoints`, and `extra_cols`.
#' @keywords internal
.ph_legacy_prepare_metadata <- function(samples_file,
                                     timepoints_file = NULL,
                                     extra_cols = character()) {
  # ---- samples -------------------------------------------------------------
  samples <- .ph_auto_read_file(samples_file) # small table
  names(samples)[1] <- "sample_id" # rename first var
  ## delete the columns: only sample_id and group are allowed to stay
  keep <- colnames(samples) %in% c("sample_id", "group", extra_cols)
  samples <- samples[keep]

  # ---- time-points (optional) ---------------------------------------------
  if (is.null(timepoints_file)) {
    timepoints <- NULL
  } else {
    tp_wide <- .ph_auto_read_file(timepoints_file)

    tp_long <- stats::reshape(
      tp_wide,
      direction = "long",
      varying   = names(tp_wide)[-1],
      v.names   = "sample_id",
      times     = names(tp_wide)[-1],
      timevar   = "timepoint",
      idvar     = "subject_id"
    )

    # remove the last variable, rename the first and reset the rownames
    tp_long <- tp_long[, -ncol(tp_long)]
    names(tp_long)[names(tp_long) == "ind_id"] <- "subject_id"
    row.names(tp_long) <- NULL

    # filter the NAs out
    tp_long <- tp_long[!is.na(tp_long$sample_id), ]
    # ---------- 3. merge ------------------------------------------------------
    # add the time-point info if present
    samples <- merge(samples,
                     tp_long,
                     by = "sample_id"
    )

    timepoints <- tp_long
  }

  list(
    samples = samples,
    timepoints = timepoints
  )
}
