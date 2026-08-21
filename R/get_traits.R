#' Retrieve trait data for one or more taxa
#'
#' `get_traits()` is the main entry point for pulling AVONET trait data into R.
#' It accepts taxon names at any rank, resolves each one to the species it
#' contains, queries the ecological, mass and geographical trait tables in a
#' single batched call, and returns the data together with the metadata and
#' literature sources needed to cite it.
#'
#' @details
#' Names supplied to `species` are resolved one at a time, so a single call can
#' mix ranks, e.g. `c("Buteo", "Falco peregrinus", "Accipitridae")`. Each name
#' is auto-detected as a species binomial, genus, family or order unless `rank`
#' forces one interpretation for all of them. Resolved species that turn out to
#' have no rows in the trait tables trigger a warning naming the species and
#' the tables they are missing from, rather than disappearing silently.
#'
#' ## Filtering
#'
#' `filter` is a named list applied after the query returns. Element names
#' accept either the full SQL column name or the short name left once the table
#' prefix is stripped (`habitat` for `ect_habitat`, `range_size` for
#' `spd_range_size`, `mass` for `mass_value`). Character columns take a single
#' value or a set of values; numeric columns take a `list(op = , val = )` pair,
#' where `op` is one of `"=="`, `"!="`, `"<"`, `"<="`, `">"` or `">="`.
#' Multiple conditions are combined with AND.
#'
#' ```
#' filter = list(habitat = "Forest")
#' filter = list(trophic_niche = c("Frugivore", "Nectarivore"))
#' filter = list(range_size = list(op = "<", val = 1000))
#' filter = list(habitat = "Forest", min_latitude = list(op = ">", val = 40))
#' ```
#'
#' ## Resolution
#'
#' The ecological, mass and geographical traits are species-level: one row per
#' species. Morphological measurements are specimen-level: many rows per
#' species. Rather than joining the two and repeating every species-level value
#' across each specimen, `resolution = "specimen"` returns the measurements as
#' a separate `specimen_data` element, so `data` stays one row per species
#' either way. Specimens are fetched only for the species that survive
#' `filter`, and species with no specimen records trigger a warning.
#'
#' @param species Character vector of taxon names at any rank, e.g.
#'   `c("Buteo", "Falco peregrinus", "Accipitridae")`.
#' @param taxonomy Integer. Taxonomy ID matched against `species_tax`:
#'   1 = BirdLife, 2 = eBird, 3 = BirdTree.
#' @param source_cols Logical. If `FALSE` (default) the per-trait `_src` /
#'   `_source` columns are stripped from `data`, since the same information is
#'   summarized in `metadata_summary` and `detailed_sources`. Set `TRUE` to
#'   keep them inline.
#' @param rank Character(1) or `NULL`. Forces every name in `species` to be
#'   read as one of `"species"`, `"genus"`, `"family"` or `"order"`. Leave
#'   `NULL` (default) to auto-detect each name individually.
#' @param filter Named list or `NULL`. Post-query filters; see Details.
#' @param resolution Character(1). `"species"` (default) returns species-level
#'   data only. `"specimen"` additionally returns raw specimen-level
#'   morphological measurements as a fourth list element.
#' @param aggregate Character(1) or `NULL`. Used only when
#'   `resolution = "specimen"`. One of `"sex"`, `"life stage"`, `"country"`,
#'   `"source type"` or `"all"`, collapsing specimen measurements into per
#'   species mean and count columns for that grouping. `NULL` (default) returns
#'   one row per specimen.
#'
#' @return A named list of three elements, or four when
#'   `resolution = "specimen"`:
#'   \describe{
#'     \item{`metadata_summary`}{Data frame with one row per trait, giving the
#'       trait description, its primary source and the source ID.}
#'     \item{`data`}{Data frame of trait values, one row per species.}
#'     \item{`detailed_sources`}{Data frame of the full literature references
#'       behind the source IDs cited in `metadata_summary`.}
#'     \item{`specimen_data`}{Present only when `resolution = "specimen"`. Data
#'       frame of specimen-level morphological measurements, one row per
#'       specimen, or one row per species and grouping level when `aggregate`
#'       is supplied.}
#'   }
#'
#' @seealso [get_trait_list()] to discover which traits are available,
#'   [get_trait_levels()] for the valid values of a categorical trait, and
#'   [get_taxonomic_info()] to check how a name resolves.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#' connect_db(username = db_user, pw = db_password)
#'
#' # A single species
#' buteo <- get_traits(species = "Buteo buteo", taxonomy = 1)
#' buteo$data
#' buteo$metadata_summary
#'
#' # Several taxa at once, mixing ranks
#' mixed <- get_traits(species = c("Buteo", "Falco peregrinus"), taxonomy = 1)
#'
#' # Filter on a categorical trait and a numeric range
#' forest <- get_traits(species = "Accipitridae", taxonomy = 1,
#'                      filter = list(habitat    = "Forest",
#'                                    range_size = list(op = "<", val = 1000)))
#'
#' # Add specimen-level morphological measurements
#' specimens <- get_traits(species = "Accipitridae", taxonomy = 1,
#'                         resolution = "specimen")
#' specimens$specimen_data
#'
#' # The same measurements, aggregated to per species means by sex
#' by_sex <- get_traits(species = "Accipitridae", taxonomy = 1,
#'                      resolution = "specimen", aggregate = "sex")
#'
#' disconnect_db()
#' }
get_traits <- function(species,
                       taxonomy,
                       source_cols = FALSE,
                       rank        = NULL,
                       filter      = NULL,
                       resolution  = c("species", "specimen"),
                       aggregate   = NULL) {

  resolution <- match.arg(resolution)

  con <- get_con()

  prefixes <- c("ect_", "spd_", "geo_", "species_")
  suffixes <- c("id", "_src", "_source")

  taxonomy <- as.integer(taxonomy)

  # ------------------------------------------------------------------
  # 1.  Resolve every supplied name to a flat, deduplicated species vector
  # ------------------------------------------------------------------
  resolved_species <- unique(unlist(lapply(species, function(taxon) {
    resolve_taxa(taxon    = taxon,
                 rank     = rank,
                 taxonomy = taxonomy)
  })))

  message(sprintf("Querying %d species in total.", length(resolved_species)))

  # ------------------------------------------------------------------
  # 2.  Single batched call to sql_query()
  #     sql_query() already handles vectors via dbBind, so we pass the
  #     full species vector directly rather than looping.
  # ------------------------------------------------------------------
  species_data <- sql_query(
    parameter1 = resolved_species,
    parameter2 = taxonomy          # recycled to match length inside sql_query()
  )


  # ------------------------------------------------------------------
  # 2b. Warn if any resolved species are missing rows in trait tables
  # ------------------------------------------------------------------
  returned_species <- species_data[["species_name"]]
  missing_species  <- setdiff(resolved_species, returned_species)

  if (length(missing_species) > 0) {
    # For each missing species, check which tables have no matching record
    missing_detail <- lapply(missing_species, function(sp) {
      tables <- c(
        eco_trait_species = glue::glue_sql("SELECT 1 FROM eco_trait_species AS ect INNER JOIN species AS s ON s.species_id = ect.species_id WHERE s.species_name = {sp} LIMIT 1;", .con = con),
        mass_species      = glue::glue_sql("SELECT 1 FROM mass_species      AS ms  INNER JOIN species AS s ON s.species_id = ms.species_id  WHERE s.species_name = {sp} LIMIT 1;", .con = con),
        geo_data_species  = glue::glue_sql("SELECT 1 FROM geo_data_species  AS gds INNER JOIN species AS s ON s.species_id = gds.species_id  WHERE s.species_name = {sp} LIMIT 1;", .con = con)
      )
      absent <- names(Filter(function(qry) {
        nrow(DBI::dbGetQuery(con, qry)) == 0
      }, tables))
      if (length(absent) > 0) {
        sprintf("  - %s: missing from %s", sp, paste(absent, collapse = ", "))
      }
    })
    missing_detail <- Filter(Negate(is.null), missing_detail)
    warning(sprintf(
      paste0(
        "%d of %d resolved species returned no data due to ",
        "missing records in one or more trait tables:\n%s"
      ),
      length(missing_species),
      length(resolved_species),
      paste(missing_detail, collapse = "\n")
    ), call. = FALSE)
  }
  # ------------------------------------------------------------------
  # 2c. Apply optional post-query filters (raw column names, before stripping)
  # ------------------------------------------------------------------
  if (!is.null(filter)) {
    species_data <- apply_filters(species_data, filter)
  }

  # ------------------------------------------------------------------
  # 2d. Optional specimen-level morphological data
  #     Fetched for the species that survived any filtering above, so the
  #     specimen set always matches what ends up in `data`.
  # ------------------------------------------------------------------
  specimen_data <- NULL

  if (resolution == "specimen") {

    surviving_species <- unique(species_data[["species_name"]])

    specimen_data <- get_morph_traits(species   = surviving_species,
                                      taxonomy  = taxonomy,
                                      aggregate = aggregate)

    no_specimens <- setdiff(surviving_species, unique(specimen_data[["species"]]))

    if (length(no_specimens) > 0) {
      warning(sprintf(
        "%d of %d species have no specimen records:\n%s",
        length(no_specimens),
        length(surviving_species),
        paste(sprintf("  - %s", no_specimens), collapse = "\n")
      ), call. = FALSE)
    }

    message(sprintf("Retrieved %d specimen rows.", nrow(specimen_data)))
  }

  # ------------------------------------------------------------------
  # 3.  Source / metadata extraction (unchanged from original)
  # ------------------------------------------------------------------
  src_suffixes <- c("_source", "src")
  src_pattern  <- paste0("(", paste(src_suffixes, collapse = "|"), ")$")
  src_cols     <- species_data[, grep(src_pattern, names(species_data))]

  metadata <- get_metadata(src_cols = src_cols)
  metadata <- unique(metadata)
  sources  <- get_sources(src_cols  = src_cols)

  ## Clean up sources table
  sources <- remove_column_prefixes(sources, prefixes = "trait_src_")
  names(sources)[names(sources) == "id"] <- "source"
  sources <- dplyr::select(sources, -.data$literature_id, -.data$lit_id)

  ## Clean up data table
  species_data <- remove_column_prefixes(species_data, prefixes = prefixes)
  names(species_data)[names(species_data) == "name"] <- "species"

  if (!source_cols) {
    species_data <- remove_suffix_columns(species_data, suffixes = suffixes)
  }

  # ------------------------------------------------------------------
  # 4.  Return
  # ------------------------------------------------------------------
  results <- list(
    metadata_summary = metadata,
    data             = species_data,
    detailed_sources = sources
  )

  ## Only added when requested, so species-level output is unchanged
  if (resolution == "specimen") {
    results$specimen_data <- specimen_data
  }

  message(sprintf(
    "Output contains data from %d sources. Please refer to the metadata for details.",
    nrow(sources)
  ))

  return(results)
}
