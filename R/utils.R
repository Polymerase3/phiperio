# ==============================================================================
# phiperio logging utilities (ASCII only; based on the chk and cli packages)
# ==============================================================================
# ---- user-tweakable globals (set via options() in .onLoad or zzz.R) ----------
# options(
#   phiperio.log.verbose   = TRUE,
#   phiperio.log.time_fmt  = "%Y-%m-%d %H:%M:%S",
#   phiperio.log.width     = getOption("width", 80)
# )

.ph_opt <- function(key,
                    default = NULL) {
  getOption(paste0("phiperio.log.", key), default)
}

.ph_now <- function() {
  format(Sys.time(), .ph_opt("time_fmt", "%H:%M:%S"))
}

.ph_base_prefix <- function(level = "INFO") {
  sprintf("[%s] %-5s ", .ph_now(), toupper(level)[1])
}

# wraps the text nicely, regardless of the console width
.ph_wrap <- function(text,
                     prefix) {
  w <- .ph_opt("width", getOption("width", 80))
  # strwrap: 'initial' for first line, 'prefix' for continuations
  strwrap(text, width = w, initial = prefix, prefix = strrep(
    " ",
    nchar(prefix)
  ))
}

# Compose multi-depth message lines
# currently the maximal supported log depth is 3:
# headline (required), step (optional), bullets (optional chr vec)
.ph_compose_lines <- function(level,
                              headline,
                              step = NULL,
                              bullets = NULL) {
  base <- .ph_base_prefix(level)
  stepP <- paste0(strrep(" ", nchar(base)), "-> ")
  bullP <- paste0(strrep(" ", nchar(base)), "  - ")

  out <- character(0)
  if (!is.null(headline) && nzchar(headline)) {
    out <- c(out, .ph_wrap(headline, base))
  }
  if (!is.null(step) && nzchar(step)) {
    out <- c(out, .ph_wrap(step, stepP))
  }
  if (length(bullets)) {
    for (b in bullets) {
      if (isTRUE(is.na(b)) || !nzchar(b)) next
      out <- c(out, .ph_wrap(b, bullP))
    }
  }
  out
}

# ---- Public logging helpers --------------------------------------------------
## monitor task progress
.ph_log_info <- function(headline,
                         step = NULL,
                         bullets = NULL,
                         verbose = .ph_opt("verbose", TRUE)) {
  if (!isTRUE(verbose)) {
    return(invisible(character()))
  }
  lines <- .ph_compose_lines("INFO", headline, step, bullets)
  cat(paste0(lines, collapse = "\n"), "\n", sep = "")
  invisible(lines)
}

## monitor task progression
.ph_log_ok <- function(headline,
                       step = NULL,
                       bullets = NULL,
                       verbose = .ph_opt("verbose", TRUE)) {
  if (!isTRUE(verbose)) {
    return(invisible(character()))
  }
  lines <- .ph_compose_lines("OK", headline, step, bullets)
  cat(paste0(lines, collapse = "\n"), "\n", sep = "")
  invisible(lines)
}

# Warnings/errors via chk, but formatted to match the style of the logger
.ph_warn <- function(headline, step = NULL, bullets = NULL, ...) {
  lines <- .ph_compose_lines("WARN", headline, step, bullets)
  msg <- paste(lines, collapse = "\n")
  if (requireNamespace("chk", quietly = TRUE)) {
    chk::wrn(msg, ...) # single string -> respects \n
  } else {
    warning(msg, call. = FALSE, ...) # fallback if chk not installed
  }
  invisible(lines)
}

.ph_abort <- function(headline, step = NULL, bullets = NULL, ...) {
  lines <- .ph_compose_lines("ERROR", headline, step, bullets)
  msg <- paste(lines, collapse = "\n")
  if (requireNamespace("chk", quietly = TRUE)) {
    chk::abort_chk(msg, ...) # single string -> respects \n
  } else {
    stop(msg, call. = FALSE, ...) # fallback if chk not installed
  }
}

# original conditional helper to not break down older code
# upgraded to the unified phiperio style
.chk_cond <- function(condition,
                      error_message,
                      error = TRUE,
                      step = NULL,
                      bullets = NULL,
                      ...) {
  # log nopthing
  if (!isTRUE(condition)) {
    return(invisible(FALSE))
  }

  # print error and abort exec
  if (isTRUE(error)) {
    .ph_abort(headline = error_message, step = step, bullets = bullets, ...)
  } else {
    # print warning and go on
    .ph_warn(headline = error_message, step = step, bullets = bullets, ...)
  }
  invisible(TRUE)
}

