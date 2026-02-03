skip_if_not_installed("chk")
skip_if_not_installed("DBI")
skip_if_not_installed("duckdb")

# -------------------------------------------------------------------------
# export_parquet ----------------------------------------------------------
# -------------------------------------------------------------------------
test_that("export_parquet sanity checks", {
  # Must export a phip_data object
  tmp_path <- withr::local_tempfile(fileext = ".parquet")
  expect_error(
    phiperio::export_parquet(123, tmp_path)
  )

  df <- phiperio::phip_load_example_data()

  # Output path should be file (not folder)
  tmp_dir <- withr::local_tempdir()
  expect_error(
    phiperio::export_parquet(df, tmp_dir)
  )

  # Invalid output path extension
  expect_error(
    phiperio::export_parquet(df, withr::local_tempfile(fileext = ".txt"))
  )
  expect_error(
    phiperio::export_parquet(df, withr::local_tempfile(fileext = ".csv"))
  )
  expect_error(
    phiperio::export_parquet(df, withr::local_tempfile(fileext = ".tsv"))
  )
  expect_error(
    phiperio::export_parquet(df, withr::local_tempfile(fileext = ".rdata"))
  )
})

test_that("export_parquet exports as expected", {
  tmp_path <- withr::local_tempfile(fileext = ".parquet")
  df <- phiperio::phip_load_example_data()

  expect_silent(
    phiperio::export_parquet(df, tmp_path)
  )

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  exported_df <- DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT * FROM read_parquet(%s);",
      DBI::dbQuoteString(con, tmp_path)
    )
  )

  expect_true(all.equal(df$data_long |> collect() |> as.data.frame(), exported_df))
})
