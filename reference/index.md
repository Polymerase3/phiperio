# Package index

## Import data

Build a `<phip_data>` object from PhIP-Seq output.

- [`convert_standard()`](https://polymerase3.github.io/phiperio/reference/convert_standard.md)
  :

  Convert raw PhIP-Seq output into a `phip_data` object

- [`convert_legacy()`](https://polymerase3.github.io/phiperio/reference/convert_legacy.md)
  :

  Convert legacy Carlos-style input to a modern **phip_data** object

- [`create_data()`](https://polymerase3.github.io/phiperio/reference/create_data.md)
  :

  Construct a **phip_data** object

## Example data

- [`load_example_data()`](https://polymerase3.github.io/phiperio/reference/load_example_data.md)
  : Load Example PhIP-Seq Dataset as \<phip_data\>
- [`get_example_path()`](https://polymerase3.github.io/phiperio/reference/get_example_path.md)
  : Path to example PhIP-Seq datasets shipped with phiperio

## Work with phip_data

- [`get_counts()`](https://polymerase3.github.io/phiperio/reference/get_counts.md)
  : Retrieve the main PhIP-Seq counts table

- [`get_meta()`](https://polymerase3.github.io/phiperio/reference/get_meta.md)
  : Retrieve the metadata list

- [`add_exist()`](https://polymerase3.github.io/phiperio/reference/add_exist.md)
  :

  Ensure an existence flag (all ones) on `data_long`

- [`expand_data()`](https://polymerase3.github.io/phiperio/reference/expand_data.md)
  :

  Expand to a full `sample_id * peptide_id` grid

- [`left_join(`*`<phip_data>`*`)`](https://polymerase3.github.io/phiperio/reference/phip_data_join.md)
  [`right_join(`*`<phip_data>`*`)`](https://polymerase3.github.io/phiperio/reference/phip_data_join.md)
  [`inner_join(`*`<phip_data>`*`)`](https://polymerase3.github.io/phiperio/reference/phip_data_join.md)
  [`full_join(`*`<phip_data>`*`)`](https://polymerase3.github.io/phiperio/reference/phip_data_join.md)
  [`semi_join(`*`<phip_data>`*`)`](https://polymerase3.github.io/phiperio/reference/phip_data_join.md)
  [`anti_join(`*`<phip_data>`*`)`](https://polymerase3.github.io/phiperio/reference/phip_data_join.md)
  :

  dplyr joins for `phip_data`

- [`merge(`*`<phip_data>`*`)`](https://polymerase3.github.io/phiperio/reference/merge.phip_data.md)
  :

  Merge or join a `phip_data` object

- [`close(`*`<phip_data>`*`)`](https://polymerase3.github.io/phiperio/reference/close.phip_data.md)
  : Close phip_data connections

## Peptide libraries

- [`get_peptide_library()`](https://polymerase3.github.io/phiperio/reference/get_peptide_library.md)
  : Retrieve the peptide metadata table into DuckDB, forcing atomic
  types
- [`detect_peptide_libraries()`](https://polymerase3.github.io/phiperio/reference/detect_peptide_libraries.md)
  : Detect the peptide libraries a set of peptides belongs to

## Export

- [`export_parquet()`](https://polymerase3.github.io/phiperio/reference/export_parquet.md)
  : Export a phip_data Table to Parquet
