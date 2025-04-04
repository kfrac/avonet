#' Connect to AVONET database
#'
#' @param username Username for AVONET database
#' @param pw Password for AVONET database
#'
#' @return A database connection
#' @export
#'
#' @examples
#' con <- connect(username = "postgres", pw = "Frankfurterstr25!")
connect <- function(username, pw){
  con <- DBI::dbConnect(RPostgres::Postgres(),
                        dbname = "avotest",
                        host = "localhost",
                        port = 5432,
                        user = username,
                        password = pw)
  return(con)
}
