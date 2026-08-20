#' Retrieve taxonomic information
#'
#' @param search_term Character vector. Either one or more species binomials
#'   (e.g. `c("Buteo buteo", "Cardinalis cardinalis")`), or one or more
#'   genus/family/order names (e.g. `c("Buteo", "Accipitridae")`) -- all
#'   elements must be the same kind (all binomials, or all not). Matching is
#'   case-insensitive.
#' @param taxonomy Choose which taxonomy your results are displayed in. 1 = BirdLife, 2 = eBird and 3 = BirdTree
#'
#' @return A dataframe with columns `species`, `family`, `order` and
#'   `match_type` (one of `"species"`, `"genus"`, `"family"` or `"order"`).
#'   A species matched by more than one `search_term` (e.g. both its genus and its
#'   family) appears once per match.
#' @export
#'
#' @examples
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#' connect_db(username = db_user, pw = db_password)
#'
#' # This works for a single species
#' get_taxonomic_info(search_term = "Buteo buteo", taxonomy = 1)
#'
#' # Or several species at once
#' get_taxonomic_info(search_term = c("Buteo buteo", "Cardinalis cardinalis"), taxonomy = 1)
#'
#' # Or several genera/families/orders at once (but not mixed with species)
#' get_taxonomic_info(search_term = c("Buteo", "Accipitridae"), taxonomy = 1)
get_taxonomic_info <- function(search_term, taxonomy) {

  con <- get_con()

  search_term <- trimws(search_term)

  ## Detect species: a binomial name contains a space ##
  has_space <- grepl(" ", search_term, fixed = TRUE)

  if (all(has_space)) {
    is_species <- TRUE
  } else if (!any(has_space)) {
    is_species <- FALSE
  } else {
    rlang::abort(
      "search_term must be either all species binomials (containing a space) or all genus/family/order names (no space) -- not a mix.",
      class = "avonet_error_mixed_rank"
    )
  }

  if (is_species) {
    query <- glue::glue_sql("
    SELECT *,
      'species' AS match_type
    FROM species as sp
    WHERE sp.species_name ILIKE ANY (ARRAY[{search_term*}])
    AND   sp.species_tax  = {taxonomy};
    ", .con = con)

    result <- DBI::dbGetQuery(con, query)

    matched <- tolower(search_term) %in% tolower(result$species_name)

  } else {
    genus_pattern <- paste0(search_term, " %")

    query <- glue::glue_sql("
    SELECT *,
      CASE
        WHEN species_name ILIKE ANY (ARRAY[{genus_pattern*}]) THEN 'genus'
        WHEN species_family ILIKE ANY (ARRAY[{search_term*}]) THEN 'family'
        WHEN species_order ILIKE ANY (ARRAY[{search_term*}]) THEN 'order'
      END AS match_type
    FROM species as sp
    WHERE (
      sp.species_name ILIKE ANY (ARRAY[{genus_pattern*}])
      OR
      sp.species_family ILIKE ANY (ARRAY[{search_term*}])
      OR
      sp.species_order ILIKE ANY (ARRAY[{search_term*}])
      )
    AND
    sp.species_tax = {taxonomy};
    ", .con = con)

    result <- DBI::dbGetQuery(con, query)

    matched <- vapply(search_term, function(term) {
      term <- tolower(term)
      any(startsWith(tolower(result$species_name), paste0(term, " "))) ||
        any(tolower(result$species_family) == term) ||
        any(tolower(result$species_order) == term)
    }, logical(1))
  }

  unmatched <- search_term[!matched]
  if (length(unmatched) > 0) {
    warning(sprintf(
      "No matches found for: %s", paste(unmatched, collapse = ", ")
    ), call. = FALSE)
  }

  result <- result[c("species_name", "species_family", "species_order", "match_type")]

  ## Rename columns ##
  names(result)[names(result) == 'species_name'] <- 'species'
  names(result)[names(result) == 'species_family'] <- 'family'
  names(result)[names(result) == 'species_order'] <- 'order'

  return(result)
}
