#' @title Convert raw PhIP-Seq output into a `phip_data` object
#'
#' @description `convert_standard()` ingests a "long" table of PhIPsSeq read counts /
#' enrichment statistics, optionally expands it to the full
#' `sample_id x peptide_id` grid, and registers the result in DuckDB.
#' The function returns a fully initialised **`phip_data`** object that can be
#' queried with the tidy API used throughout the package.
#'
#' @param data_long_path Character scalar. File or directory containing the
#'   *long-format* PhIP-Seq data. Allowed extensions are **`.csv`** and
#'   **`.parquet`**. Directories are treated as partitions of a parquet set.
#' @param sample_id,peptide_id,subject_id,timepoint,exist,fold_change,counts_input,counts_hit
#' Optional character strings. Supply these only if your column names differ
#' from the defaults (`"sample_id"`, `"peptide_id"`, `"subject_id"`,
#' `"timepoint"`, `"exist"`, `"fold_change"`, `"counts_input"`,
#' `"counts_hit"`). Each argument should contain the *name* of the column in the
#' incoming data; `NULL` lets the default stand.
#'
#' @param n_cores Integer >= 1. Number of CPU threads DuckDB may use while
#'   reading and writing files.
#'
#' @param materialise_table Logical. If `FALSE` the result is registered as a
#'   **view**; if `TRUE` the table is fully **materialised** and stored on disk,
#'   trading higher load time and storage for faster repeated queries.
#'
#' @param auto_expand Logical. If `TRUE` and the incoming data are **not** a
#'   complete Cartesian product of `sample_id x peptide_id`, missing
#'   combinations are generated:
#'   * Columns that are constant within each `sample_id` (metadata) are copied
#'     to the new rows.
#'   * Non-recyclable measurement columns (`fold_change`, `exist`,
#'     `counts_input`, `counts_hit`, etc.) are initialised to 0.
#'   The expanded table replaces the original *in place*.
#'
#' @param peptide_library Logical. If `TRUE` (default) `convert_standard()` will
#'   attempt to locate and attach the matching peptide-library metadata for
#'   downstream annotation. Set to `FALSE` to skip this step.
#'
#' @return An S3 object of class **`phip_data`** containing:
#' \describe{
#'   \item{`data_long`}{The (possibly expanded) long-format table.}
#'   \item{`peptide_library`}{Loaded peptide-library metadata (if
#'     `peptide_library = TRUE`).}
#'   \item{`meta`}{List with DuckDB connection handles.}
#' }
#'
#' @details
#' *Paths are resolved to absolute form* before any work begins, and explicit
#' checks confirm existence as well as extension validity.
#' @examples
#' # Basic import, auto-detecting default column names
#' phip_obj <- convert_standard(
#'   data_long_path = get_example_path("phip_mixture"),
#'   n_cores = 4,
#'   materialise_table = TRUE
#' )
#'
#' \dontrun{
#' # Import a CSV and rename columns
#' phip_mem <- convert_standard(
#'   data_long_path = "data/phip_long.csv",
#'   sample_id      = "sample",
#'   peptide_id     = "pep"
#' )
#' }
#'
#' @seealso
#' * `create_data()` for the object constructor.
#' * `dplyr::tbl()` to query DuckDB tables lazily.
#'
#' @export

