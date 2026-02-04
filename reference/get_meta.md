# Retrieve the metadata list

Accesses the `meta` slot, which holds flags such as whether the table is
a full peptide \* sample grid, the available outcome columns, etc.

## Usage

``` r
get_meta(x)
```

## Arguments

- x:

  A valid `phip_data` object.

## Value

A named list.

## Examples

``` r
pd <- load_example_data()
meta <- get_meta(pd)
```
