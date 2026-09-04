make_raw_meta <- function() {
  data.frame(
    peptide_id = c("pep1", "pep2"),
    bin_num = c(0, 1),
    tf_char = c("TRUE", "FALSE"),
    num_char = c("1.5", "2.2"),
    id_like = c("agilent_1", "agilent_10"),
    list_col = I(list("x", "y")),
    nan_num = c(NaN, 3),
    nan_char = c("NaN", "ok"),
    stringsAsFactors = FALSE
  )
}

write_meta_rds <- function(path) {
  saveRDS(make_raw_meta(), path)
}

test_that("get_peptide_library builds cache and sanitizes types", {
  skip_if_not_installed("mockery")

  cache_dir <- withr::local_tempdir()
  withr::local_options(list(phiperio.cache_dir = cache_dir))

  src <- withr::local_tempfile(fileext = ".rds")
  write_meta_rds(src)

  mockery::stub(
    get_peptide_library,
    ".ph_download_file",
    function(url, dest, sha_expected, force) {
      file.copy(src, dest, overwrite = TRUE)
      invisible(dest)
    }
  )

  peptides_tbl <- get_peptide_library(force_refresh = TRUE)

  expect_s3_class(peptides_tbl, "tbl_dbi")
  con <- attr(peptides_tbl, "duckdb_con")
  expect_true(inherits(con, "DBIConnection"))

  meta <- dplyr::collect(peptides_tbl)

  expect_true(all(c("peptide_id", "bin_num", "tf_char") %in% names(meta)))
  expect_true(is.logical(meta$bin_num))
  expect_identical(meta$bin_num, c(FALSE, TRUE))
  expect_true(is.logical(meta$tf_char))
  expect_identical(meta$tf_char, c(TRUE, FALSE))
  expect_true(is.numeric(meta$num_char))
  expect_identical(meta$list_col, c("x", "y"))
  expect_true(is.na(meta$nan_num[1]))
  expect_true(is.na(meta$nan_char[1]))

  # regression: alphanumeric ID-like strings (e.g. "agilent_1") must NOT be
  # coerced to numeric just because they contain digits (this used to turn
  # the whole column into NA, see protein_id in the real library)
  expect_true(is.character(meta$id_like))
  expect_identical(meta$id_like, c("agilent_1", "agilent_10"))
  expect_false(anyNA(meta$id_like))

  DBI::dbDisconnect(con, shutdown = TRUE)
})

test_that("get_peptide_library uses cached table when available", {
  skip_if_not_installed("mockery")

  cache_dir <- withr::local_tempdir()
  withr::local_options(list(phiperio.cache_dir = cache_dir))

  src <- withr::local_tempfile(fileext = ".rds")
  write_meta_rds(src)

  mockery::stub(
    get_peptide_library,
    ".ph_download_file",
    function(url, dest, sha_expected, force) {
      file.copy(src, dest, overwrite = TRUE)
      invisible(dest)
    }
  )

  first_tbl <- get_peptide_library(force_refresh = TRUE)
  DBI::dbDisconnect(attr(first_tbl, "duckdb_con"), shutdown = TRUE)

  mockery::stub(
    get_peptide_library,
    ".ph_download_file",
    function(...) {
      stop("download should not run on fast path")
    }
  )

  second_tbl <- get_peptide_library(force_refresh = FALSE)
  expect_s3_class(second_tbl, "tbl_dbi")
  DBI::dbDisconnect(attr(second_tbl, "duckdb_con"), shutdown = TRUE)
})

