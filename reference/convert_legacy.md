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

  logical, defining if the `peptide_library` is to be downloaded from
  the official `phiperio` GitHub

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
#> [11:52:00] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [11:52:00] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [11:52:00] INFO  Checking structural requirements (shape & mandatory columns)
#> [11:52:00] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [11:52:00] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [11:52:00] INFO  Ensuring all columns are atomic (no list-cols)
#> [11:52:00] INFO  Checking key uniqueness
#> [11:52:00] INFO  Validating value ranges & types for outcomes
#> [11:52:00] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [11:52:00] INFO  Checking peptide_id coverage against peptide_library
#> [11:52:00] INFO  Checking full grid completeness (peptide * sample)
#> [11:52:00] OK    Counts table is a full peptide * sample grid
#> [11:52:00] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.276s
#> [11:52:00] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.276s

## 2. YAML-driven usage (explicit args override YAML)
pd <- convert_legacy(
  config_yaml = file.path(ext, "config.yaml"),
  peptide_library = FALSE
)
#> Warning: [11:52:00] WARN  'output_dir' is deprecated and will be ignored.
#> [11:52:00] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [11:52:00] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [11:52:00] INFO  Checking structural requirements (shape & mandatory columns)
#> [11:52:00] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [11:52:00] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [11:52:00] INFO  Ensuring all columns are atomic (no list-cols)
#> [11:52:00] INFO  Checking key uniqueness
#> [11:52:00] INFO  Validating value ranges & types for outcomes
#> [11:52:00] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [11:52:01] INFO  Checking peptide_id coverage against peptide_library
#> [11:52:01] INFO  Checking full grid completeness (peptide * sample)
#> [11:52:01] OK    Counts table is a full peptide * sample grid
#> [11:52:01] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.272s
#> [11:52:01] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.272s

```
