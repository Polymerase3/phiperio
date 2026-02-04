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
#> [11:51:49] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [11:51:49] INFO  Fetching peptide metadata library via get_peptide_library()
#> [11:51:49] INFO  Retrieving peptide metadata into DuckDB cache
#>                  -> get_peptide_library(force_refresh = FALSE)
#> [11:51:49] INFO  Opened DuckDB connection
#>                    - cache dir:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/phip_cache.duckdb
#>                    - table: peptide_meta
#> [11:51:49] INFO  Starting download
#>                    - dest:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/combined_library_15.01.26.rds
#> [11:51:49] OK    Download succeeded (method = <getOption()>)
#> [11:51:49] OK    Checksum verified (SHA-256 match)
#> [11:51:52] OK    Download complete and loaded into R
#> [11:51:57] INFO  Importing sanitized metadata into DuckDB cache...
#> [11:51:59] OK    peptide_meta table created in DuckDB cache
#> [11:51:59] OK    Retrieving peptide metadata into DuckDB cache - done
#>                  -> elapsed: 9.831s
#> [11:51:59] OK    Peptide metadata acquired
#> [11:51:59] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [11:51:59] INFO  Checking structural requirements (shape & mandatory columns)
#> [11:51:59] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [11:51:59] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [11:51:59] INFO  Ensuring all columns are atomic (no list-cols)
#> [11:51:59] INFO  Checking key uniqueness
#> [11:51:59] INFO  Validating value ranges & types for outcomes
#> Warning: Missing values are always removed in SQL aggregation functions.
#> Use `na.rm = TRUE` to silence this warning
#> This warning is displayed once every 8 hours.
#> [11:51:59] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [11:51:59] INFO  Checking peptide_id coverage against peptide_library
#> Warning: [11:51:59] WARN  peptide_id not found in peptide_library (e.g. 10003)
#>                  -> peptide library coverage.
#> [11:51:59] INFO  Checking full grid completeness (peptide * sample)
#> Warning: [11:51:59] WARN  Counts table is not a full peptide * sample grid.
#>                  -> grid completeness
#>                    - observed rows: 78200
#>                    - expected rows: 156000.
#> Warning: [11:51:59] WARN  Grid remains incomplete (auto_expand = FALSE).
#>                  -> grid completeness
#>                    - observed rows: 78200
#>                    - expected rows: 156000.
#> [11:51:59] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.614s
#> [11:51:59] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 10.447s
pd <- add_exist(pd, overwrite = TRUE) # overwrites if present
#> [11:51:59] INFO  Ensuring existence flag on data_long
#>                  -> column: 'exist'; overwrite: TRUE
#> Warning: [11:51:59] WARN  Overwriting existing existence flag.
#>                  -> adding existence indicator
#>                    - column: "exist".
#> [11:51:59] OK    Ensuring existence flag on data_long - done
#>                  -> elapsed: 0.008s
```
