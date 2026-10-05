# base URL of the library files, hosted in the companion phiper repo
.ph_library_base_url <- paste0(
  "https://raw.githubusercontent.com/Polymerase3/phiper/",
  "main/library-metadata/"
)

# peptide libraries known to phiperio: the RDS file in the phiper repo, its
# SHA-256, and the peptide_id prefixes (the part before the trailing
# "_<number>") that identify the library's peptides
.ph_library_registry <- list(
  combined = list(
    file = "combined_library_06.07.26.rds",
    sha256 = "ce12b27d42ed3a6e26d02a25328c80f1b0bebd281c0112e3ee72a7c367d5ce02",
    prefixes = c("agilent", "twist", "corona2")
  ),
  human_proteome = list(
    file = "human_proteome_library_16.09.26.rds",
    sha256 = "c702e5968136363d6cd903b6aee587051e8674cc98b1ce848bc2a173a9bddb6b",
    prefixes = "humanProteome"
  ),
  icam = list(
    file = "icam_library_01.10.26.rds",
    sha256 = "2ec7488a7b983c37fd953b88b666bc56d042d19f70efc12e2e0a32af3788f84e",
    prefixes = "icam"
  )
)

#' @title Retrieve the peptide metadata table into DuckDB, forcing atomic types
#'
#' @description This function uses the phiperio logging utilities for
#'   consistent, ASCII-only progress messages and timing. Long-running steps are
#'   bracketed with `.ph_with_timing()`, and informational/warning/error
#'   messages are emitted via `.ph_log_info()`, `.ph_log_ok()`, `.ph_warn()`,
#'   and `.ph_abort()`.
#' * Downloads each requested library RDS once, sanitizes types (logical,
#'   character, numeric), and writes it into a DuckDB cache on disk.
#' * Subsequent calls return a lazy `tbl_dbi` without loading into R memory.
#'
#' @param library Character vector naming the libraries to retrieve:
#'   `"combined"` (agilent, twist and corona2 peptides), `"human_proteome"`,
#'   and/or `"icam"`. Several names return one table stacking those libraries.
#' @param force_refresh Logical. If `TRUE`, re-downloads and rebuilds the cache.
#'
#' @return A `dplyr::tbl_dbi` pointing to the requested library: the
#'   `peptide_meta_<name>` table for a single library, or a view stacking the
#'   tables of several. The returned object carries an attribute `"duckdb_con"`
#'   with the open `DBI` connection.
#'
#' @details
#' **Caching:** A persistent DuckDB database is created under the user cache
#' directory (via `tools::R_user_dir("phiperio", "cache")`). You can override
#' this location with `options(phiperio.cache_dir = \"...\")`. Each library is
#' stored in its own `peptide_meta_<name>` table. The `force_refresh` argument
#' bypasses the fast path and rebuilds the cache.
#'
#' **Several libraries:** The libraries are stacked by column name in a view
#' named after them (e.g. `peptide_meta_combined_icam`). Columns that only some
#' libraries have are `NA` for the peptides of the others. Peptide IDs carry a
#' library-specific prefix, so they do not collide.
#'
#' **Sanitization:** Columns are stripped of attributes, list-columns are
#' flattened, textual `"NaN"` and numeric `NaN` are coerced to `NA`. Binary 0/1
#' fields are converted to `logical`, `"TRUE"/"FALSE"` (case-insensitive) are
#' converted to `logical`, and numeric-looking character columns (beyond trivial
#' 0/1) are converted to `numeric`. All other atomic types are preserved.
#'
#' **Integrity check:** If a SHA-256 checksum is provided, a warning is logged
#' when the downloaded file’s checksum does not match the expected value.
#'
#' @seealso [dplyr::tbl()], [DBI::dbConnect()], [duckdb::duckdb()]
#' @examples
#' lib <- get_peptide_library()
#'
#' @export
get_peptide_library <- function(library = "combined",
                                force_refresh = FALSE) {
  .ph_with_timing(
    headline = "Retrieving peptide metadata into DuckDB cache",
    step = sprintf(
      "get_peptide_library(library = %s, force_refresh = %s)",
      paste(library, collapse = ", "),
      as.character(force_refresh)
    ),
    expr = {
      # check if dependencies installed --> maybe hard dep in the future?
      rlang::check_installed(c("duckdb", "DBI", "dplyr", "withr"))

      unknown <- setdiff(library, names(.ph_library_registry))
      .ph_check_cond(
        length(unknown) > 0,
        "Unknown peptide library requested.",
        step = "get_peptide_library()",
        bullets = c(
          sprintf("unknown: %s", .ph_word_list(unknown, quotes = 2L)),
          sprintf(
            "available: %s",
            .ph_word_list(names(.ph_library_registry), quotes = 2L)
          )
        )
      )
      library <- sort(unique(library))
      lib_tables <- paste0("peptide_meta_", library)

      # 1. Prep cache dir & DuckDB connection (persistent cache by default)
      cache_root <- getOption(
        "phiperio.cache_dir",
        tools::R_user_dir("phiperio", "cache")
      )
      cache_dir <- file.path(cache_root, "peptide_meta")
      dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
      if (!dir.exists(cache_dir)) {
        cache_dir <- withr::local_tempdir("phiperio_cache",
          .local_envir = globalenv()
        )
        .ph_warn(
          headline = "Persistent cache unavailable; using temp dir.",
          step = "cache setup",
          bullets = sprintf("cache dir: %s", cache_dir)
        )
      }
      duckdb_file <- file.path(cache_dir, "phip_cache.duckdb")
      con <- tryCatch(
        DBI::dbConnect(duckdb::duckdb(), dbdir = duckdb_file),
        error = function(e) {
          # fall back to read-only if the cache is locked elsewhere
          tryCatch(
            DBI::dbConnect(duckdb::duckdb(), dbdir = duckdb_file,
                           read_only = TRUE),
            error = function(e2) {
              # final fallback: use a temporary copy of the cache DB
              tmp_db <- file.path(
                withr::local_tempdir("phiperio_cache",
                                     .local_envir = globalenv()),
                "phip_cache.duckdb"
              )
              if (file.exists(duckdb_file)) {
                file.copy(duckdb_file, tmp_db, overwrite = TRUE)
              }
              DBI::dbConnect(duckdb::duckdb(), dbdir = tmp_db)
            }
          )
        }
      )
      .ph_log_info("Opened DuckDB connection",
        bullets = c(
          sprintf("cache dir: %s", duckdb_file),
          sprintf("tables: %s", paste(lib_tables, collapse = ", "))
        )
      )

      for (i in seq_along(library)) {
        lib_table <- lib_tables[i]
        entry <- .ph_library_registry[[library[i]]]

        # 2. fast path: already cached? --> next library
        ## the user can also force the evaluation by force_refresh arg
        if (!force_refresh && DBI::dbExistsTable(con, lib_table)) {
          .ph_log_ok(sprintf("Using cached %s (fast path)", lib_table))
          next
        }

        # 3. download raw RDS from the github repo
        url <- paste0(.ph_library_base_url, entry$file)
        tmp <- file.path(cache_dir, entry$file)

        ## safe download (fallbacks if file changed, or if download does not
        ## succeed)
        .ph_download_file(url, tmp, entry$sha256,
                          force = isTRUE(force_refresh))

        ## reading the raw RDS file --> it needs a lot of polishin (is prolly
        ## python generated, see attributes)
        raw_meta <- readRDS(tmp)
        .ph_log_ok("Download complete and loaded into R")

        # 4. peptide_id is now stored in the column withthe same name
        peptide_ids <- raw_meta$peptide_id
        raw_meta <- raw_meta[, -1]
        rownames(raw_meta) <- NULL

        # 5. sanitize each column
        clean_list <- lapply(raw_meta, function(col) {
          # drop all attributes
          attributes(col) <- NULL

          # unlist it if column is a list
          if (typeof(col) == "list") {
            col <- unlist(col)
          }

          # replace NaN with NA's, also the NaNs as characters
          col[is.nan(col)] <- NA
          col[col == "NaN"] <- NA

          # 1) numeric 0/1 -> logical (in the Carlos's metadata binary variables
          # are saved as doubles; here a fallback for other types as well)
          if (all(col %in% c(0, 1, NA)) || all(col %in% c("0", "1", NA))) {
            return(as.logical(col))
          }

          # 2) character "TRUE"/"FALSE" --> logical
          if (is.character(col) &&
            all(tolower(col[!is.na(col)]) %in% c("true", "false", NA))) {
            return(as.logical(col))
          }

          # 3) character column that really holds numeric values
          # (but not just 0/1)
          if (is.character(col)) {
            # remove NAs for testing
            non_na <- col[!is.na(col)]
            # detect strings that fully parse as numeric (not just
            # containing a digit somewhere, e.g. "agilent_1" must NOT match)
            converted <- suppressWarnings(as.numeric(non_na))
            is_num_str <- !is.na(converted)

            # only proceed if all non-NA entries are numeric strings
            # and not all of them are "0" or "1"
            if (length(non_na) > 0 &&
              all(is_num_str) &&
              !all(non_na %in% c("0", "1"))) {
              return(suppressWarnings(as.numeric(col)))
            }
          }

          # 4) otherwise leave atomic as it was
          # (logical/integer/double/character)
          col
        })

        # 6. prepend peptide_id column
        clean_list <- c(list(peptide_id = peptide_ids), clean_list)

        meta_df <- data.frame(
          clean_list,
          stringsAsFactors = FALSE,
          check.names = TRUE
        )

        # 7. write into DuckDB
        if (DBI::dbExistsTable(con, lib_table)) {
          DBI::dbRemoveTable(con, lib_table)
        }
        .ph_log_info("Importing sanitized metadata into DuckDB cache...")
        DBI::dbWriteTable(con, lib_table, meta_df, overwrite = TRUE)
        .ph_log_ok(sprintf("%s table created in DuckDB cache", lib_table))
      }

      # 8. several libraries --> stack them by column name in a view; columns
      # missing from a library are NULL for its peptides
      lib_view <- paste0("peptide_meta_", paste(library, collapse = "_"))
      if (length(library) > 1L) {
        qi <- function(x) DBI::dbQuoteIdentifier(con, x)
        DBI::dbExecute(
          con,
          sprintf(
            "CREATE OR REPLACE VIEW %s AS %s;",
            qi(lib_view),
            paste(
              sprintf("SELECT * FROM %s", qi(lib_tables)),
              collapse = " UNION ALL BY NAME "
            )
          )
        )
      }

      # 9. return lazy handle --> the whole dataframe in the memory takes ~ 1GB
      peptides_tbl <- dplyr::tbl(con, lib_view)
      attr(peptides_tbl, "duckdb_con") <- con
      peptides_tbl
    },
    verbose = .ph_opt("verbose", TRUE)
  )
}

