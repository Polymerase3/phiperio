# Importing legacy PhIP-Seq data (convert_legacy)

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

## What this covers

[`convert_legacy()`](https://polymerase3.github.io/phiperio/reference/convert_legacy.md)
ingests the classic three-file PhIP-Seq input (exist/fold_change/raw
counts) plus sample metadata (and optional timepoints). This vignette
shows compact cross-sectional and longitudinal examples.

## Cross-sectional: one sample per subject

We create minimal CSVs in a temp dir: `exist`, `samples`, and raw
counts.

``` r
tmp <- withr::local_tempdir()

# exist matrix: peptide x sample
exist_path <- file.path(tmp, "exist.csv")
write.csv(data.frame(
  peptide_id = c("p1", "p2"),
  s1 = c(1, 0),
  s2 = c(0, 1)
), exist_path, row.names = FALSE)

# raw counts (input/hit)
input_path <- file.path(tmp, "counts_input.csv")
write.csv(data.frame(
  peptide_id = c("p1", "p2"),
  s1 = c(100, 80),
  s2 = c(90, 120)
), input_path, row.names = FALSE)

hit_path <- file.path(tmp, "counts_hit.csv")
write.csv(data.frame(
  peptide_id = c("p1", "p2"),
  s1 = c(5, 0),
  s2 = c(0, 7)
), hit_path, row.names = FALSE)

# sample metadata (cross-sectional: sample_id == subject_id)
samples_path <- file.path(tmp, "samples.csv")
write.csv(data.frame(
  sample_id = c("s1", "s2"),
  age       = c(34, 58),
  sex       = c("F", "M")
), samples_path, row.names = FALSE)

pd_xc <- convert_legacy(
  exist_file       = exist_path,
  input_file       = input_path,
  hit_file         = hit_path,
  samples_file     = samples_path,
  extra_cols       = c("age", "sex"),
  peptide_library  = FALSE,
  materialise_table = FALSE
)
#> [13:45:36] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [13:45:36] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [13:45:36] INFO  Checking structural requirements (shape & mandatory columns)
#> [13:45:36] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [13:45:36] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [13:45:36] INFO  Ensuring all columns are atomic (no list-cols)
#> [13:45:36] INFO  Checking key uniqueness
#> [13:45:37] INFO  Validating value ranges & types for outcomes
#> [13:45:37] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> Warning: Missing values are always removed in SQL aggregation functions.
#> Use `na.rm = TRUE` to silence this warning
#> This warning is displayed once every 8 hours.
#> [13:45:37] INFO  Checking peptide_id coverage against peptide_library
#> [13:45:37] INFO  Checking full grid completeness (peptide * sample)
#> [13:45:37] OK    Counts table is a full peptide * sample grid
#> [13:45:37] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.463s
#> [13:45:37] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.465s

get_counts(pd_xc) |> arrange(sample_id, peptide_id) |> collect()
#> # A tibble: 4 × 7
#>   peptide_id sample_id exist input_count hit_count   age sex  
#>   <chr>      <chr>     <dbl>       <dbl>     <dbl> <int> <chr>
#> 1 p1         s1            1         100         5    34 F    
#> 2 p2         s1            0          80         0    34 F    
#> 3 p1         s2            0          90         0    58 M    
#> 4 p2         s2            1         120         7    58 M
```

## Longitudinal: multiple samples per subject

Add a timepoints map so the same subject_id has multiple sample_ids.

``` r
# reuse exist/raw counts shapes but rename columns to match sample_ids
exist_lg_path <- file.path(tmp, "exist_long.csv")
write.csv(data.frame(
  peptide_id = c("p1", "p2"),
  s1_t1 = c(1, 0),
  s1_t2 = c(1, 0),
  s2_t1 = c(0, 1),
  s2_t2 = c(0, 1)
), exist_lg_path, row.names = FALSE)

input_lg_path <- file.path(tmp, "counts_input_long.csv")
write.csv(data.frame(
  peptide_id = c("p1", "p2"),
  s1_t1 = c(100, 80),
  s1_t2 = c(110, 90),
  s2_t1 = c(95, 130),
  s2_t2 = c(90, 125)
), input_lg_path, row.names = FALSE)

hit_lg_path <- file.path(tmp, "counts_hit_long.csv")
write.csv(data.frame(
  peptide_id = c("p1", "p2"),
  s1_t1 = c(6, 0),
  s1_t2 = c(7, 0),
  s2_t1 = c(0, 8),
  s2_t2 = c(0, 9)
), hit_lg_path, row.names = FALSE)

samples_lg_path <- file.path(tmp, "samples_long.csv")
write.csv(data.frame(
  sample_id = c("s1_t1", "s1_t2", "s2_t1", "s2_t2"),
  subject_id = c("subj1", "subj1", "subj2", "subj2"),
  timepoint  = c("T1", "T2", "T1", "T2"),
  age       = c(34, 34, 58, 58),
  sex       = c("F", "F", "M", "M")
), samples_lg_path, row.names = FALSE)

pd_lg <- convert_legacy(
  exist_file       = exist_lg_path,
  input_file       = input_lg_path,
  hit_file         = hit_lg_path,
  samples_file     = samples_lg_path,
  timepoints_file  = NULL,  # subject_id/timepoint already in samples metadata
  extra_cols       = c("subject_id", "timepoint", "age", "sex"),
  peptide_library  = FALSE,
  materialise_table = FALSE
)
#> [13:45:37] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [13:45:37] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [13:45:37] INFO  Checking structural requirements (shape & mandatory columns)
#> [13:45:37] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [13:45:37] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [13:45:37] INFO  Ensuring all columns are atomic (no list-cols)
#> [13:45:37] INFO  Checking key uniqueness
#> [13:45:37] INFO  Validating value ranges & types for outcomes
#> [13:45:37] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [13:45:37] INFO  Checking peptide_id coverage against peptide_library
#> [13:45:37] INFO  Checking full grid completeness (peptide * sample)
#> [13:45:38] OK    Counts table is a full peptide * sample grid
#> [13:45:38] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.432s
#> [13:45:38] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.433s

get_counts(pd_lg) |>
  distinct(subject_id, sample_id, timepoint, peptide_id, exist, input_count, hit_count) |>
  arrange(subject_id, timepoint, peptide_id) |>
  collect()
#> # A tibble: 8 × 7
#>   subject_id sample_id timepoint peptide_id exist input_count hit_count
#>   <chr>      <chr>     <chr>     <chr>      <dbl>       <dbl>     <dbl>
#> 1 subj1      s1_t1     T1        p1             1         100         6
#> 2 subj1      s1_t1     T1        p2             0          80         0
#> 3 subj1      s1_t2     T2        p1             1         110         7
#> 4 subj1      s1_t2     T2        p2             0          90         0
#> 5 subj2      s2_t1     T1        p1             0          95         0
#> 6 subj2      s2_t1     T1        p2             1         130         8
#> 7 subj2      s2_t2     T2        p1             0          90         0
#> 8 subj2      s2_t2     T2        p2             1         125         9
```

## Key points

- Cross-sectional: `sample_id == subject_id`; no timepoints file needed.
- Longitudinal: provide `timepoints_file` so samples map to subjects and
  visits.
- [`convert_legacy()`](https://polymerase3.github.io/phiperio/reference/convert_legacy.md)
  accepts CSV or Parquet for each matrix.
- Keep columns consistent across files (same peptide_id set, matching
  sample_id columns).
- Use `peptide_library = TRUE` to attach annotations (skip here for
  speed).
