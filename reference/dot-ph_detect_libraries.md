# Detect the peptide libraries a counts table draws from

Matches the `peptide_id` prefixes of `data_long` (the part before the
trailing `"_<number>"`) against the prefixes of the libraries known to
[`get_peptide_library()`](https://polymerase3.github.io/phiperio/reference/get_peptide_library.md).

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
