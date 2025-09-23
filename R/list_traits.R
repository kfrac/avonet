list_traits <- function(table_name) {
  con <- connect_db(username = "postgres", pw = "Frankfurterstr25!")  # Use your secure connection function
  on.exit(DBI::dbDisconnect(con))
  query <- sprintf(
    "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '%s';",
    table_name
  )
  traits <- DBI::dbGetQuery(con, query)
  return(traits)
}
