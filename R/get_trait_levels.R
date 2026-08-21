#' Get the possible levels of a categorical trait
#'
#' `get_trait_levels()` looks up the unique values a categorical trait can
#' take, based on the `trait_value` column returned by [get_trait_values()].
#' It errors if `trait` is not classified as `"categorical"` (e.g. it is
#' `"continuous"` or `"spatial"`), since those traits have no fixed set of
#' levels to enumerate.
#'
#' @param trait A string. A trait name matching a value in the `trait_name`
#'   column returned by [get_trait_values()].
#' @param return_defs Logical. If `FALSE` (default), returns a plain
#'   character vector of the trait's unique values. If `TRUE`, returns a
#'   tibble with each value alongside its `short_description` and
#'   `long_description` definitions.
#'
#' @return By default, a character vector of unique trait values. If
#'   `return_defs = TRUE`, a tibble with columns `trait`,
#'   `short_description` and `long_description`.
#' @export
#'
#' @seealso [get_trait_values()], [get_trait_list()]
#'
#' @examples
#' \dontrun{
#' get_trait_levels("habitat")
#' get_trait_levels("habitat", return_defs = TRUE)
#' }
get_trait_levels <- function(trait, return_defs = FALSE) {

  trait <- trimws(trait)

  trait_vals <- get_trait_values()

  trait_rows <- trait_vals[trait_vals$trait_name == trait, ]

  if (nrow(trait_rows) == 0) {
    rlang::abort(
      sprintf(
        "Trait '%s' not found. See get_trait_list() for valid trait names.",
        trait
      ),
      class = "avonet_error_unknown_trait"
    )
  }

  trait_class <- unique(trait_rows$trait_class)

  if (!identical(trait_class, "categorical")) {
    rlang::abort(
      sprintf(
        "Trait '%s' is '%s', not categorical. get_trait_levels() only applies to categorical traits.",
        trait, paste(trait_class, collapse = ", ")
      ),
      class = "avonet_error_not_categorical"
    )
  }

  if (return_defs) {
    defs <- trait_rows[!duplicated(trait_rows$trait_value),
                        c("trait_value", "value_desc_short", "value_desc_long")]
    names(defs) <- c("trait", "short_description", "long_description")
    return(dplyr::as_tibble(defs))
  }

  unique(trait_rows$trait_value)
}
