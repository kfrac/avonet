#' See which traits belong to a trait group
#'
#' `get_trait_list()` returns a tibble of the traits available in a trait
#' group, or across every group at once. Alongside each trait name it gives a
#' description, the values the trait can take, the publication most of those
#' values are attributed to, and whether the trait is recorded per species or
#' per measured specimen.
#'
#' @details
#' Group names are the ones returned by [get_trait_groups()]: `"eco"`,
#' `"social"`, `"morpho"` and `"geo"`. Two further groups exist in the
#' database schema but are not yet available — `"reproductive"`, whose table is
#' currently empty, and `"demo"`.
#'
#' Traits with no attributable literature source are omitted, so this lists
#' what can be cited rather than every column present in a table.
#'
#' An unrecognised group name raises an error of class
#' `avonet_error_unknown_group` listing the valid names. Only the requested
#' group is queried, so naming one group reads one table rather than all four.
#'
#' @param group Character(1) or `NULL`. One of the group names returned by
#'   [get_trait_groups()]. `NULL` (the default) returns the traits of every
#'   group combined, with an extra `group` column identifying which group each
#'   trait came from.
#'
#' @return A tibble with one row per trait and the columns `trait`,
#'   `resolution` (`"species"` or `"specimen"`), `description`, `value`
#'   (`"numeric"`, or the categorical levels as a comma-separated string) and
#'   `primary_source`. When `group` is `NULL` a leading `group` column is added,
#'   giving six columns rather than five.
#' @export
#'
#' @seealso [get_trait_groups()] for the valid group names,
#'   [get_trait_levels()] for the levels of a single categorical trait, and
#'   [get_traits()] to pull the trait data itself.
#'
#' @examples
#' \dontrun{
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#' connect_db(username = db_user, pw = db_password)
#'
#' # One group at a time
#' eco_traits <- get_trait_list(group = "eco")
#' eco_traits
#'
#' # Or every group at once, with a `group` column added
#' all_traits <- get_trait_list()
#' all_traits
#'
#' disconnect_db()
#' }
get_trait_list <- function(group = NULL) {

  group_tables <- trait_group_tables()

  if (!is.null(group)) {

    if (length(group) != 1 || !group %in% names(group_tables)) {
      rlang::abort(
        sprintf(
          "Unknown trait group '%s'. Valid groups: %s. See get_trait_groups().",
          paste(group, collapse = ", "),
          paste(names(group_tables), collapse = ", ")
        ),
        class = "avonet_error_unknown_group"
      )
    }

    # Only the requested group is queried
    return(dplyr::as_tibble(list_traits(group_tables[[group]])))
  }

  # No group given: every group, tagged with where each trait came from
  cols <- c("group", "trait", "resolution", "description", "value", "primary_source")

  output <- lapply(names(group_tables), function(nm) {
    traits <- list_traits(group_tables[[nm]])
    traits$group <- nm
    traits[, cols]
  })

  dplyr::as_tibble(do.call("rbind", output))
}
