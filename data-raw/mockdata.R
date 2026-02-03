# This script creates a small mock dataset for the antibody repertoires,
# principally to enable efficient automated testing of the package, but also to
# give small examples or vigtnettes to the users (thats why i export this
# dataset with use_data() at the end).
#
# The data have no biological meaning at all. I tried to mimic the structure and
# distribution of PhIP-Seq data by sampling from beta, binomial and poisson
# distribution, but obviously it is nearly impossible to mimic the exact
# structure and different relationships in such complex biological setting.
#
# Therefore i highlight once more: this data is only meant for testing and
# showing examples on how the code works. In the future we may want to ship
# another publicly available PhIP-Seq data, but for testing we need something
# small and lightweight.
#
# Structure:
# * two groups:              A and B,
# * two timepoints:          T1 and T2,
# * sample sizes (subjects): A_T1 = 20; A_T2 = 18, B_T1 = 23; B_T2 = 19
#
# The data is exported as .parquet. To load it using phiperio:
#
# library(phiperio)
# sim_path <- phip_example_path("phip_mixture")
#
# x <- phip_convert(
#   data_long_path = sim_path,
#   sample_id      = "sample_id",
#   peptide_id     = "peptide_id",
#   subject_id     = "subject_id",
#   timepoint      = "time",
#   exist          = "exist",
#   counts_input   = "counts_control",
#   counts_hit     = "counts_hits",
#   fold_change    = "fold_change",
#   n_cores        = 4
# )

# setting seed for reproducibility
set.seed(16783978L)
current_seed <- .Random.seed

# ------------------------------------------------------------------------------
# 1) Beta + binomial mixture generator for a single group * time
# ------------------------------------------------------------------------------
#' @title Simulate a two–component mixture of peptide prevalences
#'
#' @descritpiton Generates per-peptide prevalences from a mixture of
#' rare and common components, and draws Bernoulli counts
#' for a given number of subjects.
#'
#' @param n_peptides Integer scalar. Number of peptides to simulate.
#' @param n_subjects Integer scalar. Number of subjects per panel
#'   used as the binomial denominator for counts.
#' @param w_rare Numeric scalar in \[0, 1]. Mixture weight of the
#'   rare component (fraction of peptides that are rare).
#' @param rare_alpha Numeric > 0. Shape1 parameter of the Beta
#'   distribution for the rare component.
#' @param rare_beta Numeric > 0. Shape2 parameter of the Beta
#'   distribution for the rare component.
#' @param common_min Numeric scalar in \[0, 1]. Lower bound of the
#'   uniform distribution for the common component.
#' @param common_max Numeric scalar in \[0, 1]. Upper bound of the
#'   uniform distribution for the common component.
#'
#' @return
#' A `data.frame` with `n_peptides` rows and the columns:
#' \describe{
#'   \item{peptide_id}{Integer peptide index (1, 2, ..., `n_peptides`).}
#'   \item{n_obs}{Integer count of subjects with the peptide present.}
#'   \item{prevalence}{Empirical prevalence `n_obs / n_subjects`.}
#'   \item{p}{Underlying Bernoulli probability drawn from the mixture.}
#'   \item{common}{Logical, `TRUE` if drawn from the common component.}
#' }
#'
#' @keywords internal
simulate_mixture <- function(n_peptides = 50000,
                             n_subjects = 70,
                             w_rare = 0.9,
                             rare_alpha = 0.2,
                             rare_beta = 20,
                             common_min = 0.05,
                             common_max = 0.7) {
  # i tried to sample the probabilities directly from beta - it fails miserably
  # as the phipseq data tend to have a fat, uniform end; so the best option for
  # the sake of simulation was to combine both worlds: sample the rare from
  # beta and the more common (in terms of prevalence) from uniform distr

  # component membership: FALSE = rare, TRUE = common
  is_common <- rbinom(n_peptides, size = 1, prob = 1 - w_rare) == 1

  p <- numeric(n_peptides)

  # rare peptides: heavy mass near 0 from beta
  p[!is_common] <- rbeta(sum(!is_common), rare_alpha, rare_beta)

  # common peptides: almost uniform prevalence in [common_min, common_max] range
  p[is_common] <- runif(sum(is_common), min = common_min, max = common_max)

  # counts per peptide from binom
  k <- rbinom(n_peptides, size = n_subjects, prob = p)

  # return
  data.frame(
    peptide_id = seq_len(n_peptides),
    n_obs = k,
    prevalence = k / n_subjects,
    p = p,
    common = is_common,
    stringsAsFactors = FALSE
  )
}

