# Single source of truth for the specimen aggregations offered by
# get_morph_traits() and, through it, get_traits(resolution = "specimen").
# Maps each user-facing `aggregate` name to the column specimens are grouped
# by, alongside species. NA means "group by species only".
morph_aggregate_columns <- function() {
  c(
    "sex"         = "sex",
    "life stage"  = "life_stage",
    "country"     = "country_wri",
    "source type" = "source_type",
    "all"         = NA_character_
  )
}


# Validates an `aggregate` argument against morph_aggregate_columns(). Called
# by get_traits() before any query runs, so a typo costs nothing, and again by
# get_morph_traits() so the check cannot be bypassed by calling it directly.
validate_aggregate <- function(aggregate) {

  if (is.null(aggregate)) return(invisible(NULL))

  valid <- names(morph_aggregate_columns())

  if (!is.character(aggregate) || length(aggregate) != 1L ||
      !(aggregate %in% valid)) {
    rlang::abort(
      sprintf(
        "`aggregate` must be NULL or one of %s.",
        paste(sprintf('"%s"', valid), collapse = ", ")
      ),
      class = "avonet_error_invalid_aggregate"
    )
  }

  invisible(aggregate)
}


get_morph_traits <- function(species, taxonomy, aggregate = NULL) {

  con <- get_con()

  ## Validate before querying -- an invalid `aggregate` used to surface only
  ## after every specimen row had been fetched and reordered.
  validate_aggregate(aggregate)

  taxonomy <- as.integer(taxonomy)

  if (length(taxonomy) != 1L || is.na(taxonomy)) {
    rlang::abort("`taxonomy` must be a single taxonomy ID.",
                 class = "avonet_error_invalid_taxonomy")
  }

  species <- unique(species)

  ## An empty species vector renders as IN (NULL), which is valid SQL matching
  ## nothing, so the zero-row frame still carries the full column set.
  if (length(species) == 0L) species <- NA_character_

  #### Query ####
  ## One set-based query for the whole species vector. The previous version
  ## bound one parameter set per species, so a family or order cost one full
  ## execution per species (~250 for Accipitridae, ~6,500 for Passeriformes).
  ##
  ## Species identity is taken from the join, not from the bound parameter.
  ## The old query filtered on `source_id IN (sources linked to species X)` and
  ## then stamped every returned row with X via a scalar subquery, which is
  ## only correct while each source_id maps to exactly one species -- an
  ## assumption that was never checked and fails silently, mislabelling rows,
  ## if a source ever covers more than one species.
  sql <- glue_sql(
    "SELECT sp.species_name AS species, mtd.*
       FROM morph_trait_detailed AS mtd
       JOIN source_specimen_species AS sss
         ON sss.source_id = mtd.source_id
       JOIN species AS sp
         ON sp.species_id = sss.species_id
      WHERE sp.species_name IN ({species*})
        AND sp.species_tax = {taxonomy};",
    species  = species,
    taxonomy = taxonomy,
    .con     = con
  )

  result <- DBI::dbGetQuery(con, sql)

  ## Postgres enum columns (sex, life_stage, source_type, ...) come back with an
  ## extra pq_* S3 class -- unwrap to factors, as query_species_traits() does,
  ## so both elements of get_traits() behave the same way downstream.
  result <- convert_enum_columns(result)

  #### Reorder columns as per Joe's email from 26.02.2026####
  ## Selection is name-based rather than positional
  admin_cols <- c("source_id", "measure_date", "measurer_id",
                  "measurer_comment", "lit_id")

  ## Specimen-level identifiers, placed after the measurements
  trailing_cols <- c("specimen_identifier", "avibase_id")

  beak_colnames       <- grep('^beak_|^gape_',             colnames(result), value = TRUE)
  dispersal_colnames  <- grep('^wing_|^kipps_|^secondary', colnames(result), value = TRUE)
  locomotory_colnames <- grep('^tail_|^tarsus_',           colnames(result), value = TRUE)

  measurement_cols <- c(beak_colnames, dispersal_colnames,
                        locomotory_colnames, "back_toe")

  ## intersect() keeps the hardcoded names from erroring if the view ever
  ## stops serving one of them
  measurement_cols <- intersect(measurement_cols, colnames(result))
  trailing_cols    <- intersect(trailing_cols,    colnames(result))

  ## Remaining identifying columns keep their original relative order and lead
  ## the table, with `species` first because the SELECT puts it there.
  id_colnames <- setdiff(colnames(result),
                         c(measurement_cols, admin_cols, trailing_cols))

  result <- result[unique(c(id_colnames, measurement_cols, trailing_cols))]

  ## species_id is no longer selected, but drop it defensively in case the
  ## underlying view starts carrying one of its own.
  result <- result[, names(result) != "species_id", drop = FALSE]

  #### Aggregates ####
  ## Grouping is always by species first, so a multi-species call returns one
  ## row per species (and per grouping level), never a single row pooling
  ## measurements across species.
  if (!is.null(aggregate)) {

    group_col <- unname(morph_aggregate_columns()[[aggregate]])

    grouped <- if (is.na(group_col)) {
      dplyr::group_by(result, .data$species)
    } else {
      dplyr::group_by(result, .data$species,
                      "aggregated_by" = .data[[group_col]])
    }

    result <- dplyr::summarize(
      grouped,
      dplyr::across(
        dplyr::where(is.numeric) & !dplyr::ends_with("_id"),
        list(mean = ~ mean(.x, na.rm = TRUE),
             n    = ~ sum(!is.na(.x)))
      ),
      .groups = "drop"
    )
  }

  return(result)
}
