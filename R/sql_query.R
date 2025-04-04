#' Create SQL query of AVONET database
#'
#' @param parameter1 Latin name of species
#' @param parameter2 Taxonomy
#'
#' @return A dataframe.
#' @export
#'
#' @examples
#' parameter1 <- "Buteo buteo"
#' parameter2 <- 1
#' result_df <- sql_query(parameter1, parameter2)
#' result_df
sql_query <- function(parameter1, parameter2) {
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
ms.mass_flag
from
species as sp,
eco_trait_species as ect,
mass_species as ms
where
sp.species_name = $1
and
sp.species_tax = $2
and
ect.species_id = sp.species_id
and
ms.species_id = sp.species_id;")

  if(length(parameter1) > length(parameter2)){
    parameter2 <- rep(parameter2, length(parameter1))
  } else if(length(parameter2) > length(parameter1)){
    parameter1 <- rep(parameter1, length(parameter2))
  }

  result <- dbGetQuery(con, query, params = list(parameter1, parameter2))
  return(result)
}
