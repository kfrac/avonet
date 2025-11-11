list_traits <- function(table_name) {

  query <- DBI::dbSendQuery(con, sprintf("SELECT * FROM %s", table_name))
  df <- DBI::dbFetch(query)
  DBI::dbClearResult(query)

  df <- remove_suffix_columns(df, c("_id"))

  prefixes <- c("ect_", "sd_", "geo_")
  df <- remove_prefixes(df, prefixes)

  traits_list <- lapply(df, function(x) paste0(sort(unique(x), na.last = TRUE), collapse = ", "))

  output <- data.frame(
    trait = rep(names(traits_list), times = lengths(traits_list)),
    value = unlist(traits_list, use.names = FALSE)
  )

  output <- as_tibble(output)

  return(output)

  # con <- connect_db(username = "postgres", pw = "Frankfurterstr25!")  # Use your secure connection function
  # on.exit(DBI::dbDisconnect(con))
  # sql <- sprintf(
  #   "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = $1"
  # )
  #
  # query <- DBI::dbSendQuery(con, sql)
  # DBI::dbBind(query, list(table_name))
  # result <- DBI::dbFetch(query)
  #
  # DBI::dbClearResult(query)
  #
  # return(result)
}
