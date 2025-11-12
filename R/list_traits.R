list_traits <- function(table_name) {

  #table_name <- "eco_trait_species"
  #table_name <- "geo_data_species"
  #table_name <- "morph_trait_specimen"

  query <- DBI::dbSendQuery(con, sprintf("SELECT * FROM %s", table_name))
  df <- DBI::dbFetch(query)
  DBI::dbClearResult(query)

  df <- remove_suffix_columns(df, c("_id", "_src", "_source"))

  prefixes <- c("ect_", "spd_", "geo_")
  df <- remove_prefixes(df, prefixes)

  traits_list <- lapply(df, function(x) {
    if (is.numeric(x)) {
      "numeric"
    } else {
      paste0(sort(unique(x), na.last = TRUE), collapse = ", ")
    }
  })

  if(table_name == "morph_trait_specimen"){
    mass_query <- DBI::dbSendQuery(con, "SELECT * FROM mass_species")
    mass_df <- DBI::dbFetch(mass_query)
    DBI::dbClearResult(mass_query)

    mass_df <- remove_suffix_columns(mass_df, c("_id", "_src", "_source"))

    mass_list <- lapply(mass_df, function(x) {
      if (is.numeric(x)) {
        "numeric"
      } else {
        paste0(sort(unique(x), na.last = TRUE), collapse = ", ")
      }
    })

    traits_list <- append(traits_list, mass_list)

  }

  output <- data.frame(
    trait = rep(names(traits_list), times = lengths(traits_list)),
    value = unlist(traits_list, use.names = FALSE)
  )

  output$resolution <- ifelse(
    table_name == "morph_trait_specimen" & !startsWith(output$trait, "mass_"), "specimen", "species")

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