# ---- timing helper for sections ----------------------------------------------
## many tasks in phiperio can be long/take a while; it was important to have the
## infos on timing - this func wraps a task to get a start/end pair in the same
## style
.ph_with_timing <- function(headline,
                            step = NULL,
                            bullets = NULL,
                            expr,
                            verbose = .ph_opt("verbose", TRUE)) {
  t0 <- Sys.time()
  .ph_log_info(headline = headline, step = step, bullets = bullets, verbose = verbose)

  res <- tryCatch(
    {
      force(expr)
    }, # evaluate user's code
    finally = {
      dt <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 3)
      .ph_log_ok(
        headline = paste0(headline, " - done"),
        step     = sprintf("elapsed: %ss", dt),
        verbose  = verbose
      )
    }
  )

  res
}

# ==============================================================================
# phiperio checks + additional helpers (ASCII-only, unified with phiperio logger)
# it depends on: .ph_abort(), .ph_warn(), .chk_cond(), word_list(), add_quotes()
# ==============================================================================

# -- check if filename has given extension ------------------------------------
# comes in handy when loading .csv or .parquet; provide filename and vector of
# extensions to check (eg c(".csv", ".parquet"))
.chk_extension <- function(name,
                           x_name,
                           ext_vec) {
  if (is.null(ext_vec) || !length(ext_vec)) {
    return(invisible(TRUE))
  }

  base <- basename(name %||% "") # extracting filename from paths
  parts <- strsplit(base, "\\.", fixed = FALSE)[[1]] # names + complex ext

  # taking last ext after . (eg .tar.gz --> .gz)
  ext <- if (length(parts) > 1L) {
    tolower(paste(parts[-1L], collapse = "."))
  } else {
    ""
  }

  norm <- function(x) sub("^\\.+", "", tolower(x)) # normalize ext
  got <- if (nzchar(ext)) norm(ext) else "<none>"
  ok <- nzchar(ext) && got %in% norm(ext_vec) # final ext check

  if (!ok) {
    .ph_abort(
      headline = sprintf("Invalid file extension for `%s`.", x_name),
      step = sprintf("validating path: %s", name),
      bullets = c(
        sprintf("got: %s", add_quotes(got, 2L)),
        sprintf(
          "allowed: %s",
          word_list(add_quotes(norm(ext_vec), 2L), and_or = "or")
        )
      )
    )
  }
  invisible(TRUE)
}

# -- check if NULL and replace with default when TRUE (warn in unified style) --
.chk_null_default <- function(x,
                              x_name,
                              method,
                              default) {
  if (is.null(x)) {
    # format the default for print
    fmt <- function(v) {
      if (is.character(v) && length(v) == 1L) {
        return(add_quotes(v, 2L))
      }
      if (is.atomic(v) && length(v) == 1L) {
        return(as.character(v))
      }
      sprintf("<%s>", paste(class(v), collapse = "/"))
    }

    # generate warning and the replace
    .ph_warn(
      headline = sprintf("Argument `%s` missing; using default.", x_name),
      step     = sprintf("method: %s", add_quotes(method, 2L)),
      bullets  = sprintf("default: %s", fmt(default))
    )
    x <- default
  }
  x
}

# -- validate path to file -----------------------------------------------------
.chk_path <- function(path,
                      arg_name,
                      extension,
                      is_dir = FALSE) {
  ## error when path not a string
  .chk_cond(
    !chk::vld_string(path),
    sprintf("`%s` must be a character scalar.", arg_name),
    step    = "path validation",
    bullets = sprintf("got class: %s", paste(class(path), collapse = "/"))
  )

  ## error when path does not exist
  if (is_dir) {
    .chk_cond(
      !chk::vld_dir(path),
      sprintf("Folder for `%s` does not exist.", arg_name),
      step    = "path validation",
      bullets = sprintf("path: %s", path)
    )
  } else {
    .chk_cond(
      !chk::vld_file(path),
      sprintf("File for `%s` does not exist.", arg_name),
      step    = "path validation",
      bullets = sprintf("path: %s", path)
    )
  }

  # optionally extension check if provided
  if (!missing(extension) && length(extension)) {
      ## error when both is_dir and extension are given
      .chk_cond(
        is_dir,
        sprintf("Can't check if `%s` is both a valid direcotry and has a certain extension", arg_name),
        step    = "path validation",
        bullets = sprintf("path: %s", path)
      )

    .chk_extension(
      path,
      arg_name,
      extension
    )
  }

  invisible(TRUE)
}

