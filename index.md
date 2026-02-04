# phiperio

The `phiperio` package provides utilities to import, validate, and
manage PhIP-Seq datasets, including standardized conversion pipelines,
data checks, and access to cached peptide metadata.

## Installation

You can install the development version of `phiperio` from GitHub with
either `pak` or `devtools`:

``` r
# install.packages("pak")
pak::pak("Polymerase3/phiperio")

# or, using devtools:
# install.packages("devtools")
devtools::install_github("Polymerase3/phiperio")
```

## Usage

For a guided walk-through (cross-sectional and longitudinal imports),
see the vignette on the pkgdown site: **[Importing long tidy data with
phiperio](https://polymerase3.github.io/phiperio/articles/importing-long-tidy-data.html)**.

Minimal one-liner to load the package:

``` r
library(phiperio)
```

## Aim and key features

`phiperio` focuses on reliable ingest and validation of PhIP-Seq data,
so downstream analyses start from a clean, standardized base. Key
features include:

- **DuckDB backend + Parquet first:** uses DuckDB under the hood and
  writes/reads Parquet by default as the transaction layer between the
  `phiper` data source and `phiperio`, giving fast I/O and great
  interoperability.
- **Scales to millions of rows:** lazy database pipelines and Parquet
  storage let you work efficiently with very large PhIP-Seq datasets.
- **Import helpers** for common PhIP-Seq inputs and peptide metadata
  (peptide library cached and maintained in the companion `phiper`
  repo).
- **Strong validation** and consistency checks to catch data issues
  early.
- **Lightweight, reproducible pipelines** to standardize raw inputs into
  `<phip_data>` objects.

## Minimal usage

``` r
library(phiperio)

# See available helpers and functions
?phiperio
```

## Issues

Spotted a bug or want to request a feature? Please open an issue:
<https://github.com/Polymerase3/phiperio/issues>
