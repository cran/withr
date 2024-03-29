#' @include with_.R

# lib ------------------------------------------------------------------------

set_libpaths <- function(paths, action = "replace") {
  paths <- as_character(paths)
  paths <- normalizePath(paths, mustWork = TRUE)

  old <- .libPaths()
  paths <- merge_new(old, paths, action)

  .libPaths(paths)
  invisible(old)
}

get_libpaths <- function(...) {
  .libPaths()
}

set_temp_libpath <- function(action = "prefix") {
  paths <- tempfile("temp_libpath")
  dir.create(paths)
  set_libpaths(paths, action = action)
}

#' Library paths
#'
#' Temporarily change library paths.
#'
#' @template with
#' @param new `[character]`\cr New library paths
#' @param action `[character(1)]`\cr should new values `"replace"`, `"prefix"` or
#'   `"suffix"` existing paths.
#' @inheritParams with_collate
#' @seealso [.libPaths()]
#' @family libpaths
#' @examples
#' .libPaths()
#' new_lib <- tempfile()
#' dir.create(new_lib)
#' with_libpaths(new_lib, print(.libPaths()))
#' unlink(new_lib, recursive = TRUE)
#' @export
with_libpaths <- with_(set_libpaths, .libPaths, get = get_libpaths)

#' @rdname with_libpaths
#' @export
local_libpaths <- local_(set_libpaths, .libPaths, get = get_libpaths)

#' Library paths
#'
#' Temporarily prepend a new temporary directory to the library paths.
#'
#' @template with
#' @seealso [.libPaths()]
#' @inheritParams with_libpaths
#' @family libpaths
#' @export
with_temp_libpaths <- with_(
  set_temp_libpath,
  .libPaths,
  get = get_libpaths,
  new = FALSE
)

#' @rdname with_temp_libpaths
#' @export
local_temp_libpaths <- local_(
  set_temp_libpath,
  .libPaths,
  get = get_libpaths,
  new = FALSE
)
