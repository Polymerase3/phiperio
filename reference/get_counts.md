# Retrieve the main PhIP-Seq counts table

Quick accessor for the `data_long` slot of a **phip_data** object.

## Usage

``` r
get_counts(x)
```

## Arguments

- x:

  A valid `phip_data` object.

## Value

A tibble or lazy table with one row per peptide \* sample pair.

## Examples

``` r
pd <- load_example_data()
tbl <- get_counts(pd)
```
