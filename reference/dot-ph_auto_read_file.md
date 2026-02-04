# Read CSV/TSV/Parquet with delimiter sniffing

`.ph_auto_read_file()` loads delimited text or parquet files, detecting
the delimiter for text inputs and using duckdb and DBI for parquet.

## Usage

``` r
.ph_auto_read_file(path, ...)
```

## Arguments

- path:

  Character scalar. Path to a CSV/TSV or parquet file.

- ...:

  Additional arguments passed to the underlying reader.

## Value

A data.frame containing the parsed file contents.
