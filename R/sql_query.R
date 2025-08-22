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
#' con <- connect(username = "postgres", pw = "Frankfurterstr25!")
#' parameter1 <- "Buteo buteo"
#' parameter2 <- 1
#' result_df <- sql_query(con, parameter1, parameter2)
#' result_df
sql_query <- function(con, parameter1, parameter2) {
  query <- paste("select
sp.species_id,
sp.species_name,
sp.species_family,
sp.species_order,
sp.species_tax,
ect.ect_habitat,
ect.ect_habitat_density,
ect.ect_migration,
ect.ect_trophic_level,
ect.ect_trophic_niche,
ect.ect_primary_lifestyle,
ms.mass_value,
ms.mass_flag,
gds.spd_min_latitude,
gds.spd_max_latitude,
gds.spd_centroid_lat,
gds.spd_centroid_lon,
gds.spd_range_size
from
species as sp,
eco_trait_species as ect,
mass_species as ms,
geo_data_species as gds
where
sp.species_name = $1
and
sp.species_tax = $2
and
ect.species_id = sp.species_id
and
ms.species_id = sp.species_id
and
gds.species_id = sp.species_id;")

  if(length(parameter1) > length(parameter2)){
    parameter2 <- rep(parameter2, length(parameter1))
  } else if(length(parameter2) > length(parameter1)){
    parameter1 <- rep(parameter1, length(parameter2))
  }

  result <- DBI::dbGetQuery(con, query, params = list(parameter1, parameter2))
  return(result)
}