# -- clean wordlists for message generation ------------------------------------
# for multiple arguments/values
word_list <- function(word_list = NULL,
                      and_or = "and",
                      is_are = FALSE,
                      quotes = FALSE) {
  # Make "a and b" / "a, b, and c"; optionally append "is/are".
  word_list <- setdiff(word_list, c(NA_character_, ""))

  if (is.null(word_list)) {
    out <- ""
    attr(out, "plural") <- FALSE
    return(out)
  }

  word_list <- add_quotes(word_list, quotes)

  len_wl <- length(word_list)

  if (len_wl == 1L) {
    out <- word_list
    if (is_are) out <- paste(out, "is")
    attr(out, "plural") <- FALSE
    return(out)
  }

  if (is.null(and_or) || isFALSE(and_or)) {
    out <- paste(word_list, collapse = ", ")
  } else {
    and_or <- match.arg(and_or, c("and", "or"))
    if (len_wl == 2L) {
      out <- sprintf("%s %s %s", word_list[1L], and_or, word_list[2L])
    } else {
      out <- sprintf(
        "%s, %s %s",
        paste(word_list[-len_wl], collapse = ", "),
        and_or, word_list[len_wl]
      )
    }
  }

  if (is_are) out <- sprintf("%s are", out)
  attr(out, "plural") <- TRUE
  out
}

# -- quoting helper (unified error style) --------------------------------------
# define number of quotes you want --> for printing logs/messages/warnings
# or define the quotes itself as a string
add_quotes <- function(x,
                       quotes = 2L) {
  if (isFALSE(quotes)) {
    return(x)
  }
  if (isTRUE(quotes)) quotes <- '"'

  if (chk::vld_string(quotes)) {
    return(paste0(quotes, x, quotes))
  }

  if (!chk::vld_count(quotes) || quotes > 2) {
    .ph_abort(
      headline = "Invalid `quotes` argument.",
      step = "formatting add_quotes()",
      bullets = c(
        "allowed: FALSE, TRUE, 0, 1, 2, or a single-character string",
        sprintf("got class: %s", paste(class(quotes), collapse = "/"))
      )
    )
  }

  if (quotes == 0L) {
    return(x)
  }
  if (quotes == 1L) {
    return(sprintf("'%s'", x))
  }
  sprintf('"%s"', x)
}

# -- not-in operator -----------------------------------------------------------
`%nin%` <- function(x, inx) {
  !(x %in% inx)
}

# -- NULL-coalescing helper ----------------------------------------------------
`%||%` <- function(x, y) if (!is.null(x)) x else y


#' @title Path to example PhIP-Seq datasets shipped with phiperio
#'
#' @param name Character scalar. Name of the example dataset.
#'   Currently supported: `"phip_mixture"`.
#'
#' @return A character scalar with an absolute path to the file.
#'
#' @examples
#' sim_path <- phip_example_path("phip_mixture")
#' # phip_obj <- phip_convert(sim_path)
#'
#' @export
phip_example_path <- function(name = c("phip_mixture")) {
  name <- match.arg(name)
  fname <- switch(
    name,
    phip_mixture = "phip_mixture.parquet"
  )

  path <- system.file("extdata", fname, package = "phiperio")
  if (path == "") {
    stop("File ", fname, " not found in extdata/", call. = FALSE)
  }
  path
}

#' @title Load Example PhIP-Seq Dataset as <phip_data>
#'
#' @description
#' Convenience helper to quickly load a shipped example dataset ("phip_mixture") into a `<phip_data>` object,
#' suitable for downstream analysis and visualization. This function wraps \code{\link{phip_convert}},
#' automatically supplying the correct parameters for the included example data.
#'
#' @param name Character scalar. Name of the shipped example dataset.
#'  Currently supported: \code{"phip_mixture"}, \code{"small_mixture"}.
#'
#' @return A `<phip_data>` object created from the chosen example dataset.
#'
#' @examples
#' # Load the example data shipped with the package:
#' ex <- phip_load_example_data()
#' # ex is now a <phip_data> object ready for analysis
#'
#' # Specify the dataset name explicitly
#' ex2 <- phip_load_example_data("small_mixture")
#'
#' # Use with plotting functions
#' p = plot_enrichment_counts(ex, group_cols = "timepoint")
#'
#' @export
phip_load_example_data <- local({
  cache_env <- new.env(parent = emptyenv())
  cache_env$loaded <- list()

  function(name = c("phip_mixture", "small_mixture")) {
    name <- match.arg(name)

    # Check if already in cache
    if (name %in% names(cache_env$loaded)) return(cache_env$loaded[[name]])

    if (name == "small_mixture") {
      ps <- phip_load_example_data(name = "phip_mixture")

      # small subset for speed: 5 peptides at time t1
      keep_pep <- c("16627", "5243", "24799", "16196", "18003")
      dat_cols <- dplyr::tbl_vars(ps$data_long)
      tp_col <- "timepoint"
        
      ps <- ps |>
        dplyr::filter(
          peptide_id %in% keep_pep,
          !!rlang::sym(tp_col) == "T1"
        ) |>
        dplyr::collect()
      
    } else {
      ps <- phip_convert(
        data_long_path = phip_example_path(name),
        peptide_library = TRUE,
        subject_id = "subject_id",
        peptide_id = "peptide_id",
        sample_id  = "sample_id",
        exist      = "exist",
        timepoint  = "time",
        fold_change= "fold_change",
        materialise_table = TRUE,
        auto_expand = FALSE,
        n_cores = 5
      )
    }

    cache_env$loaded[[name]] <- ps
    ps
  }
})


