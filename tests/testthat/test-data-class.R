skip_if_not_installed("dplyr")
skip_if_not_installed("cli")
skip_if_not_installed("knitr")
skip_if_not_installed("DBI")

# ---------------------------------------------------------------------------
# helper: tiny example data
# ---------------------------------------------------------------------------
counts_tbl <- tibble::tibble(
  peptide_id    = c("pep1", "pep2", "pep1", "pep2"),
  subject_id    = c("S1", "S1", "S2", "S2"),
  sample_id     = 1:4,
  timepoint     = c("T1", "T1", "T1", "T1"),
  fold_change   = c(1.2, 0.8, 1.5, 0.7),
  present       = c(1L, 0L, 0L, 1L),
  group         = c("a", "b", "a", "b")
)

# ---------------------------------------------------------------------------
# constructor + meta flags
# ---------------------------------------------------------------------------
test_that("create_data sets meta flags correctly", {
  withr::with_message_sink(
    tempfile(),
    withr::with_options(list(warn = -1), {
      pd <- create_data(counts_tbl, peptide_library = FALSE)
    })
  )


  expect_s3_class(pd, "phip_data")
  expect_true(pd$meta$longitudinal)
  expect_true(pd$meta$fold_change)
})

# ---------------------------------------------------------------------------
# supplied peptide library
# ---------------------------------------------------------------------------
test_that("create_data attaches a supplied peptide_library", {
  lib_tbl <- tibble::tibble(
    peptide_id = c("pep1", "pep2"),
    Fullname   = c("protein A", "protein B")
  )

  withr::with_message_sink(
    tempfile(),
    withr::with_options(list(warn = -1), {
      pd <- create_data(counts_tbl, peptide_library = lib_tbl)
    })
  )

  expect_s3_class(pd, "phip_data")
  expect_identical(pd$peptide_library, lib_tbl)
})

test_that("create_data rejects an invalid peptide_library", {
  withr::with_message_sink(
    tempfile(),
    withr::with_options(list(warn = -1), {
      expect_error(
        create_data(counts_tbl, peptide_library = 42),
        "must be TRUE, FALSE, library names"
      )
    })
  )
})

# ---------------------------------------------------------------------------
# library detection / library names
# ---------------------------------------------------------------------------
test_that("create_data attaches the libraries detected from peptide_id", {
  skip_if_not_installed("mockery")

  lib_tbl <- tibble::tibble(
    peptide_id = c("agilent_1", "icam_1"),
    Fullname   = c("protein A", "protein B")
  )
  requested <- NULL
  mockery::stub(
    create_data,
    "get_peptide_library",
    function(library) {
      requested <<- library
      lib_tbl
    }
  )

  counts <- counts_tbl
  counts$peptide_id <- c("agilent_1", "icam_1", "agilent_1", "icam_1")

  withr::with_message_sink(
    tempfile(),
    withr::with_options(list(warn = -1), {
      pd <- create_data(counts, peptide_library = TRUE)
    })
  )

  expect_identical(requested, c("combined", "icam"))
  expect_identical(pd$peptide_library, lib_tbl)
  expect_identical(pd$meta$peptide_libraries, c("combined", "icam"))
})

test_that("create_data attaches no library when no peptide_id is recognised", {
  skip_if_not_installed("mockery")

  mockery::stub(
    create_data,
    "get_peptide_library",
    function(...) stop("no library should be fetched")
  )

  withr::with_message_sink(
    tempfile(),
    withr::with_options(list(warn = -1), {
      pd <- create_data(counts_tbl, peptide_library = TRUE)
    })
  )

  expect_null(pd$peptide_library)
  expect_null(pd$meta$peptide_libraries)
})

test_that("create_data attaches the libraries named in peptide_library", {
  skip_if_not_installed("mockery")

  lib_tbl <- tibble::tibble(peptide_id = c("pep1", "pep2"))
  requested <- NULL
  mockery::stub(
    create_data,
    "get_peptide_library",
    function(library) {
      requested <<- library
      lib_tbl
    }
  )

  withr::with_message_sink(
    tempfile(),
    withr::with_options(list(warn = -1), {
      pd <- create_data(
        counts_tbl,
        peptide_library = c("human_proteome", "icam")
      )
    })
  )

  expect_identical(requested, c("human_proteome", "icam"))
  expect_identical(pd$peptide_library, lib_tbl)
  expect_identical(pd$meta$peptide_libraries, c("human_proteome", "icam"))
})

# ---------------------------------------------------------------------------
# print method (just make sure it runs and contains certain strings)
# ---------------------------------------------------------------------------
test_that("print.phip_data shows previews", {
  withr::with_message_sink(
    tempfile(),
    withr::with_options(list(warn = -1), {
      pd <- create_data(counts_tbl, peptide_library = FALSE)
    })
  )


  out <- capture.output(print(pd))
  expect_true(any(grepl("counts \\(first 5 rows\\):", out)))
})

# ---------------------------------------------------------------------------
# plain accessors and .check_pd guard
# ---------------------------------------------------------------------------
test_that("accessors work and .check_pd errors on wrong class", {
  withr::with_message_sink(
    tempfile(),
    withr::with_options(list(warn = -1), {
      pd <- create_data(counts_tbl,
        peptide_library = FALSE, auto_expand = FALSE
      )
    })
  )

  expect_equal(get_counts(pd), counts_tbl)
  expect_equal(get_meta(pd)$longitudinal, TRUE)

  expect_error(get_counts(list(a = 1)), "`x` must be a <phip_data> object")

  expect_no_error(get_peptide_library())
})

# ---------------------------------------------------------------------------
# dplyr verb wrappers
# ---------------------------------------------------------------------------
test_that("dplyr wrappers modify data_long lazily", {
  withr::with_message_sink(
    tempfile(),
    withr::with_options(list(warn = -1), {
      pd <- create_data(counts_tbl,
        peptide_library = FALSE, auto_expand = FALSE
      )
    })
  )

  pd2 <- dplyr::filter(pd, peptide_id == "pep1")

  expect_s3_class(pd2, "phip_data")
  expect_equal(
    dplyr::collect(pd2$data_long)$peptide_id,
    c("pep1", "pep1")
  )

  pd3 <- dplyr::select(pd, peptide_id)
  expect_equal(colnames(pd3$data_long), "peptide_id")

  pd4 <- dplyr::mutate(pd, new_val = present * 2)
  expect_true("new_val" %in% colnames(pd4$data_long))

  pd5 <- dplyr::arrange(pd, desc(present))
  expect_equal(nrow(pd5$data_long), 4)

  n <- dplyr::summarise(pd, n = dplyr::n())
  expect_equal(n$n, 4)

  collected <- dplyr::collect(pd)
  expect_s3_class(collected, "data.frame")
})

# ---------------------------------------------------------------------------
# close helper (mock DBI)
# ---------------------------------------------------------------------------
test_that("close.phip_data closes duckdb connection if present", {
  skip_if_not_installed("duckdb")

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  withr::with_message_sink(
    tempfile(),
    withr::with_options(list(warn = -1), {
      pd <- create_data(counts_tbl,
        materialise_table = TRUE,
        meta = list(con = con),
        peptide_library = FALSE
      )
    })
  )

  expect_true(DBI::dbIsValid(con))

  close(pd) # should close

  expect_false(DBI::dbIsValid(con))
})