#' @title Detect the peptide libraries a counts table draws from
#'
#' @description Matches the `peptide_id` prefixes of `data_long` (the part
#'   before the trailing `"_<number>"`) against the prefixes of the libraries
#'   known to [get_peptide_library()].
#'
#' @param data_long A data frame or lazy table with a `peptide_id` column.
#'
#' @return Character vector with the names of the matched libraries; empty if
#'   no peptide matched any library.
#' @keywords internal
.ph_detect_libraries <- function(data_long) {
  # a missing peptide_id is reported by validate_phip_data()
  if (!"peptide_id" %in% colnames(data_long)) {
    return(character())
  }

  .data <- rlang::.data
  peptide_ids <- data_long |>
    dplyr::distinct(.data$peptide_id) |>
    dplyr::pull()
  prefixes <- unique(sub("_[0-9]+$", "", peptide_ids))

  matched <- vapply(
    .ph_library_registry,
    function(entry) any(entry$prefixes %in% prefixes),
    logical(1)
  )
  names(.ph_library_registry)[matched]
}

#' @keywords internal
.ph_download_file <- function(url,
                           dest,
                           sha_expected = NULL,
                           force = FALSE) {
  ## setup
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  methods <- c("", "libcurl", "curl")
  ok <- FALSE

  if (!isTRUE(force) && file.exists(dest) &&
    isTRUE(file.info(dest)$size > 0)) {
    if (is.null(sha_expected)) {
      .ph_log_ok("Using cached download")
      return(invisible(TRUE))
    }

    sha_actual <- .ph_sha256_file(dest)
    if (!is.na(sha_actual) &&
      identical(tolower(sha_actual), tolower(sha_expected))) {
      .ph_log_ok("Using cached download (SHA-256 match)")
      return(invisible(TRUE))
    }
  }

  .ph_log_info("Starting download",
    bullets = c(
      sprintf("dest: %s", dest)
    )
  )

  ## perform the actual download with given method (or at least try)
  for (m in methods) {
    method <- if (nzchar(m)) m else getOption("download.file.method")
    # without --fail, curl saves the HTTP error page (e.g. a 404) and exits 0
    extra <- getOption("download.file.extra")
    if (identical(method, "curl")) extra <- c(extra, "--fail")

    status <- tryCatch(
      utils::download.file(
        url, dest,
        mode = "wb",
        quiet = TRUE,
        method = method,
        extra = extra
      ),
      error = function(e) e,
      warning = function(w) w
    )
    if (identical(status, 0L)) {
      .ph_log_ok(sprintf(
        "Download succeeded (method = %s)",
        if (nzchar(m)) m else "<getOption()>"
      ))
      ok <- TRUE
      break
    } else {
      .ph_warn(
        headline = "Download attempt failed; trying next method.",
        step     = "download.file",
        bullets  = sprintf("method: %s", if (nzchar(m)) m else "<getOption()>")
      )
    }
  }

  ## Print out error if download did not succeed
  if (!ok || !file.exists(dest) || isTRUE(file.info(dest)$size == 0)) {
    .ph_abort(
      headline = "Failed to download file.",
      step = "download.file",
      bullets = c(
        sprintf("url: %s", url),
        sprintf("dest: %s", dest)
      )
    )
  }

  ## Compare the checksums for the whole file, generate a warning if the file
  ## changed
  if (!is.null(sha_expected)) {
    sha_actual <- .ph_sha256_file(dest)

    if (is.na(sha_actual) ||
      !identical(tolower(sha_actual), tolower(sha_expected))) {
      .ph_warn(
        headline = "Checksum mismatch for downloaded file.",
        step = "integrity check",
        bullets = c(
          sprintf("expected: %s", sha_expected),
          sprintf("actual:   %s", sha_actual %||% "NA")
        )
      )
    } else {
      .ph_log_ok("Checksum verified (SHA-256 match)")
    }
  }

  invisible(dest)
}

#' @keywords internal
.ph_sha256_file <- function(path) {
  tryCatch(
    digest::digest(file = path, algo = "sha256"),
    error = function(e) NA_character_
  )
}
