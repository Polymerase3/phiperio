# Importing cross-sectional and longitudinal tidy data with phiperio

``` r
library(phiperio)
```

## Overview

This vignette shows, step by step, how to import **cross-sectional** and
**longitudinal** PhIP-Seq data with
[`convert_standard()`](https://polymerase3.github.io/phiperio/reference/convert_standard.md),
inspect and manipulate the resulting `<phip_data>` object, and export
it. Explanations are written for first‑time users - plenty of comments
and plain language.

## Key concepts (read first)

- `sample_id` - **must be unique per sample/assay run.** For example:
  identifies a single well in 96-well plate.
- `subject_id` - identifies the person/test subject. In cross-sectional
  data `subject_id == sample_id`, so you can omit it. In longitudinal
  data, the same `subject_id` appears across multiple `sample_id`s
  (different timepoints).
- Outcomes: you need at least one of `exist`, `fold_change`, or raw
  counts (`counts_input`, `counts_hit`).
- Format: **long** table (one row per `sample_id × peptide_id`).

## Cross-sectional workflow (simpler)

In cross-sectional data each subject has exactly one sample, so
`subject_id == sample_id` and you do **not** need to supply
`subject_id`.

``` r
# ---- 1) Make a tiny cross-sectional long table ----------------------------
# One subject = one sample; sample_id is unique and also identifies the subject
cross_long <- data.frame(
  sample_id   = c("s1", "s1", "s2", "s2"),  # unique sample IDs
  peptide_id  = c("p1", "p2", "p1", "p2"),  # peptide identifiers
  exist       = c(1, 0, 0, 1),              # example outcome (binary)
  fold_change = c(1.2, 0.8, 0.4, 2.0),      # non‑negative fold-change
  age         = c(34, 34, 58, 58),          # per-sample metadata
  sex         = c("F", "F", "M", "M"),      # per-sample metadata
  stringsAsFactors = FALSE
)

# Print the tiny table so you can see the structure:
cross_long
#>   sample_id peptide_id exist fold_change age sex
#> 1        s1         p1     1         1.2  34   F
#> 2        s1         p2     0         0.8  34   F
#> 3        s2         p1     0         0.4  58   M
#> 4        s2         p2     1         2.0  58   M
# Each row is a sample_id × peptide_id combination.
# exist/fold_change are measurements; age/sex are sample-level metadata.

# Save to CSV (you could also use Parquet). convert_standard reads either.
xc_csv <- tempfile(fileext = ".csv")
utils::write.csv(cross_long, xc_csv, row.names = FALSE)

# ---- 2) Import with convert_standard --------------------------------------
# Because column names already match the defaults, we only pass the file path.
pd_xc <- convert_standard(
  data_long_path    = xc_csv,
  peptide_library   = TRUE,    # attach peptide annotations
  materialise_table = FALSE    # keep as a view for fast iterations
)
#> Skipping ANALYZE - raw_combined is a view.
#> [13:45:40] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [13:45:40] INFO  Fetching peptide metadata library via get_peptide_library()
#> [13:45:40] INFO  Retrieving peptide metadata into DuckDB cache
#>                  -> get_peptide_library(force_refresh = FALSE)
#> [13:45:41] INFO  Opened DuckDB connection
#>                    - cache dir:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/phip_cache.duckdb
#>                    - table: peptide_meta
#> [13:45:41] OK    Using cached peptide_meta (fast path)
#> [13:45:41] OK    Retrieving peptide metadata into DuckDB cache - done
#>                  -> elapsed: 0.251s
#> [13:45:41] OK    Peptide metadata acquired
#> [13:45:41] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [13:45:41] INFO  Checking structural requirements (shape & mandatory columns)
#> [13:45:41] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [13:45:41] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [13:45:41] INFO  Ensuring all columns are atomic (no list-cols)
#> [13:45:41] INFO  Checking key uniqueness
#> [13:45:41] INFO  Validating value ranges & types for outcomes
#> Warning: Missing values are always removed in SQL aggregation functions.
#> Use `na.rm = TRUE` to silence this warning
#> This warning is displayed once every 8 hours.
#> [13:45:41] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [13:45:41] INFO  Checking peptide_id coverage against peptide_library
#> Warning: [13:45:41] WARN  peptide_id not found in peptide_library (e.g. p1)
#>                  -> peptide library coverage.
#> [13:45:41] INFO  Checking full grid completeness (peptide * sample)
#> [13:45:41] OK    Counts table is a full peptide * sample grid
#> [13:45:41] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.769s
#> [13:45:41] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 1.023s
# The peptide library comes from the companion repo
# https://github.com/Polymerase3/phiper and is maintained by our group with
# collaborator-provided annotations. Setting peptide_library = TRUE pulls the
# current cached version automatically.
```

Inspect and manipulate:

``` r
# Show the phip_data object (prints a concise summary)
pd_xc
#> ── <phip_data> ───────────────────────────────────────────────────────────────── 
#> 
#> counts (first 5 rows): 
#> # A tibble: 4 × 6
#>   sample_id peptide_id exist fold_change   age sex  
#>   <chr>     <chr>      <dbl>       <dbl> <dbl> <chr>
#> 1 s1        p1             1         1.2    34 F    
#> 2 s1        p2             0         0.8    34 F    
#> 3 s2        p1             0         0.4    58 M    
#> 4 s2        p2             1         2      58 M    
#> 
#> table size: 4 rows x 6 columns
#> 
#> peptide library preview (first 5 rows): 
#> # A tibble: 5 × 8
#>   peptide_id Fullname                    species genus family order class common
#>   <chr>      <chr>                       <chr>   <chr> <chr>  <chr> <chr> <chr> 
#> 1 agilent_1  Chromodomain-helicase-DNA-… Homo s… Homo  Homin… Prim… Mamm… Human 
#> 2 agilent_2  integral membrane protein   Mycoba… Myco… Mycob… Myco… Acti… NA    
#> 3 agilent_3  hypothetical protein (6/16… Mycoba… Myco… Mycob… Myco… Acti… NA    
#> 4 agilent_4  envelope protein (5/8) & a… Orthof… Orth… Flavi… Amar… Flas… JEV   
#> 5 agilent_5  Myosin-7 & beta-myosin hea… Homo s… Homo  Homin… Prim… Mamm… Human 
#> ... plus 36 more columns
#> 
#> library size: 357,190 rows x 44 columns
#> 
#> meta flags: 
#>   con:            <duckdb_connection>
#>   longitudinal:   FALSE
#>   exist:          TRUE
#>   fold_change:    TRUE
#>   raw_counts:     FALSE
#>   extra_cols:     age, sex
#>   peptide_con:    <duckdb_connection>
#>   materialise_table: FALSE
#>   finalizer_env:  <environment>
#>   full_cross:     TRUE

# Peek at the long table lazily (no data pulled yet)
# get_counts() returns the same table as pd_xc$data_long
get_counts(pd_xc)
#> # Source:   table<raw_combined> [?? x 6]
#> # Database: DuckDB 1.4.4 [unknown@Linux 6.11.0-1018-azure:R 4.5.2//tmp/Rtmpmvm9ha/phiperio_cache1f9d162c788a/phip_cache.duckdb]
#>   sample_id peptide_id exist fold_change   age sex  
#>   <chr>     <chr>      <dbl>       <dbl> <dbl> <chr>
#> 1 s1        p1             1         1.2    34 F    
#> 2 s1        p2             0         0.8    34 F    
#> 3 s2        p1             0         0.4    58 M    
#> 4 s2        p2             1         2      58 M

# Filter to positive fold_change and collect to R
pd_xc_pos <- pd_xc |>
  dplyr::filter(fold_change > 0) |>
  dplyr::select(sample_id, peptide_id, fold_change) |>
  dplyr::collect()

pd_xc_pos
#> # A tibble: 4 × 3
#>   sample_id peptide_id fold_change
#>   <chr>     <chr>            <dbl>
#> 1 s1        p1                 1.2
#> 2 s1        p2                 0.8
#> 3 s2        p1                 0.4
#> 4 s2        p2                 2
```

Export to Parquet:

``` r
out_parquet <- tempfile(fileext = ".parquet")
export_parquet(pd_xc, out_parquet)
out_parquet
#> [1] "/tmp/Rtmpmvm9ha/file1f9d1ad18d66.parquet"

# Re-import the Parquet file directly with convert_standard()
pd_xc_again <- convert_standard(
  data_long_path = out_parquet,
  peptide_library = TRUE,
  materialise_table = FALSE
)
#> Skipping ANALYZE - raw_combined is a view.
#> [13:45:42] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [13:45:42] INFO  Fetching peptide metadata library via get_peptide_library()
#> [13:45:42] INFO  Retrieving peptide metadata into DuckDB cache
#>                  -> get_peptide_library(force_refresh = FALSE)
#> [13:45:42] INFO  Opened DuckDB connection
#>                    - cache dir:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/phip_cache.duckdb
#>                    - table: peptide_meta
#> [13:45:42] OK    Using cached peptide_meta (fast path)
#> [13:45:42] OK    Retrieving peptide metadata into DuckDB cache - done
#>                  -> elapsed: 0.229s
#> [13:45:42] OK    Peptide metadata acquired
#> [13:45:42] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [13:45:42] INFO  Checking structural requirements (shape & mandatory columns)
#> [13:45:42] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [13:45:42] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [13:45:42] INFO  Ensuring all columns are atomic (no list-cols)
#> [13:45:42] INFO  Checking key uniqueness
#> [13:45:42] INFO  Validating value ranges & types for outcomes
#> [13:45:42] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [13:45:42] INFO  Checking peptide_id coverage against peptide_library
#> Warning: [13:45:42] WARN  peptide_id not found in peptide_library (e.g. p1)
#>                  -> peptide library coverage.
#> [13:45:42] INFO  Checking full grid completeness (peptide * sample)
#> [13:45:43] OK    Counts table is a full peptide * sample grid
#> [13:45:43] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.531s
#> [13:45:43] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.761s
pd_xc_again
#> ── <phip_data> ───────────────────────────────────────────────────────────────── 
#> 
#> counts (first 5 rows): 
#> # A tibble: 4 × 6
#>   sample_id peptide_id exist fold_change   age sex  
#>   <chr>     <chr>      <dbl>       <dbl> <dbl> <chr>
#> 1 s1        p1             1         1.2    34 F    
#> 2 s1        p2             0         0.8    34 F    
#> 3 s2        p1             0         0.4    58 M    
#> 4 s2        p2             1         2      58 M    
#> 
#> table size: 4 rows x 6 columns
#> 
#> peptide library preview (first 5 rows): 
#> # A tibble: 5 × 8
#>   peptide_id Fullname                    species genus family order class common
#>   <chr>      <chr>                       <chr>   <chr> <chr>  <chr> <chr> <chr> 
#> 1 agilent_1  Chromodomain-helicase-DNA-… Homo s… Homo  Homin… Prim… Mamm… Human 
#> 2 agilent_2  integral membrane protein   Mycoba… Myco… Mycob… Myco… Acti… NA    
#> 3 agilent_3  hypothetical protein (6/16… Mycoba… Myco… Mycob… Myco… Acti… NA    
#> 4 agilent_4  envelope protein (5/8) & a… Orthof… Orth… Flavi… Amar… Flas… JEV   
#> 5 agilent_5  Myosin-7 & beta-myosin hea… Homo s… Homo  Homin… Prim… Mamm… Human 
#> ... plus 36 more columns
#> 
#> library size: 357,190 rows x 44 columns
#> 
#> meta flags: 
#>   con:            <duckdb_connection>
#>   longitudinal:   FALSE
#>   exist:          TRUE
#>   fold_change:    TRUE
#>   raw_counts:     FALSE
#>   extra_cols:     age, sex
#>   peptide_con:    <duckdb_connection>
#>   materialise_table: FALSE
#>   finalizer_env:  <environment>
#>   full_cross:     TRUE
```

## Longitudinal workflow (subjects with multiple samples)

Here, `subject_id` must be provided to link multiple `sample_id`s that
belong to the same subject. We also include a `timepoint` column so you
can track visits.

``` r
# ---- 1) Build a tiny longitudinal long table ------------------------------
# subject_id repeats across samples; sample_id stays unique per draw/run
long_long <- data.frame(
  subject_id   = c("subj1", "subj1", "subj1", "subj2", "subj2", "subj2"),
  sample_id    = c("s1_t1", "s1_t2", "s1_t3", "s2_t1", "s2_t2", "s2_t3"),
  timepoint    = c("T1", "T2", "T3", "T1", "T2", "T3"),     # visit labels
  peptide_id   = c("p1", "p1", "p2", "p1", "p2", "p2"),
  exist        = c(1, 1, 0, 0, 1, 1),
  fold_change  = c(1.5, 1.1, 0.2, 0.8, 1.9, 2.5),            # non‑negative
  input_reads  = c(1200, 1300, 800, 900, 1500, 1700),        # counts_input (custom name)
  hit_reads    = c(12, 15, 4, 5, 22, 28),                    # counts_hit (custom name)
  run_id       = c("runA", "runA", "runA", "runB", "runB", "runB"),
  plate_id     = c("plate1", "plate1", "plate1", "plate2", "plate2", "plate2"),
  stringsAsFactors = FALSE
)

lg_csv <- tempfile(fileext = ".csv")
utils::write.csv(long_long, lg_csv, row.names = FALSE)

# ---- 2) Import with subject_id and timepoint ------------------------------
pd_lg <- convert_standard(
  data_long_path    = lg_csv,
  subject_id        = "subject_id",  # explicitly map subject_id
  timepoint         = "timepoint",   # map timepoint column
  counts_input      = "input_reads", # map custom raw-count columns
  counts_hit        = "hit_reads",
  peptide_library   = FALSE,
  auto_expand       = FALSE,         # keep as-is; set TRUE to fill full grid
  materialise_table = FALSE
)
#> Skipping ANALYZE - raw_combined is a view.
#> [13:45:43] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [13:45:43] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [13:45:43] INFO  Checking structural requirements (shape & mandatory columns)
#> [13:45:43] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [13:45:43] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [13:45:43] INFO  Ensuring all columns are atomic (no list-cols)
#> [13:45:43] INFO  Checking key uniqueness
#> [13:45:43] INFO  Validating value ranges & types for outcomes
#> [13:45:43] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [13:45:43] INFO  Checking peptide_id coverage against peptide_library
#> [13:45:43] INFO  Checking full grid completeness (peptide * sample)
#> Warning: [13:45:43] WARN  Counts table is not a full peptide * sample grid.
#>                  -> grid completeness
#>                    - observed rows: 6
#>                    - expected rows: 12.
#> Warning: [13:45:43] WARN  Grid remains incomplete (auto_expand = FALSE).
#>                  -> grid completeness
#>                    - observed rows: 6
#>                    - expected rows: 12.
#> [13:45:43] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.371s
#> [13:45:43] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.371s
```

Work with the longitudinal data:

``` r
# Look at the object summary
pd_lg
#> ── <phip_data> ───────────────────────────────────────────────────────────────── 
#> 
#> counts (first 5 rows): 
#> # A tibble: 5 × 10
#>   subject_id sample_id timepoint peptide_id exist fold_change counts_input
#>   <chr>      <chr>     <chr>     <chr>      <dbl>       <dbl>        <dbl>
#> 1 subj1      s1_t1     T1        p1             1         1.5         1200
#> 2 subj1      s1_t2     T2        p1             1         1.1         1300
#> 3 subj1      s1_t3     T3        p2             0         0.2          800
#> 4 subj2      s2_t1     T1        p1             0         0.8          900
#> 5 subj2      s2_t2     T2        p2             1         1.9         1500
#> # ℹ 3 more variables: counts_hit <dbl>, run_id <chr>, plate_id <chr>
#> 
#> table size: 6 rows x 10 columns
#> 
#> peptide library preview (first 5 rows): 
#> meta flags: 
#>   con:            <duckdb_connection>
#>   longitudinal:   TRUE
#>   exist:          TRUE
#>   fold_change:    TRUE
#>   raw_counts:     TRUE
#>   extra_cols:     run_id, plate_id
#>   materialise_table: FALSE
#>   finalizer_env:  <environment>
#>   full_cross:     FALSE

# Filter to one subject and collect
pd_lg_subj1 <- pd_lg |>
  dplyr::filter(subject_id == "subj1") |>
  dplyr::collect()

pd_lg_subj1
#> # A tibble: 3 × 10
#>   subject_id sample_id timepoint peptide_id exist fold_change counts_input
#>   <chr>      <chr>     <chr>     <chr>      <dbl>       <dbl>        <dbl>
#> 1 subj1      s1_t1     T1        p1             1         1.5         1200
#> 2 subj1      s1_t2     T2        p1             1         1.1         1300
#> 3 subj1      s1_t3     T3        p2             0         0.2          800
#> # ℹ 3 more variables: counts_hit <dbl>, run_id <chr>, plate_id <chr>

# Compute average fold_change per subject across timepoints (lazy until collect)
pd_lg_avg <- pd_lg |>
  dplyr::group_by(subject_id) |>
  dplyr::summarise(mean_fc = mean(fold_change, na.rm = TRUE)) |>
  dplyr::collect()

pd_lg_avg
#> # A tibble: 2 × 2
#>   subject_id mean_fc
#>   <chr>        <dbl>
#> 1 subj2        1.73 
#> 2 subj1        0.933

# Inspect extra columns (metadata not part of the standard set)
pd_lg$meta$extra_cols  # should list run_id and plate_id
#> [1] "run_id"   "plate_id"
```

Export longitudinal data:

``` r
out_parquet_lg <- tempfile(fileext = ".parquet")
export_parquet(pd_lg, out_parquet_lg)
out_parquet_lg
#> [1] "/tmp/Rtmpmvm9ha/file1f9d99bc91f.parquet"
```

## Tips and gotchas

- **Uniqueness:** `sample_id` must be unique per sample. In
  cross-sectional data that also serves as the subject identifier; in
  longitudinal data use `subject_id` to connect multiple `sample_id`s.
- **Column mapping:** If your column names differ, map them with the
  function arguments (`sample_id`, `peptide_id`, `subject_id`,
  `timepoint`, etc.).
- **Auto-expand:** set `auto_expand = TRUE` to fill missing
  `sample_id × peptide_id` combinations (measurement columns filled with
  0 or overrides).
- **Peptide library:** set `peptide_library = TRUE` to attach metadata;
  keep `FALSE` for quick examples or offline runs.

## Using the built-in example

``` r
ex <- load_example_data()
#> [13:45:44] INFO  Constructing <phip_data> object
#>                  -> create_data()
#> [13:45:44] INFO  Fetching peptide metadata library via get_peptide_library()
#> [13:45:44] INFO  Retrieving peptide metadata into DuckDB cache
#>                  -> get_peptide_library(force_refresh = FALSE)
#> [13:45:44] INFO  Opened DuckDB connection
#>                    - cache dir:
#>                      /home/runner/.cache/R/phiperio/peptide_meta/phip_cache.duckdb
#>                    - table: peptide_meta
#> [13:45:44] OK    Using cached peptide_meta (fast path)
#> [13:45:44] OK    Retrieving peptide metadata into DuckDB cache - done
#>                  -> elapsed: 0.213s
#> [13:45:44] OK    Peptide metadata acquired
#> [13:45:44] INFO  Validating <phip_data>
#>                  -> validate_phip_data()
#> [13:45:44] INFO  Checking structural requirements (shape & mandatory columns)
#> [13:45:44] INFO  Checking outcome family availability (exist / fold_change /
#>                  raw_counts)
#> [13:45:44] INFO  Checking collisions with reserved names
#>                    - subject_id, sample_id, timepoint, peptide_id, exist,
#>                      fold_change, counts_input, counts_hit
#> [13:45:44] INFO  Ensuring all columns are atomic (no list-cols)
#> [13:45:44] INFO  Checking key uniqueness
#> [13:45:44] INFO  Validating value ranges & types for outcomes
#> [13:45:44] INFO  Assessing sparsity (NA/zero prevalence vs threshold)
#>                    - warn threshold: 50%
#> [13:45:44] INFO  Checking peptide_id coverage against peptide_library
#> Warning: [13:45:45] WARN  peptide_id not found in peptide_library (e.g. 10003)
#>                  -> peptide library coverage.
#> [13:45:45] INFO  Checking full grid completeness (peptide * sample)
#> Warning: [13:45:45] WARN  Counts table is not a full peptide * sample grid.
#>                  -> grid completeness
#>                    - observed rows: 78200
#>                    - expected rows: 156000.
#> Warning: [13:45:45] WARN  Grid remains incomplete (auto_expand = FALSE).
#>                  -> grid completeness
#>                    - observed rows: 78200
#>                    - expected rows: 156000.
#> [13:45:45] OK    Validating <phip_data> - done
#>                  -> elapsed: 0.596s
#> [13:45:45] OK    Constructing <phip_data> object - done
#>                  -> elapsed: 0.811s
ex
#> ── <phip_data> ───────────────────────────────────────────────────────────────── 
#> 
#> counts (first 5 rows): 
#> # A tibble: 5 × 9
#>   sample_id subject_id group timepoint peptide_id exist counts_control
#>   <chr>     <chr>      <chr> <chr>     <chr>      <int>          <int>
#> 1 A_T1_1    1          A     T1        10003          1              5
#> 2 A_T1_1    1          A     T1        10017          1             37
#> 3 A_T1_1    1          A     T1        10023          1             11
#> 4 A_T1_1    1          A     T1        10062          1              0
#> 5 B_T1_1    1          B     T1        10087          1              1
#> # ℹ 2 more variables: counts_hits <int>, fold_change <dbl>
#> 
#> table size: 78,200 rows x 9 columns
#> 
#> peptide library preview (first 5 rows): 
#> # A tibble: 5 × 8
#>   peptide_id Fullname                    species genus family order class common
#>   <chr>      <chr>                       <chr>   <chr> <chr>  <chr> <chr> <chr> 
#> 1 agilent_1  Chromodomain-helicase-DNA-… Homo s… Homo  Homin… Prim… Mamm… Human 
#> 2 agilent_2  integral membrane protein   Mycoba… Myco… Mycob… Myco… Acti… NA    
#> 3 agilent_3  hypothetical protein (6/16… Mycoba… Myco… Mycob… Myco… Acti… NA    
#> 4 agilent_4  envelope protein (5/8) & a… Orthof… Orth… Flavi… Amar… Flas… JEV   
#> 5 agilent_5  Myosin-7 & beta-myosin hea… Homo s… Homo  Homin… Prim… Mamm… Human 
#> ... plus 36 more columns
#> 
#> library size: 357,190 rows x 44 columns
#> 
#> meta flags: 
#>   con:            <duckdb_connection>
#>   longitudinal:   TRUE
#>   exist:          TRUE
#>   fold_change:    TRUE
#>   raw_counts:     FALSE
#>   extra_cols:     group, counts_control, counts_hits
#>   peptide_con:    <duckdb_connection>
#>   materialise_table: TRUE
#>   finalizer_env:  <environment>
#>   full_cross:     FALSE
```
