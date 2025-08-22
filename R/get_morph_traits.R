get_morph_traits <- function(con, species, taxonomy, aggregate = NULL) {
  query <- c("select
mtd.*,
(SELECT species_id FROM species WHERE species_name = $1 and species_tax = $2) AS species_id
from
morph_trait_detailed as mtd
where
mtd.source_id in (select sss.source_id
                  from
                  source_specimen_species as sss,
                  species as sp
                  where
                  sp.species_name = $1 and sp.species_tax = $2
                  and
                  sss.species_id = sp.species_id);")

  if(length(species) > length(taxonomy)){
    taxonomy <- rep(taxonomy, length(species))
  } else if(length(taxonomy) > length(species)){
    species <- rep(species, length(taxonomy))
  }

  result <- DBI::dbGetQuery(con, query, params = list(species, taxonomy))

  if(aggregate == "sex"){
    result %>%
      group_by(sd_sex) %>%
      summarize(n = n(),
                mean_wing_length = mean(wing_length),
                mean_kipps_distance = mean(kipps_distance),
                mean_beak_length_culmen = mean(beak_length_culmen),
                mean_beak_length_nares = mean(beak_length_nares),
                mean_beak_width = mean(beak_width),
                mean_gape_with = mean(gape_with),
                mean_beak_depth = mean(beak_depth),
                mean_beak_depth_max = mean(beak_depth_max),
                mean_tail_length = mean(tail_length),
                mean_tail_graduation = mean(tail_graduation),
                mean_tarsus_length = mean(tarsus_length),
                mean_tarsus_diameter_sag = mean(tarsus_diameter_sag),
                mean_tarsus_diameter_lat = mean(tarsus_diameter_lat),
                mean_back_toe = mean(back_toe),
                mean_secondary_1 = mean(secondary_1)) -> result
  } else if(aggregate == "life stage") {
    result %>%
      group_by(sd_life_stage) %>%
      summarize(n = n(),
                mean_wing_length = mean(wing_length),
                mean_kipps_distance = mean(kipps_distance),
                mean_beak_length_culmen = mean(beak_length_culmen),
                mean_beak_length_nares = mean(beak_length_nares),
                mean_beak_width = mean(beak_width),
                mean_gape_with = mean(gape_with),
                mean_beak_depth = mean(beak_depth),
                mean_beak_depth_max = mean(beak_depth_max),
                mean_tail_length = mean(tail_length),
                mean_tail_graduation = mean(tail_graduation),
                mean_tarsus_length = mean(tarsus_length),
                mean_tarsus_diameter_sag = mean(tarsus_diameter_sag),
                mean_tarsus_diameter_lat = mean(tarsus_diameter_lat),
                mean_back_toe = mean(back_toe),
                mean_secondary_1 = mean(secondary_1)) -> result
  } else if(aggregate == "source type"){
    result %>%
      group_by(source_type) %>%
      summarize(n = n(),
                mean_wing_length = mean(wing_length),
                mean_kipps_distance = mean(kipps_distance),
                mean_beak_length_culmen = mean(beak_length_culmen),
                mean_beak_length_nares = mean(beak_length_nares),
                mean_beak_width = mean(beak_width),
                mean_gape_with = mean(gape_with),
                mean_beak_depth = mean(beak_depth),
                mean_beak_depth_max = mean(beak_depth_max),
                mean_tail_length = mean(tail_length),
                mean_tail_graduation = mean(tail_graduation),
                mean_tarsus_length = mean(tarsus_length),
                mean_tarsus_diameter_sag = mean(tarsus_diameter_sag),
                mean_tarsus_diameter_lat = mean(tarsus_diameter_lat),
                mean_back_toe = mean(back_toe),
                mean_secondary_1 = mean(secondary_1)) -> result
  } else {
    result <- result
  }

  return(result)
}
