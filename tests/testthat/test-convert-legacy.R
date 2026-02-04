test_that("convert_legacy reads config yaml with timepoints", {

  ext <- system.file("extdata", package = "phiperio")
  cfg <- file.path(ext, "config.yaml")

  pd <- expect_warning(
    withr::with_message_sink(tempfile(), {
      convert_legacy(
        config_yaml = cfg,
        peptide_library = FALSE
      )
    }),
    "output_dir"
  )

  expect_s3_class(pd, "phip_data")

  cols <- colnames(pd$data_long)
  expect_true(all(c("sample_id", "peptide_id", "exist") %in% cols))
  expect_true(all(c("subject_id", "timepoint") %in% cols))

  expect_true(isTRUE(pd$meta$exist))
  expect_true(isTRUE(pd$meta$longitudinal))
  expect_false(isTRUE(pd$meta$fold_change))
  expect_true(all(c("Sex", "Age") %in% pd$meta$extra_cols))
})

test_that("convert_legacy accepts explicit paths and parquet inputs", {
  ext <- system.file("extdata", package = "phiperio")

  pd <- withr::with_message_sink(tempfile(), {
    convert_legacy(
      exist_file = file.path(ext, "exist.parquet"),
      fold_change_file = file.path(ext, "fold_change.csv"),
      input_file = file.path(ext, "raw_input.csv"),
      hit_file = file.path(ext, "raw_hit.csv"),
      samples_file = file.path(ext, "samples_meta.csv"),
      timepoints_file = NULL,
      peptide_library = FALSE
    )
  })

  expect_s3_class(pd, "phip_data")

  cols <- colnames(pd$data_long)
  expect_true(all(c("exist", "fold_change") %in% cols))
  expect_true(all(c("input_count", "hit_count") %in% cols))
  expect_false(any(c("Sex", "Age") %in% cols))

  expect_true(isTRUE(pd$meta$exist))
  expect_true(isTRUE(pd$meta$fold_change))
  expect_false(isTRUE(pd$meta$longitudinal))
  expect_true(all(c("input_count", "hit_count") %in% pd$meta$extra_cols))
})
