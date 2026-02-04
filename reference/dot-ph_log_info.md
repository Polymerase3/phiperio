# Internal helper: .ph_log_info

Emit an INFO log block if verbose logging is enabled.

## Usage

``` r
.ph_log_info(
  headline,
  step = NULL,
  bullets = NULL,
  verbose = .ph_opt("verbose", TRUE)
)
```
