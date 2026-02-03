#' @title Retrieve the peptide metadata table into DuckDB, forcing atomic types
#'
#' @description This function uses the phiperio logging utilities for consistent,
#'   ASCII-only progress messages and timing. Long-running steps are bracketed
#'   with `.ph_with_timing()`, and informational/warning/error messages are
#'   emitted via `.ph_log_info()`, `.ph_log_ok()`, `.ph_warn()`, and
#'   `.ph_abort()`.
#' * Downloads the RDS once, sanitizes types (logical, character, numeric),
#'   and writes into a DuckDB cache on disk.
#' * Subsequent calls return a lazy `tbl_dbi` without loading into R memory.
#'
#' @param force_refresh Logical. If `TRUE`, re-downloads and rebuilds the cache.
#'
#' @return A `dplyr::tbl_dbi` pointing to the `peptide_meta` table. The returned
#'   object carries an attribute `"duckdb_con"` with the open `DBI` connection.
#'
#' @details
#' **Caching:** A persistent DuckDB database is created under the user cache
#' directory (via `tools::R_user_dir("phiperio", "cache")`). You can override
#' this location with `options(phiperio.cache_dir = \"...\")`. The
#' `force_refresh` argument bypasses the fast path and rebuilds the cache.
#'
#' **Sanitization:** Columns are stripped of attributes, list-columns are
#' flattened, textual `"NaN"` and numeric `NaN` are coerced to `NA`. Binary
#' 0/1 fields are converted to `logical`, `"TRUE"/"FALSE"` (case-insensitive)
#' are converted to `logical`, and numeric-looking character columns (beyond
#' trivial 0/1) are converted to `numeric`. All other atomic types are preserved.
#'
#' **Integrity check:** If a SHA-256 checksum is provided, a warning is logged
#' when the downloaded file’s checksum does not match the expected value.
#'
#' @seealso [dplyr::tbl()], [DBI::dbConnect()], [duckdb::duckdb()]
#' @examples
#' \donttest{
#' lib <- get_peptide_library()
#' }
#' @export
get_peptide_library <- function(force_refresh = FALSE) {
  .ph_with_timing(
    headline = "Retrieving peptide metadata into DuckDB cache",
    step = sprintf(
      "get_peptide_library(force_refresh = %s)",
      as.character(force_refresh)
    ),
    expr = {
      # check if dependencies installed --> maybe hard dep in the future?
      rlang::check_installed(c("duckdb", "DBI", "dplyr", "withr"))

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
            DBI::dbConnect(duckdb::duckdb(), dbdir = duckdb_file, read_only = TRUE),
            error = function(e2) {
              # final fallback: use a temporary copy of the cache DB
              tmp_db <- file.path(
                withr::local_tempdir("phiperio_cache", .local_envir = globalenv()),
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
          "table: peptide_meta"
        )
      )

      # 2. fast path: already cached? --> return
      ## the user can also force the evaluation by force_refresh arg
      if (!force_refresh && DBI::dbExistsTable(con, "peptide_meta")) {
        .ph_log_ok("Using cached peptide_meta (fast path)")
        peptides_tbl <- dplyr::tbl(con, "peptide_meta")
        attr(peptides_tbl, "duckdb_con") <- con
        return(peptides_tbl)
      }

      # 3. download raw RDS from the github repo
      url <- paste0(
        "https://raw.githubusercontent.com/Polymerase3/phiper/",
        "main/library-metadata/",
        "combined_library_15.01.26.rds"
      )
      tmp <- file.path(cache_dir, "combined_library_15.01.26.rds")
      sha <- "86c167453b2d13135c3c4147e6deacdfbd9030bbac1f7420c409483f1ca71915"

      ## safe download (fallbacks if file changed, or if download does not
      ## succeed)
      .ph_download_file(url, tmp, sha, force = isTRUE(force_refresh))

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
          # detect pure numeric strings (optionally scientific)
          is_num_str <- grepl("[0-9]+", non_na)

          # only proceed if all non-NA entries are numeric strings
          # and not all of them are "0" or "1"
          if (length(non_na) > 0 &&
            all(is_num_str) &&
            !all(non_na %in% c("0", "1"))) {
            return(suppressWarnings(as.numeric(col)))
          }
        }

        # 4) otherwise leave atomic as it was (logical/integer/double/character)
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
      if (DBI::dbExistsTable(con, "peptide_meta")) {
        DBI::dbRemoveTable(con, "peptide_meta")
      }
      .ph_log_info("Importing sanitized metadata into DuckDB cache...")
      DBI::dbWriteTable(con, "peptide_meta", meta_df, overwrite = TRUE)
      .ph_log_ok("peptide_meta table created in DuckDB cache")

      # 8. return lazy handle --> the whole dataframe in the memory takes ~ 1GB
      peptides_tbl <- dplyr::tbl(con, "peptide_meta")
      attr(peptides_tbl, "duckdb_con") <- con
      peptides_tbl
    },
    verbose = .ph_opt("verbose", TRUE)
  )
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
    status <- tryCatch(
      utils::download.file(
        url, dest,
        mode = "wb",
        quiet = TRUE,
        method = if (nzchar(m)) m else getOption("download.file.method")
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
    {
      strsplit(system2("sha256sum", path, stdout = TRUE), "\\s+")[[1]][1]
    },
    error = function(e) NA_character_
  )
}
