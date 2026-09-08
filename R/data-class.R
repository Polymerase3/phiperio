#' @title Construct a **phip_data** object
#'
#' @description Creates a fully-validated S3 object that bundles the tidy
#'   PhIP-Seq counts (`data_long`), a peptide-library annotation table, and
#'   other metadata. The data itself is validated via `validate_phip_data()`.
#'
#' @param data_long A tidy data frame (or `tbl_lazy`) with one row per
#'   `peptide_id` x `sample_id` combination. **Required.**
#' @param peptide_library Peptide annotations to attach. `TRUE` (default)
#'   downloads the reference library via [get_peptide_library()]; `FALSE`
#'   attaches none. A data frame or lazy table with one row per `peptide_id`
#'   is attached as supplied, which is useful offline and in tests.
#' @param meta Optional named list of metadata flags to pre-populate the
#'   \code{meta} slot (rarely needed by users).
#' @param auto_expand Logical. If `TRUE` and the input is **not** already the
#'   full Cartesian product of `sample_id` x `peptide_id`, the function fills in
#'   the missing combinations.
#'   * Columns that are constant within a `sample_id` (metadata) are duplicated
#'     to the newly created rows.
#'   * Measurement columns such as `fold_change`, `exist`, raw counts, or any
#'     other non-recyclable fields are initialised to 0.
#'   The expanded table replaces `data_long` in place.
#' @param materialise_table Logical. If `FALSE` the result is registered as a
#'   **view**. If `TRUE` (default) the result is fully **materialised** and
#'   stored as a physical table, which speeds up repeated queries at the cost
#'   of extra memory/disk.
#'
#' @return An object of class \code{"phip_data"}.
#'
#' @examples
#' ## minimal constructor call
#' tidy_counts <- data.frame(
#'   sample_id = c("s1", "s1"),
#'   peptide_id = c("p1", "p2"),
#'   exist = c(1, 0),
#'   stringsAsFactors = FALSE
#' )
#' pd <- create_data(
#'   data_long = tidy_counts,
#'   peptide_library = FALSE,
#'   materialise_table = FALSE
#' )
#'
#' @export
create_data <- function(data_long,
                          peptide_library = TRUE,
                          auto_expand = TRUE,
                          materialise_table = TRUE,
                          meta = list()) {
  .ph_with_timing(
    headline = "Constructing <phip_data> object",
    step = "create_data()",
    expr = {

      # ------------------------------------------------------------------------
      # Download or attach the peptide metadata library
      # ------------------------------------------------------------------------
      if (isTRUE(peptide_library)) {
        .ph_log_info("Fetching peptide metadata library via
                     get_peptide_library()")
        peptide_library <- get_peptide_library()
        .ph_log_ok("Peptide metadata acquired")
      } else if (isFALSE(peptide_library)) {
        peptide_library <- NULL
      } else {
        .ph_check_cond(
          !is.data.frame(peptide_library) &&
            !inherits(peptide_library, "tbl"),
          "`peptide_library` must be TRUE, FALSE, or a table of annotations",
          step = "create_data()"
        )
        .ph_log_ok("Using supplied peptide metadata library")
      }

      # ------------------------------------------------------------------------
      # Scan column names for automatic meta flags
      # ------------------------------------------------------------------------
      # colnames() works for tibble, tbl_dbi, and arrow_dplyr_query
      cols <- colnames(data_long)
      standard_cols <- c(
        "subject_id", "sample_id", "timepoint", "peptide_id",
        "exist", "fold_change", "counts_input", "counts_hit"
      )

      meta$longitudinal <- all(c("timepoint", "sample_id") %in% cols)
      meta$exist <- "exist" %in% cols
      meta$fold_change <- "fold_change" %in% cols
      meta$raw_counts <- all(c("counts_input", "counts_hit") %in% cols)
      meta$extra_cols <- cols[cols %nin% standard_cols]
      meta$peptide_con <- attr(peptide_library, "duckdb_con")
      meta$materialise_table <- materialise_table

      # define the object
      obj <- structure(
        list(
          data_long       = data_long, # lazy tbl or tibble
          peptide_library = peptide_library,
          meta            = meta
        ),
        class = "phip_data"
      )

      obj <- .ph_sync_peptide_con(obj)
      obj <- .ph_attach_finalizer(obj)

      # ------------------------------------------------------------------------
      # Validate the objects used to construct the phip_data
      # ------------------------------------------------------------------------
      # will stop on error, warn on non-fatal issues
      obj <- validate_phip_data(obj, auto_expand = auto_expand)

      # return clean validated phip_data
      return(obj)
    },
    verbose = .ph_opt("verbose", TRUE)
  )
}