test_that("get_peptide_library falls back to temp cache dir when needed", {
  skip_if_not_installed("mockery")

  cache_dir <- withr::local_tempdir()
  withr::local_options(list(
    phiperio.cache_dir = cache_dir,
    phiperio.log.verbose = FALSE
  ))

  src <- withr::local_tempfile(fileext = ".rds")
  write_meta_rds(src)

  warn_state <- NULL

  mockery::stub(
    get_peptide_library,
    "dir.exists",
    function(path) FALSE
  )
  mockery::stub(
    get_peptide_library,
    ".ph_warn",
    function(headline, step = NULL, bullets = NULL, ...) {
      warn_state <<- list(headline = headline, step = step, bullets = bullets)
      invisible(bullets)
    }
  )
  mockery::stub(
    get_peptide_library,
    ".ph_download_file",
    function(url, dest, sha_expected, force) {
      file.copy(src, dest, overwrite = TRUE)
      invisible(dest)
    }
  )
  mockery::stub(
    get_peptide_library,
    "DBI::dbConnect",
    function(...) structure(list(), class = "DBIConnection")
  )
  mockery::stub(
    get_peptide_library,
    "DBI::dbExistsTable",
    function(...) FALSE
  )
  mockery::stub(
    get_peptide_library,
    "DBI::dbWriteTable",
    function(...) TRUE
  )
  mockery::stub(
    get_peptide_library,
    "dplyr::tbl",
    function(...) structure(list(), class = "tbl_dbi")
  )

  peptides_tbl <- get_peptide_library(force_refresh = TRUE)

  expect_s3_class(peptides_tbl, "tbl_dbi")
  expect_true(is.list(warn_state))
  expect_match(warn_state$headline, "Persistent cache unavailable")
})

test_that("get_peptide_library retries dbConnect and removes old table", {
  skip_if_not_installed("mockery")

  cache_dir <- withr::local_tempdir()
  withr::local_options(list(
    phiperio.cache_dir = cache_dir,
    phiperio.log.verbose = FALSE
  ))

  src <- withr::local_tempfile(fileext = ".rds")
  write_meta_rds(src)

  calls <- 0
  remove_called <- FALSE

  mockery::stub(
    get_peptide_library,
    ".ph_download_file",
    function(url, dest, sha_expected, force) {
      file.copy(src, dest, overwrite = TRUE)
      invisible(dest)
    }
  )
  mockery::stub(
    get_peptide_library,
    "DBI::dbConnect",
    function(..., read_only = FALSE) {
      calls <<- calls + 1
      if (calls == 1) stop("primary connect fails")
      if (calls == 2) stop("read-only connect fails")
      structure(list(), class = "DBIConnection")
    }
  )
  mockery::stub(
    get_peptide_library,
    "file.exists",
    function(path) TRUE
  )
  mockery::stub(
    get_peptide_library,
    "file.copy",
    function(...) TRUE
  )
  mockery::stub(
    get_peptide_library,
    "DBI::dbExistsTable",
    function(...) TRUE
  )
  mockery::stub(
    get_peptide_library,
    "DBI::dbRemoveTable",
    function(...) {
      remove_called <<- TRUE
      TRUE
    }
  )
  mockery::stub(
    get_peptide_library,
    "DBI::dbWriteTable",
    function(...) TRUE
  )
  mockery::stub(
    get_peptide_library,
    "dplyr::tbl",
    function(...) structure(list(), class = "tbl_dbi")
  )

  peptides_tbl <- get_peptide_library(force_refresh = TRUE)

  expect_s3_class(peptides_tbl, "tbl_dbi")
  expect_true(remove_called)
  expect_gte(calls, 3)
})

test_that(".ph_download_file uses cached file when checksum matches", {
  skip_if_not_installed("mockery")

  dest <- withr::local_tempfile(fileext = ".rds")
  writeLines("cached", dest)

  mockery::stub(
    .ph_download_file,
    ".ph_sha256_file",
    function(path) "abc123"
  )
  mockery::stub(
    .ph_download_file,
    "utils::download.file",
    function(...) stop("download called unexpectedly")
  )

  withr::with_options(
    list(phiperio.log.verbose = FALSE),
    expect_silent(
      .ph_download_file("http://example.com/file.rds", dest, "abc123")
    )
  )
})

test_that(".ph_download_file warns on checksum mismatch", {
  skip_if_not_installed("mockery")

  dest <- withr::local_tempfile(fileext = ".rds")

  mockery::stub(
    .ph_download_file,
    "utils::download.file",
    function(url, dest, ...) {
      writeLines("downloaded", dest)
      0L
    }
  )
  mockery::stub(
    .ph_download_file,
    ".ph_sha256_file",
    function(path) "bad"
  )

  expect_warning(
    .ph_download_file("http://example.com/file.rds", dest, "expected"),
    "Checksum mismatch"
  )
})