#' @title Resolve legacy-import paths and perform fast-fail argument checks
#'
#' @description Combines explicit arguments with a YAML config (if given),
#'   expands every relative path to an absolute path (relative paths are
#'   evaluated against `dirname(config_yaml)` (!!!) when YAML is used, otherwise
#'   against the directory that contains the first supplied data matrix (!!!)),
#'   and returns a fully populated list of file locations and options ready for
#'   downstream conversion. Only cheap, load-blocking checks are done here:
#'
#' * `input_file` and `hit_file` must be supplied together or both omitted.
#'
#' * At least one matrix source (`exist_file`, `fold_change_file`, or the
#'   `input_file` + `hit_file` pair) must be present.
#'
#' * Deprecated `output_dir` triggers a soft warning.
#'
#'  All deeper table-content validation is deferred to `phip_data` class
#'  validation.
#'
#' @param exist_file,fold_change_file,input_file,hit_file,samples_file,timepoints_file
#'  Character paths (relative or absolute) to the respective CSV/Parquet inputs.
#'  `NULL` means "not supplied".
#' @param extra_cols Character vector of extra metadata columns to keep; may be
#'   `NULL`.
#' @param output_dir Ignored (soft-deprecated).
#' @param config_yaml Optional path to a YAML file whose keys mirror the
#'   function arguments; relative paths inside the YAML are resolved against the
#'   YAML’s own directory.
#'
#' @return A named list with absolute paths, `extra_cols`, and `base_dir`;
#'   suitable for downstream helper functions.
#'
#' @keywords internal
.ph_resolve_paths <- function(
    exist_file = NULL,
    fold_change_file = NULL,
    samples_file = NULL,
    input_file = NULL,
    hit_file = NULL,
    timepoints_file = NULL,
    extra_cols = NULL,
    output_dir = NULL, # deprecated
    data_long_path = NULL,
    peptide_library = TRUE,
    n_cores = NULL,
    materialise_table = NULL,
    auto_expand = NULL,
    config_yaml = NULL
) {
  ## ------------------------------------------------------------------------ ##
  ## 1.  locate base directory & read yaml (if any provided)                  ##
  ## ------------------------------------------------------------------------ ##
  is_abs_path <- function(p) {
    grepl("^(/|[A-Za-z]:[/\\\\])", p)
  }
  abs_path <- function(p, start = NULL) {
    if (is.null(p)) return(p)
    if (!is.null(start) && !is_abs_path(p)) p <- file.path(start, p)
    normalizePath(p, winslash = "/", mustWork = FALSE)
  }

  # Determine base_dir depending on which input source was provided
  base_dir <- if (!is.null(config_yaml)) {
    # 1) If a YAML config was given, take its folder
    dirname(abs_path(config_yaml))
  } else if (!is.null(data_long_path)) {
    # 2) If a data_long_path directory was given - use it
    dirname(abs_path(data_long_path))
  } else {
    # 3) Otherwise require at least a samples_file (or exist_file)
    .chk_cond(
      is.null(samples_file) && is.null(exist_file),
      "When neither 'config_yaml' nor 'data_long_path' is provided,
      you must supply 'samples_file' or 'exist_file'."
    )
    # pick samples_file if present, else exist_file, then take its parent folder
    dirname(abs_path(samples_file %||% exist_file))
  }

  yaml_cfg <- if (!is.null(config_yaml)) {
    ## validate the file extension
    .chk_path(config_yaml, "config_yaml", c("yml", "yaml"))

    ## read the yamlW
    rlang::check_installed("yaml")
    yaml::read_yaml(config_yaml)
  } else {
    ## safe fallback
    NULL
  }

  ## ------------------------------------------------------------------------ ##
  ## 2.  helper to merge yaml + explicit args, validate & absolutise          ##
  ## ------------------------------------------------------------------------ ##
  fetch <- function(arg,
                    key,
                    validate = NULL,
                    optional = FALSE,
                    absolutize = FALSE,
                    ...) {
    # safe fallback to NULL --> if both NULL, then %||% returns NULL
    val <- yaml_cfg[[key]] %||% arg # yaml first, then explicit

    # required argument have to be provided!
    .chk_cond(
      is.null(val) && !optional,
      sprintf("Missing required argument '%s' in YAML or call.", key)
    )

    # if the validator is .chk_path or absolute == TRUE, expand the path
    # to absolute
    if ((!is.null(val) && identical(validate, .chk_path)) ||
        (!is.null(val) && absolutize)) {
      if (!is_abs_path(val)) {
        val <- abs_path(basename(val), start = base_dir)
      } else {
        val <- abs_path(val)
      }
    }

    # perform the custom validation if specified
    if (!is.null(val) && is.function(validate)) {
      validate(val, key, ...)
    }

    # return
    val
  }

  ## ------------------------------------------------------------------------ ##
  ## 3.  resolve every supported argument                                     ##
  ## ------------------------------------------------------------------------ ##
  samples_required <- !is.null(data_long_path)

  cfg <- list(
    exist_file = fetch(exist_file,
                       "exist_file",
                       .chk_path,
                       optional = TRUE,
                       extension = c("csv", "parquet", "parq", "pq")
    ),
    fold_change_file = fetch(fold_change_file,
                             "fold_change_file",
                             .chk_path,
                             optional = TRUE,
                             extension = c("csv", "parquet", "parq", "pq")
    ),
    input_file = fetch(input_file,
                       "input_file",
                       .chk_path,
                       optional = TRUE,
                       extension = c("csv", "parquet", "parq", "pq")
    ),
    hit_file = fetch(hit_file,
                     "hit_file",
                     .chk_path,
                     optional = TRUE,
                     extension = c("csv", "parquet", "parq", "pq")
    ),
    samples_file = fetch(samples_file,
                         "samples_file",
                         .chk_path,
                         optional = samples_required,
                         extension = c("csv", "parquet", "parq", "pq")
    ),
    timepoints_file = fetch(timepoints_file,
                            "timepoints_file",
                            .chk_path,
                            optional = TRUE,
                            extension = c("csv", "parquet", "parq", "pq")
    ),
    extra_cols = fetch(extra_cols,
                       "extra_cols",
                       optional = TRUE
    ),
    output_dir = fetch(output_dir,
                       "output_dir",
                       optional = TRUE
    ),
    data_long_path = fetch(data_long_path,
                           "data_long_path",
                           optional = !samples_required,
                           absolutize = TRUE
    ),
    peptide_library = peptide_library,
    n_cores = n_cores,
    materialise_table = materialise_table,
    auto_expand = auto_expand,
    base_dir = base_dir # for downstream helpers
  )

  ## ------------------------------------------------------------------------ ##
  ## 4.  fast-fail rules that really must hold before heavy work              ##
  ## ------------------------------------------------------------------------ ##
  #  rule 1: input_file and hit_file must be provided together ----------
  .chk_cond(
    xor(is.null(cfg$input_file), is.null(cfg$hit_file)),
    "Arguments 'input_file' and 'hit_file' must be provided together."
  )

  # Rule 2a: if data_long_path is provided, it must be the ONLY file argument
  if (!is.null(cfg$data_long_path)) {
    others_supplied <- any(
      !is.null(cfg$exist_file),
      !is.null(cfg$fold_change_file),
      !is.null(cfg$input_file),
      !is.null(cfg$hit_file)
    )
    .chk_cond(
      others_supplied,
      "When 'data_long_path' is supplied, do not supply 'exist_file',
      'fold_change_file', 'input_file', or 'hit_file'."
    )
  } else {
    # Rule 2b: if data_long_path is NOT provided,
    #          require at least one of the other file arguments
    all_null <- with(
      cfg,
      is.null(exist_file) &&
        is.null(fold_change_file) &&
        is.null(input_file) &&
        is.null(hit_file)
    )
    .chk_cond(
      all_null,
      paste0(
        "Supply at least one of:\n",
        "  * 'exist_file'\n",
        "  * 'fold_change_file'\n",
        "  * both 'input_file' and 'hit_file'"
      )
    )
  }

  #  deprecation notice -------------------------------------------------
  .chk_cond(!is.null(cfg$output_dir),
            error = FALSE,
            "'output_dir' is deprecated and will be ignored."
  )

  # validate the tables itself --> the logic has been moved entirely to the
  # phip_data class validator

  cfg
}
