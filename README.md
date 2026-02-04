
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- badges: start -->

[![Codecov test
coverage](https://codecov.io/gh/Polymerase3/phiperio/graph/badge.svg)](https://app.codecov.io/gh/Polymerase3/phiperio)
[![R-CMD-check](https://github.com/Polymerase3/phiperio/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Polymerase3/phiperio/actions/workflows/R-CMD-check.yaml)
[![pkgcheck](https://github.com/Polymerase3/phiperio/workflows/pkgcheck/badge.svg)](https://github.com/Polymerase3/phiperio/actions?query=workflow%3Apkgcheck)
[![test-coverage](https://github.com/Polymerase3/phiperio/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/Polymerase3/phiperio/actions/workflows/test-coverage.yaml)
[![version](https://img.shields.io/github/r-package/v/Polymerase3/phiperio?label=version)](https://github.com/Polymerase3/phiperio)
[![Project Status:
Active/Unstable](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

<!-- badges: end -->

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

## Aim and key features

`phiperio` focuses on reliable ingest and validation of PhIP-Seq data,
so downstream analyses start from a clean, standardized base. Key
features include:

- Import helpers for common PhIP-Seq inputs and metadata.
- Validation and consistency checks to catch data issues early.
- Lightweight, reproducible pipelines for converting raw inputs into
  standardized objects.

## CI workflows

The repository includes continuous integration workflows to keep the
package healthy:

- **R-CMD-check**: Runs `R CMD check` on macOS, Windows, and Linux with
  release and oldrel R versions.
- **pkgcheck**: Lints package structure and surfaces potential issues in
  issues/PRs.
- **test-coverage**: Computes test coverage with `covr` and uploads
  results to Codecov.

## Minimal usage

``` r
library(phiperio)

# See available helpers and functions
?phiperio
```
