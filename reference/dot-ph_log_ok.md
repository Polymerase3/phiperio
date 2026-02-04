# Internal helper: .ph_log_ok

Emit an OK log block if verbose logging is enabled.

## Usage

``` r
.ph_log_ok(
  headline,
  step = NULL,
  bullets = NULL,
  verbose = .ph_opt("verbose", TRUE)
)
```
