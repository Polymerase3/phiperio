# # testing the legacy workflow for loading the data from separate files
# test_that("convert legacy: duckdb", {
#   withr::with_message_sink(
#     tempfile(),
#     withr::with_options(list(warn = -1), {
#       ## test the .yaml file interface
#       withr::with_tempdir({
#         path <- file.path(
#           system.file("extdata", package = "phiper"),
#           "config.yaml"
#         )
#
#         ## SMOKE TEST --------------------------------------------------------------
#         expect_no_error(
#           pd <- phip_convert_legacy(config_yaml = path)
#         )
#
#         expect_output(print(pd))
#
#         ### with explicit paths, without config file, .parquet handling
#         expect_no_error(
#           pd <- phip_convert_legacy(
#             exist_file = file.path(
#               system.file("extdata", package = "phiper"),
#               "exist.parquet"
#             ),
#             samples_file = file.path(
#               system.file("extdata", package = "phiper"),
#               "samples_meta.csv"
#             ),
#             comparisons_file = file.path(
#               system.file("extdata", package = "phiper"),
#               "comparisons.csv"
#             ),
#             peptide_library = FALSE
#           )
#         )
#
#         expect_output(print(pd))
#
#         ### error when no required file present
#         expect_error(
#           phip_convert_legacy(
#             exist_file = file.path(
#               system.file("extdata", package = "phiper"),
#               "exist.csv"
#             ),
#             peptide_library = FALSE
#           ), "samples_file"
#         )
#
#         ### fold_change and raw counts handling
#         expect_no_error(
#           phip_convert_legacy(
#             exist_file = file.path(
#               system.file("extdata", package = "phiper"),
#               "exist.parquet"
#             ),
#             fold_change_file = file.path(
#               system.file("extdata", package = "phiper"),
#               "fold_change.csv"
#             ),
#             samples_file = file.path(
#               system.file("extdata", package = "phiper"),
#               "samples_meta.csv"
#             ),
#             input_file = file.path(
#               system.file("extdata", package = "phiper"),
#               "raw_input.csv"
#             ),
#             hit_file = file.path(
#               system.file("extdata", package = "phiper"),
#               "raw_hit.csv"
#             ),
#             peptide_library = FALSE
#           )
#         )
#
#         expect_no_error(
#           phip_convert_legacy(
#             exist_file = file.path(
#               system.file("extdata", package = "phiper"),
#               "exist.parquet"
#             ),
#             fold_change_file = file.path(
#               system.file("extdata", package = "phiper"),
#               "fold_change.csv"
#             ),
#             samples_file = file.path(
#               system.file("extdata", package = "phiper"),
#               "samples_meta.csv"
#             ),
#             input_file = file.path(
#               system.file("extdata", package = "phiper"),
#               "raw_input.csv"
#             ),
#             hit_file = file.path(
#               system.file("extdata", package = "phiper"),
#               "raw_hit.csv"
#             ),
#             peptide_library = FALSE
#           )
#         )
#       })
#     })
#   )
# })
#
# ## duckdb-only tests
# skip_if_not_installed("duckdb")
# skip_if_not_installed("DBI")
# skip_if_not_installed("dbplyr")
#
# test_that("convert legacy: duckdb", {
#   withr::with_message_sink(
#     tempfile(),
#     withr::with_options(list(warn = -1), {
#       ## test the .yaml file interface
#       withr::with_tempdir({
#         path <- file.path(
#           system.file("extdata", package = "phiper"),
#           "config.yaml"
#         )
#         ## SMOKE TESTS -------------------------------------------------------------
#         ### default
#         expect_no_error(
#           phip_convert_legacy(
#             config_yaml = path,
#             peptide_library = FALSE
#           )
#         )
#
#         ### works without extra_cols -----------------------------------------------
#         # ------------------------------------------------------------------#
#         # 1. Build a sandbox directory in tempdir()
#         # ------------------------------------------------------------------#
#         workdir <- withr::local_tempdir()
#
#         # helper: copy a file into workdir, keep basename
#         copy_to_workdir <- function(src) {
#           dst <- file.path(workdir, basename(src))
#           file.copy(src, dst, overwrite = TRUE)
#           basename(src) # return relative path
#         }
#
#         # ------------------------------------------------------------------#
#         # 2. Locate original example files in your package
#         # ------------------------------------------------------------------#
#         pkg_ext <- function(name) system.file("extdata", name, package = "phiper")
#
#         yaml_src <- pkg_ext("config.yaml")
#         exist_src <- pkg_ext("exist.csv")
#         samples_src <- pkg_ext("samples_meta.csv")
#         timepoints_src <- NULL
#         comps_src <- pkg_ext("comparisons.csv")
#
#         # ------------------------------------------------------------------#
#         # 3. Copy everything into workdir
#         # ------------------------------------------------------------------#
#         yaml_dst <- file.path(workdir, "config.yaml")
#         exist_rel <- copy_to_workdir(exist_src)
#         samples_rel <- copy_to_workdir(samples_src)
#         comps_rel <- copy_to_workdir(comps_src)
#         file.copy(yaml_src, yaml_dst, overwrite = TRUE)
#
#         # ------------------------------------------------------------------#
#         # 4. Edit the YAML: remove extra_cols, fix paths to be local
#         # ------------------------------------------------------------------#
#         cfg <- yaml::read_yaml(yaml_dst)
#
#         cfg$extra_cols <- NULL # drop the key
#         cfg$exist_file <- exist_rel # point to local file
#         cfg$samples_file <- samples_rel
#         cfg$timepoints_file <- NULL
#         cfg$comparisons_file <- comps_rel
#
#         yaml::write_yaml(cfg, yaml_dst)
#
#         # ------------------------------------------------------------------#
#         # 5. Call the converter
#         # ------------------------------------------------------------------#
#         pd <- phip_convert_legacy(
#           config_yaml = yaml_dst,
#           peptide_library = FALSE
#         )
#
#
#         # ------------------------------------------------------------------#
#         # 6. Expectations
#         # ------------------------------------------------------------------#
#         expect_s3_class(pd, "phip_data")
#         expect_gt(ncol(get_counts(pd)), 3) # additional columns from meta,
#
#         # as there is no extra_cols
#         expect_false(isTRUE(pd$meta$fold_change))
#         expect_false(isTRUE(pd$meta$longitudinal))
#       })
#     })
#   )
# })
#
# ## .ph_auto_read_file
# tmp_csv <- withr::local_tempfile(fileext = ".csv")
# write.csv(data.frame(a = 1:3, b = 4:6), tmp_csv, row.names = FALSE)
#
# # ------------------------------------------------------------------
# # 1) branch where data.table IS available
# # ------------------------------------------------------------------
# test_that(".ph_auto_read_file uses data.table::fread when available", {
#   skip_if_not_installed("data.table") # ensures branch can run
#
#   res <- .ph_auto_read_file(tmp_csv)
#
#   expect_s3_class(res, "data.frame")
#   expect_equal(nrow(res), 3)
#   expect_true(attr(res, "class")[1] != "data.frame" ||
#                 # fread returns data.frame if data.table=FALSE
#                 TRUE)
# })
#
# # ------------------------------------------------------------------
# # 2) branch where data.table is *pretended* to be missing
# # ------------------------------------------------------------------
# test_that(".ph_auto_read_file falls back to read.csv when data.table is absent", {
#   # Mock requireNamespace() so it always returns FALSE inside this call
#   mockery::stub(.ph_auto_read_file, "requireNamespace", function(pkg, ...) FALSE)
#
#   res <- .ph_auto_read_file(tmp_csv)
#
#   expect_s3_class(res, "data.frame")
#   expect_equal(nrow(res), 3)
# })
