#' Retrieve taxonomic information
#'
#' @param con Connection to the AVONET database
#' @param search_term Name of a genus, family or order
#' @param taxonomy Choose which taxonomy your results are displayed in. 1 = BirdLife, 2 = eBird and 3 = BirdTree
#'
#' @return A dataframe
#' @export
#'
#' @examples
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#' con <- connect_db(username = db_user, pw = db_password)
#'
#' # This works for a single species
#' get_taxonomic_info(con, search_term = "Buteo buteo", taxonomy = 1)
#'
#' # Or a list of several species
#' get_taxonomic_info(con, search_term = "passeriformes", taxonomy = 1)
get_taxonomic_info <- function(con, search_term, taxonomy) {

  ## Detect species: a binomial name contains a space ##
  is_species <- grepl(" ", trimws(search_term))

  if (is_species) {
    query <- glue::glue_sql("
    SELECT *,
      'species' AS match_type
    FROM species as sp
    WHERE sp.species_name ILIKE {search_term}
    AND   sp.species_tax  = {taxonomy};
    ", .con = con)

    result <- DBI::dbGetQuery(con, query)

  } else {
    genus_pattern <- paste0(search_term, " %")

    query <- glue::glue_sql("
    SELECT *,
      CASE
        WHEN species_name ILIKE {genus_pattern} THEN 'genus'
        WHEN species_family ILIKE {search_term} THEN 'family'
        WHEN species_order ILIKE {search_term} THEN 'order'
      END AS match_type
    FROM species as sp
    WHERE (
      sp.species_name ILIKE {genus_pattern}
      OR
      sp.species_family ILIKE {search_term}
      OR
      sp.species_order ILIKE {search_term}
      )
    AND
    sp.species_tax = {taxonomy};
    ", .con = con)

    result <- DBI::dbGetQuery(con, query)
  }

  result <- result[c("species_name", "species_family", "species_order", "match_type")]

  ## Rename columns ##
  names(result)[names(result) == 'species_name'] <- 'species'
  names(result)[names(result) == 'species_family'] <- 'family'
  names(result)[names(result) == 'species_order'] <- 'order'

  return(result)
}
