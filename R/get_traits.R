# -----------------------------------------------------------------------------
# get_traits()  (refactored)
# -----------------------------------------------------------------------------
# Retrieve trait data for one or more taxonomic names at any rank.
#
# Arguments (changes vs. original):
#   species  - now accepts a *vector* of names at any taxonomic rank,
#              e.g. c("Buteo", "Falco peregrinus", "Accipitridae")
#   taxonomy - integer(1): taxonomy ID passed as species_tax to the DB
#              (unchanged from original)
#   rank     - character(1) or NULL: force a specific rank for all names in
#              `species`; leave NULL to auto-detect per name (recommended)
#   filter   - named list or NULL: optional post-query filters. Each element
#              name can be a short name (suffix after the table prefix) or the
#              full SQL column name -- both are accepted.
#
#              Exact / set match (character columns):
#                filter = list(habitat = "Forest")
#                filter = list(trophic_niche = c("Frugivore", "Nectarivore"))
#
#              Numeric comparison:
#                filter = list(min_latitude = list(op = ">",  val = 40))
#                filter = list(range_size   = list(op = "<",  val = 1000))
#
#              Multiple conditions (AND logic):
#                filter = list(
#                  habitat    = "Forest",
#                  range_size = list(op = "<", val = 1000)
#                )
#
# All other arguments (source_cols) are unchanged.
# -----------------------------------------------------------------------------
get_traits <- function(species,
                       taxonomy,
                       source_cols = FALSE,
                       rank        = NULL,
                       filter      = NULL) {

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

  message(sprintf(
    "Output contains data from %d sources. Please refer to the metadata for details.",
    nrow(sources)
  ))

  return(results)
}