# ------------------------------------------------------------------------------
# 2) Helper: expand one panel to subject * peptide long format
# ------------------------------------------------------------------------------
#' @title Expand a panel-level peptide summary to subject-level presence/absence
#'
#' @description Takes a panel-level data frame with per-peptide counts (`n_obs`)
#'   and expands it into a long subject-by-peptide table with a binary `exist`
#'   indicator for each subject/peptide combination.
#'
#' For each peptide, exactly `n_obs` subjects are sampled without
#' replacement from `1:n_subjects` and assigned `exist = 1`; all other
#' subject/peptide combinations receive `exist = 0`.
#'
#' @param panel_df An output `data.frame` from `simulate_mixture`
#'
#' @return
#' A `data.frame` with one row per subject–peptide combination and
#' columns:
#' \describe{
#'   \item{sample_id}{Character ID combining `group`, `time` and
#'     `subject_id` (e.g. `"A_T1_3"`).}
#'   \item{subject_id}{Integer subject index, `1, 2, ..., n_subjects`.}
#'   \item{time}{Timepoint label copied from `panel_df`.}
#'   \item{peptide_id}{Peptide identifier copied from `panel_df`.}
#'   \item{exist}{Integer 0/1 indicator of presence for this subject
#'     and peptide.}
#'   \item{group}{Group label copied from `panel_df`.}
#' }
#'
#' @keywords internal
expand_to_subjects <- function(panel_df) {
  # single n_subjects in this panel
  n_subj <- unique(panel_df$n_subjects)
  n_subj <- n_subj[1L]

  # for each peptide, choose n_obs subjects as "1"
  n_pep <- nrow(panel_df)
  pos_list <- vector("list", n_pep)

  for (i in seq_len(n_pep)) {
    k_i <- panel_df$n_obs[i] # how many people have this peptide
    if (k_i > 0L) {
      # when some people have this peptide, then sample k_i 1's
      pos_list[[i]] <- data.frame(
        peptide_id = panel_df$peptide_id[i],
        subject_id = sample.int(n_subj, size = k_i, replace = FALSE),
        exist = 1L,
        stringsAsFactors = FALSE
      )
    } else {
      # otherwise no sampling, cause nobody has it
      pos_list[[i]] <- NULL
    }
  }

  non_null <- !vapply(pos_list, is.null, logical(1))
  if (!any(non_null)) {
    # empty table when all peptides null
    pos_table <- data.frame(
      peptide_id = integer(0),
      subject_id = integer(0),
      exist      = integer(0)
    )
  } else {
    # otherwise bind the rows from pos_list tables
    pos_table <- dplyr::bind_rows(pos_list[non_null])
  }

  # full grid: all subjects * all peptides
  grid <- expand.grid(
    subject_id = seq_len(n_subj),
    peptide_id = panel_df$peptide_id
  )

  # group/time assumed constant within panel
  grid$group <- panel_df$group[1L]
  grid$time <- panel_df$time[1L]

  # merge and build sample_id from group * timepoint
  long_df <- merge(
    grid,
    pos_table,
    by = c("peptide_id", "subject_id"),
    all.x = TRUE,
    sort = FALSE
  )

  # should not happen but fallback
  long_df$exist[is.na(long_df$exist)] <- 0L

  long_df$sample_id <- paste(long_df$group, long_df$time,
                             long_df$subject_id, sep = "_")

  # reorder columns
  long_df <- long_df[, c(
    "sample_id", "subject_id", "group", "time",
    "peptide_id", "exist"
  )]

  long_df
}

