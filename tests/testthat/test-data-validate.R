test_that("validate_phip_data warns on high NA fraction in exist", {
  df <- data.frame(
    sample_id = c("s1", "s1", "s2", "s2"),
    peptide_id = c("p1", "p2", "p1", "p2"),
    exist = c(NA, NA, NA, 1),
    stringsAsFactors = FALSE
  )

  expect_warning(
    phiperio::create_data(
      data_long = df,
      peptide_library = FALSE,
      auto_expand = FALSE
    ),
    "High NA fraction in `exist`"
  )
})

test_that(".ph_expand_full_grid aborts when required columns are missing", {
  df <- data.frame(
    sample_id = c("s1", "s2"),
    exist = c(1, 0),
    stringsAsFactors = FALSE
  )

  expect_error(
    phiperio:::.ph_expand_full_grid(
      df,
      key_col = "sample_id",
      id_col = "peptide_id",
      validate = TRUE
    ),
    "Required columns are missing"
  )
})

test_that(".ph_expand_full_grid aborts on duplicate (key, id) pairs", {
  df <- data.frame(
    sample_id = c("s1", "s1"),
    peptide_id = c("p1", "p1"),
    exist = c(1, 0),
    stringsAsFactors = FALSE
  )

  expect_error(
    phiperio:::.ph_expand_full_grid(
      df,
      key_col = "sample_id",
      id_col = "peptide_id",
      validate = TRUE
    ),
    "Duplicate (key, id) pairs found",
    fixed = TRUE
  )
})

test_that(".ph_expand_full_grid fills numeric/logical defaults on lazy tables", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  df <- data.frame(
    sample_id = c("s1", "s1", "s2"),
    peptide_id = c("p1", "p2", "p1"),
    fold_change = c(1.2, 0.5, 2.1),
    flag = c(TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
  DBI::dbWriteTable(con, "raw", df, overwrite = TRUE)
  tbl <- dplyr::tbl(con, "raw")

  out <- phiperio:::.ph_expand_full_grid(
    tbl,
    key_col = "sample_id",
    id_col = "peptide_id",
    validate = FALSE
  )

  res <- dplyr::collect(out)
  miss_row <- res[res$sample_id == "s2" & res$peptide_id == "p2", ]
  expect_equal(miss_row$fold_change, 0)
  expect_identical(miss_row$flag, FALSE)
})

test_that(".ph_expand_full_grid warns and overwrites existing exist column", {
  df <- data.frame(
    sample_id = c("s1", "s2"),
    peptide_id = c("p1", "p1"),
    exist = c(0, 1),
    stringsAsFactors = FALSE
  )

  expect_warning(
    out <- phiperio:::.ph_expand_full_grid(
      df,
      key_col = "sample_id",
      id_col = "peptide_id",
      add_exist = TRUE,
      exist_col = "exist",
      validate = FALSE
    ),
    "Overwriting existing existence flag"
  )

  res <- dplyr::collect(out)
  expect_true(all(res$exist %in% c(0L, 1L)))
})

test_that(".ph_register_phip_data_tbl creates a view when requested", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  df <- data.frame(
    sample_id = c("s1", "s2"),
    peptide_id = c("p1", "p2"),
    exist = c(1, 0),
    stringsAsFactors = FALSE
  )
  DBI::dbWriteTable(con, "data_long", df, overwrite = TRUE)

  lazy <- dplyr::tbl(con, "data_long") |>
    dplyr::filter(exist == 1)

  out <- phiperio:::.ph_register_phip_data_tbl(
    lazy,
    con = con,
    name = "data_long_view",
    materialise_table = FALSE,
    temporary = TRUE
  )

  expect_s3_class(out, "tbl_dbi")

  obj_type <- DBI::dbGetQuery(
    con,
    "SELECT table_type FROM information_schema.tables WHERE table_name = 'data_long_view'"
  )$table_type[1]
  expect_identical(toupper(obj_type), "VIEW")
})
