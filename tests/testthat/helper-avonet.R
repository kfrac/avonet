# Forces the bundled example data for the duration of a test, whether or not
# the developer running the suite happens to have a connection open.
#
# using_example_data() is "is there a usable connection?", so mocking
# has_connection() is the whole switch. Without this, devtools::test() in a
# connected session would query the database, and the row counts asserted
# below -- which are properties of the bundled snapshot -- would not hold.
local_example_data <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(has_connection = function() FALSE, .env = env)
}


# Quietly, since the package reports what it is doing at some length and the
# messages are not what these tests are about.
silently <- function(expr) {
  suppressMessages(suppressWarnings(expr))
}