convert_standard <- function(
  data_long_path,
  sample_id = NULL,
  peptide_id = NULL,
  subject_id = NULL,
  timepoint = NULL,
  exist = NULL,
  fold_change = NULL,
  counts_input = NULL,
  counts_hit = NULL,
  n_cores = 8,
  materialise_table = TRUE,
  auto_expand = FALSE,
  peptide_library = TRUE
) {
  # ------------------------------------------------------------------
  # 1. arg checks
  # ------------------------------------------------------------------
  chk::chk_numeric(n_cores)
  chk::chk_flag(materialise_table)

  # ------------------------------------------------------------------
  # 2. resolving the data_long_file path to absolute
  # ------------------------------------------------------------------
  ## check if the data_long_path provided
  .ph_check_cond(
    missing(data_long_path) || !nzchar(data_long_path),
    "'data_long_path' must be provided and non-empty,
            no default is set."
  )

  ## check if this is a directory or a file
  info <- file.info(data_long_path)

  ## pre-check if exists
  .ph_check_cond(
    all(is.na(info)),
    sprintf("Path '%s' does not exist", data_long_path)
  )

  if (!info$isdir || is.na(info$isdir)) {
    .ph_check_path(data_long_path,
      "data_long_path",
      extension = c("csv", "parquet", "parq", "pq")
    )
  }

  ## resolve the path to data_long_path
  cfg <- .ph_resolve_paths(
    data_long_path = data_long_path,
    peptide_library = peptide_library,
    n_cores = n_cores,
    materialise_table = materialise_table,
    auto_expand = auto_expand
  )

  ## filter the NULLs
  cfg <- Filter(Negate(is.null), cfg)

  # ------------------------------------------------------------------
  # 3. mapping the column names
  # ------------------------------------------------------------------
  colname_map <- list(
    sample_id    = sample_id %||% "sample_id",
    peptide_id   = peptide_id %||% "peptide_id",
    subject_id   = subject_id %||% "subject_id",
    timepoint    = timepoint %||% "timepoint",
    exist        = exist %||% "exist",
    fold_change  = fold_change %||% "fold_change",
    counts_input = counts_input %||% "counts_input",
    counts_hit   = counts_hit %||% "counts_hit"
  )

  # ------------------------------------------------------------------
  # 4. create the phip_data object (DuckDB)
  # ------------------------------------------------------------------
  # using the helper to keep the backend setup consistent
  con <- .ph_standard_read_duckdb_backend(cfg, colname_map)

  ## duckdb-specific code
  long <- dplyr::tbl(con, "raw_combined")

  # returning the phip_data object
  create_data(
    data_long = long,
    peptide_library = cfg$peptide_library,
    auto_expand = cfg$auto_expand,
    materialise_table = cfg$materialise_table,
    meta = list(con = con)
  )
}

