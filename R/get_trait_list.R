#' See which traits belong to a trait group
#'
#' `get_trait_list()` returns a tibble of the traits that are available in a specific
#' trait group. In addition to the traits, it provides a description, possible values,
#' sources and the resolution of the trait (species vs. specimen).
#'
#' @param group A string. Currently accepts one of the following values: "eco",
#' "morpho" or "geo". If NULL, then `get_trait_list()` returns all traits from every group.
#'
#' @returns A tibble of traits
#' @export
#'
#' @examples
#' eco_traits <- get_trait_list(group = "eco")
#' eco_traits
get_trait_list <- function(group = NULL) {
  # if(length(group) > 1) {
  #   traits <- as.data.frame(do.call("rbind", trait_groups_dict))
  # } else {
  #   traits <- trait_groups_dict[[group]]
  # }

  trait_groups_dict <- list()

  trait_groups_dict[["eco"]] <- list_traits("eco_trait_species")
  trait_groups_dict[["reproduction"]] <- list_traits("reproduction_trait_species")
  trait_groups_dict[["social"]] <- list_traits("social_trait_species")
  # trait_groups_dict[["demo"]] <- list_traits("demo") update table_prefixes
  trait_groups_dict[["morpho"]] <- list_traits("morph_trait_specimen")
  trait_groups_dict[["geo"]] <- list_traits("geo_data_species")

  if(is.null(group)) {
    lapply(names(trait_groups_dict), function(nm) {
      x <- trait_groups_dict[[nm]]
      x$group <- nm
      x <- x[,c("group", "trait", "resolution", "description", "value", "primary_source")]
    }) -> output
    output <- do.call("rbind", output)
  } else {
    output <- trait_groups_dict[[group]]
  }

  output <- dplyr::as_tibble(output)

  return(output)
}
