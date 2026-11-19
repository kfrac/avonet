#' Retrieve the raw trait dictionary
#'
#' `query_trait_values()` reads `trait_info_detailed`, the database's own
#' dictionary of traits and the values they can take. It is the raw-SQL layer
#' behind the package's trait-discovery functions, in the same sense as
#' [query_species_traits()]: callers shape its output rather than returning it
#' to the user unchanged.
#'
#' @details
#' Column names are the database's own rather than the package's tidied
#' vocabulary, which is why this is not exported. Users reach the same
#' information through [get_trait_list()], which lists every trait with a
#' data-derived summary of the values it actually takes, and
#' [get_trait_levels()], which gives one categorical trait's levels alongside
#' their short and long definitions.
#'
#' Rows are not unique -- a trait can appear more than once with the same
#' `trait_value` -- so all three callers deduplicate before using it:
#'
#' * [get_trait_levels()] filters by `trait_name`, reads `trait_class` to
#'   reject non-categorical traits, and drops duplicate `trait_value` rows.
#' * `get_metadata()` and `list_traits()` join `trait_description` onto their
#'   own output by trait name.
#'
#' `trait_info_detailed` holds no Postgres enum columns, so unlike the other
#' query functions this one does not call `convert_enum_columns()`.
#'
#' @return A data frame with columns `trait_group`, `trait_name`,
#'   `trait_class` (e.g. `"categorical"`, `"continuous"` or `"spatial"`),
#'   `trait_description`, `trait_value`, `value_desc_short` and
#'   `value_desc_long`, all character.
#'
#' @keywords internal
#'
#' @seealso [get_trait_list()] and [get_trait_levels()], the exported functions
#'   that shape this table for users.
#'
#' @examples
#' \dontrun{
#' avonet:::query_trait_values()
#' }
query_trait_values <- function() {
  db_table("trait_info_detailed")
}
