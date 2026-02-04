# Retrieve the peptide metadata table into DuckDB, forcing atomic types

This function uses the phiperio logging utilities for consistent,
ASCII-only progress messages and timing. Long-running steps are
bracketed with
[`.ph_with_timing()`](https://polymerase3.github.io/phiperio/reference/dot-ph_with_timing.md),
and informational/warning/error messages are emitted via
[`.ph_log_info()`](https://polymerase3.github.io/phiperio/reference/dot-ph_log_info.md),
[`.ph_log_ok()`](https://polymerase3.github.io/phiperio/reference/dot-ph_log_ok.md),
[`.ph_warn()`](https://polymerase3.github.io/phiperio/reference/dot-ph_warn.md),
and
[`.ph_abort()`](https://polymerase3.github.io/phiperio/reference/dot-ph_abort.md).

- Downloads the RDS once, sanitizes types (logical, character, numeric),
  and writes into a DuckDB cache on disk.

- Subsequent calls return a lazy `tbl_dbi` without loading into R
  memory.

## Usage

``` r
get_peptide_library(force_refresh = FALSE)
```

## Arguments

- force_refresh:

  Logical. If `TRUE`, re-downloads and rebuilds the cache.

## Value

A `dplyr::tbl_dbi` pointing to the `peptide_meta` table. The returned
object carries an attribute `"duckdb_con"` with the open `DBI`
connection.

## Details

**Caching:** A persistent DuckDB database is created under the user
cache directory (via `tools::R_user_dir("phiperio", "cache")`). You can
override this location with `options(phiperio.cache_dir = \"...\")`. The
`force_refresh` argument bypasses the fast path and rebuilds the cache.

**Sanitization:** Columns are stripped of attributes, list-columns are
flattened, textual `"NaN"` and numeric `NaN` are coerced to `NA`. Binary
0/1 fields are converted to `logical`, `"TRUE"/"FALSE"`
(case-insensitive) are converted to `logical`, and numeric-looking
character columns (beyond trivial 0/1) are converted to `numeric`. All
other atomic types are preserved.

**Integrity check:** If a SHA-256 checksum is provided, a warning is
logged when the downloaded file’s checksum does not match the expected
value.

## See also

[`dplyr::tbl()`](https://dplyr.tidyverse.org/reference/tbl.html),
[`DBI::dbConnect()`](https://dbi.r-dbi.org/reference/dbConnect.html),
[`duckdb::duckdb()`](https://r.duckdb.org/reference/duckdb.html)

## Examples

``` r
lib <- get_peptide_library()
#> [11:52:09] INFO  Retrieving peptide metadata into DuckDB cache
#>                  -> get_peptide_library(force_refresh = FALSE)
#> [11:52:09] INFO  Opened DuckDB connection
#>                    - cache dir:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/phip_cache.duckdb
#>                    - table: peptide_meta
#> [11:52:09] OK    Using cached peptide_meta (fast path)
#> [11:52:09] OK    Retrieving peptide metadata into DuckDB cache - done
#>                  -> elapsed: 0.04s
```
