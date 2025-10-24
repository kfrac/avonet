get_trait_groups <- function() {
  vector <- c("eco_trait_species", "geo_data_species", "reproductive_trait_species", "social_trait_species", "morph_trait_specimen")
  names(vector) <- c("eco", "geo", "reprod", "social", "morpho")

  return(names(vector))
}
