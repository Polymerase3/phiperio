#' phiperio
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @useDynLib phiperio, .registration = TRUE
## usethis namespace: end
NULL

# There is a note for not-declared global variables in R CMD CHECK. This is a
# little bit tricky when using dplyr to manipulate the data, as you use the
# unquoted names of the variables to access the columns in the data. R CMD CHECK
# sees it as a global variable and cries, that you use it, but haven't defined
# it. It is a pretty well known bug, i bypassed it a little bit differently in
# vecmatch, but actually defining all the variables as global will also do the
# trick + you have all the vars in one place.
utils::globalVariables(c(
  ".",
  ".env",
  ".exist",
  ".x",
  ":=",
  "N",
  "b",
  "d1",
  "d2",
  "design",
  "dummy",
  "example",
  "group",
  "group1",
  "group2",
  "group_col",
  "k",
  "n",
  "n_dups",
  "n_peptides",
  "peptide_id",
  "present",
  "prop",
  "ratio",
  "sample_id",
  "subject_id",
  "v",
  "view",
  "x",
  "y"
))