#' @title Read and register "long" phiperio data into a DuckDB-backed database
#'
#' @description This internal function ingests one or more data files (Parquet or CSV)
#' specified by `cfg$data_long_path` into a single DuckDB view named
#' `data_long`, applying user-provided column mappings (`colmap`) to
#' rename each source column to the standard PHIPERIO names. The resulting
#' `phip_data` object contains a lazy DuckDB table that can be queried
#' with dplyr without loading the full dataset into R until explicitly
#' collected.
#'
#' @param cfg Named list, must contain element `data_long_path` pointing
#'   to either a single file or a directory of files. Supported file
#'   extensions are `.parquet`, `.parq`, `.pq`, and `.csv`.
#' @param colmap Named character list mapping **standard** PHIPERIO column
#'   names (e.g. `"sample_id"`, `"peptide_id"`, ...) to the **actual**
#'   column names found in the source files.
#'
#' @return A `phip_data` S3/S4 object (depending on your package
#'   implementation) whose `data_long` slot is a `dplyr::tbl_dbi`
#'   representing the union of all source files. Calculations against
#'   `data_long` remain lazy until `collect()` is called.
#'
#' @details
#' - If `cfg$data_long_path` is a **directory**, all matching files
#'   within it are UNION ALL'ed.
#' - Parquet files are read via `parquet_scan()`, CSV via
#'   `read_csv_auto()`.
#' - Column renaming is performed in SQL with `AS`, so no R-level
#'   `rename()` calls are needed.
#' - A DuckDB **VIEW** called `data_long` is created (dropped if it
#'   existed previously) for downstream queries.
#'
#' @keywords internal
.ph_standard_read_duckdb_backend <- function(cfg, colmap) {

  ## 0. open a DuckDB connection -------------------------------------------
  ## keep it persistent only for this R session, but ON DISK (so it can spill)
  cache_dir <- withr::local_tempdir("phiperio_cache", .local_envir = globalenv())
  duckdb_file <- file.path(cache_dir, "phip_cache.duckdb")
  tmp_dir <- file.path(cache_dir, "tmp")
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)

  ## set threads + enable spilling via memory_limit & temp_directory
  con <- DBI::dbConnect(
    duckdb::duckdb(),
    dbdir = duckdb_file,
    config = list(
      threads        = as.character(cfg$n_cores),
      memory_limit   = cfg$duckdb_mem %||% "32GB",
      temp_directory = tmp_dir
    )
  )

  ## -- 1. Determine files to load ---------------------------------------------
  info <- file.info(cfg$data_long_path)

  files <- if (isTRUE(info$isdir)) {
    list.files(cfg$data_long_path,
               pattern = "\\.(parquet|parq|pq|csv)$", full.names = TRUE
    )
  } else {
    cfg$data_long_path
  }

  stopifnot(length(files) > 0)

  ## -- 2. Helper: load a single file into a (disk-backed) TABLE ---------------
  load_file <- function(path, tbl_name) {
    path_q <- gsub("'", "''", path)
    if (grepl("\\.csv$", path, ignore.case = TRUE)) {
      DBI::dbExecute(
        con,
        sprintf(
          "CREATE TABLE %s AS
             SELECT * FROM read_csv_auto('%s', HEADER=TRUE);",
          tbl_name, path_q
        )
      )
    } else {
      DBI::dbExecute(
        con,
        sprintf(
          "CREATE TABLE %s AS
             SELECT * FROM parquet_scan('%s');",
          tbl_name, path_q
        )
      )
    }
  }

  tbl_names <- sprintf("f_%d", seq_along(files))
  Map(load_file, files, tbl_names)

  ## -- 3. UNION ALL --> raw_combined ------------------------------------------
  union_sql <- paste(
    sprintf("SELECT * FROM %s", tbl_names),
    collapse = " UNION ALL "
  )

  # 2. Execute either a materialized table or a view based on cfg$table_type
  if (cfg$materialise_table) {
    # Create or replace a real table (snapshot persisted to disk)
    DBI::dbExecute(
      con,
      sprintf(
        "CREATE OR REPLACE TABLE raw_combined AS %s;",
        union_sql
      )
    )
  } else {
    # Create or replace a view (virtual table; query re-runs on each SELECT)
    DBI::dbExecute(
      con,
      sprintf(
        "CREATE OR REPLACE VIEW raw_combined AS %s;",
        union_sql
      )
    )
  }

  ## -- 4. Standardise column names inside DuckDB ------------------------------
  .ph_rename_to_standard_inplace(
    con = con,
    tbl = "raw_combined",
    colname_map = colmap
  )

  # return "BASE TABLE", "VIEW", or NA if it does not exist
  obj_type <- DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT table_type
       FROM information_schema.tables
      WHERE table_schema = current_schema
        AND table_name   = %s",
      DBI::dbQuoteString(con, "raw_combined")
    )
  )$table_type[1]

  if (!is.na(obj_type) && toupper(obj_type) != "VIEW") {
    DBI::dbExecute(con, "ANALYZE raw_combined;")
  } else {
    message("Skipping ANALYZE - raw_combined is a view.")
  }

  ## -- 5. Clean up intermediate tables ----------------------------------------
  ## we actually want to clean up the tables only, when the main table is
  ## materialised. When it's not materialised, the view will take a look on the
  ## original files/tables, so we can not delete them --> we have to have
  ## something to reference to
  if (!is.na(obj_type) && toupper(obj_type) != "VIEW") {
    invisible(lapply(
      tbl_names,
      function(tn) {
        DBI::dbExecute(
          con,
          sprintf("DROP TABLE %s;", tn)
        )
      }
    ))
  }

  invisible(con) # return the open connection
}

