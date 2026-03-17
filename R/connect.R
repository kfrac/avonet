#' Connect to AVONET database
#'
#' @param username Username for AVONET database
#' @param pw Password for AVONET database
#'
#' @return A database connection
#' @export
#'
#' @examples
#'
#' # This example makes use of the `keyring` package to store users' credentials
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#'
#' con <- connect_db(username = db_user, pw = db_password)
connect_db <- function(username, pw){
  con <- DBI::dbConnect(RPostgres::Postgres(),
                        dbname = "avonet",
                        host = "localhost",
                        port = 5432,
                        user = username,
                        password = pw)
  return(con)
}
