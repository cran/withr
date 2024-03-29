test_that("with_tempfile works", {

  f1 <- character()
  f2 <- character()

  with_tempfile("file1", {
    writeLines("foo", file1)
    expect_equal(readLines(file1), "foo")
    with_tempfile("file2", {
      writeLines("bar", file2)
      expect_equal(readLines(file1), "foo")
      expect_equal(readLines(file2), "bar")

      f2 <<- file2
    })
    expect_false(file.exists(f2))
    f1 <<- file1
  })
  expect_false(file.exists(f1))
})

test_that("local_tempfile with `new` works with a warning", {

  f1 <- character()
  f2 <- character()

  f <- function() {
    expect_warning(
      local_tempfile("file1"),
      "is deprecated"
    )
    writeLines("foo", file1)
    expect_equal(readLines(file1), "foo")
    expect_warning(
      local_tempfile("file2"),
      "is deprecated"
    )
    writeLines("bar", file2)
    expect_equal(readLines(file1), "foo")
    expect_equal(readLines(file2), "bar")
    f1 <<- file1
    f2 <<- file2
  }
  f()

  expect_false(file.exists(f1))
  expect_false(file.exists(f2))
})

test_that("local_tempfile works", {
  f1 <- character()
  f2 <- character()

  f <- function() {
    file1 <- local_tempfile()

    writeLines("foo", file1)
    expect_equal(readLines(file1), "foo")

    file2 <- local_tempfile()
    writeLines("bar", file2)
    expect_equal(readLines(file1), "foo")
    expect_equal(readLines(file2), "bar")
    f1 <<- file1
    f2 <<- file2
  }
  f()

  expect_false(file.exists(f1))
  expect_false(file.exists(f2))
})

test_that("local_tempfile() can add data", {
  path <- local_tempfile(lines = c("a", "b"))
  expect_equal(readLines(path), c("a", "b"))
})

test_that("local_tempfile() always writes \n", {
  path <- local_tempfile(lines = "x")
  expect_equal(file.size(path), 2)
  expect_equal(readChar(path, file.size(path)), "x\n")
})

test_that("local_tempfile() uses UTF-8", {
  utf8 <- "\u00e1" # á
  latin1 <- iconv(utf8, "UTF-8", "latin1")

  path <- local_tempfile(lines = latin1)

  local_options(encoding = "native.enc")
  expect_equal(readLines(path, encoding = "UTF-8"), utf8)
})
