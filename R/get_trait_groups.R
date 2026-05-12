get_trait_groups <- function() {
  vector <- c("eco_trait_species",
              #"reproductive_trait_species",
              #"social_trait_species",
              #"demo_trait_specimen",
              "morph_trait_specimen",
              "geo_data_species")
  names(vector) <- c("eco",
                     #"reprod",
                     #"social",
                     #"demo",
                     "morpho",
                     "geo")

  return(names(vector))
}
