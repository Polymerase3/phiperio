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
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpG87kB5/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [10:05:31] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [10:05:31] INFO  Fetching peptide metadata library via get_peptide_library()
#> [10:05:31] INFO  Retrieving peptide metadata into DuckDB cache
#>                  -> get_peptide_library(force_refresh = FALSE)
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/RtmpG87kB5/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [10:05:31] INFO  Opened DuckDB connection
#>                    - cache dir:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/phip_cache.duckdb
#>                    - table: peptide_meta
#> [10:05:31] INFO  Starting download
#>                    - dest:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/combined_library_06.07.26.rds
#> [10:05:33] OK    Download succeeded (method = <getOption()>)
#> [10:05:33] OK    Checksum verified (SHA-256 match)
#> [10:05:35] OK    Download complete and loaded into R
#> [10:05:38] INFO  Importing sanitized metadata into DuckDB cache...
#> [10:05:40] OK    peptide_meta table created in DuckDB cache
#> [10:05:40] OK    Retrieving peptide metadata into DuckDB cache - done
#>                  -> elapsed: 8.516s
#> [10:05:40] OK    Peptide metadata acquired
#> [10:05:40] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [10:05:40] INFO  Checking structural requirements (shape & mandatory columns)
#> [10:05:40] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [10:05:40] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [10:05:40] INFO  Ensuring all columns are atomic (no list-cols)
#> [10:05:40] INFO  Checking key uniqueness
#> [10:05:40] INFO  Validating value ranges & types for outcomes
#> Warning: Missing values are always removed in SQL aggregation functions.
#> Use `na.rm = TRUE` to silence this warning
#> This warning is displayed once every 8 hours.
#> [10:05:40] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [10:05:40] INFO  Checking peptide_id coverage against peptide_library
#> [10:05:40] INFO  Checking full grid completeness (peptide * sample)
#> [10:05:40] INFO  Counts table is not a full peptide * sample grid
#>                    - observed rows: 78200
#>                    - expected rows: 156000
#> Warning: [10:05:40] WARN  Grid remains incomplete (auto_expand = FALSE).
#>                  -> grid completeness
#>                    - observed rows: 78200
#>                    - expected rows: 156000.
#> [10:05:40] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.331s
#> [10:05:40] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 8.849s
pd <- add_exist(pd, overwrite = TRUE) # overwrites if present
#> [10:05:40] INFO  Ensuring existence flag on data_long
#>                  -> column: 'exist'; overwrite: TRUE
#> Warning: [10:05:40] WARN  Overwriting existing existence flag.
#>                  -> adding existence indicator
#>                    - column: "exist".
#> [10:05:40] OK    Ensuring existence flag on data_long - done
#>                  -> elapsed: 0.005s
```
