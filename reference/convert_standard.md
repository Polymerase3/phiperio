# Convert raw PhIP-Seq output into a `phip_data` object

`convert_standard()` ingests a "long" table of PhIPsSeq read counts /
enrichment statistics, optionally expands it to the full
`sample_id x peptide_id` grid, and registers the result in DuckDB. The
function returns a fully initialised **`phip_data`** object that can be
queried with the tidy API used throughout the package.

## Usage

``` r
convert_standard(
  data_long_path,
  sample_id = NULL,
  peptide_id = NULL,
  subject_id = NULL,
  timepoint = NULL,
  exist = NULL,
  fold_change = NULL,
  counts_input = NULL,
  counts_hit = NULL,
  n_cores = 8,
  materialise_table = TRUE,
  auto_expand = FALSE,
  peptide_library = TRUE
)
```

## Arguments

- data_long_path:

  Character scalar. File or directory containing the *long-format*
  PhIP-Seq data. Allowed extensions are **`.csv`** and **`.parquet`**.
  Directories are treated as partitions of a parquet set.

- sample_id, peptide_id, subject_id, timepoint, exist, fold_change,
  counts_input, counts_hit:

  Optional character strings. Supply these only if your column names
  differ from the defaults (`"sample_id"`, `"peptide_id"`,
  `"subject_id"`, `"timepoint"`, `"exist"`, `"fold_change"`,
  `"counts_input"`, `"counts_hit"`). Each argument should contain the
  *name* of the column in the incoming data; `NULL` lets the default
  stand.

- n_cores:

  Integer \>= 1. Number of CPU threads DuckDB may use while reading and
  writing files.

- materialise_table:

  Logical. If `FALSE` the result is registered as a **view**; if `TRUE`
  the table is fully **materialised** and stored on disk, trading higher
  load time and storage for faster repeated queries.

- auto_expand:

  Logical. If `TRUE` and the incoming data are **not** a complete
  Cartesian product of `sample_id x peptide_id`, missing combinations
  are generated:

  - Columns that are constant within each `sample_id` (metadata) are
    copied to the new rows.

  - Non-recyclable measurement columns (`fold_change`, `exist`,
    `counts_input`, `counts_hit`, etc.) are initialised to 0. The
    expanded table replaces the original *in place*.

- peptide_library:

  Logical. If `TRUE` (default) `convert_standard()` will attempt to
  locate and attach the matching peptide-library metadata for downstream
  annotation. Set to `FALSE` to skip this step.

## Value

An S3 object of class **`phip_data`** containing:

- `data_long`:

  The (possibly expanded) long-format table.

- `peptide_library`:

  Loaded peptide-library metadata (if `peptide_library = TRUE`).

- `meta`:

  List with DuckDB connection handles.

## Details

*Paths are resolved to absolute form* before any work begins, and
explicit checks confirm existence as well as extension validity.

## See also

- [`create_data()`](https://polymerase3.github.io/phiperio/reference/create_data.md)
  for the object constructor.

- [`dplyr::tbl()`](https://dplyr.tidyverse.org/reference/tbl.html) to
  query DuckDB tables lazily.

## Examples

``` r
# Basic import, auto-detecting default column names
phip_obj <- convert_standard(
  data_long_path = get_example_path("phip_mixture"),
  n_cores = 4,
  materialise_table = TRUE
)
#> [11:52:01] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [11:52:01] INFO  Fetching peptide metadata library via get_peptide_library()
#> [11:52:01] INFO  Retrieving peptide metadata into DuckDB cache
#>                  -> get_peptide_library(force_refresh = FALSE)
#> [11:52:01] INFO  Opened DuckDB connection
#>                    - cache dir:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/phip_cache.duckdb
#>                    - table: peptide_meta
#> [11:52:01] OK    Using cached peptide_meta (fast path)
#> [11:52:01] OK    Retrieving peptide metadata into DuckDB cache - done
#>                  -> elapsed: 0.049s
#> [11:52:01] OK    Peptide metadata acquired
#> [11:52:01] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [11:52:01] INFO  Checking structural requirements (shape & mandatory columns)
#> [11:52:01] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [11:52:01] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [11:52:01] INFO  Ensuring all columns are atomic (no list-cols)
#> [11:52:01] INFO  Checking key uniqueness
#> [11:52:01] INFO  Validating value ranges & types for outcomes
#> [11:52:01] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [11:52:01] INFO  Checking peptide_id coverage against peptide_library
#> Warning: [11:52:02] WARN  peptide_id not found in peptide_library (e.g. 10003)
#>                  -> peptide library coverage.
#> [11:52:02] INFO  Checking full grid completeness (peptide * sample)
#> Warning: [11:52:02] WARN  Counts table is not a full peptide * sample grid.
#>                  -> grid completeness
#>                    - observed rows: 78200
#>                    - expected rows: 156000.
#> Warning: [11:52:02] WARN  Grid remains incomplete (auto_expand = FALSE).
#>                  -> grid completeness
#>                    - observed rows: 78200
#>                    - expected rows: 156000.
#> [11:52:02] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.597s
#> [11:52:02] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.648s

# Import a CSV and rename columns
tmp_csv <- tempfile(fileext = ".csv")
utils::write.csv(
  data.frame(
    sample = c("s1", "s1"),
    pep = c("p1", "p2"),
    exist = c(1, 0),
    stringsAsFactors = FALSE
  ),
  tmp_csv,
  row.names = FALSE
)
phip_mem <- convert_standard(
  data_long_path = tmp_csv,
  sample_id      = "sample",
  peptide_id     = "pep",
  peptide_library = FALSE,
  materialise_table = FALSE
)
#> Skipping ANALYZE - raw_combined is a view.
#> [11:52:02] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [11:52:02] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [11:52:02] INFO  Checking structural requirements (shape & mandatory columns)
#> [11:52:02] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [11:52:02] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [11:52:02] INFO  Ensuring all columns are atomic (no list-cols)
#> [11:52:02] INFO  Checking key uniqueness
#> [11:52:02] INFO  Validating value ranges & types for outcomes
#> [11:52:02] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [11:52:02] INFO  Checking peptide_id coverage against peptide_library
#> [11:52:02] INFO  Checking full grid completeness (peptide * sample)
#> [11:52:02] OK    Counts table is a full peptide * sample grid
#> [11:52:02] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.261s
#> [11:52:02] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.262s
```
