# phiperio 0.5.5

- `validate_phip_data()` no longer reports `agilent_0` and `twist_0` as missing
  from the peptide library. Both are the FLAG-tag (`DYKDDDDK`) spike-in control
  rather than biological peptides: they carry no protein, position or taxonomy,
  and are absent from the reference library, so the warning was never
  actionable.
- `create_data()` now accepts a peptide-library table for `peptide_library`, as
  its documentation always claimed. The argument was previously only a logical
  switch (`if (peptide_library)`), so passing the documented data frame failed
  with "the condition has length > 1" and `NULL` with "argument is of length
  zero". `TRUE` and `FALSE` behave as before; a value that is neither a logical
  nor a table is now rejected with an explicit message.
- Corrected the `materialise_table` documentation in `create_data()`, which
  labelled `FALSE` as the default when the default is `TRUE`.

# phiperio 0.5.4 (2026-08-31)

- `.ph_sha256_file()` now hashes files with `digest` instead of shelling out to
  the `sha256sum` command, which does not exist on Windows. There, the helper
  always returned `NA` and `.ph_download_file()` reported that as a checksum
  mismatch, so the integrity check on the downloaded peptide library never
  actually verified anything on that platform.
- Tests now pin `duckdb.home` to a temporary directory. duckdb 1.5.5 resolves a
  storage location on every `duckdb()` driver and announces it in
  non-interactive sessions unless one is chosen explicitly, which broke tests
  asserting that a call produces no output.

# phiperio 0.5.3 (2026-08-31)

- Declared `curl` in `Suggests`. `testthat::skip_if_offline()` calls
  `rlang::check_installed("curl")`, which errors rather than skips in a
  non-interactive session, so the live peptide-library test failed R CMD check
  on runners where `curl` was not installed.
- Regenerated `inst/extdata/phip_mixture.parquet` so its `peptide_id` values are
  drawn from the reference peptide library instead of bare integer indices. The
  example data previously matched no peptide in the library, which made
  `load_example_data()` warn about missing coverage for every peptide. The
  simulated values are unchanged; only the identifiers were remapped.
- `validate_phip_data()` no longer warns that the counts table is not a full
  peptide * sample grid when `auto_expand = TRUE` immediately fills it; the
  condition is logged instead. With `auto_expand = FALSE` a single warning is
  emitted rather than two carrying identical row counts.
- The peptide-library coverage warning now reports how many `peptide_id` values
  are missing and shows up to three of them, instead of a single example that
  understated the size of a mismatch.

# phiperio 0.5.2 (2026-07-08)

- Fixed `get_peptide_library()` silently coercing alphanumeric ID-like
  columns (e.g. `protein_id` values such as `"agilent_1"`) to all-`NA`. The
  character-to-numeric sanitizer previously matched any string containing a
  digit; it now requires the value to fully parse as numeric.
- Added a regression test for the fix and a live test that flags checksum
  drift against the published library and any column collapsing to all-`NA`
  during sanitization.

# phiperio 0.5.1

- Updated the peptide metadata library used by `get_peptide_library()` to
  `combined_library_06.07.26.rds` (with matching SHA-256 checksum) from the
  `Polymerase3/phiper` repository.

# phiperio 0.5.0

- Added `sample_id_from_filenames` to `convert_standard()` to derive sample IDs
  from file stems when ingesting a directory of CSV/Parquet files; added tests.
- New vignettes: “Importing multiple files with phiperio” (batch ingest +
  filename-derived sample IDs), and “Importing legacy PhIP-Seq data
  (convert_legacy)” for compact cross-sectional/longitudinal examples; updated
  “Importing long tidy data” with clearer workflows.
- README/pkgdown refreshed: links to all vignettes, navigation updated, minimal
  section removed.
- Robustified example handling and filename conflicts for vignette builds.
- Version bumped to 0.5.0.

# phiperio 0.4.0

- Make examples self-contained and reliable: fix `convert_standard()` example
  to use a temp CSV, switch `expand_data()` example to `load_example_data()`,
  and remove examples for internal helpers.
- Remove all `\donttest{}` / `\dontrun{}` wrappers from examples in R and Rd
  files so they run during checks.
- Harden `load_example_data()` caching by rebuilding when a cached object’s
  DuckDB connection is no longer valid.
- Significantly improved coverage.

# phiperio 0.3.0

- Rename exported API to verb_noun naming (e.g., `create_data`, `convert_standard`,
  `convert_legacy`, `load_example_data`, `get_example_path`, `expand_data`) and
  align docs/tests.
- Rename internal helpers to `.ph_` prefix and add internal roxygen docs.
- Reorganize `R/utils.R` into themed sections with clearer helper descriptions.
- Centralize connection teardown via `close.phip_data()` with GC finalizer and
  connection sync helpers.
- Persist peptide metadata cache in user cache dir and reuse cached downloads
  with SHA-256 validation.
- Improve peptide library preview columns in `print.phip_data()`.
- Update file naming under `R/` to a consistent convention.
- Adjust validation flow to reduce duplication around full-grid checks.
- Update DESCRIPTION metadata (title, authors, description, dependencies).

# phiperio 0.2.0

- Remove all comparisons/contrasts mechanics, validation, tests, and mock files.
- Add centralized connection teardown via `close.phip_data()` and internal
  helpers; attach an auto-finalizer for GC cleanup.
- Reduce duplicate validation by consolidating full-grid checks in
  `validate_phip_data()` and adding optional validation toggles for expansion.
- Clean unused globals in `R/zzz.R` and remove unused utils helpers.
- Update tests and docs to reflect the new API and validation flow.

# phiperio 0.1.0

- Initial release with IO/convert functionality migrated from phiper.
