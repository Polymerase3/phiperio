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
