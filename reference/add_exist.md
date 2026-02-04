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
#> [12:00:08] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [12:00:08] INFO  Fetching peptide metadata library via get_peptide_library()
#> [12:00:08] INFO  Retrieving peptide metadata into DuckDB cache
#>                  -> get_peptide_library(force_refresh = FALSE)
#> [12:00:08] INFO  Opened DuckDB connection
#>                    - cache dir:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/phip_cache.duckdb
#>                    - table: peptide_meta
#> [12:00:08] INFO  Starting download
#>                    - dest:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/combined_library_15.01.26.rds
#> [12:00:08] OK    Download succeeded (method = <getOption()>)
#> [12:00:09] OK    Checksum verified (SHA-256 match)
#> [12:00:11] OK    Download complete and loaded into R
#> [12:00:17] INFO  Importing sanitized metadata into DuckDB cache...
#> [12:00:18] OK    peptide_meta table created in DuckDB cache
#> [12:00:18] OK    Retrieving peptide metadata into DuckDB cache - done
#>                  -> elapsed: 9.995s
#> [12:00:18] OK    Peptide metadata acquired
#> [12:00:18] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [12:00:18] INFO  Checking structural requirements (shape & mandatory columns)
#> [12:00:18] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [12:00:18] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [12:00:18] INFO  Ensuring all columns are atomic (no list-cols)
#> [12:00:18] INFO  Checking key uniqueness
#> [12:00:18] INFO  Validating value ranges & types for outcomes
#> Warning: Missing values are always removed in SQL aggregation functions.
#> Use `na.rm = TRUE` to silence this warning
#> This warning is displayed once every 8 hours.
#> [12:00:18] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [12:00:19] INFO  Checking peptide_id coverage against peptide_library
#> Warning: [12:00:19] WARN  peptide_id not found in peptide_library (e.g. 10003)
#>                  -> peptide library coverage.
#> [12:00:19] INFO  Checking full grid completeness (peptide * sample)
#> Warning: [12:00:19] WARN  Counts table is not a full peptide * sample grid.
#>                  -> grid completeness
#>                    - observed rows: 78200
#>                    - expected rows: 156000.
#> Warning: [12:00:19] WARN  Grid remains incomplete (auto_expand = FALSE).
#>                  -> grid completeness
#>                    - observed rows: 78200
#>                    - expected rows: 156000.
#> [12:00:19] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.664s
#> [12:00:19] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 10.662s
pd <- add_exist(pd, overwrite = TRUE) # overwrites if present
#> [12:00:19] INFO  Ensuring existence flag on data_long
#>                  -> column: 'exist'; overwrite: TRUE
#> Warning: [12:00:19] WARN  Overwriting existing existence flag.
#>                  -> adding existence indicator
#>                    - column: "exist".
#> [12:00:19] OK    Ensuring existence flag on data_long - done
#>                  -> elapsed: 0.008s
```
