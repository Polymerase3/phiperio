# Load Example PhIP-Seq Dataset as \<phip_data\>

Convenience helper to quickly load a shipped example dataset
("phip_mixture") into a `<phip_data>` object, suitable for downstream
analysis and visualization. This function wraps
[`convert_standard`](https://polymerase3.github.io/phiperio/reference/convert_standard.md),
automatically supplying the correct parameters for the included example
data.

## Usage

``` r
load_example_data(name = c("phip_mixture", "small_mixture"))
```

## Arguments

- name:

  Character scalar. Name of the shipped example dataset. Currently
  supported: `"phip_mixture"`, `"small_mixture"`.

## Value

A `<phip_data>` object created from the chosen example dataset.

## Examples

``` r
# Load the example data shipped with the package:
ex <- load_example_data()
# ex is now a <phip_data> object ready for analysis

# Specify the dataset name explicitly
ex2 <- load_example_data("small_mixture")

# Use with downstream analysis/plotting functions as needed
```
