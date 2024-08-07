# Include standalone defer to overwrite it:
#' @include standalone-defer.R
NULL

#' Defer Evaluation of an Expression
#'
#' Similar to [on.exit()], but allows one to attach
#' an expression to be evaluated when exiting any frame currently
#' on the stack. This provides a nice mechanism for scoping side
#' effects for the duration of a function's execution.
#'
#' @param expr `[expression]`\cr An expression to be evaluated.
#' @param envir `[environment]`\cr Attach exit handlers to this environment.
#'   Typically, this should be either the current environment or
#'   a parent frame (accessed through [parent.frame()]).
#' @param priority `[character(1)]`\cr Specify whether this handler should
#' be executed `"first"` or `"last"`, relative to any other
#' registered handlers on this environment.
#'
#' @section Running handlers within `source()`:
#' withr handlers run within `source()` are run when `source()` exits
#' rather than line by line.
#'
#' This is only the case when the script is sourced in `globalenv()`.
#' For a local environment, the caller needs to set
#' `options(withr.hook_source = TRUE)`. This is to avoid paying the
#' penalty of detecting `source()` in the normal usage of `defer()`.
#'
#' @details
#' `defer()` works by attaching handlers to the requested environment (as an
#' attribute called `"handlers"`), and registering an exit handler that
#' executes the registered handler when the function associated with the
#' requested environment finishes execution.
#'
#' Deferred events can be set on the global environment, primarily to facilitate
#' the interactive development of code that is intended to be executed inside a
#' function or test. A message alerts the user to the fact that an explicit
#' `deferred_run()` is the only way to trigger these deferred events. Use
#' `deferred_clear()` to clear them without evaluation. The global environment
#' scenario is the main motivation for these functions.
#'
#' @family local-related functions
#' @export
#' @examples
#' # define a 'local' function that creates a file, and
#' # removes it when the parent function has finished executing
#' local_file <- function(path) {
#'   file.create(path)
#'   defer_parent(unlink(path))
#' }
#'
#' # create tempfile path
#' path <- tempfile()
#'
#' # use 'local_file' in a function
#' local({
#'   local_file(path)
#'   stopifnot(file.exists(path))
#' })
#'
#' # file is deleted as we leave 'local' local
#' stopifnot(!file.exists(path))
#'
#' # investigate how 'defer' modifies the
#' # executing function's environment
#' local({
#'   local_file(path)
#'   print(attributes(environment()))
#' })
#'
#' # Note that examples lack function scoping so deferred calls are
#' # generally executed immediately
#' defer(print("one"))
#' defer(print("two"))
defer <- function(expr, envir = parent.frame(), priority = c("first", "last")) {
  if (identical(envir, globalenv())) {
    source_frame <- source_exit_frame_option(envir)
    if (!is.null(source_frame)) {
      # Automatically enable `source()` special-casing for the global
      # environment. This is the default for `source()` and the normal
      # case when users run scripts. This also happens in R CMD check
      # when withr is used inside an example because an R example is
      # run inside `withAutoprint()` which uses `source()`.
      local_options(withr.hook_source = TRUE)
      # And fallthrough to the default `defer()` handling. Within
      # `source()` we don't require manual calling of
      # `deferred_run()`.
    } else if (is_top_level_global_env(envir)) {
      global_defer(expr, priority = priority)
      return(invisible(NULL))
    }
  }

  priority <- match.arg(priority, choices = c("first", "last"))

  if (knitr_in_progress() && identical(envir, knitr::knit_global())) {
    return(defer_knitr(expr, envir, priority = priority))
  }

  # Don't handle `source()` by default to avoid a performance hit
  if (!is.null(getOption("withr.hook_source"))) {
    envir <- source_exit_frame(envir)
  }

  thunk <- as.call(list(function() expr))
  after <- priority == "last"

  do.call(
    base::on.exit,
    list(thunk, TRUE, after),
    envir = envir
  )
}

# Inline formals for performance
formals(defer)[["priority"]] <- eval(formals(defer)[["priority"]])


#' @rdname defer
#' @export
defer_parent <- function(expr, priority = c("first", "last")) {
  defer(expr, parent.frame(2), priority = priority)
}

