# This script curates the human proteome peptide library into the RDS file
# hosted in the companion phiper repo (library-metadata/), from which
# get_peptide_library(library = "human_proteome") downloads it.
#
# Source: HumanProteomeLib.csv (16.09.2026), stored on LISC under
# /lisc/data/work/ccr/SHARED_RESOURCES/. Run this script from the directory
# holding that file.
#
# Curation:
# * empty strings are read as NA,
# * full_aa_seq is dropped: it repeats the full protein sequence on every
#   peptide row (68,078 distinct proteins, 414 of the 570 MB), which pushes the
#   RDS past GitHub's 100 MB file limit. The combined library carries no
#   protein sequences either,
# * the comma-separated labels column is split into one logical is_<label>
#   column per label, matching the is_* flags of the other libraries,
# * the result is saved with xz compression.

src <- "HumanProteomeLib.csv"
out <- "human_proteome_library_16.09.26.rds"

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

# labels -> logical flags, e.g. "stable_transpos_ORF,proteome" sets
# is_stable_transpos_ORF and is_proteome
label_sets <- strsplit(lib$labels, ",", fixed = TRUE)
# typo in the source table
label_sets <- lapply(label_sets, sub,
  pattern = "^thearpeutic$", replacement = "therapeutic"
)
labels <- sort(unique(unlist(label_sets)))

flags <- lapply(labels, function(label) {
  vapply(label_sets, function(set) label %in% set, logical(1))
})
names(flags) <- paste0("is_", labels)

lib$labels <- NULL
lib <- cbind(lib, as.data.frame(flags, check.names = FALSE))

saveRDS(lib, out, compress = "xz")
