#' @title Close phip_data connections
#'
#' @description Closes any open database connections held by a `phip_data`
#' object. This includes the main `data_long` backend connection and any
#' peptide-library connection stored in attributes or metadata. The method is
#' idempotent and safe to call multiple times.
#'
#' @param con A valid `phip_data` object.
#' @param ... Unused (for S3 generic compatibility).
#'
#' @return The input `phip_data` object, invisibly.
#' @exportS3Method close phip_data
close.phip_data <- function(con, ...) {
  .check_pd(con)
  con <- .ph_close_phip_data(con, clear = TRUE)
  invisible(con)
}

#' @title Close connections referenced by a phip_data object
#'
#' @description Internal helper that disconnects all tracked connections and
#' optionally clears connection references stored in the object.
#'
#' @param x A valid `phip_data` object.
#' @param clear Logical; if `TRUE`, clear connection references after closing.
#'
#' @return A `phip_data` object with closed (and possibly cleared) connections.
#' @keywords internal
.ph_close_phip_data <- function(x, clear = TRUE) {
  conns <- .ph_collect_connections(x)
  for (con in conns) {
    if (!is.null(con) && DBI::dbIsValid(con)) {
      try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
    }
  }

  if (isTRUE(clear)) {
    x <- .ph_clear_connections(x)
  }

  x
}

#' @title Clear connection references in a phip_data object
#'
#' @description Internal helper that removes stored DBI connections from the
#' `meta` slot and from the peptide-library attributes.
#'
#' @param x A valid `phip_data` object.
#'
#' @return A `phip_data` object with connection references cleared.
#' @keywords internal
.ph_clear_connections <- function(x) {
  if (!is.null(x$meta$con)) x$meta$con <- NULL
  if (!is.null(x$meta$peptide_con)) x$meta$peptide_con <- NULL
  if (!is.null(x$meta$finalizer_env)) x$meta$finalizer_env <- NULL

  lib <- x$peptide_library
  if (!is.null(lib) && !is.null(attr(lib, "duckdb_con"))) {
    attr(lib, "duckdb_con") <- NULL
  }

  x
}

#' @title Collect all connection handles from a phip_data object
#'
#' @description Internal helper that gathers all known DBI connections from
#' `meta` and from the peptide-library attributes, de-duplicated by identity.
#'
#' @param x A valid `phip_data` object.
#'
#' @return A list of unique DBI connections.
#' @keywords internal
.ph_collect_connections <- function(x) {
  con_list <- list(
    x$meta$con %||% NULL,
    x$meta$peptide_con %||% NULL
  )

  lib <- x$peptide_library
  lib_con <- attr(lib, "duckdb_con")
  if (!is.null(lib_con)) {
    con_list <- c(con_list, list(lib_con))
  }

  unique_con <- list()
  for (con in con_list) {
    if (is.null(con)) next
    if (length(unique_con) == 0) {
      unique_con <- list(con)
    } else if (!any(vapply(unique_con, identical, logical(1), con))) {
      unique_con <- c(unique_con, list(con))
    }
  }

  unique_con
}

#' @title Attach an auto-finalizer for phip_data connections
#'
#' @description Creates a small environment that stores the current connection
#' handles and registers a finalizer to close them when the object is GC'd.
#'
#' @param x A valid `phip_data` object.
#'
#' @return A `phip_data` object with an attached finalizer environment.
#' @keywords internal
.ph_attach_finalizer <- function(x) {
  fin <- new.env(parent = emptyenv())
  fin$connections <- .ph_collect_connections(x)
  reg.finalizer(fin, function(e) {
    for (con in e$connections) {
      if (!is.null(con) && DBI::dbIsValid(con)) {
        try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
      }
    }
  }, onexit = TRUE)

  x$meta$finalizer_env <- fin
  x
}

#' @title Refresh finalizer connection list
#'
#' @description Updates the finalizer environment with the current connections.
#'
#' @param x A valid `phip_data` object.
#'
#' @return A `phip_data` object with refreshed finalizer connections.
#' @keywords internal
.ph_refresh_finalizer <- function(x) {
  fin <- x$meta$finalizer_env
  if (is.environment(fin)) {
    fin$connections <- .ph_collect_connections(x)
  }
  x
}

#' @title Sync peptide connection handle
#'
#' @description Ensures `meta$peptide_con` mirrors the peptide library attribute.
#'
#' @param x A valid `phip_data` object.
#'
#' @return A `phip_data` object with `meta$peptide_con` updated.
#' @keywords internal
.ph_sync_peptide_con <- function(x) {
  lib <- x$peptide_library
  lib_con <- attr(lib, "duckdb_con")
  if (!is.null(lib_con)) {
    x$meta$peptide_con <- lib_con
  }
  x
}
