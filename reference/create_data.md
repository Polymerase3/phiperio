# Construct a **phip_data** object

Creates a fully-validated S3 object that bundles the tidy PhIP-Seq
counts (`data_long`), a peptide-library annotation table, and other
metadata. The data itself is validated via
[`validate_phip_data()`](https://polymerase3.github.io/phiperio/reference/validate_phip_data.md).

## Usage

``` r
create_data(
  data_long,
  peptide_library = TRUE,
  auto_expand = TRUE,
  materialise_table = TRUE,
  meta = list()
)
```

## Arguments

- data_long:

  A tidy data frame (or `tbl_lazy`) with one row per `peptide_id` x
  `sample_id` combination. **Required.**

- peptide_library:

  Peptide annotations to attach. `TRUE` (default) downloads the
  reference library via
  [`get_peptide_library()`](https://polymerase3.github.io/phiperio/reference/get_peptide_library.md);
  `FALSE` attaches none. A data frame or lazy table with one row per
  `peptide_id` is attached as supplied, which is useful offline and in
  tests.

- auto_expand:

  Logical. If `TRUE` and the input is **not** already the full Cartesian
  product of `sample_id` x `peptide_id`, the function fills in the
  missing combinations.

  - Columns that are constant within a `sample_id` (metadata) are
    duplicated to the newly created rows.

  - Measurement columns such as `fold_change`, `exist`, raw counts, or
    any other non-recyclable fields are initialised to 0. The expanded
    table replaces `data_long` in place.

- materialise_table:

  Logical. If `FALSE` the result is registered as a **view**. If `TRUE`
  (default) the result is fully **materialised** and stored as a
  physical table, which speeds up repeated queries at the cost of extra
  memory/disk.

- meta:

  Optional named list of metadata flags to pre-populate the `meta` slot
  (rarely needed by users).

## Value

An object of class `"phip_data"`.

## Examples

``` r
## minimal constructor call
tidy_counts <- data.frame(
  sample_id = c("s1", "s1"),
  peptide_id = c("p1", "p2"),
  exist = c(1, 0),
  stringsAsFactors = FALSE
)
pd <- create_data(
  data_long = tidy_counts,
  peptide_library = FALSE,
  materialise_table = FALSE
)
#> [19:30:51] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [19:30:51] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [19:30:51] INFO  Checking structural requirements (shape & mandatory columns)
#> [19:30:51] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [19:30:51] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [19:30:51] INFO  Ensuring all columns are atomic (no list-cols)
#> [19:30:51] INFO  Checking key uniqueness
#> [19:30:51] INFO  Validating value ranges & types for outcomes
#> [19:30:51] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [19:30:51] INFO  Checking peptide_id coverage against peptide_library
#> [19:30:51] INFO  Checking full grid completeness (peptide * sample)
#> [19:30:51] OK    Counts table is a full peptide * sample grid
#> [19:30:51] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.022s
#> [19:30:51] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.023s
```
