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
