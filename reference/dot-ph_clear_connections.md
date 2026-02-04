# Clear connection references in a phip_data object

Internal helper that removes stored DBI connections from the `meta` slot
and from the peptide-library attributes.

## Usage

``` r
.ph_clear_connections(x)
```

## Arguments

- x:

  A valid `phip_data` object.

## Value

A `phip_data` object with connection references cleared.
