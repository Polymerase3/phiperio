# Merge or join a `phip_data` object

Merge or join a `phip_data` object

## Usage

``` r
# S3 method for class 'phip_data'
merge(x, y, ...)
```

## Arguments

- x:

  A `phip_data` object.

- y:

  A data-frame-like object *or* another `phip_data`.

- ...:

  Arguments forwarded to either
  [`base::merge()`](https://rdrr.io/r/base/merge.html) or the chosen
  **dplyr** join (e.g. `by =`, `suffix =`, etc.).

## Value

A new `phip_data` whose `data_long` contains the merged / joined tibble.

## Examples

``` r
pd <- load_example_data()
merged <- merge(pd, pd, by = c("sample_id", "peptide_id"))
#> Warning: [11:52:10] WARN  `merge()` copies both tables in full; this may exhaust RAM.
```
