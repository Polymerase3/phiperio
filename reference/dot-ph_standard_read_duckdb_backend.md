# Read and register "long" phiperio data into a DuckDB-backed database

This internal function ingests one or more data files (Parquet or CSV)
specified by `cfg$data_long_path` into a single DuckDB view named
`data_long`, applying user-provided column mappings (`colmap`) to rename
each source column to the standard PHIPERIO names. The resulting
`phip_data` object contains a lazy DuckDB table that can be queried with
dplyr without loading the full dataset into R until explicitly
collected.

## Usage

``` r
.ph_standard_read_duckdb_backend(cfg, colmap)
```

## Arguments

- cfg:

  Named list, must contain element `data_long_path` pointing to either a
  single file or a directory of files. Supported file extensions are
  `.parquet`, `.parq`, `.pq`, and `.csv`.

- colmap:

  Named character list mapping **standard** PHIPERIO column names (e.g.
  `"sample_id"`, `"peptide_id"`, ...) to the **actual** column names
  found in the source files.

## Value

A `phip_data` S3/S4 object (depending on your package implementation)
whose `data_long` slot is a `dplyr::tbl_dbi` representing the union of
all source files. Calculations against `data_long` remain lazy until
`collect()` is called.

## Details

- If `cfg$data_long_path` is a **directory**, all matching files within
  it are UNION ALL'ed.

- Parquet files are read via `parquet_scan()`, CSV via
  `read_csv_auto()`.

- Column renaming is performed in SQL with `AS`, so no R-level
  `rename()` calls are needed.

- A DuckDB **VIEW** called `data_long` is created (dropped if it existed
  previously) for downstream queries.
