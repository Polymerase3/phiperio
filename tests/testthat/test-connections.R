test_that(".ph_refresh_finalizer updates finalizer connection list", {
  con1 <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con1, shutdown = TRUE), add = TRUE)

  con2 <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con2, shutdown = TRUE), add = TRUE)

  df <- data.frame(
    sample_id = c("s1", "s1", "s2", "s2"),
    peptide_id = c("p1", "p2", "p1", "p2"),
    exist = c(1, 0, 0, 1),
    stringsAsFactors = FALSE
  )

  pd <- phiperio::create_data(
    data_long = df,
    peptide_library = FALSE,
    auto_expand = FALSE,
    meta = list(con = con1)
  )

  lib <- data.frame(
    peptide_id = c("p1", "p2"),
    stringsAsFactors = FALSE
  )
  attr(lib, "duckdb_con") <- con2
  pd$peptide_library <- lib
  pd$meta$peptide_con <- con2

  fin <- new.env(parent = emptyenv())
  fin$connections <- list("stale")
  pd$meta$finalizer_env <- fin

  pd <- phiperio:::.ph_refresh_finalizer(pd)

  expect_true(is.environment(pd$meta$finalizer_env))
  expect_equal(length(pd$meta$finalizer_env$connections), 2)
  expect_true(any(vapply(pd$meta$finalizer_env$connections, identical,
                         logical(1), con1)))
  expect_true(any(vapply(pd$meta$finalizer_env$connections, identical,
                         logical(1), con2)))
})

test_that(".ph_clear_connections clears peptide_con and library attr", {
  con1 <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con1, shutdown = TRUE), add = TRUE)

  con2 <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con2, shutdown = TRUE), add = TRUE)

  df <- data.frame(
    sample_id = c("s1", "s1", "s2", "s2"),
    peptide_id = c("p1", "p2", "p1", "p2"),
    exist = c(1, 0, 0, 1),
    stringsAsFactors = FALSE
  )

  pd <- phiperio::create_data(
    data_long = df,
    peptide_library = FALSE,
    auto_expand = FALSE,
    meta = list(con = con1, peptide_con = con2, finalizer_env = new.env())
  )

  lib <- new.env(parent = emptyenv())
  attr(lib, "duckdb_con") <- con2
  pd$peptide_library <- lib

  pd <- phiperio:::.ph_clear_connections(pd)

  expect_null(pd$meta$con)
  expect_null(pd$meta$peptide_con)
  expect_null(pd$meta$finalizer_env)
  expect_null(attr(pd$peptide_library, "duckdb_con"))
})