# ------------------------------------------------------------------------------
# 3) Base panels: A_T1 and B_T1 (first panel-leves, peptide * summary)
# ------------------------------------------------------------------------------

n_peptides_target <- 1000L

# --- A_T1 ---
n_subjects_A_T1 <- 20L

# simulate (we have to wrap the call using the withr pacakge to preserve the
# seed; the sampling function are hella crazy and when i wrote my first package,
# vecmatch, i had a really hard time figuring out what is happening; it turns
# out, that all sample(), and r*() function, which sample from different
# distributions, change your .Random.seed by default. Wrapping them with withr
# prevents this behaviour. Some journals have extremely strict reproducibility
# policy, like JSS e.g., so we have to take good care of the seeds)
withr::with_preserve_seed({
  df_all_A_T1 <- simulate_mixture(
    n_peptides = 30000,
    n_subjects = n_subjects_A_T1,
    w_rare     = 0.93,
    common_min = 0.02,
    common_max = 0.90,
    rare_alpha = 0.35,
    rare_beta  = 25
  )
})

# filter to 1000 present peptides, no empty peptides in the set
withr::with_preserve_seed({
  df_A_T1 <- df_all_A_T1 |>
    dplyr::filter(n_obs > 0L) |>
    dplyr::slice_sample(n = n_peptides_target) |>
    dplyr::mutate(
      group      = "A",
      time       = "T1",
      n_subjects = n_subjects_A_T1
    ) |>
    dplyr::select(
      peptide_id, group, time, n_subjects,
      n_obs, prevalence, p, common
    )
})

# --- B_T1 ---
n_subjects_B_T1 <- 23L

withr::with_preserve_seed({
  df_all_B_T1 <- simulate_mixture(
    n_peptides = 30000,
    n_subjects = n_subjects_B_T1,
    # slightly different parameters than A_T1
    w_rare     = 0.91,
    common_min = 0.03,
    common_max = 0.80,
    rare_alpha = 0.40,
    rare_beta  = 18
  )
})

withr::with_preserve_seed({
  df_B_T1 <- df_all_B_T1 |>
    dplyr::filter(n_obs > 0L) |>
    dplyr::slice_sample(n = n_peptides_target) |>
    dplyr::mutate(
      group      = "B",
      time       = "T1",
      n_subjects = n_subjects_B_T1
    ) |>
    dplyr::select(
      peptide_id, group, time, n_subjects,
      n_obs, prevalence, p, common
    )
})

# ------------------------------------------------------------------------------
# 4) Expand A_T1 and B_T1 to subject * peptide long format
# ------------------------------------------------------------------------------

withr::with_preserve_seed({
  panel_A_T1_long <- expand_to_subjects(df_A_T1)
  panel_B_T1_long <- expand_to_subjects(df_B_T1)
})

# ------------------------------------------------------------------------------
# 5) Helper: derive T2 panel from T1 by dropout + noise
# ------------------------------------------------------------------------------

