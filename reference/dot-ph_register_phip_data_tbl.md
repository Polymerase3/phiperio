# Register a lazy table back to the database as a TABLE or VIEW

Convenience wrapper that either materialises a lazy pipeline via
[`dplyr::compute()`](https://dplyr.tidyverse.org/reference/compute.html)
(creating a TABLE) or emits a `CREATE [TEMP] VIEW AS ...` (creating a
VIEW). Returns a
[`dplyr::tbl()`](https://dplyr.tidyverse.org/reference/tbl.html)
pointing to the created object.

## Usage

``` r
.ph_register_phip_data_tbl(
  tbl,
  con,
  name = "data_long",
  materialise_table = TRUE,
  temporary = TRUE
)
```

## Arguments

- tbl:

  A lazy table (e.g., from `dbplyr`).

- con:

  A `DBI` connection.

- name:

  Target name to create (default `"data_long"`).

- materialise_table:

  If `TRUE`, create a TABLE via `compute()`. If `FALSE`, create a VIEW.

- temporary:

  If `TRUE`, create a TEMP table/view where supported.

## Value

A lazy [`dplyr::tbl`](https://dplyr.tidyverse.org/reference/tbl.html)
referencing the new TABLE/VIEW.
