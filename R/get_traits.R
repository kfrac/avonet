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
#' forces one interpretation for all of them. A resolved species with no trait
#' data comes back as an all-`NA` row rather than disappearing, and is named in
#' a warning.
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
#' Species-level and specimen-level conditions can be mixed in one list, with
#' nothing to declare: each name is matched against the species-level columns
#' first and the specimen-level ones second.
#'
#' ```
#' filter = list(habitat = "Forest", beak_width = list(op = ">", val = 20))
#' ```
#'
#' They are applied in that order, which keeps the work down -- specimens are
#' fetched only for the species that passed the species-level conditions. A
#' specimen-level condition then narrows both elements of the result:
#' `specimen_data` keeps only the matching specimens, and `data` keeps only
#' the species that still have at least one. So the example above means
#' "forest species, and of those only the individuals with a wide gape",
#' rather than "forest species, plus all of their specimens".
#'
#' A specimen-level condition with `resolution = "species"` is an error rather
#' than a silent no-op, there being no specimens to apply it to. `aggregate`
#' runs after both, so per-species means summarize the specimens that
#' survived.
#'
#' ## Resolution
#'
#' Morphological measurements are specimen-level, taken from
#' individual birds, so there are many rows per species. They are also the part
#' of AVONET that cannot be had from a species checklist elsewhere, which is
#' why `resolution = "specimen"` is the default. The ecological, mass and
#' geographical traits are species-level: one row per species.
#'
#' Rather than joining the two and repeating every species-level value across
#' each specimen, the measurements come back as a separate `specimen_data`
#' element, so `data` stays one row per species either way. Specimens are
#' fetched only for the species that survive `filter`, and species with no
#' specimen records trigger a warning. Pass `resolution = "species"` to skip
#' the specimen query when only the species-level traits are wanted.
#'
#' Every species is fetched in a single query, and each specimen row carries
#' the species it is linked to in the database rather than one inferred from
#' the call, so a multi-species request returns correctly labelled rows.
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
#' @param filter Named list or `NULL`. Post-query filters, at either
#'   resolution and mixable in one list; see Details.
#' @param resolution Character(1). `"specimen"` (default) returns the raw
#'    specimen-level morphological measurements as a fourth list element.
#'    `"species"` returns the species-level data only and omits the specimen query.
#' @param aggregate Character(1) or `NULL`. Used only when
#'   `resolution = "specimen"`. One of `"sex"`, `"life stage"`, `"country"`,
#'   `"source type"` or `"all"`, collapsing specimen measurements into per
#'   species mean and count columns for that grouping, so a multi-species call
#'   never pools measurements across species. `NULL` (default) returns one row
#'   per specimen. Supplying it with `resolution = "species"` warns and is
#'   ignored.
#' @param inferred Logical. Reserved for traits inferred for species created by
#'   taxonomic splits and merges. Not implemented yet: any value other than
#'   `FALSE` (the default) raises `avonet_error_not_implemented`.
#'
#' @return A named list of four elements, or three when
#'   `resolution = "species"`:
#'   \describe{
#'     \item{`metadata_summary`}{Data frame of the queried traits with their
#'       description, primary source and source ID. A trait's source can
#'       differ between species, so a trait appears once per distinct source
#'       rather than exactly once.}
#'     \item{`data`}{Data frame of trait values, one row per species.}
#'     \item{`detailed_sources`}{Data frame of the full literature references
#'       behind the source IDs cited in `metadata_summary`.}
#'     \item{`specimen_data`}{Present unless `resolution = "species"`. Data
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
#' # Mix a species-level and a specimen-level condition
#' wide_gape <- get_traits(species = "Accipitridae", taxonomy = 1,
#'                         filter = list(habitat    = "Forest",
#'                                       beak_width = list(op = ">", val = 20)))
#' nrow(wide_gape$data)            # forest species with a wide-gaped specimen
#' nrow(wide_gape$specimen_data)   # only those specimens
#'
#' # Filter on a categorical trait and a numeric range
#' forest <- get_traits(species = "Accipitridae", taxonomy = 1,
#'                      filter = list(habitat    = "Forest",
#'                                    range_size = list(op = "<", val = 1000)))
#'
#' # Specimen-level measurements come back by default, one row per specimen
#' specimens <- get_traits(species = "Accipitridae", taxonomy = 1)
#' specimens$specimen_data
#'
#' # Several species at once -- every row labelled with its own species
#' raptors <- get_traits(species = c("Buteo buteo", "Falco peregrinus"),
#'                       taxonomy = 1)
#' table(raptors$specimen_data$species)
#'
#' # The same measurements, aggregated to per species means by sex
#' by_sex <- get_traits(species = "Accipitridae", taxonomy = 1,
#'                      aggregate = "sex")
#'
#' # Species-level traits only, skipping the specimen query
#' quick <- get_traits(species = "Accipitridae", taxonomy = 1,
#'                     resolution = "species")
#'
#' disconnect_db()
#' }
get_traits <- function(species,
                       taxonomy,
                       source_cols = FALSE,
                       rank        = NULL,
                       filter      = NULL,
                       resolution  = c("specimen", "species"),
                       aggregate   = NULL,
                       inferred    = FALSE) {

  resolution <- match.arg(resolution)

  ## Reserved for a database feature that does not exist yet; kept as an
  ## argument so the signature does not change when it lands.
  if (!isFALSE(inferred)) {
    rlang::abort(
      "Inferred traits are not implemented yet. Please set `inferred = FALSE`.",
      class = "avonet_error_not_implemented"
    )
  }

  ## Validated here, before the species-level query, so a typo in `aggregate`
  ## does not cost a full fetch before erroring.
  validate_aggregate(aggregate)

  if (!is.null(aggregate) && resolution == "species") {
    warning("`aggregate` is ignored when resolution = \"species\".",
            call. = FALSE)
  }

  ## Say up front when the answer will come from the bundled example data,
  ## and otherwise fail fast on a missing connection before any other work.
  notify_example_data()
  if (!using_example_data()) get_con()

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
  # 2.  Single batched call to query_species_traits()
  #     query_species_traits() already handles vectors via dbBind, so we
  #     pass the full species vector directly rather than looping.
  # ------------------------------------------------------------------
  species_data <- query_species_traits(
    species  = resolved_species,
    taxonomy = taxonomy   # recycled inside query_species_traits()
  )


  # ------------------------------------------------------------------
  # 2b. Warn about resolved species that carry no trait data at all
  #     query_species_traits() LEFT joins outward from `species`, and
  #     resolve_taxa() draws its names from that same table with the same
  #     taxonomy filter, so every resolved species always comes back as a
  #     row. A species with nothing recorded against it is therefore an
  #     all-NA row rather than a missing one, which is what this checks --
  #     from data already in hand, with no extra queries.
  # ------------------------------------------------------------------
  trait_cols <- grep("^(ect_|mass_|spd_)", names(species_data), value = TRUE)
  trait_cols <- grep("(_src|_source)$", trait_cols, value = TRUE, invert = TRUE)

  if (length(trait_cols) > 0) {

    has_traits    <- rowSums(!is.na(species_data[trait_cols])) > 0
    empty_species <- species_data[["species_name"]][!has_traits]

    if (length(empty_species) > 0) {
      warning(sprintf(
        paste0(
          "%d of %d resolved species have no ecological, mass or ",
          "geographical trait data:\n%s"
        ),
        length(empty_species),
        length(resolved_species),
        paste(sprintf("  - %s", empty_species), collapse = "\n")
      ), call. = FALSE)
    }
  }

  # ------------------------------------------------------------------
  # 2c. Split the filters by resolution, then apply the species-level half
  #     A name is species-level if it addresses a column of the species frame;
  #     anything else is held back for the specimen frame, which does not
  #     exist yet. Species-level filters run first so that specimens are
  #     fetched only for the species that survive them.
  # ------------------------------------------------------------------
  specimen_filter <- NULL

  if (!is.null(filter)) {

    is_species_level <- vapply(
      names(filter),
      function(nm) filter_matches_frame(nm, species_data),
      logical(1)
    )

    species_filter  <- filter[is_species_level]
    specimen_filter <- filter[!is_species_level]

    if (length(specimen_filter) > 0 && resolution != "specimen") {
      rlang::abort(
        sprintf(
          paste0(
            "Filter(s) %s are not species-level columns. If they are ",
            "specimen measurements, drop `resolution = \"species\"` so the ",
            "specimens are fetched; otherwise check the spelling against ",
            "get_trait_list()."
          ),
          paste(sprintf("'%s'", names(specimen_filter)), collapse = ", ")
        ),
        class = "avonet_error_specimen_filter_resolution"
      )
    }

    if (length(species_filter) > 0) {
      species_data <- apply_filters(species_data, species_filter,
                                    what = "species")
    }
  }

  # ------------------------------------------------------------------
  # 2d. Optional specimen-level morphological data
  #     Fetched for the species that survived any filtering above, so the
  #     specimen set always matches what ends up in `data`.
  # ------------------------------------------------------------------
  specimen_data <- NULL

  if (resolution == "specimen") {

    surviving_species <- unique(species_data[["species_name"]])

    specimen_data <- get_morph_traits(species  = surviving_species,
                                      taxonomy = taxonomy)

    ## Reported before any specimen-level filter runs, so that "no records"
    ## keeps meaning "none in the database" rather than "none that matched".
    no_specimens <- setdiff(surviving_species, unique(specimen_data[["species"]]))

    if (length(no_specimens) > 0) {
      warning(sprintf(
        "%d of %d species have no specimen records:\n%s",
        length(no_specimens),
        length(surviving_species),
        paste(sprintf("  - %s", no_specimens), collapse = "\n")
      ), call. = FALSE)
    }

    if (length(specimen_filter) > 0) {

      ## Names that matched neither frame are reported once, against both, so
      ## a typo is not blamed on the resolution it happened to fall through to.
      unknown <- names(specimen_filter)[
        !vapply(names(specimen_filter),
                function(nm) filter_matches_frame(nm, specimen_data),
                logical(1))
      ]

      if (length(unknown) > 0) {
        rlang::abort(
          sprintf(
            paste0(
              "Filter column(s) %s match neither resolution.\n",
              "Species-level columns:  %s\n",
              "Specimen-level columns: %s"
            ),
            paste(sprintf("'%s'", unknown), collapse = ", "),
            paste(names(filterable_columns(species_data)),  collapse = ", "),
            paste(names(filterable_columns(specimen_data)), collapse = ", ")
          ),
          class = "avonet_error_unknown_filter"
        )
      }

      specimen_data <- apply_filters(specimen_data, specimen_filter,
                                     what = "specimens")

      ## A specimen-level filter narrows the species too: a species none of
      ## whose specimens matched is no longer part of the answer, so `data`
      ## and `specimen_data` continue to describe the same set of species.
      kept <- species_data[["species_name"]] %in% unique(specimen_data[["species"]])

      if (any(!kept)) {
        message(sprintf(
          "Specimen filter left %d of %d species with no matching specimens.",
          sum(!kept), length(kept)
        ))
      }

      species_data <- species_data[kept, , drop = FALSE]
    }

    ## Aggregation comes last, so it summarizes the specimens that survived.
    specimen_data <- aggregate_specimens(specimen_data, aggregate)

    message(sprintf("Retrieved %d specimen rows.", nrow(specimen_data)))
  }

  # ------------------------------------------------------------------
  # 3.  Source / metadata extraction (unchanged from original)
  # ------------------------------------------------------------------
  src_suffixes <- c("_source", "src")
  src_pattern  <- paste0("(", paste(src_suffixes, collapse = "|"), ")$")
  src_cols     <- species_data[, grep(src_pattern, names(species_data))]

  ## get_metadata() reads the trait columns as well as their source columns,
  ## so it takes the whole frame; get_sources() needs only the source columns.
  metadata <- get_metadata(species_data)
  sources  <- get_sources(src_cols  = src_cols)

  ## Clean up sources table
  sources <- remove_column_prefixes(sources, prefixes = "trait_src_")
  names(sources)[names(sources) == "id"] <- "source"
  sources <- dplyr::select(sources, -"literature_id", -"lit_id")

  ## Clean up data table -- see tidy_species_columns() for the column contract
  species_data <- tidy_species_columns(species_data, source_cols = source_cols)

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
