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
