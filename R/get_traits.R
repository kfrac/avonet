get_traits <- function(group) {

  vector <- c("eco_trait_species", "geo_data_species", "reproductive_trait_species", "social_trait_species")
  names(vector) <- c("eco", "geo", "reproductive", "social")

  con <- connect_db(username = "postgres", pw = "Frankfurterstr25!")  # Use your secure connection function
  on.exit(DBI::dbDisconnect(con))

  if(group == "eco"){
    query <- paste("SELECT * FROM eco_trait_species ORDER BY ect_id ASC;")
    traits <- DBI::dbGetQuery(con, query)
  } else if(group == "geo"){
    query <- paste("SELECT * FROM geo_data_species ORDER BY spd_id ASC;")
    traits <- DBI::dbGetQuery(con, query)
  } else {
    traits <- NULL
  }
  return(traits)

}