test_that(".ph_download_file uses cached file when checksum is not provided", {
  skip_if_not_installed("mockery")

  dest <- withr::local_tempfile(fileext = ".rds")
  writeLines("cached", dest)

  mockery::stub(
    .ph_download_file,
    "utils::download.file",
    function(...) stop("download called unexpectedly")
  )

  withr::with_options(
    list(phiperio.log.verbose = FALSE),
    expect_silent(
      .ph_download_file("http://example.com/file.rds", dest, NULL)
    )
  )
})

test_that(".ph_download_file warns when retrying download methods", {
  skip_if_not_installed("mockery")

  dest <- withr::local_tempfile(fileext = ".rds")
  calls <- 0

  mockery::stub(
    .ph_download_file,
    "utils::download.file",
    function(url, dest, ...) {
      calls <<- calls + 1
      if (calls == 1) return(1L)
      writeLines("downloaded", dest)
      0L
    }
  )

  withr::with_options(
    list(phiperio.log.verbose = FALSE),
    expect_warning(
      .ph_download_file("http://example.com/file.rds", dest, NULL),
      "Download attempt failed"
    )
  )
})

test_that(".ph_download_file aborts when download fails entirely", {
  skip_if_not_installed("mockery")

  dest <- withr::local_tempfile(fileext = ".rds")

  mockery::stub(
    .ph_download_file,
    "utils::download.file",
    function(...) 1L
  )

  withr::with_options(
    list(phiperio.log.verbose = FALSE),
    expect_error(
      suppressWarnings(
        .ph_download_file("http://example.com/file.rds", dest, NULL)
      ),
      "Failed to download file"
    )
  )
})

test_that(".ph_download_file logs when checksum matches", {
  skip_if_not_installed("mockery")

  dest <- withr::local_tempfile(fileext = ".rds")

  mockery::stub(
    .ph_download_file,
    "utils::download.file",
    function(url, dest, ...) {
      writeLines("downloaded", dest)
      0L
    }
  )
  mockery::stub(
    .ph_download_file,
    ".ph_sha256_file",
    function(path) "good"
  )

  withr::with_options(
    list(phiperio.log.verbose = FALSE),
    expect_silent(
      .ph_download_file("http://example.com/file.rds", dest, "good")
    )
  )
})

test_that(".ph_sha256_file hashes a file and handles errors", {
  path <- withr::local_tempfile()
  writeBin(charToRaw("abc"), path)

  # SHA-256 of the three bytes "abc", per FIPS 180-4
  expect_identical(
    .ph_sha256_file(path),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )

  expect_true(is.na(.ph_sha256_file(file.path(path, "does-not-exist"))))
})

test_that(
  "get_peptide_library fetches the current library without checksum drift or NA-collapsed columns",
  {
    skip_on_cran()
    skip_if_offline("raw.githubusercontent.com")

    cache_dir <- withr::local_tempdir()
    withr::local_options(list(phiperio.cache_dir = cache_dir))

    warnings_seen <- character()

    peptides_tbl <- withCallingHandlers(
      get_peptide_library(force_refresh = TRUE),
      warning = function(w) {
        warnings_seen <<- c(warnings_seen, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    con <- attr(peptides_tbl, "duckdb_con")
    withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))

    # if the SHA-256 hardcoded in get_peptide_library() no longer matches the
    # file published at the URL, .ph_download_file() emits this warning --
    # i.e. the library reference in the package is stale
    expect_false(any(grepl("Checksum mismatch", warnings_seen)))

    meta <- dplyr::collect(peptides_tbl)

    raw_path <- list.files(
      cache_dir,
      pattern = "\\.rds$", recursive = TRUE, full.names = TRUE
    )[1]
    raw_meta <- readRDS(raw_path)

    # a column that had real data in the raw source must not end up fully NA
    # after sanitization (this is exactly how the "agilent_1" -> NA bug in
    # protein_id manifested)
    had_data_raw <- vapply(raw_meta, function(x) any(!is.na(x)), logical(1))
    fully_na_now <- vapply(meta, function(x) all(is.na(x)), logical(1))

    common_cols <- intersect(names(had_data_raw), names(fully_na_now))
    collapsed_cols <- common_cols[had_data_raw[common_cols] & fully_na_now[common_cols]]

    expect_length(collapsed_cols, 0)
  }
)
