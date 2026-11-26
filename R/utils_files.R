# Small filesystem helpers shared by analysis scripts and package functions.

#' Current timestamp in a filename-safe format
#'
#' @return Character scalar like `"20261125_123456"`.
#' @export
timestamp_string <- function() {
  base::format(base::Sys.time(), "%Y%m%d_%H%M%S")
}

#' Build a timestamped file path without writing the file
#'
#' @param directory Character scalar directory.
#' @param prefix Character scalar filename prefix.
#' @param extension Character scalar extension including the leading dot,
#'   e.g. `".csv"`.
#' @param timestamp Character scalar timestamp; defaults to the value from
#'   [timestamp_string()].
#' @return Character scalar path `directory/prefix_timestamp.extension`.
#' @export
timestamped_path <- function(directory, prefix, extension, timestamp = timestamp_string()) {
  if (!base::is.character(directory) || length(directory) != 1 || base::is.na(directory) || directory == "") {
    base::stop("directory must be one non-empty character string.")
  }
  if (!base::is.character(prefix) || length(prefix) != 1 || base::is.na(prefix)) {
    base::stop("prefix must be one non-missing character string.")
  }
  if (!base::is.character(extension) || length(extension) != 1 ||
      base::is.na(extension) || !base::startsWith(extension, ".")) {
    base::stop("extension must be one character string starting with '.'.")
  }
  base::file.path(directory, base::paste0(prefix, "_", timestamp, extension))
}
