% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/defer.R
\name{defer}
\alias{defer}
\alias{defer_parent}
\alias{deferred_run}
\alias{deferred_clear}
\title{Defer Evaluation of an Expression}
\usage{
defer(expr, envir = parent.frame(), priority = c("first", "last"))

defer_parent(expr, priority = c("first", "last"))

deferred_run(envir = parent.frame())

deferred_clear(envir = parent.frame())
}
\arguments{
\item{expr}{\verb{[expression]}\cr An expression to be evaluated.}

\item{envir}{\verb{[environment]}\cr Attach exit handlers to this environment.
Typically, this should be either the current environment or
a parent frame (accessed through \code{\link[=parent.frame]{parent.frame()}}).}

\item{priority}{\verb{[character(1)]}\cr Specify whether this handler should
be executed \code{"first"} or \code{"last"}, relative to any other
registered handlers on this environment.}
}
\description{
Similar to \code{\link[=on.exit]{on.exit()}}, but allows one to attach
an expression to be evaluated when exiting any frame currently
on the stack. This provides a nice mechanism for scoping side
effects for the duration of a function's execution.
}
\details{
\code{defer()} works by attaching handlers to the requested environment (as an
attribute called \code{"handlers"}), and registering an exit handler that
executes the registered handler when the function associated with the
requested environment finishes execution.

Deferred events can be set on the global environment, primarily to facilitate
the interactive development of code that is intended to be executed inside a
function or test. A message alerts the user to the fact that an explicit
\code{deferred_run()} is the only way to trigger these deferred events. Use
\code{deferred_clear()} to clear them without evaluation. The global environment
scenario is the main motivation for these functions.
}
\section{Running handlers within \code{source()}}{

withr handlers run within \code{source()} are run when \code{source()} exits
rather than line by line.

This is only the case when the script is sourced in \code{globalenv()}.
For a local environment, the caller needs to set
\code{options(withr.hook_source = TRUE)}. This is to avoid paying the
penalty of detecting \code{source()} in the normal usage of \code{defer()}.
}

\examples{
# define a 'local' function that creates a file, and
# removes it when the parent function has finished executing
local_file <- function(path) {
  file.create(path)
  defer_parent(unlink(path))
}

# create tempfile path
path <- tempfile()

# use 'local_file' in a function
local({
  local_file(path)
  stopifnot(file.exists(path))
})

# file is deleted as we leave 'local' local
stopifnot(!file.exists(path))

# investigate how 'defer' modifies the
# executing function's environment
local({
  local_file(path)
  print(attributes(environment()))
})

# Note that examples lack function scoping so deferred calls are
# generally executed immediately
defer(print("one"))
defer(print("two"))
}
\concept{local-related functions}
