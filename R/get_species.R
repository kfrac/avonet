#' Retrieve species-level trait data
#'
#' `get_species()` returns the species-level side of AVONET as a plain data
#' frame: one row per species, combining the taxonomic backbone with the
#' ecological, body mass and geographic trait tables. It is the lightweight
#' counterpart to [get_traits()], returning the same columns as that function's
#' `data` element but without the accompanying metadata and literature sources.
#'
#' @details
#' Names in `species` must be species binomials that match `species_name`
#' exactly for the requested taxonomy — no rank detection or fuzzy matching is
#' applied. Use [get_traits()] if you want to supply a genus, family or order
#' and have it resolved to the species it contains, or [get_taxonomic_info()]
#' to check how a name resolves first.
#'
#' Names with no match are dropped silently rather than returning a row of
#' `NA`s, so a shorter result than input is the normal signal that a binomial
#' was misspelled or belongs to a different taxonomy version. A species that
#' exists but has no rows in a given trait table does return a row, with `NA`
#' in that table's columns.
#'
#' `species` and `taxonomy` are recycled against each other, so a vector of
#' species can be queried against a single taxonomy version — the usual case —
#' or each species paired with its own version.
#'
#' ## Columns
#'
#' The underlying query prefixes every column with its source table (`ect_`,
#' `mass_`, `spd_`, `species_`) to keep names unique across the join, and
#' returns each trait alongside a `_src` / `_source` column recording where the
#' value came from. Both are bookkeeping rather than data, so `get_species()`
#' strips the prefixes and drops the source columns before returning, exactly
#' as `get_traits()` does for its `data` element. `species_id` is dropped for
#' the same reason.
#'
#' If you need the source of each value, use
#' `get_traits()`, which returns it resolved into a `metadata_summary` table,
#' or `get_traits(source_cols = TRUE)` to keep the raw columns inline.
#'
#' @param species Character vector of species binomials, e.g. `"Buteo buteo"`
#'   or `c("Buteo buteo", "Aquila chrysaetos")`.
#' @param taxonomy Integer. Taxonomy ID matched against `species_tax`:
#'   1 = BirdLife, 2 = eBird, 3 = BirdTree. Recycled to the length of
#'   `species`.
#' @param inferred Logical. Whether to include traits inferred for species
#'   created by taxonomic splits, merges and other revisions. Only `FALSE`
#'   (the default) is currently implemented; `TRUE` raises an error of class
#'   `avonet_error_not_implemented`.
#'
#' @return A data frame with one row per matched species, identical in shape to
#'   the `data` element of [get_traits()]:
#'   \describe{
#'     \item{`species`, `family`, `order`, `tax`}{Taxonomic backbone: the
#'       binomial, its family and order, and the taxonomy the row belongs to.}
#'     \item{`habitat`, `habitat_density`, `migration`, `trophic_level`,
#'       `trophic_niche`, `primary_lifestyle`}{Ecological traits}
#'     \item{`mass_value`, `mass_flag`}{Body mass in grams and its quality flag.}
#'     \item{`min_latitude`, `max_latitude`, `centroid_lat`, `centroid_lon`,
#'       `range_size`}{Geographic extent, range centroid and range size.}
#'   }
#'   Returns zero rows if no species matched.
#'
#' @export
#'
#' @seealso [get_traits()] for the same data bundled with metadata and
#'   sources, and for querying above species rank; [get_taxonomic_info()] to
#'   check a name before querying.
#'
#' @examples
#' \dontrun{
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#' connect_db(username = db_user, pw = db_password)
#'
#' # A single species
#' get_species("Buteo buteo", 1)
#'
#' # Or a vector of several species, against one taxonomy version
#' my_birds <- c("Haliaeetus leucocephalus", "Aptenodytes forsteri", "Cardinalis cardinalis")
#' get_species(my_birds, 1)
#'
#' # The same species under a different taxonomy
#' get_species("Buteo buteo", taxonomy = 2)
#'
#' # Same columns as the data element of get_traits()
#' identical(
#'   names(get_species("Buteo buteo", 1)),
#'   names(get_traits("Buteo buteo", 1)$data)
#' )
#'
#' disconnect_db()
#' }
get_species <- function(species, taxonomy, inferred = FALSE) {

  if (!isFALSE(inferred)) {
    rlang::abort(
      "Inferred traits are not implemented yet. Please set `inferred = FALSE`.",
      class = "avonet_error_not_implemented"
    )
  }

  species_data <- query_species_traits(species = species, taxonomy = taxonomy)

  ## Shared with get_traits(), so both return the same columns
  .tidy_species_columns(species_data)
}
