skip_if_not_installed("chk")

# -------------------------------------------------------------------------
# .chk_cond ----------------------------------------------------------------
# -------------------------------------------------------------------------
test_that(".chk_cond emits errors and warnings correctly", {
  expect_error(
    .chk_cond(TRUE,
      "boom",
      error = TRUE
    ),
    label = "boom"
  )

  expect_warning(
    .chk_cond(TRUE,
      "soft boom",
      error = FALSE
    ),
    label = "soft_boom"
  )

  # When condition is FALSE nothing happens
  expect_silent(.chk_cond(FALSE, "no-op"))
})

# -------------------------------------------------------------------------
# .chk_extension -----------------------------------------------------------
# -------------------------------------------------------------------------
test_that(".chk_extension passes correct ext and fails otherwise", {
  # good
  expect_silent(
    .chk_extension("file.TSV", "file", c("tsv", "csv"))
  )

  # bad
  expect_error(
    .chk_extension("file.bad", "file", c("tsv", "csv")),
    class = "chk_error"
  )
})

# -------------------------------------------------------------------------
# .chk_null_default --------------------------------------------------------
# -------------------------------------------------------------------------
test_that(".chk_null_default returns original or default", {
  expect_equal(
    .chk_null_default(5, "x", "m", 10),
    5
  )

  withr::with_options(list(warn = 1), {
    expect_warning(
      out <- .chk_null_default(NULL, "x", "m", 10),
      label = "method"
    )
    expect_equal(out, 10)
  })
})

# -------------------------------------------------------------------------
# .chk_path ----------------------------------------------------------------
# -------------------------------------------------------------------------
test_that(".chk_path validates path + ext", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  writeLines("test", tmp)

  # passes
  expect_silent(
    .chk_path(tmp, "arg", extension = "csv")
  )

  # fails on extension
  expect_error(
    .chk_path(tmp, "arg", extension = "tsv"),
    class = "chk_error"
  )

  # fails on non-existent path
  expect_error(
    .chk_path(file.path(tempdir(), "nope.csv"), "arg", extension = "csv"),
    class = "chk_error"
  )
})

test_that(".chk_path works for folders", {
  tmp <- withr::local_tempdir()

  # Default is is_dir=FALSE
  expect_error(
    .chk_path(tmp, "arg")
  )

  # Explicit *file* check
  expect_error(
    .chk_path(tmp, "arg", is_dir=FALSE)
  )

  # Correct folder check
  expect_silent(
    .chk_path(tmp, "arg", is_dir=TRUE)
  )

  # Both folder and extension should fail
  expect_error(
    .chk_path(tmp, "arg", c("txt", "pqt"), is_dir=TRUE)
  )

  # Non existing directory should fail
  expect_error(
    .chk_path("this/path/should/definetly/not/exist", "arg", is_dir=TRUE)
  )
})

# -------------------------------------------------------------------------
# word_list / add_quotes ---------------------------------------------------
# -------------------------------------------------------------------------
test_that("word_list and add_quotes behave", {
  expect_equal(
    as.vector(word_list(c("a", "b", "c"), and_or = "and", quotes = TRUE)),
    '"a", "b", and "c"'
  )

  expect_equal(
    attr(word_list("a"), "plural"),
    FALSE
  )

  # quotes variations
  expect_equal(add_quotes("x", quotes = FALSE), "x")
  expect_equal(add_quotes("x", quotes = TRUE), '"x"')
  expect_equal(add_quotes("x", quotes = 1), "'x'")
  expect_equal(add_quotes("x", quotes = 2), '"x"')
})
