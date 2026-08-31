# duckdb >= 1.5.5 resolves a "home" for its extensions and stored secrets on
# every duckdb() driver, and emits an advisory message about that location in
# non-interactive sessions unless one is chosen explicitly (see
# ?duckdb_storage). Point it at a per-session temp directory so tests that
# assert on silence keep testing our own output rather than duckdb's notice.
withr::local_options(
  list(duckdb.home = file.path(tempdir(), "duckdb-home")),
  .local_envir = testthat::teardown_env()
)
