# -------------------------------------------------------------------------
# export_parquet ----------------------------------------------------------
# -------------------------------------------------------------------------
test_that("export_parquet sanity checks", {
  # Must export a phip_data object
  tmp_path <- withr::local_tempfile(fileext = ".parquet")
  expect_error(
    phiperio::export_parquet(123, tmp_path)
  )

  df <- phiperio::load_example_data()

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
  df <- phiperio::load_example_data()

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

  expect_true(all.equal(df$data_long |> collect() |> as.data.frame(),
                        exported_df))
})

test_that("head/dim/print work on phip_data (data.frame backend)", {
  df <- data.frame(
    peptide_id = c("pep1", "pep2", "pep1"),
    sample_id = c("s1", "s1", "s2"),
    exist = c(1, 0, 1),
    stringsAsFactors = FALSE
  )
  pd <- phiperio::create_data(
    data_long = df,
    peptide_library = FALSE,
    auto_expand = FALSE
  )

  expect_s3_class(head(pd, 2), "data.frame")
  expect_equal(dim(pd)[2], ncol(df))

  expect_output(print(pd), "<phip_data>")
  expect_output(print(pd), "counts")
  expect_output(print(pd), "meta flags")
})

test_that("get_counts/get_meta return slots", {
  df <- data.frame(
    peptide_id = c("pep1", "pep2"),
    sample_id = c("s1", "s2"),
    exist = c(1, 0),
    stringsAsFactors = FALSE
  )
  pd <- phiperio::create_data(
    data_long = df,
    peptide_library = FALSE,
    auto_expand = FALSE
  )

  expect_identical(phiperio::get_counts(pd), pd$data_long)
  expect_identical(phiperio::get_meta(pd), pd$meta)
})

test_that("dplyr wrappers modify or return as expected", {
  df <- data.frame(
    peptide_id = c("pep1", "pep2", "pep1"),
    sample_id = c("s1", "s1", "s2"),
    exist = c(1, 0, 1),
    stringsAsFactors = FALSE
  )
  pd <- phiperio::create_data(
    data_long = df,
    peptide_library = FALSE,
    auto_expand = FALSE
  )

  pd2 <- dplyr::filter(pd, sample_id == "s1")
  expect_s3_class(pd2, "phip_data")
  expect_equal(nrow(dplyr::collect(pd2$data_long)), 2)

  pd3 <- dplyr::select(pd, sample_id, peptide_id)
  expect_true(all(c("sample_id", "peptide_id") %in% colnames(pd3$data_long)))

  pd4 <- dplyr::mutate(pd, flag = exist == 1)
  expect_true("flag" %in% colnames(pd4$data_long))

  pd5 <- dplyr::arrange(pd, sample_id)
  expect_s3_class(pd5, "phip_data")

  pd6 <- dplyr::group_by(pd, sample_id)
  expect_s3_class(pd6, "phip_data")

  pd7 <- dplyr::ungroup(pd6)
  expect_s3_class(pd7, "phip_data")

  out <- dplyr::summarise(pd, n = dplyr::n())
  expect_s3_class(out, "data.frame")
  expect_identical(out$n, nrow(df))

  distinct_tbl <- dplyr::distinct(pd, sample_id)
  expect_s3_class(distinct_tbl, "data.frame")
  expect_true(nrow(distinct_tbl) <= nrow(df))
})

test_that("merge/join wrappers handle phip_data and data frames", {
  df <- data.frame(
    peptide_id = c("pep1", "pep2"),
    sample_id = c("s1", "s2"),
    exist = c(1, 0),
    stringsAsFactors = FALSE
  )
  pd <- phiperio::create_data(
    data_long = df,
    peptide_library = FALSE,
    auto_expand = FALSE
  )
  other <- data.frame(
    peptide_id = c("pep1", "pep2"),
    sample_id = c("s1", "s2"),
    extra = c(10, 20),
    stringsAsFactors = FALSE
  )

  expect_warning(
    merged <- merge(pd, other, by = c("sample_id", "peptide_id")),
    "merge"
  )
  expect_s3_class(merged, "phip_data")
  expect_true("extra" %in% colnames(merged$data_long))

  joined <- dplyr::left_join(pd, other, by = c("sample_id", "peptide_id"))
  expect_s3_class(joined, "phip_data")
  expect_true("extra" %in% colnames(joined$data_long))

  anti <- dplyr::anti_join(pd, other, by = c("sample_id", "peptide_id"))
  expect_s3_class(anti, "phip_data")
})

