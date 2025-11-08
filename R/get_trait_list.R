get_trait_list <- function(group) {
  # if(length(group) > 1) {
  #   traits <- as.data.frame(do.call("rbind", trait_groups_dict))
  # } else {
  #   traits <- trait_groups_dict[[group]]
  # }

  trait_groups_dict <- list()

  table_prefixes <- c("ect_", "spd_")

  trait_groups_dict[["eco"]] <- list_traits("eco_trait_species")
  trait_groups_dict[["geo"]] <- list_traits("geo_data_species")
  # trait_groups_dict[["reprod"]] <- list_traits("reproductive") update table_prefixes
  # trait_groups_dict[["social"]] <- list_traits("social") update table_prefixes
  trait_groups_dict[["morpho"]] <- list_traits("morph_trait_specimen")

  new_names <- ifelse(Reduce(`|`, lapply(table_prefixes, startsWith, x = trait_groups_dict[[group]]$column_name)),
                      sub("^[^_]*_", "", trait_groups_dict[[group]]$column_name),
                      trait_groups_dict[[group]]$column_name)

  trait_groups_dict[[group]]$column_name <- new_names

  return(trait_groups_dict[[group]])
}
