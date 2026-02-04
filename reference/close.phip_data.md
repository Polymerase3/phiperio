# Close phip_data connections

Closes any open database connections held by a `phip_data` object. This
includes the main `data_long` backend connection and any peptide-library
connection stored in attributes or metadata. The method is idempotent
and safe to call multiple times.

## Usage

``` r
# S3 method for class 'phip_data'
close(con, ...)
```

## Arguments

- con:

  A valid `phip_data` object.

- ...:

  Unused (for S3 generic compatibility).

## Value

The input `phip_data` object, invisibly.

## Examples

``` r
pd <- load_example_data()
close(pd)
```
