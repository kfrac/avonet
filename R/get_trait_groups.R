#' Discover available trait groups
#'
#' `get_trait_groups()` returns a character vector of the groups of traits that
#' are available in the AVONET dataset.
#'
#' @returns A character vector of trait groups, e.g. "eco", "social", "morpho", "geo".
#' Further trait groups, e.g. "reproductive" and "demo" will be implemented soon.
#' @export
#'
#' @examples
#' traitGroups <- get_trait_groups()
#' traitGroups
get_trait_groups <- function() {
  vector <- c("eco_trait_species",
              #"reproductive_trait_species",
              "social_trait_species",
              #"demo_trait_specimen",
              "morph_trait_specimen",
              "geo_data_species")
  names(vector) <- c("eco",
                     #"reproductive",
                     "social",
                     #"demo",
                     "morpho",
                     "geo")

  return(names(vector))
}
