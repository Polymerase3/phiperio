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
  sample_id_from_filenames = FALSE,
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

- sample_id_from_filenames:

  Logical. If `TRUE` and `data_long_path` is a **directory of files**
  (CSV or Parquet), automatically derive `sample_id` from each filename
  (basename without extension). Requires that no `sample_id` mapping is
  provided and that the input files do not already contain a `sample_id`
  column. Default: `FALSE`.

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

  If `TRUE` (default) `convert_standard()` detects the peptide libraries
  the `peptide_id`s belong to and attaches their metadata for downstream
  annotation; if no peptide matches a known library, none is attached. A
  character vector of library names (`"combined"`, `"human_proteome"`,
  `"icam"`) attaches exactly those. Set to `FALSE` to skip this step.
  See
  [`create_data()`](https://polymerase3.github.io/phiperio/reference/create_data.md)
  and
  [`get_peptide_library()`](https://polymerase3.github.io/phiperio/reference/get_peptide_library.md).

## Value

An S3 object of class **`phip_data`** containing:

- `data_long`:

  The (possibly expanded) long-format table.

- `peptide_library`:

  Loaded peptide-library metadata (if any library was detected or
  requested).

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
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/Rtmpx3O1yL/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [13:09:12] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [13:09:12] INFO  Fetching peptide metadata library via get_peptide_library()
#>                    - libraries: combined
#> [13:09:12] INFO  Retrieving peptide metadata into DuckDB cache
#>                  -> get_peptide_library(library = combined, force_refresh =
#>                     FALSE)
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/Rtmpx3O1yL/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [13:09:12] INFO  Opened DuckDB connection
#>                    - cache dir:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/phip_cache.duckdb
#>                    - tables: peptide_meta_combined
#> [13:09:12] OK    Using cached peptide_meta_combined (fast path)
#> [13:09:12] OK    Retrieving peptide metadata into DuckDB cache - done
#>                  -> elapsed: 0.032s
#> [13:09:12] OK    Peptide metadata acquired
#> [13:09:12] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [13:09:12] INFO  Checking structural requirements (shape & mandatory columns)
#> [13:09:12] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [13:09:12] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [13:09:12] INFO  Ensuring all columns are atomic (no list-cols)
#> [13:09:12] INFO  Checking key uniqueness
#> [13:09:12] INFO  Validating value ranges & types for outcomes
#> [13:09:12] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [13:09:12] INFO  Checking peptide_id coverage against peptide_library
#> [13:09:13] INFO  Checking full grid completeness (peptide * sample)
#> [13:09:13] INFO  Counts table is not a full peptide * sample grid
#>                    - observed rows: 78200
#>                    - expected rows: 156000
#> Warning: [13:09:13] WARN  Grid remains incomplete (auto_expand = FALSE).
#>                  -> grid completeness
#>                    - observed rows: 78200
#>                    - expected rows: 156000.
#> [13:09:13] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.395s
#> [13:09:13] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.449s

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
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/Rtmpx3O1yL/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> Skipping ANALYZE - raw_combined is a view.
#> [13:09:13] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [13:09:13] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [13:09:13] INFO  Checking structural requirements (shape & mandatory columns)
#> [13:09:13] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [13:09:13] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [13:09:13] INFO  Ensuring all columns are atomic (no list-cols)
#> [13:09:13] INFO  Checking key uniqueness
#> [13:09:13] INFO  Validating value ranges & types for outcomes
#> [13:09:13] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [13:09:13] INFO  Checking peptide_id coverage against peptide_library
#> [13:09:13] INFO  Checking full grid completeness (peptide * sample)
#> [13:09:13] OK    Counts table is a full peptide * sample grid
#> [13:09:13] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.134s
#> [13:09:13] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.134s
```
