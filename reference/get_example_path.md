# Path to example PhIP-Seq datasets shipped with phiperio

Path to example PhIP-Seq datasets shipped with phiperio

## Usage

``` r
get_example_path(name = c("phip_mixture"))
```

## Arguments

- name:

  Character scalar. Name of the example dataset. Currently supported:
  `"phip_mixture"`.

## Value

A character scalar with an absolute path to the file.

## Examples

``` r
sim_path <- get_example_path("phip_mixture")
# phip_obj <- convert_standard(sim_path)
```
