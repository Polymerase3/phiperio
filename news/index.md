# Changelog

## phiperio 0.5.0

- Added `sample_id_from_filenames` to
  [`convert_standard()`](https://polymerase3.github.io/phiperio/reference/convert_standard.md)
  to derive sample IDs from file stems when ingesting a directory of
  CSV/Parquet files; added tests.
- New vignettes: “Importing multiple files with phiperio” (batch
  ingest + filename-derived sample IDs), and “Importing legacy PhIP-Seq
  data (convert_legacy)” for compact cross-sectional/longitudinal
  examples; updated “Importing long tidy data” with clearer workflows.
- README/pkgdown refreshed: links to all vignettes, navigation updated,
  minimal section removed.
- Robustified example handling and filename conflicts for vignette
  builds.
- Version bumped to 0.5.0.

## phiperio 0.4.0

- Make examples self-contained and reliable: fix
  [`convert_standard()`](https://polymerase3.github.io/phiperio/reference/convert_standard.md)
  example to use a temp CSV, switch
  [`expand_data()`](https://polymerase3.github.io/phiperio/reference/expand_data.md)
  example to
  [`load_example_data()`](https://polymerase3.github.io/phiperio/reference/load_example_data.md),
  and remove examples for internal helpers.
- Remove all `\donttest{}` / `\dontrun{}` wrappers from examples in R
  and Rd files so they run during checks.
- Harden
  [`load_example_data()`](https://polymerase3.github.io/phiperio/reference/load_example_data.md)
  caching by rebuilding when a cached object’s DuckDB connection is no
  longer valid.
- Significantly improved coverage.

## phiperio 0.3.0

- Rename exported API to verb_noun naming (e.g., `create_data`,
  `convert_standard`, `convert_legacy`, `load_example_data`,
  `get_example_path`, `expand_data`) and align docs/tests.
- Rename internal helpers to `.ph_` prefix and add internal roxygen
  docs.
- Reorganize `R/utils.R` into themed sections with clearer helper
  descriptions.
- Centralize connection teardown via
  [`close.phip_data()`](https://polymerase3.github.io/phiperio/reference/close.phip_data.md)
  with GC finalizer and connection sync helpers.
- Persist peptide metadata cache in user cache dir and reuse cached
  downloads with SHA-256 validation.
- Improve peptide library preview columns in `print.phip_data()`.
- Update file naming under `R/` to a consistent convention.
- Adjust validation flow to reduce duplication around full-grid checks.
- Update DESCRIPTION metadata (title, authors, description,
  dependencies).

## phiperio 0.2.0

- Remove all comparisons/contrasts mechanics, validation, tests, and
  mock files.
- Add centralized connection teardown via
  [`close.phip_data()`](https://polymerase3.github.io/phiperio/reference/close.phip_data.md)
  and internal helpers; attach an auto-finalizer for GC cleanup.
- Reduce duplicate validation by consolidating full-grid checks in
  [`validate_phip_data()`](https://polymerase3.github.io/phiperio/reference/validate_phip_data.md)
  and adding optional validation toggles for expansion.
- Clean unused globals in `R/zzz.R` and remove unused utils helpers.
- Update tests and docs to reflect the new API and validation flow.

## phiperio 0.1.0

- Initial release with IO/convert functionality migrated from phiper.
