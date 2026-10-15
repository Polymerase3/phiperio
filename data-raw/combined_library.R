# This script curates the combined (agilent, twist and corona2) peptide library
# into the RDS file hosted in the companion phiper repo (library-metadata/),
# from which get_peptide_library(library = "combined") downloads it.
#
# Sources:
# * peptide_library.rds (16.07.2026), the library of the phipflow pipeline
#   (Vogl-Lab-Research/phipflow, peplib/), with the revised taxonomy and the
#   protein-level columns protein_seq_id, protein_unique_annotation and
#   taxon_with_protein_unique_annotation,
# * combined_library_06.07.26.rds, the previously hosted combined library, for
#   its protein_id column, which the phipflow library lacks.
# Run this script from the directory holding both files.
#
# Curation:
# * protein_id is matched in by peptide_id and placed before protein_seq_id,
# * the corona2 peptides, which the source leaves without protein-level
#   annotation, get it from their own columns: one protein_seq_id per Fullname
#   (numbered after the source's highest protseq_ id), Description as
#   protein_unique_annotation, and "<species>: <Description>" (NA without
#   species) as taxon_with_protein_unique_annotation,
# * the result is saved as a plain data.frame with xz compression.

src <- "peptide_library.rds"
prev <- "combined_library_06.07.26.rds"
out <- "combined_library_16.07.26.rds"

lib <- as.data.frame(readRDS(src))
prev_lib <- readRDS(prev)

stopifnot(
  names(lib)[1] == "peptide_id",
  !anyDuplicated(lib$peptide_id),
  setequal(lib$peptide_id, prev_lib$peptide_id)
)

protein_id <- prev_lib$protein_id[match(lib$peptide_id, prev_lib$peptide_id)]
seq_pos <- match("protein_seq_id", names(lib))
lib <- cbind(
  lib[seq_len(seq_pos - 1)],
  protein_id = protein_id,
  lib[seq_pos:ncol(lib)]
)

# corona2 proteins, numbered in order of first appearance
corona <- startsWith(lib$peptide_id, "corona2_")
proteins <- unique(lib$Fullname[corona])
last_id <- max(as.integer(sub("^protseq_", "", lib$protein_seq_id)), na.rm = TRUE)
lib$protein_seq_id[corona] <- paste0(
  "protseq_", last_id + match(lib$Fullname[corona], proteins)
)
lib$protein_unique_annotation[corona] <- lib$Description[corona]
lib$taxon_with_protein_unique_annotation[corona] <- ifelse(
  is.na(lib$species[corona]),
  NA,
  paste0(lib$species[corona], ": ", lib$Description[corona])
)

saveRDS(lib, out, compress = "xz")