#' @rdname defer
#' @export
deferred_run <- function(envir = parent.frame()) {
  if (knitr_in_progress() && identical(envir, knitr::knit_global())) {
    # The handlers are thunks so we don't need to clear them.
    # They will only be run once.
    frame <- knitr_exit_frame(envir)
    handlers <- knitr_handlers(frame)
  } else {
    if (is_top_level_global_env(envir)) {
      handlers <- the$global_exits
    } else {
      handlers <- frame_exits(envir)
    }
    deferred_clear(envir)
  }

  n <- length(handlers)
  i <- 0L

  if (!n) {
    message("No deferred expressions to run")
    return(invisible(NULL))
  }

  defer(message(
    sprintf("Ran %s/%s deferred expressions", i, n)
  ))

  for (expr in handlers) {
    eval(expr, envir)
    i <- i + 1L
  }
}

frame_exits <- function(frame = parent.frame()) {
  exits <- do.call(sys.on.exit, list(), envir = frame)

  # The exit expressions are stored in a single object that is
  # evaluated on exit. This can be NULL, an expression, or multiple
  # expressions wrapped in {. We convert this data structure to a list
  # of expressions.
  if (is.null(exits)) {
    list()
  } else if (identical(exits[[1]], quote(`{`))) {
    as.list(exits[-1])
  } else {
    list(exits)
  }
}
frame_clear_exits <- function(frame = parent.frame()) {
  do.call(on.exit, list(), envir = frame)
}

#' @rdname defer
#' @export
deferred_clear <- function(envir = parent.frame()) {
  if (is_top_level_global_env(envir)) {
    the$global_exits <- list()
  } else {
    frame_clear_exits(envir)
  }
  invisible()
}

#' Defer expression globally
#'
#' This function is mostly internal. It is exported to be called in
#' standalone `defer()` implementations to defer expressions from the
#' global environment.
#'
#' @inheritParams defer
#' @keywords internal
#' @export
global_defer <- function(expr, priority = c("first", "last")) {
  priority <- match.arg(priority, choices = c("first", "last"))

  env <- globalenv()
  handlers <- the$global_exits

  if (!length(handlers)) {
    # For session scopes we use reg.finalizer()
    if (is_interactive()) {
      message(
        sprintf("Setting global deferred event(s).\n"),
        "i These will be run:\n",
        "  * Automatically, when the R session ends.\n",
        "  * On demand, if you call `withr::deferred_run()`.\n",
        "i Use `withr::deferred_clear()` to clear them without executing."
      )
    }
    reg.finalizer(env, function(env) deferred_run(env), onexit = TRUE)
  }

  handler <- as.call(list(function() expr))

  if (priority == "first") {
    the$global_exits <- c(list(handler), handlers)
  } else {
    the$global_exits <- c(handlers, list(handler))
  }

  invisible(NULL)
}

the$global_exits <- list()

# Evaluate `frames` lazily to avoid expensive `sys.frames()`
# call for the default case of a local environment
is_top_level_global_env <- function(envir, frames = sys.frames()) {
  if (!identical(envir, globalenv())) {
    return(FALSE)
  }

  # Check if another global environment is on the stack
  !any(vapply(frames, identical, NA, globalenv()))
}


# This picks up knitr's first frame on the stack and registers the
# handler there. To avoid mixing up knitr's own exit handlers with
# ours, we don't hook directly but instead save the list of handlers
# as an attribute on the frame environment. This allows `deferred_run()`
# to run our handlers without running the knitr ones.
defer_knitr <- function(expr, envir, priority = c("first", "last")) {
  priority <- match.arg(priority, choices = c("first", "last"))

  envir <- knitr_exit_frame(envir)
  handler <- as.call(list(function() expr))

  handlers <- knitr_handlers(envir)

  # Add `on.exit` hook if run for first time
  if (!length(handlers)) {
    defer_knitr_run(envir)
  }

  if (priority == "first") {
    handlers <- c(list(handler), handlers)
  } else {
    handlers <- c(handlers, list(handler))
  }
  attr(envir, "withr_knitr_handlers") <- handlers

  invisible(NULL)
}

knitr_handlers <- function(envir) {
  attr(envir, "withr_knitr_handlers") %||% list()
}

# Evaluate `handlers` lazily so we get the latest version
defer_knitr_run <- function(
  envir,
  handlers = knitr_handlers(envir)
) {
  defer(envir = envir, {
    for (expr in handlers) {
      eval(expr, envir)
    }
  })
}
