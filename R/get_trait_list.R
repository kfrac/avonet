get_trait_list <- function(group) {
  # if(length(group) > 1) {
  #   traits <- as.data.frame(do.call("rbind", trait_groups_dict))
  # } else {
  #   traits <- trait_groups_dict[[group]]
  # }

  trait_groups_dict <- list()

  trait_groups_dict[["eco"]] <- list_traits("eco_trait_species")
  trait_groups_dict[["geo"]] <- list_traits("geo_data_species")
  # trait_groups_dict[["reprod"]] <- list_traits("reproductive")
  # trait_groups_dict[["social"]] <- list_traits("social")
  trait_groups_dict[["morpho"]] <- list_traits("morph_trait_specimen")

  trait_groups_dict[[group]]$column_name[-c(1, 2)] <- sub("^[^_]*_", "", trait_groups_dict[[group]]$column_name[-c(1, 2)])

  return(trait_groups_dict[[group]])
}
