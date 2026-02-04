# Export a phip_data Table to Parquet

Exports the `data_long` table from a **phip_data** object to disk in
Apache Parquet format.

## Usage

``` r
export_parquet(x, path)
```

## Arguments

- x:

  A \<phip_data\> object or a data frame.

- path:

  File path (character) to save the output `.parquet` file.

## Value

NULL (invisibly).

## Note

The export is performed directly and efficiently from the database/lazy
table without reading all data into memory.

## Examples

``` r
pd <- load_example_data()
out_path <- tempfile(fileext = ".parquet")
export_parquet(pd, out_path)
unlink(out_path)
```