test_that("add_exist appends or overwrites exist flag", {
  df <- data.frame(
    peptide_id = c("pep1", "pep2"),
    sample_id = c("s1", "s2"),
    fold_change = c(1.2, 0.8),
    stringsAsFactors = FALSE
  )
  pd <- phiperio::create_data(
    data_long = df,
    peptide_library = FALSE,
    auto_expand = FALSE
  )

  pd2 <- phiperio::add_exist(pd)
  expect_true("exist" %in% colnames(pd2$data_long))
  expect_true(isTRUE(pd2$meta$exist))

  expect_error(
    phiperio::add_exist(pd2, overwrite = FALSE),
    "Existence column already present"
  )

  pd3 <- phiperio::add_exist(pd2, overwrite = TRUE)
  expect_true("exist" %in% colnames(pd3$data_long))
})

test_that("print refreshes invalid peptide_library tbl_dbi and prints
          preview", {
  skip_if_not_installed("mockery")

  df <- data.frame(
    peptide_id = c("pep1", "pep2"),
    sample_id = c("s1", "s2"),
    exist = c(1, 0),
    stringsAsFactors = FALSE
  )
  pd <- phiperio::create_data(
    data_long = df,
    peptide_library = FALSE,
    auto_expand = FALSE
  )

  stale_con <- structure(list(), class = "DBIConnection")
  stale_src <- structure(list(con = stale_con), class = "src_dbi")
  stale_lib <- structure(list(src = stale_src), class = c("tbl_dbi", "tbl"))

  mockery::stub(
    print.phip_data,
    "DBI::dbIsValid",
    function(con) FALSE
  )

  fresh_con <- structure(list(), class = "DBIConnection")
  fresh_src <- structure(list(con = fresh_con), class = "src_dbi")
  fresh_tbl <- structure(list(src = fresh_src), class = c("tbl_dbi", "tbl"))

  mockery::stub(
    print.phip_data,
    "get_peptide_library",
    function(...) fresh_tbl
  )
  mockery::stub(
    print.phip_data,
    "dplyr::collect",
    function(x, ...) {
      data.frame(
        peptide_id = c("pep1", "pep2"),
        Fullname = c("A", "B"),
        species = c("sp1", "sp2"),
        stringsAsFactors = FALSE
      )
    }
  )
  mockery::stub(
    print.phip_data,
    "dplyr::summarise",
    function(.data, ...) {
      data.frame(n = 2)
    }
  )
  mockery::stub(
    print.phip_data,
    "dplyr::pull",
    function(.data, ...) 2
  )
  mockery::stub(
    print.phip_data,
    ".ph_sync_peptide_con",
    function(x) x
  )
  mockery::stub(
    print.phip_data,
    ".ph_refresh_finalizer",
    function(x) x
  )

  pd$peptide_library <- stale_lib

  expect_output(print(pd), "peptide library preview")
  expect_output(print(pd), "library size")
})

test_that("export_parquet handles data.frame input", {
  df <- data.frame(
    peptide_id = c("pep1", "pep2"),
    sample_id = c("s1", "s2"),
    exist = c(1, 0),
    stringsAsFactors = FALSE
  )

  tmp_path <- withr::local_tempfile(fileext = ".parquet")

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

  expect_true(isTRUE(
    all.equal(tibble::as_tibble(df), exported_df, check.attributes = FALSE)
  ))
})

test_that("additional join wrappers return phip_data", {
  df <- data.frame(
    peptide_id = c("pep1", "pep2"),
    sample_id = c("s1", "s2"),
    exist = c(1, 0),
    stringsAsFactors = FALSE
  )
  pd <- phiperio::create_data(
    data_long = df,
    peptide_library = FALSE,
    auto_expand = FALSE
  )
  other <- data.frame(
    peptide_id = c("pep1", "pep2"),
    sample_id = c("s1", "s2"),
    extra = c(10, 20),
    stringsAsFactors = FALSE
  )

  expect_s3_class(
    dplyr::right_join(pd, other, by = c("sample_id", "peptide_id")),
    "phip_data"
  )
  expect_s3_class(
    dplyr::inner_join(pd, other, by = c("sample_id", "peptide_id")),
    "phip_data"
  )
  expect_s3_class(
    dplyr::full_join(pd, other, by = c("sample_id", "peptide_id")),
    "phip_data"
  )
  expect_s3_class(
    dplyr::semi_join(pd, other, by = c("sample_id", "peptide_id")),
    "phip_data"
  )
})
