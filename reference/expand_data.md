# Expand to a full `sample_id * peptide_id` grid

Create the full Cartesian product of samples and peptides and join back
per-sample metadata. For rows introduced by the expansion,
numeric/integer columns are filled with `0` and logical columns with
`FALSE`, unless overridden via `fill_override`.

## Usage

``` r
expand_data(
  x,
  key_col = "sample_id",
  id_col = "peptide_id",
  fill_override = NULL,
  add_exist = FALSE,
  exist_col = "exist",
  validate = TRUE,
  ...
)
```

## Arguments

- x:

  A `<phip_data>` object.

- key_col:

  Name(s) of the sample identifier column(s). Character scalar or
  vector, e.g. `"sample_id"` or `c("subject_id", "timepoint_factor")`.

- id_col:

  Name of the peptide identifier column. Default `"peptide_id"`.

- fill_override:

  Optional named list of fill values for **introduced** rows, e.g.
  `list(present = 0L, fold_change = NA_real_)`. User-provided entries
  take precedence over the defaults.

- add_exist:

  If `TRUE`, add an integer existence flag (0/1) marking whether a row
  was present before the expansion.

- exist_col:

  Name for the existence flag. If this column already exists, it will be
  **overwritten**.

- validate:

  Logical; if `TRUE`, perform input checks for required columns and
  uniqueness. Set to `FALSE` when these checks were already performed
  upstream (e.g., inside
  [`validate_phip_data()`](https://polymerase3.github.io/phiperio/reference/validate_phip_data.md)).

- ...:

  Reserved for future extensions; currently unused.

## Value

The updated `<phip_data>` object.

## Details

Updates `x$data_long` in place (preserving laziness unless you later
`compute()` / `collect()`).

## Examples

``` r
pd <- load_example_data()
#> [07:31:41] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [07:31:41] INFO  Fetching peptide metadata library via get_peptide_library()
#> [07:31:41] INFO  Retrieving peptide metadata into DuckDB cache
#>                  -> get_peptide_library(force_refresh = FALSE)
#> [07:31:41] INFO  Opened DuckDB connection
#>                    - cache dir:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/phip_cache.duckdb
#>                    - table: peptide_meta
#> [07:31:41] OK    Using cached peptide_meta (fast path)
#> [07:31:41] OK    Retrieving peptide metadata into DuckDB cache - done
#>                  -> elapsed: 0.051s
#> [07:31:41] OK    Peptide metadata acquired
#> [07:31:41] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [07:31:41] INFO  Checking structural requirements (shape & mandatory columns)
#> [07:31:41] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [07:31:41] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [07:31:41] INFO  Ensuring all columns are atomic (no list-cols)
#> [07:31:41] INFO  Checking key uniqueness
#> [07:31:41] INFO  Validating value ranges & types for outcomes
#> [07:31:41] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [07:31:41] INFO  Checking peptide_id coverage against peptide_library
#> Warning: [07:31:42] WARN  peptide_id not found in peptide_library (e.g. 10003)
#>                  -> peptide library coverage.
#> [07:31:42] INFO  Checking full grid completeness (peptide * sample)
#> Warning: [07:31:42] WARN  Counts table is not a full peptide * sample grid.
#>                  -> grid completeness
#>                    - observed rows: 78200
#>                    - expected rows: 156000.
#> Warning: [07:31:42] WARN  Grid remains incomplete (auto_expand = FALSE).
#>                  -> grid completeness
#>                    - observed rows: 78200
#>                    - expected rows: 156000.
#> [07:31:42] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.417s
#> [07:31:42] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.47s
pd <- expand_data(pd, fill_override = list(fold_change = NA_real_))
#> [07:31:42] INFO  Expanding <phip_data> to full grid
#>                  -> updating x$data_long
#> [07:31:42] INFO  Expanding to full key * id grid
#>                  -> keys: 'sample_id'; id: 'peptide_id'
#> [07:31:42] INFO  Checking uniqueness of (key, id) pairs
#> [07:31:42] INFO  Type probe on lazy table
#>                  -> collect(head 0)
#> [07:31:42] INFO  Building Cartesian product of keys and ids
#> [07:31:42] INFO  Detecting per-key constant (recyclable) columns
#>                    - candidates: subject_id, group, timepoint, exist,
#>                      counts_control, counts_hits, fold_change
#> [07:31:42] OK    Column split decided
#>                    - recyclable: subject_id, group, timepoint
#>                    - non-recyclable: exist, counts_control, counts_hits,
#>                      fold_change
#> [07:31:42] INFO  Preparing fill defaults for introduced rows
#>                    - numeric/integer: exist, fold_change, counts_control,
#>                      counts_hits
#>                    - logical: <none>
#> [07:31:42] INFO  Applying user-provided fill overrides
#>                    - overrides: fold_change
#> [07:31:42] OK    Expanding to full key * id grid - done
#>                  -> elapsed: 0.269s
#> [07:31:42] INFO  Registering expanded table back to DB
#>                    - name: 'data_long'
#>                    - materialise_table: TRUE
#> [07:31:42] INFO  Registering lazy table
#>                  -> name: 'data_long'; as TABLE
#> [07:31:42] INFO  Materialising via dplyr::compute()
#> [07:31:43] OK    Registering lazy table - done
#>                  -> elapsed: 0.295s
#> [07:31:43] OK    Expanding <phip_data> to full grid - done
#>                  -> elapsed: 1.123s
```
