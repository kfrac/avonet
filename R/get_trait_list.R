get_trait_list <- function(group = NULL) {
  # if(length(group) > 1) {
  #   traits <- as.data.frame(do.call("rbind", trait_groups_dict))
  # } else {
  #   traits <- trait_groups_dict[[group]]
  # }

  trait_groups_dict <- list()

  trait_groups_dict[["eco"]] <- list_traits("eco_trait_species")
  trait_groups_dict[["geo"]] <- list_traits("geo_data_species")
  # trait_groups_dict[["reprod"]] <- list_traits("reproductive") update table_prefixes
  # trait_groups_dict[["social"]] <- list_traits("social") update table_prefixes
  trait_groups_dict[["morpho"]] <- list_traits("morph_trait_specimen")

  if(is.null(group)) {
    lapply(names(trait_groups_dict), function(nm) {
      x <- trait_groups_dict[[nm]]
      x$group <- nm
      x <- x[,c("group", "trait", "value", "resolution")]
    }) -> output
    output <- do.call("rbind", output)
  } else {
    output <- trait_groups_dict[[group]]
  }

  output <- as_tibble(output)

  return(output)
}
