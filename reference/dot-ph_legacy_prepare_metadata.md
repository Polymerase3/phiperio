# Prepare sample metadata for legacy import

Reads the `samples_file` and `timepoints_file`, and merges them when
present to add a subject identifier and timepoint variable.

## Usage

``` r
.ph_legacy_prepare_metadata(
  samples_file,
  timepoints_file = NULL,
  extra_cols = character()
)
```

## Arguments

- samples_file:

  Absolute path to the samples CSV/Parquet.

- timepoints_file:

  Absolute path to timepoints CSV/Parquet, or `NULL`.

- extra_cols:

  Character vector of extra metadata columns to keep.

## Value

A list with elements `samples`, `timepoints`, and `extra_cols`.