#' @title Derive a T2 panel from a T1 subject * peptide table
#'
#' @param long_df Data frame from `expand_to_subjects`
#' @param n_drop Integer. Number of subjects to remove (dropout).
#' @param flip_prop Numeric in [0, 1]. Proportion of rows in which to
#'   flip `exist` (0 <-> 1) as noise.
#' @param new_time Character. Label for the new timepoint (e.g. `"T2"`).
#'
#' @return A modified copy of `long_df` with fewer subjects,
#'   updated `time` and `sample_id`, and noisy `exist`.
#'
#' @keywords internal
make_T2_from_T1 <- function(long_df,
                            n_drop,
                            flip_prop = 0.20,
                            new_time = "T2") {
  # randomly choose subjects to drop; preserved by seed
  subj_ids <- sort(unique(long_df$subject_id))

  drop_subj <- sample(subj_ids, size = n_drop, replace = FALSE)
  keep_subj <- setdiff(subj_ids, drop_subj)

  # keep remaining subjects, set time to T2 by default and rebuild sample_id
  t2 <- long_df[long_df$subject_id %in% keep_subj, , drop = FALSE]
  t2$time <- new_time
  t2$sample_id <- paste(t2$group, t2$time, t2$subject_id, sep = "_")

  # flip exist for a subset of rows as noise
  n_rows <- nrow(t2)
  n_flip <- floor(flip_prop * n_rows)

  if (n_flip > 0L) {
    flip_idx <- sample.int(n_rows, size = n_flip, replace = FALSE)
    t2$exist[flip_idx] <- 1L - t2$exist[flip_idx]
  }

  t2
}

# A_T2: remove 2 subjects from A
withr::with_preserve_seed({
  panel_A_T2_long <- make_T2_from_T1(
    long_df = panel_A_T1_long,
    n_drop = 2L,
    flip_prop = 0.20,
    new_time = "T2"
  )
})

# B_T2: remove 4 subjects from B
withr::with_preserve_seed({
  panel_B_T2_long <- make_T2_from_T1(
    long_df = panel_B_T1_long,
    n_drop = 4L,
    flip_prop = 0.20,
    new_time = "T2"
  )
})


# ------------------------------------------------------------------------------
# 6) Combine everything into one long data.frame
# ------------------------------------------------------------------------------

panel_AB_T1_T2_long <- dplyr::bind_rows(
  panel_A_T1_long,
  panel_B_T1_long,
  panel_A_T2_long,
  panel_B_T2_long
)


# sanity check if the sample sizes are allright
panel_AB_T1_T2_long |>
  dplyr::count(group, time, subject_id) |>
  dplyr::count(group, time)

# ------------------------------------------------------------------------------
# 7) Add counts and fold_change + unique sample_id's
# ------------------------------------------------------------------------------

# additionally to the binary 0's and 1's we usually also have the raw number of
# reads, denoted here as counts_control and counts_hits; it is important to know
# that the reads you see in the original phipseq data are reads only for the
# peptides, which were marked as "hits" in the normalization pipelines. You
# don't really see all the other missing peptides from the library
#
# Simple sampling from Poisson + pseudocounts for fold_change. Should be fine
# for now; may expand/refine in the future
withr::with_preserve_seed({
  panel_AB_T1_T2_long <- panel_AB_T1_T2_long |>
    dplyr::mutate(
      sample_id = droplevels(factor(sample_id)),
      lambda_ctrl = runif(dplyr::n(), min = 0, max = 30),
      lambda_hits = runif(dplyr::n(), min = 10, max = 5000),
      counts_control = rpois(dplyr::n(), lambda = lambda_ctrl),
      counts_hits = rpois(dplyr::n(), lambda = lambda_hits),
      fold_change = (counts_hits + 0.5) / (counts_control + 0.5)
    ) |>
    dplyr::select(-lambda_ctrl, -lambda_hits)
})
# ------------------------------------------------------------------------------
# 8) Final touches + save the data
# ------------------------------------------------------------------------------
# convert the subject_id and peptide_id to characters
panel_AB_T1_T2_long$subject_id <- as.character(panel_AB_T1_T2_long$subject_id)
panel_AB_T1_T2_long$peptide_id <- as.character(panel_AB_T1_T2_long$peptide_id)

# remove potential duplicates
panel_AB_T1_T2_long <- panel_AB_T1_T2_long |>
  dplyr::arrange(subject_id, time, peptide_id) |>
  dplyr::distinct(subject_id, time, peptide_id, .keep_all = TRUE)

# Saving
out_path <- file.path("inst", "extdata", "phip_mixture.parquet")
export_parquet(panel_AB_T1_T2_long, out_path)

# reproducibility check
all.equal(current_seed, .Random.seed)
