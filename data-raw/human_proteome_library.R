# This script curates the human proteome peptide library into the RDS file
# hosted in the companion phiper repo (library-metadata/), from which
# get_peptide_library(library = "human_proteome") downloads it.
#
# Source: humanProteome_newCol.rds (09.10.2026), stored on LISC under
# /lisc/data/scratch/ccr/NH/PhIP-Seq_projects/phipflow/peplib/. It is the
# previously hosted human_proteome_library_16.09.26.rds (curated from
# HumanProteomeLib.csv by the previous version of this script) with the
# protein-level columns prot_seq_id and taxon_with_protein_unique_annotation
# added. Run this script from the directory holding that file.
#
# Curation:
# * prot_seq_id is renamed to protein_seq_id, the name the other libraries use,
# * taxon_with_protein_unique_annotation is set to NA where species is NA (the
#   source writes "NA: <Fullname>"), as in the other libraries,
# * the result is saved as a plain data.frame with xz compression.

src <- "humanProteome_newCol.rds"
out <- "human_proteome_library_09.10.26.rds"

lib <- as.data.frame(readRDS(src))

stopifnot(
  names(lib)[1] == "peptide_id",
  !anyDuplicated(lib$peptide_id)
)

names(lib)[names(lib) == "prot_seq_id"] <- "protein_seq_id"

lib$taxon_with_protein_unique_annotation[is.na(lib$species)] <- NA

saveRDS(lib, out, compress = "xz")
