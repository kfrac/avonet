#' Create SQL query of AVONET database
#'
#' @param con Connection to the AVONET database
#' @param parameter1 Latin name of species
#' @param parameter2 Taxonomy
#'
#' @return A dataframe.
#' @export
#'
#' @examples
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#' con <- connect_db(username = db_user, pw = db_password)
#'
#' parameter1 <- "Buteo buteo"
#' parameter2 <- 1
#' result_df <- sql_query(con, parameter1, parameter2)
#' result_df
sql_query <- function(con, parameter1, parameter2) {
  sql <- paste("
  SELECT
    sp.species_id,
    sp.species_name,
    sp.species_family,
    sp.species_order,
    sp.species_tax,
    ect.ect_habitat,
    ect.ect_habitat_src,
    ect.ect_habitat_density,
    ect.ect_habitat_density_src,
    ect.ect_migration,
    ect.ect_migration_src,
    ect.ect_trophic_level,
    ect.ect_trophic_level_src,
    ect.ect_trophic_niche,
    ect.ect_trophic_niche_src,
    ect.ect_primary_lifestyle,
    ect.ect_primary_lifestyle_src,
    ms.mass_value,
    ms.mass_trait_src,
    ms.mass_flag,
    gds.spd_min_latitude,
    gds.spd_max_latitude,
    gds.spd_centroid_lat,
    gds.spd_centroid_lon,
    gds.spd_range_size,
    gds.spd_spatial_source
  FROM
    species as sp
    left join eco_trait_species as ect on ect.species_id = sp.species_id
    left join mass_species      as ms  on ms.species_id  = sp.species_id
    left join geo_data_species  as gds on gds.species_id = sp.species_id
  WHERE
    sp.species_name = $1
  AND
    sp.species_tax = $2;")

  if(length(parameter1) > length(parameter2)){
    parameter2 <- rep(parameter2, length(parameter1))
  } else if(length(parameter2) > length(parameter1)){
    parameter1 <- rep(parameter1, length(parameter2))
  }

  query <- DBI::dbSendQuery(con, sql)
  DBI::dbBind(query, list(parameter1, parameter2))
  result <- DBI::dbFetch(query)

  DBI::dbClearResult(query)

  return(result)
}
