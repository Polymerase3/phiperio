# Detect the peptide libraries a set of peptides belongs to

Matches the prefixes of `peptide_ids` (the part before the trailing
`"_<number>"`, e.g. `agilent` in `agilent_123`) against the prefixes of
the libraries known to
[`get_peptide_library()`](https://polymerase3.github.io/phiperio/reference/get_peptide_library.md):
`agilent`, `twist` and `corona2` for `"combined"`, `humanProteome` for
`"human_proteome"`, and `icam` for `"icam"`.

## Usage

``` r
detect_peptide_libraries(peptide_ids)
```

## Arguments

- peptide_ids:

  Character vector of peptide IDs.

## Value

Character vector with the names of the matched libraries, ready to pass
to
[`get_peptide_library()`](https://polymerase3.github.io/phiperio/reference/get_peptide_library.md);
empty if no peptide matched any library.

## Examples

``` r
detect_peptide_libraries(c("agilent_1", "icam_7", "pep_x"))
#> [1] "combined" "icam"    
```
