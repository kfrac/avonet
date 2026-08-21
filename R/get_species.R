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
#' as `get_traits()` does for its `data` element.
#'
#' `source_cols = TRUE` keeps the source columns inline, giving 26 columns
#' rather than 17. It also retains the species `id` column, which is otherwise
#' dropped alongside them. The values in the source columns are source IDs
#' rather than citations — use [get_traits()] if you want them resolved into a
#' `metadata_summary` table with the full literature references.
#'
#' @param species Character vector of species binomials, e.g. `"Buteo buteo"`
#'   or `c("Buteo buteo", "Aquila chrysaetos")`.
#' @param taxonomy Integer. Taxonomy ID matched against `species_tax`:
#'   1 = BirdLife, 2 = eBird, 3 = BirdTree. Recycled to the length of
#'   `species`.
#' @param source_cols Logical. If `FALSE` (default) the per-trait `_src` /
#'   `_source` columns are stripped, since they hold source IDs rather than
#'   trait values. Set `TRUE` to keep them inline; see Details.
#' @param inferred Logical. Whether to include traits inferred for species
#'   created by taxonomic splits, merges and other revisions. Only `FALSE`
#'   (the default) is currently implemented; `TRUE` raises an error of class
#'   `avonet_error_not_implemented`.
#'
#' @return A data frame with one row per matched species, identical in shape to
#'   the `data` element of [get_traits()] called with the same `source_cols`:
#'   \describe{
#'     \item{`species`, `family`, `order`, `tax`}{Taxonomic backbone: the
#'       binomial, its family and order, and the taxonomy version the row
#'       belongs to.}
#'     \item{`habitat`, `habitat_density`, `migration`, `trophic_level`,
#'       `trophic_niche`, `primary_lifestyle`}{Ecological traits, returned as
#'       factors since they are Postgres enums.}
#'     \item{`mass_value`, `mass_flag`}{Body mass in grams and its quality
#'       flag.}
#'     \item{`min_latitude`, `max_latitude`, `centroid_lat`, `centroid_lon`,
#'       `range_size`}{Geographic extent, range centroid and range size.}
#'   }
#'   When `source_cols = TRUE` an `id` column is prepended and the source
#'   columns are kept inline, giving 26 columns: each ecological trait and
#'   `mass_value` gain their own `_src` column, while the geographic block
#'   shares a single `spatial_source` and `mass_flag` has no source column.
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
#' # Keep the per-trait source columns inline
#' get_species("Buteo buteo", 1, source_cols = TRUE)
#'
#' # Same columns as the data element of get_traits()
#' identical(
#'   names(get_species("Buteo buteo", 1)),
#'   names(get_traits("Buteo buteo", 1)$data)
#' )
#'
#' disconnect_db()
#' }
get_species <- function(species, taxonomy, source_cols = FALSE, inferred = FALSE) {

  if (!isFALSE(inferred)) {
    rlang::abort(
      "Inferred traits are not implemented yet. Please set `inferred = FALSE`.",
      class = "avonet_error_not_implemented"
    )
  }

  species_data <- query_species_traits(species = species, taxonomy = taxonomy)

  ## Shared with get_traits(), so both return the same columns
  tidy_species_columns(species_data, source_cols = source_cols)
}
