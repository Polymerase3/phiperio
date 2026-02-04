# Rename columns to PHIPERIO standard names in-place

`.ph_rename_to_standard_inplace()` renames columns in a DuckDB table or
view to the standard PHIPERIO schema using a mapping of standard names
to source columns. For views, it recreates the view with aliased
columns; for tables, it issues `ALTER TABLE ... RENAME COLUMN`
statements.

## Usage

``` r
.ph_rename_to_standard_inplace(tbl, con, colname_map)
```

## Arguments

- tbl:

  Character scalar. Name of the DuckDB table or view to modify.

- con:

  A valid DBI connection to DuckDB.

- colname_map:

  Named character list mapping **standard** PHIPERIO column names (e.g.
  `"sample_id"`, `"peptide_id"`) to the **actual** column names present
  in `tbl`.

## Value

Invisibly returns `tbl` after applying any renames.

## Details

- Only columns present in `tbl` are renamed.

- For views, the existing definition is retrieved and wrapped in a new
  `CREATE OR REPLACE VIEW` statement with aliased columns.

- If no matching columns are found, the function emits a message and
  exits.
