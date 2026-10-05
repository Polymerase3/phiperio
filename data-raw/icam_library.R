# This script curates the ICAM peptide library into the RDS file hosted in the
# companion phiper repo (library-metadata/), from which
# get_peptide_library(library = "icam") downloads it.
#
# Source: ICAM_library_with_all_info.csv.gz (01.10.2026), shipped in
# encoded_library_all_info.tar.gz together with the files of the
# normalization pipeline. Run this script from the directory holding the
# extracted csv.gz.
#
# Curation:
# * empty strings are read as NA,
# * full_aa_seq is dropped: it repeats the full protein sequence on every
#   peptide row (104,894 distinct proteins, 304 MB), which pushes the RDS past
#   GitHub's 100 MB file limit even with xz. The combined library carries no
#   protein sequences either,
# * Fullname, which the source omits, is filled with Description,
# * tax_id is stored as integer (the source writes it as a float, "411903.0"),
# * the 0/1 is_* flags are stored as logical,
# * the result is saved with xz compression.

src <- "ICAM_library_with_all_info.csv.gz"
out <- "icam_library_01.10.26.rds"

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

# Fullname goes right before Description
desc_pos <- match("Description", names(lib))
lib <- cbind(
  lib[seq_len(desc_pos - 1)],
  Fullname = lib$Description,
  lib[desc_pos:ncol(lib)]
)

lib$tax_id <- as.integer(lib$tax_id)

flag_cols <- grep("^is_", names(lib), value = TRUE)
lib[flag_cols] <- lapply(lib[flag_cols], as.logical)

saveRDS(lib, out, compress = "xz")
