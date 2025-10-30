list_traits <- function(table_name) {
  con <- connect_db(username = "postgres", pw = "Frankfurterstr25!")  # Use your secure connection function
  on.exit(DBI::dbDisconnect(con))
  sql <- sprintf(
    "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = $1"
  )

  query <- DBI::dbSendQuery(con, sql)
  DBI::dbBind(query, list(table_name))
  result <- DBI::dbFetch(query)

  DBI::dbClearResult(query)

  return(result)
}
