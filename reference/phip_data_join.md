# dplyr joins for `phip_data`

dplyr joins for `phip_data`

## Usage

``` r
# S3 method for class 'phip_data'
left_join(x, y, ...)

# S3 method for class 'phip_data'
right_join(x, y, ...)

# S3 method for class 'phip_data'
inner_join(x, y, ...)

# S3 method for class 'phip_data'
full_join(x, y, ...)

# S3 method for class 'phip_data'
semi_join(x, y, ...)

# S3 method for class 'phip_data'
anti_join(x, y, ...)
```

## Arguments

- x:

  A `phip_data` object.

- y:

  A `phip_data` or a data frame / tbl.

- ...:

  Passed to the corresponding `dplyr::<join>` function.

## Value

A `phip_data` object with updated `data_long`.

## Examples

``` r
pd <- load_example_data()
joined <- dplyr::left_join(pd, pd, by = c("sample_id", "peptide_id"))
```
