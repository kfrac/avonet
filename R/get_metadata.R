#' Build the metadata summary for an AVONET query
#'
#' Produces the `metadata_summary` element of [get_traits()]: the queried
#' traits, the source recorded against each one, and the trait's description
#' from the database's own dictionary.
#'
#' @details
#' Which source column backs which trait comes from `species_trait_sources()`,
#' which also records why that mapping has to be stated rather than derived.
#' Two consequences are worth knowing:
#'
#' * The five geographic traits share a single `spd_spatial_source` column, so
#'   each gets its own row naming that shared source. Earlier versions derived
#'   trait names by stripping suffixes off the source columns instead, which
#'   collapsed all five into one row called `spatial_source` -- a column name,
#'   not a trait -- and left the five traits themselves unmentioned.
#' * `mass_value` has no entry in `trait_info_detailed`, so its `description`
#'   is always `NA`. That is a gap in the database rather than in this
#'   function; its `primary_source` still resolves, because `mass_trait_src`
#'   is populated per species.
#'
#' A trait's source can differ from species to species, so across a multi
#' species query a trait appears once per distinct source rather than exactly
#' once. Rows are de-duplicated on trait and source before the description is
#' joined.
#'
#' @param data Data frame of raw `query_species_traits()` output, carrying both
#'   the trait columns and their `_src` / `_source` partners.
#'
#' @returns A dataframe with columns \code{trait}, \code{description},
#' \code{primary_source} and \code{source}, which references the trait_src_id
#' column in the AVONET database table trait_source_detailed.
#' @keywords internal
#'
#' @seealso [get_traits()], which returns this as `metadata_summary`.
#'   `get_sources()` resolves the same `source` IDs to their full literature
#'   references; it carries no roxygen block by design, so it is not linked.
#'
#' @examples
#' \dontrun{
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#' connect_db(username = db_user, pw = db_password)
#'
#' species_data <- avonet:::query_species_traits(species = "Buteo buteo", taxonomy = 1)
#'
#' avonet:::get_metadata(species_data)
#' }
get_metadata <- function(data) {

  ## Only the traits this query actually returned, in the order the lookup
  ## lists them.
  map <- species_trait_sources()
  map <- map[names(map) %in% names(data) & unname(map) %in% names(data)]

  if (length(map) == 0) {
    return(data.frame(trait          = character(0),
                      description    = character(0),
                      primary_source = character(0),
                      source         = integer(0),
                      stringsAsFactors = FALSE))
  }

  ## One row per trait per source value recorded for it. Stacking trait by
  ## trait keeps the mapping explicit, where pivoting the source columns lost
  ## track of which traits each one belonged to.
  metadata <- do.call(rbind, lapply(names(map), function(trait_col) {
    data.frame(
      trait  = sub("^(ect_|spd_)", "", trait_col),
      source = data[[map[[trait_col]]]],
      stringsAsFactors = FALSE
    )
  }))

  metadata <- unique(metadata)

  # --- Source lookup from trait_source_detailed ---
  # metadata$source holds trait_src_id values. Look each up to get the
  # lit_abbrev used as primary_source.
  src_lookup <- db_table("trait_source_detailed")[, c("trait_src_id", "lit_abbrev")]

  # na_matches = "never" is load-bearing. trait_source_detailed holds two rows
  # with no trait_src_id at all (dataset-level citations), and dplyr treats NA
  # as equal to NA when joining. A trait whose source column is NULL -- every
  # trait of a species with no data, or a single trait elsewhere -- therefore
  # matched both of them, fanning one row out into two and naming papers that
  # say nothing about that trait. get_sources() resolves the same values in
  # SQL, where NULL never matches NULL, so this also keeps the two halves of
  # the source machinery agreeing about what a missing source means.
  metadata <- dplyr::left_join(
    metadata,
    src_lookup,
    by          = c("source" = "trait_src_id"),
    na_matches  = "never"
  )

  # If source_comment is desired, "trait_src_description" needs to be readded
  # to SELECT statement in SQL
  #names(metadata)[names(metadata) == "trait_src_description"] <- "source_comment"
  names(metadata)[names(metadata) == "lit_abbrev"] <- "primary_source"

  # --- short_description from the trait dictionary ---
  # Deduplicated on trait name alone, so a trait carrying more than one
  # description in the dictionary cannot fan these rows out again.
  trait_descriptions <- query_trait_values()
  trait_descriptions <- trait_descriptions[, c("trait_name", "trait_description")]
  names(trait_descriptions) <- c("trait", "description")
  trait_descriptions <- trait_descriptions[!duplicated(trait_descriptions$trait), ]

  metadata <- dplyr::left_join(metadata, trait_descriptions, by = "trait")

  metadata_output <- metadata[, c("trait", "description", "primary_source", "source")]

  return(metadata_output)

}
