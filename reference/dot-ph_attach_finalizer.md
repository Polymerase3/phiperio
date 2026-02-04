# Attach an auto-finalizer for phip_data connections

Creates a small environment that stores the current connection handles
and registers a finalizer to close them when the object is GC'd.

## Usage

``` r
.ph_attach_finalizer(x)
```

## Arguments

- x:

  A valid `phip_data` object.

## Value

A `phip_data` object with an attached finalizer environment.
