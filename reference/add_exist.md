# Ensure an existence flag (all ones) on `data_long`

Appends/overwrites a column (default: "exist") filled with 1L on the
lazy `data_long` table. Preserves laziness; no collection is forced.

## Usage

``` r
add_exist(phip_data, exist_col = "exist", overwrite = FALSE)
```

## Arguments

- phip_data:

  A \<phip_data\> object.

- exist_col:

  Name of the existence column to append/overwrite.

- overwrite:

  If FALSE and the column exists, abort with a phiperio-style error.

## Value

Modified \<phip_data\> with updated `data_long`.

## Examples

``` r
pd <- load_example_data()
#> duckdb: caching downloaded extensions in the package library:
#> ℹ /home/runner/work/_temp/Library/duckdb/extensions
#> ℹ This is removed when the package is re-installed; see `?duckdb_storage` to choose a different location.
#> [07:31:24] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [07:31:24] INFO  Fetching peptide metadata library via get_peptide_library()
#> [07:31:24] INFO  Retrieving peptide metadata into DuckDB cache
#>                  -> get_peptide_library(force_refresh = FALSE)
#> [07:31:24] INFO  Opened DuckDB connection
#>                    - cache dir:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/phip_cache.duckdb
#>                    - table: peptide_meta
#> [07:31:24] INFO  Starting download
#>                    - dest:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/combined_library_06.07.26.rds
#> [07:31:24] OK    Download succeeded (method = <getOption()>)
#> [07:31:24] OK    Checksum verified (SHA-256 match)
#> [07:31:27] OK    Download complete and loaded into R
#> [07:31:32] INFO  Importing sanitized metadata into DuckDB cache...
#> [07:31:34] OK    peptide_meta table created in DuckDB cache
#> [07:31:34] OK    Retrieving peptide metadata into DuckDB cache - done
#>                  -> elapsed: 9.553s
#> [07:31:34] OK    Peptide metadata acquired
#> [07:31:34] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [07:31:34] INFO  Checking structural requirements (shape & mandatory columns)
#> [07:31:34] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [07:31:34] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [07:31:34] INFO  Ensuring all columns are atomic (no list-cols)
#> [07:31:34] INFO  Checking key uniqueness
#> [07:31:34] INFO  Validating value ranges & types for outcomes
#> Warning: Missing values are always removed in SQL aggregation functions.
#> Use `na.rm = TRUE` to silence this warning
#> This warning is displayed once every 8 hours.
#> [07:31:34] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [07:31:34] INFO  Checking peptide_id coverage against peptide_library
#> Warning: [07:31:34] WARN  peptide_id not found in peptide_library (e.g. 10003)
#>                  -> peptide library coverage.
#> [07:31:34] INFO  Checking full grid completeness (peptide * sample)
#> Warning: [07:31:34] WARN  Counts table is not a full peptide * sample grid.
#>                  -> grid completeness
#>                    - observed rows: 78200
#>                    - expected rows: 156000.
#> Warning: [07:31:34] WARN  Grid remains incomplete (auto_expand = FALSE).
#>                  -> grid completeness
#>                    - observed rows: 78200
#>                    - expected rows: 156000.
#> [07:31:34] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.444s
#> [07:31:34] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 10s
pd <- add_exist(pd, overwrite = TRUE) # overwrites if present
#> [07:31:34] INFO  Ensuring existence flag on data_long
#>                  -> column: 'exist'; overwrite: TRUE
#> Warning: [07:31:34] WARN  Overwriting existing existence flag.
#>                  -> adding existence indicator
#>                    - column: "exist".
#> [07:31:34] OK    Ensuring existence flag on data_long - done
#>                  -> elapsed: 0.008s
```
