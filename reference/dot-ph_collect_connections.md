# Collect all connection handles from a phip_data object

Internal helper that gathers all known DBI connections from `meta` and
from the peptide-library attributes, de-duplicated by identity.

## Usage

``` r
.ph_collect_connections(x)
```

## Arguments

- x:

  A valid `phip_data` object.

## Value

A list of unique DBI connections.
