# This script curates the ICAM peptide library into the RDS file hosted in the
# companion phiper repo (library-metadata/), from which
# get_peptide_library(library = "icam") downloads it.
#
# Source: ICAM_library_with_all_info.csv (09.10.2026), stored on LISC under
# /lisc/data/scratch/ccr/GI_projects/cancer_IAM_library/encoded_library/
# supporting_info/. Run this script from the directory holding that file.
#
# Curation:
# * empty strings are read as NA,
# * full_aa_seq is dropped: it repeats the full protein sequence on every
#   peptide row (104,894 distinct proteins, 304 MB), which pushes the RDS past
#   GitHub's 100 MB file limit even with xz. The combined library carries no
#   protein sequences either,
# * the 0/1 is_* flags are stored as logical,
# * the result is saved with xz compression.

src <- "ICAM_library_with_all_info.csv"
out <- "icam_library_09.10.26.rds"

lib <- utils::read.csv(
  src,
  na.strings = "",
  stringsAsFactors = FALSE,
  check.names = FALSE
)

stopifnot(
  names(lib)[1] == "peptide_id",
  !anyDuplicated(lib$peptide_id)
)

# full protein sequence, repeated for every peptide of the protein
lib$full_aa_seq <- NULL

flag_cols <- grep("^is_", names(lib), value = TRUE)
lib[flag_cols] <- lapply(lib[flag_cols], as.logical)

saveRDS(lib, out, compress = "xz")
