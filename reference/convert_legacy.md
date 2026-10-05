# Convert legacy Carlos-style input to a modern **phip_data** object

`convert_legacy()` ingests the original three-file PhIP-Seq input
(binary *exist* matrix, *samples* metadata, optional *timepoints* map).
Paths can be supplied directly or via a single YAML config; explicit
arguments always override the YAML. The function normalises the chosen
DuckDB storage, validates every file, and returns a ready-to-use
`phip_data` object.

## Usage

``` r
convert_legacy(
  exist_file = NULL,
  fold_change_file = NULL,
  samples_file = NULL,
  input_file = NULL,
  hit_file = NULL,
  timepoints_file = NULL,
  extra_cols = NULL,
  output_dir = NULL,
  peptide_library = TRUE,
  n_cores = 8,
  materialise_table = TRUE,
  config_yaml = NULL
)
```

## Arguments

- exist_file:

  Path to the **exist** CSV (peptide x sample binary matrix). *Required
  unless given in `config_yaml`.*

- fold_change_file:

  Path to the **fold_change** CSV (peptide x sample numeric matrix).
  *Required unless given in `config_yaml`.*

- samples_file:

  Path to the **samples** CSV (sample metadata). *Required unless given
  in `config_yaml`.*

- input_file, hit_file:

  Paths to the **raw_counts** CSV (peptide x sample integer matrix).
  *Required unless given in `config_yaml`.*

- timepoints_file:

  Path to the **timepoints** CSV (subject \<-\> sample mapping).
  Optional for cross-sectional data.

- extra_cols:

  Character vector of extra metadata columns to retain.

- output_dir:

  *Deprecated.* Ignored with a warning.

- peptide_library:

  If `TRUE` (default), detects the peptide libraries the `peptide_id`s
  belong to and attaches their metadata, downloaded from the companion
  `phiper` GitHub repo; if no peptide matches a known library, none is
  attached. A character vector of library names (`"combined"`,
  `"human_proteome"`, `"icam"`) attaches exactly those. `FALSE` attaches
  none. See
  [`create_data()`](https://polymerase3.github.io/phiperio/reference/create_data.md)
  and
  [`get_peptide_library()`](https://polymerase3.github.io/phiperio/reference/get_peptide_library.md).

- n_cores:

  Integer \>= 1. Number of CPU threads DuckDB may use while reading and
  writing files.

- materialise_table:

  Logical. If `FALSE` the result is registered as a **view**; if `TRUE`
  the table is fully **materialised** and stored on disk, trading higher
  load time and storage for faster repeated queries.

- config_yaml:

  Optional YAML file containing any of the above parameters (see
  example).

## Value

A validated `phip_data` object whose `data_long` slot is backed by a
DuckDB connection.

## Details

Input files are validated in two stages:

- **Fast-fail** checks (paths, extensions, and required arguments) run
  during path resolution.

- **Data validation** (required columns, uniqueness, value ranges, etc.)
  is centralized in
  [`validate_phip_data()`](https://polymerase3.github.io/phiperio/reference/validate_phip_data.md).

## Examples

``` r
## 1. Direct-path usage (package example files)
ext <- system.file("extdata", package = "phiperio")
pd <- convert_legacy(
  exist_file = file.path(ext, "exist.csv"),
  samples_file = file.path(ext, "samples_meta.csv"),
  timepoints_file = file.path(ext, "samples2ind_timepoints.csv"),
  peptide_library = FALSE
)
#> duckdb keeps downloaded extensions and secrets in a temporary directory:
#> ℹ /tmp/Rtmpx3O1yL/duckdb
#> This is removed when the R session ends.
#> • Extensions are re-downloaded each session.
#> • Secrets are lost.
#> ℹ Run duckdb(shared_home = TRUE) (or create ~/.duckdb) to keep them (suitable for most users).
#> ℹ Run duckdb(shared_home = FALSE) to accept the temporary directory (and silence this message).
#> ℹ See ?duckdb_storage for details and alternatives.
#> [13:09:11] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [13:09:11] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [13:09:11] INFO  Checking structural requirements (shape & mandatory columns)
#> [13:09:11] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [13:09:11] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [13:09:11] INFO  Ensuring all columns are atomic (no list-cols)
#> [13:09:11] INFO  Checking key uniqueness
#> [13:09:11] INFO  Validating value ranges & types for outcomes
#> [13:09:11] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [13:09:11] INFO  Checking peptide_id coverage against peptide_library
#> [13:09:11] INFO  Checking full grid completeness (peptide * sample)
#> [13:09:11] OK    Counts table is a full peptide * sample grid
#> [13:09:11] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.109s
#> [13:09:11] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.11s

## 2. YAML-driven usage (explicit args override YAML)
pd <- convert_legacy(
  config_yaml = file.path(ext, "config.yaml"),
  peptide_library = FALSE
)
#> Warning: [13:09:11] WARN  'output_dir' is deprecated and will be ignored.
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
#> [13:09:12] INFO  Checking full grid completeness (peptide * sample)
#> [13:09:12] OK    Counts table is a full peptide * sample grid
#> [13:09:12] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.142s
#> [13:09:12] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.143s

```