#' @title Rename columns to PHIPERIO standard names in-place
#'
#' @description `.ph_rename_to_standard_inplace()` renames columns in a DuckDB
#' table or view to the standard PHIPERIO schema using a mapping of standard
#' names to source columns. For views, it recreates the view with aliased
#' columns; for tables, it issues `ALTER TABLE ... RENAME COLUMN` statements.
#'
#' @param tbl Character scalar. Name of the DuckDB table or view to modify.
#' @param con A valid DBI connection to DuckDB.
#' @param colname_map Named character list mapping **standard** PHIPERIO column
#'   names (e.g. `"sample_id"`, `"peptide_id"`) to the **actual** column names
#'   present in `tbl`.
#'
#' @return Invisibly returns `tbl` after applying any renames.
#'
#' @details
#' - Only columns present in `tbl` are renamed.
#' - For views, the existing definition is retrieved and wrapped in a new
#'   `CREATE OR REPLACE VIEW` statement with aliased columns.
#' - If no matching columns are found, the function emits a message and exits.
#'
#' @keywords internal
.ph_rename_to_standard_inplace <- function(tbl, con, colname_map) {
  ## --- checks -------------------------------------------------------------
  stopifnot(is.character(tbl) && length(tbl) == 1L)
  stopifnot(DBI::dbIsValid(con))
  stopifnot(is.list(colname_map) && length(colname_map) > 0)

  q <- function(x) DBI::dbQuoteString(con, x) # 'string'
  qi <- function(x) DBI::dbQuoteIdentifier(con, x) # "identifier"

  ## --- map old --> new ------------------------------------------------------
  old_to_new <- stats::setNames(names(colname_map), unlist(colname_map))

  ## --- object type --------------------------------------------------------
  meta <- DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT table_type
         FROM information_schema.tables
        WHERE table_name = %s
          AND table_schema = current_schema",
      q(tbl)
    )
  )
  if (nrow(meta) == 0) {
    stop(sprintf("Object `%s` does not exist in current schema.", tbl),
         call. = FALSE
    )
  }

  is_view <- identical(toupper(meta$table_type[1]), "VIEW")

  ## --- existing columns ---------------------------------------------------
  existing_cols <- DBI::dbGetQuery(
    con,
    sprintf("PRAGMA table_info(%s)", qi(tbl))
  )$name

  old_to_new <- old_to_new[names(old_to_new) %in% existing_cols]
  if (length(old_to_new) == 0L) {
    message("No matching columns found - nothing to rename.")
    return(invisible(tbl))
  }

  ## --- TABLE: simple ALTER TABLE -----------------------------------------
  if (!is_view) {
    for (old in names(old_to_new)) {
      new <- unname(old_to_new[[old]])
      DBI::dbExecute(
        con,
        sprintf(
          "ALTER TABLE %s RENAME COLUMN %s TO %s",
          qi(tbl), qi(old), qi(new)
        )
      )
    }
    return(invisible(tbl))
  }

  ## --- VIEW: recreate with aliases ---------------------------------------
  ## 1. try information_schema.views
  defn <- DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT view_definition
         FROM information_schema.views
        WHERE table_name = %s
          AND table_schema = current_schema",
      q(tbl)
    )
  )$view_definition

  ## 2. fallback to SHOW CREATE VIEW
  if (is.na(defn) || trimws(defn) == "") {
    defn <- DBI::dbGetQuery(
      con, sprintf("SHOW CREATE VIEW %s", qi(tbl))
    )$sql[1]
  }

  if (is.na(defn) || trimws(defn) == "") {
    stop("Cannot fetch view definition.", call. = FALSE)
  }

  ## 3. strip leading 'CREATE ... AS' and trailing ';'
  defn <- sub(
    pattern = "(?is)^\\s*create\\s+(or\\s+replace\\s+)?view\\s+[^ ]+\\s+as\\s+",
    replacement = "",
    x = defn,
    perl = TRUE
  )
  defn <- sub(";\\s*$", "", defn)

  ## 4. build SELECT list with aliases
  sel_list <- vapply(
    existing_cols,
    function(col) {
      if (col %in% names(old_to_new)) {
        sprintf("%s AS %s", qi(col), qi(old_to_new[[col]]))
      } else {
        qi(col)
      }
    },
    FUN.VALUE = character(1)
  )

  create_sql <- sprintf(
    "CREATE OR REPLACE VIEW %s AS
     SELECT %s
       FROM (%s) AS src;",
    qi(tbl),
    paste(sel_list, collapse = ", "),
    defn
  )
  DBI::dbExecute(con, create_sql)

  invisible(tbl)
}
