#' Connect to AVONET database
#'
#' @param username Username for AVONET database
#' @param pw Password for AVONET database
#'
#' @return A database connection
#' @export
#'
#' @seealso [disconnect_db()]
#'
#' @examples
#' # This example makes use of the `keyring` package to store users' credentials
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#'
#' # Connect to the AVONET database
#' connect_db(username = db_user, pw = db_password)
#'
#' # ...do some work...
#'
#' # Disconnect from the AVONET database
#' disconnect_db()
connect_db <- function(username, pw){
  con <- DBI::dbConnect(RPostgres::Postgres(),
                        dbname = "avonet",
                        host = "localhost",
                        port = 5432,
                        user = username,
                        password = pw)
  .pkg_env$con <- con
  reg.finalizer(.pkg_env, function(e) { # safety net when R session exits normally
    if (!is.null(e$con) && DBI::dbIsValid(e$con))
      DBI::dbDisconnect(e$con)
  }, onexit = TRUE)
  invisible(con)
}

#' Disconnect from AVONET database
#'
#' Closes the active database connection opened by [connect_db()], if there
#' is one.
#'
#' @return Invisibly, `NULL`.
#' @export
#'
#' @seealso [connect_db()]
#'
#' @examples
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#' connect_db(username = db_user, pw = db_password)
#'
#' # ...do some work...
#'
#' disconnect_db()
disconnect_db <- function() {
  con <- .pkg_env$con
  if (is.null(con)) { message("No active connection."); return(invisible(NULL)) }
  if (DBI::dbIsValid(con)) DBI::dbDisconnect(con)
  .pkg_env$con <- NULL
  invisible(NULL)
}

#' @keywords internal
get_con <- function() {
  con <- .pkg_env$con
  if (is.null(con))  stop("Call `avonet::connect_db(...)` first.", call. = FALSE)
  if (!DBI::dbIsValid(con)) stop("Connection is stale. Call `avonet::connect_db(...)` again.", call. = FALSE)
  con
}

.pkg_env <- new.env(parent = emptyenv())
