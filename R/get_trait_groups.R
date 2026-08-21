# Single source of truth for trait groups: maps each user-facing group name to
# the database table that holds it. Both get_trait_groups() and
# get_trait_list() read from here so the two cannot list different groups.
#
# Two further groups exist in the schema but are not yet usable:
#   "reproductive" -- reproduction_trait_species is empty in the DB
#   "demo"         -- needs table_prefixes updating first
trait_group_tables <- function() {
  c(
    eco    = "eco_trait_species",
    social = "social_trait_species",
    morpho = "morph_trait_specimen",
    geo    = "geo_data_species"
  )
}


#' Discover available trait groups
#'
#' `get_trait_groups()` returns a character vector of the groups of traits that
#' are available in the AVONET dataset.
#'
#' @returns A character vector of trait groups: "eco", "social", "morpho" and
#' "geo". Further trait groups, e.g. "reproductive" and "demo", will be
#' implemented soon.
#' @export
#'
#' @seealso [get_trait_list()], which takes one of these names as its `group`
#'   argument.
#'
#' @examples
#' \dontrun{
#' traitGroups <- get_trait_groups()
#' traitGroups
#' }
get_trait_groups <- function() {
  names(trait_group_tables())
}
