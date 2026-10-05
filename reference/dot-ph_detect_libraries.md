# Detect the peptide libraries a counts table draws from

Runs
[`detect_peptide_libraries()`](https://polymerase3.github.io/phiperio/reference/detect_peptide_libraries.md)
on the distinct `peptide_id` values of `data_long`.

## Usage

``` r
.ph_detect_libraries(data_long)
```

## Arguments

- data_long:

  A data frame or lazy table with a `peptide_id` column.

## Value

Character vector with the names of the matched libraries; empty if no
peptide matched any library.
