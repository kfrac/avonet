get_traits <- function(con, species, taxonomy, source_cols = FALSE) {

  #source_cols = FALSE

  #species <- "Buteo buteo"

  prefixes <- c("ect_", "spd_", "geo_", "species_")
  suffixes <- c("id", "_src", "_source")

  results <- list()

  species_data <- sql_query(con = con, parameter1 = species, parameter2 = taxonomy)

  src_suffixes <- c("_source", "src")
  src_pattern <- paste0("(", paste(src_suffixes, collapse="|"), ")$")
  src_cols <- species_data[, grep(src_pattern, names(species_data))]

  metadata <- get_metadata(src_cols = src_cols)

  sources <- get_sources(src_cols = src_cols)

  species_data <- remove_prefixes(species_data, prefixes = prefixes)

  if(source_cols == FALSE){
    species_data <- remove_suffix_columns(species_data, suffixes = suffixes)
  }

  results <- list("metadata" = metadata, "data" = species_data, "sources" = sources)

  message(sprintf("Output contains data from %d sources. Please refer to the metadata for details.", nrow(sources)))

  return(results)



  # vector <- c("eco_trait_species", "geo_data_species", "reproductive_trait_species", "social_trait_species")
  # names(vector) <- c("eco", "geo", "reproductive", "social")
  #
  # con <- connect_db(username = "postgres", pw = "Frankfurterstr25!")  # Use your secure connection function
  # on.exit(DBI::dbDisconnect(con))
  #
  # if(group == "eco"){
  #   query <- paste("SELECT * FROM eco_trait_species ORDER BY ect_id ASC;")
  #   traits <- DBI::dbGetQuery(con, query)
  # } else if(group == "geo"){
  #   query <- paste("SELECT * FROM geo_data_species ORDER BY spd_id ASC;")
  #   traits <- DBI::dbGetQuery(con, query)
  # } else {
  #   traits <- NULL
  # }
  # return(traits)

}
