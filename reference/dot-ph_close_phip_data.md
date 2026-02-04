# Close connections referenced by a phip_data object

Internal helper that disconnects all tracked connections and optionally
clears connection references stored in the object.

## Usage

``` r
.ph_close_phip_data(x, clear = TRUE)
```

## Arguments

- x:

  A valid `phip_data` object.

- clear:

  Logical; if `TRUE`, clear connection references after closing.

## Value

A `phip_data` object with closed (and possibly cleared) connections.
