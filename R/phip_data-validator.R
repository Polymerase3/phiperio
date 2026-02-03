#' Internal validator for <phip_data> objects
#' @keywords internal
validate_phip_data <- function(x,
                               na_warn_thresh = 0.50, # warn if >50% NA / zero
                               # optionally fill missing grid
                               auto_expand = TRUE) {
  .check_pd(x) # existing helper (assumes class & slots are sane)
  .data <- rlang::.data # to silence lintr / R CMD CHECK notes

  # timing the whole command
  .ph_with_timing(
    headline = "Validating <phip_data>",
    step = "validate_phip_data()",
    expr = {
      tbl <- x$data_long
      cols <- colnames(tbl)

      # defining the reserved names in phiper, thay can not be used for
      # extra_cols
      reserved <- c(
        "subject_id", "sample_id", "timepoint",
        "peptide_id", "exist", "fold_change",
        "counts_input", "counts_hit"
      )

      ## ---------------------------------------------- 1  STRUCTURE -----------
      .ph_log_info("Checking structural requirements
                   (shape & mandatory columns)")

      # is data longitudinal?
      is_long <- all(c("subject_id", "timepoint") %in% cols)

      # different sets of cols needed for longitudinal and cross-sectional
      need <- if (is_long) {
        c("subject_id", "timepoint", "sample_id", "peptide_id")
      } else {
        c("sample_id", "peptide_id")
      }

      # any cols needed but not provided?
      miss <- setdiff(need, cols)
      .chk_cond(
        length(miss) > 0,
        sprintf(
          "Missing mandatory column(s): %s",
          paste(miss, collapse = ", ")
        ),
        step = "structure"
      )

      # quick validate if at least one row in the data
      n_rows <- tbl |>
        dplyr::summarise(n = dplyr::n()) |>
        dplyr::pull(.data$n)

      .chk_cond(
        n_rows < 1,
        "The `data_long` has no rows!
        No peptides and/or subjects are specified.",
        step = "structure"
      )

      ## ---------------------------------------------- 2  OUTCOME FAMILY ------
      .ph_log_info("Checking outcome family availability
                   (exist / fold_change / raw_counts)")
      have <- list(
        exist = "exist" %in% cols,
        fold_change = "fold_change" %in% cols,
        raw_counts = all(c("input_count", "hit_count") %in% cols)
      )
      k <- sum(unlist(have))
      .chk_cond(
        k == 0,
        "No outcome column found (need exist / fold_change / raw_counts).",
        step = "outcomes"
      )

      ## -------------------------------------- 3  RESERVED-NAME COLLISIONS ----
      # reserved names defined at the beginning
      .ph_log_info("Checking collisions with reserved names",
        bullets = paste(reserved, collapse = ", ")
      )
      overlap <- intersect(x$meta$extra_cols, reserved)
      .chk_cond(
        length(overlap) > 0,
        sprintf(
          "extra_cols overlap with reserved names: %s",
          paste(overlap, collapse = ", ")
        ),
        step = "reserved names"
      )

      ## --------------------------------------------- 4  ATOMIC COLUMNS -------
      .ph_log_info("Ensuring all columns are atomic (no list-cols)")
      sample0 <- if (inherits(tbl, "tbl_lazy")) {
        # LIMIT 0 --> fetch only the schema, then drop DB-specific classes
        tbl |>
          utils::head(0) |>
          dplyr::collect() |>
          as.data.frame()
      } else {
        as.data.frame(tbl)
      }

      bad_atomic <- names(sample0)[vapply(sample0, is.list, logical(1))]
      .chk_cond(
        length(bad_atomic) > 0,
        sprintf(
          "Non-atomic (list) columns found: %s",
          paste(bad_atomic, collapse = ", ")
        ),
        step = "atomicity"
      )

      ## --------------------------------------------- 5  UNIQUENESS -----------
      .ph_log_info("Checking key uniqueness")
      if (is_long) {
        # in longitudinal layout, (subject_id, timepoint, peptide_id)
        # must map to a single sample_id
        dup <- tbl |>
          dplyr::count(.data$subject_id, .data$timepoint, .data$peptide_id) |>
          dplyr::filter(.data$n > 1) |>
          utils::head(1) |>
          dplyr::collect()

        .chk_cond(
          nrow(dup) > 0,
          "Each (subject_id, peptide_id, timepoint)
          must map to exactly one sample_id.",
          step = "uniqueness (longitudinal)"
        )
      } else {
        # in cross-sectional layout, (sample_id, peptide_id) pairs must be
        # unique
        dup <- tbl |>
          dplyr::count(.data$sample_id, .data$peptide_id) |>
          dplyr::filter(.data$n > 1) |>
          utils::head(1) |>
          dplyr::collect()

        .chk_cond(
          nrow(dup) > 0,
          "Duplicate (sample_id, peptide_id) pairs found.",
          step = "uniqueness (cross-sectional)"
        )
      }

      ## ---------------------------------------------- 6  VALUE RANGES --------
      .ph_log_info("Validating value ranges & types for outcomes")

      if (have$exist) {
        bad <- tbl |>
          dplyr::filter(!is.na(.data$exist) & !(.data$exist %in% c(0, 1))) |>
          utils::head(1) |>
          dplyr::collect()
        .chk_cond(nrow(bad) > 0, "`exist` must be 0/1/NA.",
          step = "value ranges: exist"
        )
      }

      if (have$fold_change) {
        ok <- tbl |>
          # multiply by 1.0 to coerce integer --> double in SQL engines
          dplyr::mutate(fold_change = .data$fold_change * 1.0) |>
          dplyr::summarise(all_finite = all(is.finite(.data$fold_change))) |>
          dplyr::pull(.data$all_finite)
        .chk_cond(!ok, "`fold_change` contains Inf/-Inf or NA.",
          step = "value ranges: fold_change"
        )
      }

      if (have$raw_counts) {
        neg <- tbl |>
          dplyr::filter(.data$input_count < 0 | .data$hit_count < 0) |>
          utils::head(1) |>
          dplyr::collect()
        .chk_cond(nrow(neg) > 0, "Raw counts must be non-negative.",
          step = "value ranges: raw_counts"
        )
      }

      ## ---------------------------------------------- 7  SPARSITY WARNING ----
      .ph_log_info("Assessing sparsity (NA/zero prevalence vs threshold)",
        bullets = sprintf(
          "warn threshold: %.0f%%",
          na_warn_thresh * 100
        )
      )

      if (have$exist) {
        prop_na <- tbl |>
          dplyr::summarise(
            p = sum(dplyr::if_else(is.na(.data$exist), 1, 0)) / dplyr::n()
          ) |>
          dplyr::pull(.data$p)

        if (prop_na > na_warn_thresh) {
          .ph_warn(
            headline = "High NA fraction in `exist`.",
            step     = "sparsity",
            bullets  = sprintf("NA share: %.0f %%", prop_na * 100)
          )
        }
      }

      if (have$raw_counts) {
        prop_zero <- tbl |>
          dplyr::summarise(
            p = sum(dplyr::if_else(.data$input_count == 0 &
              .data$hit_count == 0, 1, 0)) / dplyr::n()
          ) |>
          dplyr::pull(.data$p)

        if (prop_zero > na_warn_thresh) {
          .ph_warn(
            headline = "Both raw count columns are 0 in many rows.",
            step     = "sparsity",
            bullets  = sprintf("zero-share: %.0f %%", prop_zero * 100)
          )
        }
      }

      ## ------------------------------------------- 8  PEPTIDE-ID COVERAGE ----
      .ph_log_info("Checking peptide_id coverage against peptide_library")
      if (!is.null(x$peptide_library)) {
        missing_in_lib <- setdiff(
          tbl |> dplyr::distinct(.data$peptide_id) |> dplyr::pull(),
          x$peptide_library |>
            dplyr::distinct(.data$peptide_id) |>
            dplyr::pull()
        )

        missing_in_lib <- missing_in_lib[order(missing_in_lib)]

        .chk_cond(
          length(missing_in_lib) > 0,
          sprintf(
            "peptide_id not found in peptide_library (e.g. %s)",
            missing_in_lib[1]
          ),
          error = FALSE, # emit warning instead of abort
          step = "peptide library coverage"
        )
      }

      ## --------------------------------------------- 9  COMPARISONS TABLE ----
      .ph_log_info("Validating comparisons table (if provided)")
      cmp <- x$comparisons
      if (nrow(cmp) > 0) {
        allowed_cmp_cols <- c("comparison", "group1", "group2", "variable")
        extra_cmp <- setdiff(colnames(cmp), allowed_cmp_cols)
        .chk_cond(
          length(extra_cmp) > 0,
          sprintf(
            "Unexpected columns in comparisons: %s",
            paste(extra_cmp, collapse = ", ")
          ),
          step = "comparisons: schema"
        )

        valid_labels <- if (is_long) {
          # which of the two exist? (timepoint / group)
          valid_cols <- dplyr::intersect(c("timepoint", "group"), colnames(tbl))

          tbl |> # keep only the existing ones
            dplyr::select(dplyr::all_of(valid_cols)) |>
            dplyr::distinct() |> # unique row-wise combinations
            dplyr::collect() |> # pull the tiny result into R
            unlist(use.names = FALSE) |> # flatten to one vector
            unique() # final de-dup
        } else {
          tbl |>
            dplyr::distinct(.data$group) |>
            dplyr::pull(.data$group)
        }

        bad_cmp <- unique(c(
          setdiff(cmp$group1, valid_labels),
          setdiff(cmp$group2, valid_labels)
        ))

        .chk_cond(
          length(bad_cmp) > 0,
          sprintf(
            "comparisons refer to unknown group labels (e.g. %s)",
            bad_cmp[1]
          ),
          step = "comparisons: labels"
        )
      }

      ## ---------------------------------------------- 10 FULL GRID -----------
      .ph_log_info("Checking full grid completeness (peptide * sample)")

      dims <- tbl |>
        dplyr::summarise(
          n_pep = dplyr::n_distinct(.data$peptide_id),
          n_smp = dplyr::n_distinct(.data$sample_id),
          n_obs = dplyr::n()
        ) |>
        dplyr::collect()

      expect <- dplyr::pull(dims, .data$n_pep) * dplyr::pull(dims, .data$n_smp)

      if (dplyr::pull(dims, .data$n_obs) != expect) {
        .ph_warn(
          headline = "Counts table is not a full peptide * sample grid.",
          step = "grid completeness",
          bullets = c(
            sprintf("observed rows: %s", dplyr::pull(dims, .data$n_obs)),
            sprintf("expected rows: %s", expect)
          )
        )

        if (isTRUE(auto_expand)) {
          .ph_log_info("Auto-expanding to full grid via
                       expand_phip_data()",
            bullets = c("add_exist = TRUE", "exist_col = \"exist\"")
          )

          x <- expand_phip_data(
            x,
            key_col = "sample_id",
            id_col = "peptide_id",
            add_exist = TRUE, # keep binary column
            exist_col = "exist",
            fill_override = list(
              exist        = 0L,
              fold_change  = 0,
              input_count  = 0L,
              hit_count    = 0L,
              counts_input = 0L,
              counts_hit   = 0L
            )
          )

          .ph_log_ok("Auto-expansion complete; grid is now full")
        } else {
          .ph_warn(
            headline = "Grid remains incomplete (auto_expand = FALSE).",
            step = "grid completeness",
            bullets = c(
              sprintf("observed rows: %s", dplyr::pull(dims, .data$n_obs)),
              sprintf("expected rows: %s", expect)
            )
          )
          x$meta$full_cross <- FALSE
        }
      } else {
        x$meta$full_cross <- TRUE
        .ph_log_ok("Counts table is a full peptide * sample grid")
      }

      invisible(x)
    },
    verbose = .ph_opt("verbose", TRUE)
  )
}

# ==============================================================================
# Full-grid expansion functions with phiper-style logging
# ==============================================================================

# 1) INTERNAL ENGINE: expand to full key*id grid, keep types, fill gaps
# ------------------------------------------------------------------------------
# Notes:
# - Works for local and lazy dbplyr tables without forcing collection (except
#   for a 0-row "type probe" when lazy, to infer column classes for fill
#   defaults - but its cheap).
# - If add_exist=TRUE and `exist_col` already exists, it will be overwritten
#   with a warning
# - The key_col can be a vector: eg. c("subject_id","timepoint_factor"), etc.
.phip_expand_full_grid <- function(tbl,
                                   key_col = "sample_id",
                                   id_col = "peptide_id",
                                   fill_override = NULL,
                                   add_exist = FALSE,
                                   exist_col = "exist") {
  # defining names
  key_cols <- as.character(key_col)
  id_col <- as.character(id_col)[1]

  # global wrapper to time the command
  .ph_with_timing(
    headline = "Expanding to full key * id grid",
    step = sprintf(
      "keys: %s; id: %s",
      paste(add_quotes(key_cols, 1L), collapse = ", "),
      add_quotes(id_col, 1L)
    ),
    expr = {
      # clean eval helper vars
      .data <- rlang::.data
      key_syms <- rlang::syms(key_cols)
      id_sym <- rlang::sym(id_col)
      row_exists_sym <- rlang::sym(".row_exists")

      # -- 0) Validate presence of required columns ----------------------------
      missing_cols <- setdiff(c(key_cols, id_col), colnames(tbl))
      if (length(missing_cols)) {
        .ph_abort(
          headline = "Required columns are missing.",
          step = "input validation",
          bullets = c(
            sprintf(
              "missing: %s",
              paste(add_quotes(missing_cols, 2L), collapse = ", ")
            ),
            sprintf(
              "available: %s",
              paste(add_quotes(colnames(tbl), 2L), collapse = ", ")
            )
          )
        )
      }

      # -- 1) Enforce uniqueness of (key, id) pairs ----------------------------
      .ph_log_info("Checking uniqueness of (key, id) pairs")
      dup_pairs <- tbl |>
        dplyr::count(
          dplyr::across(dplyr::all_of(c(
            key_cols,
            id_col
          ))),
          name = ".n"
        ) |>
        dplyr::filter(.data$.n > 1L)

      dup_count <- dup_pairs |>
        dplyr::tally(name = "n_dups") |>
        dplyr::collect() |>
        dplyr::pull(n_dups)
      dup_count <- if (length(dup_count)) dup_count else 0L

      # give examples in the error message when duplicates present
      if (dup_count > 0L) {
        # collect the duplicates (only 5 to keep things lean)
        ex <- dup_pairs |>
          dplyr::slice_head(n = 5) |>
          dplyr::collect()

        # format a few duplicate examples with vapply
        fmt_ex <- character(0)
        if (nrow(ex) > 0L) { # fallback
          # loop over rows
          fmt_ex <- vapply(seq_len(nrow(ex)), function(i) {
            row_i <- ex[i, , drop = FALSE] # grab the row

            kv_key <- vapply( # format the key columns
              key_cols,
              function(k) {
                sprintf(
                  "%s=%s",
                  k,
                  add_quotes(as.character(row_i[[k]]), 1L)
                )
              },
              character(1)
            )

            kv_id <- sprintf(
              "%s=%s", # format the id col
              id_col,
              add_quotes(as.character(row_i[[id_col]]), 1L)
            )

            kv_n <- sprintf(
              ".n=%s", # how many duplicate overall
              as.character(row_i[[".n"]])
            )

            paste(c(kv_key, kv_id, kv_n), collapse = ", ") # paste message
          }, character(1))
          fmt_ex <- paste0("  - ", fmt_ex)
        }

        # hard abort, as no duplicates are allowed; it actually should already
        # be checked with the phiper validator, but the auto_expand method can
        # also be usade for data.frames, so it was important to check it here
        # too
        .ph_abort(
          headline = "Duplicate (key, id) pairs found.",
          step = "uniqueness enforcement",
          bullets = c(
            sprintf("duplicates: %s", dup_count),
            if (length(fmt_ex)) c("examples:", fmt_ex) else NULL
          )
        )
      }

      # -- 2) probe column types (for lazy tables: head(0) to infer classes) ---
      sample0 <- if (inherits(tbl, "tbl_lazy")) {
        .ph_log_info("Type probe on lazy table", step = "collect(head 0)")
        tbl |>
          utils::head(0) |>
          dplyr::collect() |>
          as.data.frame()
      } else {
        as.data.frame(tbl)
      }

      # -- 3) Build robust cross of distinct keys * distinct ids ---------------
      .ph_log_info("Building Cartesian product of keys and ids")
      make_cross <- function(tbl_in) {
        key_tbl <- tbl_in |> # distinct keys
          dplyr::distinct(dplyr::across(dplyr::all_of(key_cols))) |>
          dplyr::transmute(dplyr::across(dplyr::all_of(key_cols)), dummy = 1L)
        id_tbl <- tbl_in |> # distinct ids
          dplyr::distinct(!!id_sym) |>
          dplyr::transmute(!!id_sym, dummy = 1L)
        key_tbl |> # join them
          dplyr::inner_join(id_tbl, by = "dummy") |>
          dplyr::select(-dummy)
      }
      cross_tbl <- make_cross(tbl)

      # -- 4) Split columns: recyclable (per-key constants) vs non-recyclable --
      # i defined the recyclable columns, as columns, whose values can be copied
      # after expansion, eg.: "sex" is defined for each sample_id in the primary
      # table; the expansion only expands the peptides, so for each new expanded
      # peptide, the sex can be copied from the same sample_id
      # non-recyclable columns are usually the output columns: fold_change,
      # exist, counts etc. --> in this case we simply fill the expanded rows
      # with 0's or NA's, dependind on what the user wants. The auto_expand
      # function actually only makes sense for the analysis of "exist"-type data
      # so we do not really care what happens to the other cols.
      candidate_cols <- setdiff(colnames(tbl), c(key_cols, id_col))
      recyclable_cols <- character(0)

      if (length(candidate_cols)) {
        # log for which columns we’ll test for per-key constancy
        .ph_log_info("Detecting per-key constant (recyclable) columns",
          bullets = sprintf(
            "candidates: %s",
            if (length(candidate_cols)) {
              paste(candidate_cols, collapse = ", ")
            } else {
              "<none>"
            }
          )
        )

        # for each key group, check if each candidate column has exactly 1
        # distinct value (NA counts as a value since na.rm = FALSE). Result: one
        # row per key, with boolean columns named "const_<col>" telling whether
        # that column is constant in that key.
        const_tbl <- tbl |>
          dplyr::group_by(dplyr::across(dplyr::all_of(key_cols))) |>
          dplyr::summarise(
            dplyr::across(
              dplyr::all_of(candidate_cols),
              # TRUE if exactly one value in this key
              ~ dplyr::n_distinct(.x, na.rm = FALSE) == 1L,
              .names = "const_{.col}"
            ),
            .groups = "drop"
          ) |>
          dplyr::collect() # pull the (small) boolean summary locally

        # keep only those candidate columns that are constant in every key group
        recyclable_cols <- candidate_cols[vapply(
          candidate_cols,
          function(col) isTRUE(all(const_tbl[[paste0("const_", col)]])),
          logical(1)
        )]
      }

      # never "recycle" the id column (fallback)
      recyclable_cols <- setdiff(recyclable_cols, id_col)
      non_recyclable_cols <- setdiff(candidate_cols, recyclable_cols)

      # log the progress
      .ph_log_ok("Column split decided",
        bullets = c(
          sprintf("recyclable: %s", if (length(recyclable_cols)) {
            paste(recyclable_cols, collapse = ", ")
          } else {
            "<none>"
          }),
          sprintf("non-recyclable: %s", if (length(non_recyclable_cols)) {
            paste(non_recyclable_cols, collapse = ", ")
          } else {
            "<none>"
          })
        )
      )

      # -- 5) Per-key metadata (unique rows) + base cells and sentinel ---------
      # sentinel is only to define, if the row was there before the expansion or
      # not --> it will be deleted at the end of the function
      sample_meta <- if (length(recyclable_cols)) {
        tbl |>
          dplyr::select(dplyr::all_of(c(key_cols, recyclable_cols))) |>
          dplyr::distinct()
      } else {
        tbl |>
          dplyr::select(dplyr::all_of(key_cols)) |>
          dplyr::distinct()
      }

      base_cells <- tbl |>
        dplyr::select(dplyr::all_of(c(
          key_cols,
          id_col,
          non_recyclable_cols
        ))) |>
        dplyr::mutate(!!row_exists_sym := 1L)

      # -- 6) Join cross with metadata and current cells -----------------------
      has_join_by <- tryCatch(utils::packageVersion("dplyr") >= "1.1.0",
        error = function(e) FALSE
      )
      by_key <- if (has_join_by) dplyr::join_by(!!!key_syms) else key_cols
      by_both <- if (has_join_by) {
        dplyr::join_by(!!!key_syms, !!id_sym)
      } else {
        c(key_cols, id_col)
      }

      ## the main workhorse of the func --> expanding the table by joining
      ## it is like that (no expand.grid), cause it's faster and works on the
      ## database backends. DO NOT CHANGE!
      out <- cross_tbl |>
        dplyr::left_join(sample_meta, by = by_key) |>
        dplyr::left_join(base_cells, by = by_both)

      # -- 7) Identify which columns to fill for introduced (new) rows ---------
      # reserved measurement variable names in phiper
      common_measurement_names <- c(
        "exist", "fold_change",
        "input_count", "hit_count",
        "counts_input", "counts_hit"
      )

      # defining which ones to fill
      have_cols <- intersect(non_recyclable_cols, colnames(out))
      fill_candidates <- intersect(common_measurement_names, colnames(out))
      more_candidates <- setdiff(have_cols, fill_candidates)

      # type of the columns to fill
      is_num <- function(x) {
        inherits(x, c(
          "numeric", "integer",
          "double", "integer64"
        ))
      }
      is_lgl <- function(x) is.logical(x)

      # preparing fills
      to_fill_num <- unique(c(
        intersect(
          fill_candidates,
          names(sample0)[vapply(sample0, is_num, logical(1))]
        ),
        more_candidates[vapply(
          more_candidates,
          function(cn) is_num(sample0[[cn]]), logical(1)
        )]
      ))

      to_fill_lgl <- unique(c(
        intersect(
          fill_candidates,
          names(sample0)[vapply(sample0, is_lgl, logical(1))]
        ),
        more_candidates[vapply(
          more_candidates,
          function(cn) is_lgl(sample0[[cn]]), logical(1)
        )]
      ))

      ## logging progress
      .ph_log_info("Preparing fill defaults for introduced rows",
        bullets = c(
          sprintf("numeric/integer: %s", if (length(to_fill_num)) {
            paste(to_fill_num, collapse = ", ")
          } else {
            "<none>"
          }),
          sprintf("logical: %s", if (length(to_fill_lgl)) {
            paste(to_fill_lgl, collapse = ", ")
          } else {
            "<none>"
          })
        )
      )

      # -- 8) Apply user overrides, then fill remaining num/logical cols -------
      if (!is.null(fill_override) && length(fill_override)) {
        .ph_log_info("Applying user-provided fill overrides",
          bullets = sprintf(
            "overrides: %s",
            paste(names(fill_override),
              collapse = ", "
            )
          )
        )

        ## override the default fills with user-provided values
        # inside your overrides loop
        for (nm in intersect(names(fill_override), colnames(out))) {
          val <- fill_override[[nm]] # scalar replacement for introduced rows
          col_sym <- rlang::sym(nm)

          out <- out |>
            dplyr::mutate(
              !!col_sym := dplyr::if_else(
                is.na(!!row_exists_sym),
                val, # scalar OK; dbplyr will inline it
                !!col_sym # <- use the symbol, not .data[[nm]]
              )
            )

          to_fill_num <- setdiff(to_fill_num, nm)
          to_fill_lgl <- setdiff(to_fill_lgl, nm)
        }
      }

      # apply defaults on the remaining columns, not specified by the user
      if (length(to_fill_num)) {
        out <- out |>
          dplyr::mutate(
            dplyr::across(
              dplyr::all_of(to_fill_num),
              ~ dplyr::if_else(is.na(!!row_exists_sym), 0, .x)
            )
          )
      }

      # same as up but logicals
      if (length(to_fill_lgl)) {
        out <- out |>
          dplyr::mutate(
            dplyr::across(
              dplyr::all_of(to_fill_lgl),
              ~ dplyr::if_else(is.na(!!row_exists_sym), FALSE, .x)
            )
          )
      }

      # -- 9) Optional existence flag (0/1); OVERWRITE if present --------------
      # the "exist" column does not have to be present in the original dataset,
      # the function can add it
      if (isTRUE(add_exist)) {
        exist_sym <- rlang::sym(exist_col)
        if (exist_col %in% colnames(out)) { # warn if "exist" is in data
          .ph_warn(
            headline = "Overwriting existing existence flag.",
            step = "adding existence indicator",
            bullets = c(
              sprintf("column: %s", add_quotes(exist_col, 2L)),
              "old values will be replaced by derived 0/1 flag"
            )
          )
        } else {
          .ph_log_info("Adding existence flag column",
            bullets = sprintf("column: %s", add_quotes(exist_col, 2L))
          )
        }

        out <- out |>
          dplyr::mutate(!!exist_sym := dplyr::if_else(is.na(!!row_exists_sym),
            0L,
            1L
          ))
      }

      # -- 10) Drop sentinel and return ----------------------------------------
      out |>
        dplyr::select(-!!row_exists_sym)
    },
    verbose = .ph_opt("verbose", TRUE) # timing option
  )
}

# ------------------------------------------------------------------------------
#' @title Expand to a full `sample_id * peptide_id` grid
#'
#' @description Create the full Cartesian product of samples and peptides and
#'   join back per-sample metadata. For rows introduced by the expansion,
#'   numeric/integer columns are filled with `0` and logical columns with
#'   `FALSE`, unless overridden via `fill_override`.
#'
#' @details Updates `x$data_long` in place (preserving laziness unless you later
#'   `compute()` / `collect()`).
#'
#' @param x A `<phip_data>` object.
#' @param key_col Name(s) of the sample identifier column(s). Character scalar
#'   or vector, e.g. `"sample_id"` or `c("subject_id", "timepoint_factor")`.
#' @param id_col  Name of the peptide identifier column. Default `"peptide_id"`.
#' @param fill_override Optional named list of fill values for **introduced**
#'   rows, e.g. `list(present = 0L, fold_change = NA_real_)`. User-provided
#'   entries take precedence over the defaults.
#' @param add_exist If `TRUE`, add an integer existence flag (0/1) marking
#'   whether a row was present before the expansion.
#' @param exist_col Name for the existence flag. If this column already exists,
#'   it will be **overwritten**.
#' @param ... Reserved for future extensions; currently unused.
#'
#' @return The updated `<phip_data>` object.
#'
#' @examples
#' \dontrun{
#' pd <- expand_phip_data(pd, fill_override = list(fold_change = NA_real_))
#' }
#' @export
expand_phip_data <- function(x,
                             key_col = "sample_id",
                             id_col = "peptide_id",
                             fill_override = NULL,
                             add_exist = FALSE,
                             exist_col = "exist",
                             ...) {
  .ph_with_timing(
    headline = "Expanding <phip_data> to full grid",
    step = "updating x$data_long",
    expr = {
      # -- Expand data_long lazily (keeps DB laziness) ---------------------------
      tbl_expanded <- .phip_expand_full_grid(
        x$data_long,
        key_col       = key_col,
        id_col        = id_col,
        fill_override = fill_override,
        add_exist     = add_exist,
        exist_col     = exist_col
      )

      # -- Compute grid completeness on the lazy object (small collect) ----------
      n_pep <- tbl_expanded |>
        dplyr::summarise(n_pep = dplyr::n_distinct(.data[[id_col]])) |>
        dplyr::collect() |>
        dplyr::pull(.data$n_pep)

      n_smp <- tbl_expanded |>
        dplyr::distinct(dplyr::across(dplyr::all_of(key_col))) |>
        dplyr::summarise(n_smp = dplyr::n()) |>
        dplyr::collect() |>
        dplyr::pull(.data$n_smp)

      n_obs <- tbl_expanded |>
        dplyr::summarise(n_obs = dplyr::n()) |>
        dplyr::collect() |>
        dplyr::pull(.data$n_obs)

      expected <- n_pep * n_smp
      x$meta$full_cross <- (n_obs == expected)

      # -- If we added an existence flag, also store the observed share ----------
      if (isTRUE(add_exist)) {
        exist_prop <- tbl_expanded |>
          dplyr::summarise(prop = mean(.data[[exist_col]] * 1.0)) |>
          dplyr::pull(.data$prop)

        x$meta$exist_prop <- as.numeric(exist_prop)
        x$meta$exist <- TRUE
      }

      # -- Register back to DB ---------------------------------------------------
      .ph_log_info("Registering expanded table back to DB",
        bullets = c(
          sprintf("name: %s", add_quotes("data_long", 1L)),
          sprintf("materialise_table: %s", as.character(x$meta$materialise_table))
        )
      )
      x$data_long <- .ph_register_phip_data_tbl(
        tbl_expanded,
        con = x$meta$con,
        name = "data_long",
        materialise_table = x$meta$materialise_table
      )

      x
    },
    verbose = .ph_opt("verbose", TRUE)
  )
}

# ------------------------------------------------------------------------------
#' @title Register a lazy table back to the database as a TABLE or VIEW
#'
#' @description Convenience wrapper that either materialises a lazy pipeline via
#'   `dplyr::compute()` (creating a TABLE) or emits a `CREATE [TEMP] VIEW AS
#'   ...` (creating a VIEW). Returns a `dplyr::tbl()`
#'   pointing to the created object.
#'
#' @param tbl A lazy table (e.g., from `dbplyr`).
#' @param con A `DBI` connection.
#' @param name Target name to create (default `"data_long"`).
#' @param materialise_table If `TRUE`, create a TABLE via `compute()`. If
#'   `FALSE`, create a VIEW.
#' @param temporary If `TRUE`, create a TEMP table/view where supported.
#'
#' @return A lazy `dplyr::tbl` referencing the new TABLE/VIEW.
#'
#' @examples
#' \dontrun{
#' lazy <- dplyr::tbl(con, "data_long") |> dplyr::filter(fold_change > 0)
#' .ph_register_phip_data_tbl(lazy, con,
#'   name = "data_long_pos",
#'   materialise_table = TRUE
#' )
#' }
#' @keywords internal
.ph_register_phip_data_tbl <- function(tbl,
                                       con,
                                       name = "data_long",
                                       materialise_table = TRUE,
                                       temporary = TRUE) {
  .ph_with_timing(
    headline = "Registering lazy table",
    step = sprintf(
      "name: %s; as %s",
      add_quotes(name, 1L),
      if (isTRUE(materialise_table)) "TABLE" else "VIEW"
    ),
    expr = {
      if (isTRUE(materialise_table)) {
        .ph_log_info("Materialising via dplyr::compute()")
        dplyr::compute(
          tbl,
          name = name,
          temporary = temporary,
          unique_indexes = NULL,
          analyze = TRUE
        )
      } else {
        .ph_log_info("Emitting CREATE VIEW statement")
        qry_sql <- dbplyr::sql_render(tbl)
        DBI::dbExecute(
          con,
          sprintf(
            "CREATE OR REPLACE %sVIEW %s AS %s;",
            if (temporary) "TEMPORARY " else "",
            DBI::dbQuoteIdentifier(con, name),
            qry_sql
          )
        )
        dplyr::tbl(con, name)
      }
    },
    verbose = .ph_opt("verbose", TRUE)
  )
}
