# Importing multiple files with phiperio

``` r
library(phiperio)
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
```

## Overview

This vignette shows how to ingest **many CSV files at once** via
[`convert_standard()`](https://polymerase3.github.io/phiperio/reference/convert_standard.md),
deriving `sample_id` automatically from filenames
(`sample_id_from_filenames = TRUE`). We’ll:

1.  Create a temporary directory with multiple tiny CSVs (names like
    `R25P01_01_002616.csv`).
2.  Peek at one file to see the expected long format.
3.  Import all files in one call.
4.  Derive `run_id` and `plate_id` from the `sample_id` pattern.

> Pattern: `R<run> P<plate> _ ...`. We’ll split on the underscore and
> then peel off the `R..` and `P..` parts.

## 1. Create a bunch of example files

Each file represents one sample. Columns are long-format: `peptide_id`,
`exist`, `fold_change`.

``` r
tmp_dir <- withr::local_tempdir()

file_names <- c(
  "R25P01_01_002616.csv",
  "R25P01_01_002617.csv",
  "R25P02_01_002618.csv",
  "R25P02_02_002619.csv",
  "R26P01_03_002620.csv",
  "R26P01_04_002621.csv",
  "R26P02_05_002622.csv",
  "R27P01_01_002623.csv",
  "R27P02_01_002624.csv",
  "R27P02_02_002625.csv"
)

# Simple helper to write a tiny two-row CSV
write_one <- function(path) {
  dat <- data.frame(
    peptide_id  = c("p1", "p2"),
    exist       = c(1, 0),
    fold_change = c(1.2, 0.9),
    stringsAsFactors = FALSE
  )
  utils::write.csv(dat, file.path(tmp_dir, path), row.names = FALSE)
}

invisible(lapply(file_names, write_one))
```

## 2. Inspect one file so you know what’s inside

``` r
one_file <- file.path(tmp_dir, file_names[[1]])
read.csv(one_file, stringsAsFactors = FALSE)
#>   peptide_id exist fold_change
#> 1         p1     1         1.2
#> 2         p2     0         0.9
```

You see two rows: one per `peptide_id` for this sample. All files have
the same column layout; only the filename differs (and will become
`sample_id`).

## 3. Import all files in one call

We point
[`convert_standard()`](https://polymerase3.github.io/phiperio/reference/convert_standard.md)
at the directory and set `sample_id_from_filenames = TRUE`. phiperio
will:

- read all CSVs in the directory,
- derive `sample_id` from the filename stem (e.g., `R25P01_01_002616`),
- union the rows into one DuckDB-backed table.

``` r
pd <- convert_standard(
  data_long_path = tmp_dir,
  sample_id_from_filenames = TRUE,
  peptide_library = FALSE,   # set TRUE if you need peptide annotations
  materialise_table = FALSE, # view is fine for exploration
  auto_expand = FALSE
)
#> Skipping ANALYZE - raw_combined is a view.
#> [13:45:47] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [13:45:47] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [13:45:47] INFO  Checking structural requirements (shape & mandatory columns)
#> [13:45:48] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [13:45:48] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [13:45:48] INFO  Ensuring all columns are atomic (no list-cols)
#> [13:45:48] INFO  Checking key uniqueness
#> [13:45:48] INFO  Validating value ranges & types for outcomes
#> Warning: Missing values are always removed in SQL aggregation functions.
#> Use `na.rm = TRUE` to silence this warning
#> This warning is displayed once every 8 hours.
#> [13:45:48] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [13:45:48] INFO  Checking peptide_id coverage against peptide_library
#> [13:45:48] INFO  Checking full grid completeness (peptide * sample)
#> [13:45:48] OK    Counts table is a full peptide * sample grid
#> [13:45:48] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.524s
#> [13:45:48] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.526s
```

Check distinct sample IDs:

``` r
get_counts(pd) |>
  distinct(sample_id) |>
  arrange(sample_id) |>
  collect()
#> # A tibble: 10 × 1
#>    sample_id       
#>    <chr>           
#>  1 R25P01_01_002616
#>  2 R25P01_01_002617
#>  3 R25P02_01_002618
#>  4 R25P02_02_002619
#>  5 R26P01_03_002620
#>  6 R26P01_04_002621
#>  7 R26P02_05_002622
#>  8 R27P01_01_002623
#>  9 R27P02_01_002624
#> 10 R27P02_02_002625
```

## 4. Derive run_id and plate_id from sample_id

Our filenames have the shape `R<run> P<plate> _ rest`. We can extract
those parts with a couple of string splits:

``` r
pd_with_meta <- pd |>
  mutate(
    # Keep the part before first underscore: e.g., "R25P01"
    rp = regexp_replace(sample_id, '_.*$', ''),
    # run_id = chunk starting with R up to P
    run_id = regexp_extract(rp, 'R[^P]+'),
    # plate_id = chunk starting with P
    plate_id = regexp_extract(rp, 'P.+')
  )

get_counts(pd_with_meta) |>
  distinct(sample_id, run_id, plate_id) |>
  arrange(sample_id) |>
  collect()
#> # A tibble: 10 × 3
#>    sample_id        run_id plate_id
#>    <chr>            <chr>  <chr>   
#>  1 R25P01_01_002616 R25    P01     
#>  2 R25P01_01_002617 R25    P01     
#>  3 R25P02_01_002618 R25    P02     
#>  4 R25P02_02_002619 R25    P02     
#>  5 R26P01_03_002620 R26    P01     
#>  6 R26P01_04_002621 R26    P01     
#>  7 R26P02_05_002622 R26    P02     
#>  8 R27P01_01_002623 R27    P01     
#>  9 R27P02_01_002624 R27    P02     
#> 10 R27P02_02_002625 R27    P02
```

Now you have per-sample `run_id` and `plate_id` derived from the
filename, alongside the original measurements.

## Summary

- Put your per-sample CSV/Parquet files in one directory.
- Call `convert_standard(..., sample_id_from_filenames = TRUE)` to
  ingest them all at once.
- Parse `sample_id` to pull out run/plate metadata as needed. DuckDB
  keeps the workflow fast even with many files and millions of rows.
