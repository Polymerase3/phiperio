# Resolve legacy-import paths and perform fast-fail argument checks

Combines explicit arguments with a YAML config (if given), expands every
relative path to an absolute path (relative paths are evaluated against
`dirname(config_yaml)` (!!!) when YAML is used, otherwise against the
directory that contains the first supplied data matrix (!!!)), and
returns a fully populated list of file locations and options ready for
downstream conversion. Only cheap, load-blocking checks are done here:

- `input_file` and `hit_file` must be supplied together or both omitted.

- At least one matrix source (`exist_file`, `fold_change_file`, or the
  `input_file` + `hit_file` pair) must be present.

- Deprecated `output_dir` triggers a soft warning.

All deeper table-content validation is deferred to `phip_data` class
validation.

## Usage

``` r
.ph_resolve_paths(
  exist_file = NULL,
  fold_change_file = NULL,
  samples_file = NULL,
  input_file = NULL,
  hit_file = NULL,
  timepoints_file = NULL,
  extra_cols = NULL,
  output_dir = NULL,
  data_long_path = NULL,
  peptide_library = TRUE,
  n_cores = NULL,
  materialise_table = NULL,
  auto_expand = NULL,
  sample_id_from_filenames = NULL,
  config_yaml = NULL
)
```

## Arguments

- exist_file, fold_change_file, input_file, hit_file, samples_file,
  timepoints_file:

  Character paths (relative or absolute) to the respective CSV/Parquet
  inputs. `NULL` means "not supplied".

- extra_cols:

  Character vector of extra metadata columns to keep; may be `NULL`.

- output_dir:

  Ignored (soft-deprecated).

- config_yaml:

  Optional path to a YAML file whose keys mirror the function arguments;
  relative paths inside the YAML are resolved against the YAML’s own
  directory.

## Value

A named list with absolute paths, `extra_cols`, and `base_dir`; suitable
for downstream helper functions.
