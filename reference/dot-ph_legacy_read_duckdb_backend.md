# Build legacy tables in DuckDB for conversion

`.ph_legacy_read_duckdb_backend()` loads legacy CSV/parquet inputs into
temporary DuckDB tables, reshapes them into a long format, and prepares
the final tables used by
[`convert_legacy()`](https://polymerase3.github.io/phiperio/reference/convert_legacy.md).

## Usage

``` r
.ph_legacy_read_duckdb_backend(cfg, meta)
```

## Arguments

- cfg:

  Named list of resolved file paths and options from
  [`.ph_resolve_paths()`](https://polymerase3.github.io/phiperio/reference/dot-ph_resolve_paths.md).

- meta:

  List of preprocessed metadata tables from
  [`.ph_legacy_prepare_metadata()`](https://polymerase3.github.io/phiperio/reference/dot-ph_legacy_prepare_metadata.md).

## Value

A DuckDB DBI connection containing the temporary and final tables needed
for the legacy conversion.

## Details

- No rows are collected into R; all transformations are executed in
  DuckDB.

- The caller is responsible for closing the returned connection.
