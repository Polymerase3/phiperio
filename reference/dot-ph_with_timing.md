# Internal helper: .ph_with_timing

Conditionally raise a formatted warning or error.

## Usage

``` r
.ph_with_timing(
  headline,
  step = NULL,
  bullets = NULL,
  expr,
  verbose = .ph_opt("verbose", TRUE)
)
```
