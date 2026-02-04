write_long_csv <- function(path, df) {
  utils::write.csv(df, path, row.names = FALSE)
}

test_that("convert_standard loads from directory and creates a view", {
  tmp_dir <- withr::local_tempdir()

  df1 <- data.frame(
    sample_id = c("s1", "s1"),
    peptide_id = c("p1", "p2"),
    exist = c(1, 0),
    stringsAsFactors = FALSE
  )
  df2 <- data.frame(
    sample_id = c("s2", "s2"),
    peptide_id = c("p1", "p2"),
    exist = c(0, 1),
    stringsAsFactors = FALSE
  )

  write_long_csv(file.path(tmp_dir, "part1.csv"), df1)
  write_long_csv(file.path(tmp_dir, "part2.csv"), df2)

  withr::with_options(
    list(phiperio.log.verbose = FALSE),
    expect_message(
      pd <- phiperio::convert_standard(
        data_long_path = tmp_dir,
        materialise_table = FALSE,
        auto_expand = FALSE,
        peptide_library = FALSE
      ),
      "Skipping ANALYZE - raw_combined is a view"
    )
  )

  expect_s3_class(pd, "phip_data")
  expect_s3_class(pd$data_long, "tbl_dbi")
  expect_equal(nrow(dplyr::collect(pd$data_long)), 4)
})

test_that("convert_standard loads a single CSV file", {
  tmp_file <- withr::local_tempfile(fileext = ".csv")

  df <- data.frame(
    sample_id = c("s1", "s1"),
    peptide_id = c("p1", "p2"),
    exist = c(1, 0),
    stringsAsFactors = FALSE
  )

  write_long_csv(tmp_file, df)

  pd <- withr::with_options(
    list(phiperio.log.verbose = FALSE),
    phiperio::convert_standard(
      data_long_path = tmp_file,
      materialise_table = TRUE,
      auto_expand = FALSE,
      peptide_library = FALSE
    )
  )

  expect_s3_class(pd, "phip_data")
  expect_equal(nrow(dplyr::collect(pd$data_long)), 2)
})

test_that(".ph_rename_to_standard_inplace errors for missing object", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  expect_error(
    phiperio:::.ph_rename_to_standard_inplace(
      tbl = "does_not_exist",
      con = con,
      colname_map = list(sample_id = "sample_id")
    ),
    "does not exist"
  )
})

test_that(".ph_rename_to_standard_inplace no-ops when no columns match", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  DBI::dbExecute(con, "CREATE TABLE t (a INTEGER, b INTEGER);")

  expect_message(
    phiperio:::.ph_rename_to_standard_inplace(
      tbl = "t",
      con = con,
      colname_map = list(sample_id = "missing")
    ),
    "No matching columns found"
  )
})

test_that(".ph_rename_to_standard_inplace recreates view via
          SHOW CREATE VIEW", {
  skip_if_not_installed("mockery")

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  DBI::dbExecute(con, "CREATE TABLE base (old_col INTEGER, keep INTEGER);")
  DBI::dbExecute(con, "CREATE VIEW v AS SELECT old_col, keep FROM base;")

  orig_dbGetQuery <- DBI::dbGetQuery

  mockery::stub(
    phiperio:::.ph_rename_to_standard_inplace,
    "DBI::dbGetQuery",
    function(con, statement, ...) {
      if (grepl("information_schema.views", statement, fixed = TRUE)) {
        return(data.frame(view_definition = NA_character_))
      }
      if (grepl("SHOW CREATE VIEW", statement, fixed = TRUE)) {
        return(data.frame(
          sql = "CREATE VIEW v AS SELECT old_col, keep FROM base"))
      }
      orig_dbGetQuery(con, statement, ...)
    }
  )

  phiperio:::.ph_rename_to_standard_inplace(
    tbl = "v",
    con = con,
    colname_map = list(sample_id = "old_col")
  )

  cols <- names(DBI::dbGetQuery(con, "SELECT * FROM v LIMIT 1"))
  expect_true("sample_id" %in% cols)
})

test_that(".ph_rename_to_standard_inplace errors when view definition
          is missing", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  with_mocked_bindings(
    expect_error(
      phiperio:::.ph_rename_to_standard_inplace(
        tbl = "v",
        con = con,
        colname_map = list(sample_id = "old_col")
      ),
      "Cannot fetch view definition"
    ),
    dbGetQuery = function(con, statement, ...) {
      if (grepl("information_schema.tables", statement, fixed = TRUE)) {
        return(data.frame(table_type = "VIEW"))
      }
      if (grepl("PRAGMA table_info", statement, fixed = TRUE)) {
        return(data.frame(name = c("old_col", "keep")))
      }
      if (grepl("information_schema.views", statement, fixed = TRUE)) {
        return(data.frame(view_definition = NA_character_))
      }
      if (grepl("SHOW CREATE VIEW", statement, fixed = TRUE)) {
        return(data.frame(sql = NA_character_))
      }
      stop("Unexpected query in mocked dbGetQuery")
    },
    .package = "DBI"
  )
})
