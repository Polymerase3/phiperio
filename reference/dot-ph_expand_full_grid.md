# Internal helper: .ph_expand_full_grid

Expand a table to the full key \* id grid with typed fill defaults.

## Usage

``` r
.ph_expand_full_grid(
  tbl,
  key_col = "sample_id",
  id_col = "peptide_id",
  fill_override = NULL,
  add_exist = FALSE,
  exist_col = "exist",
  validate = TRUE
)
```
