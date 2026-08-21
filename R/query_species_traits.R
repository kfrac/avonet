#' Query species-level traits from the AVONET database
#'
#' Internal workhorse behind [get_species()] and [get_traits()]. Pulls one row
#' per species from the species-level side of the database, joining the
#' taxonomic backbone to the ecological, mass and geographic traits (with more
#' to potentially follow later).
#'
#' @details
#' The query left-joins four tables on `species_id`, so a species present in
#' `species` but absent from a trait table still returns a row, with `NA` in
#' that table's columns:
#'
#' * `species` — taxonomic backbone (name, family, order, taxonomy version)
#' * `eco` — habitat, migration, trophic and lifestyle traits
#' * `mass` — body mass and its quality flag
#' * `geodata` — latitudinal extent, centroid and range size
#'
#' Every trait column is accompanied by its `_src` / `_trait_src` source
#' column, which downstream callers hand to [get_metadata()].
#'
#' `species` and `taxonomy` are recycled against each other so users can
#' pass a vector of species with a single taxonomy (the common case),
#' or pair each species with its own taxonomy. Values are never interpolated
#' into the SQL text: they are bound as query parameters via [DBI::dbBind()],
#' which lets a whole vector of species be fetched in one batched call rather
#' than one round trip per name.
#'
#' Postgres enum columns arrive from `RPostgres` wrapped in an extra `pq_*` S3
#' class. These are unwrapped and converted to plain factors before returning,
#' so downstream `dplyr` verbs and `table()` behave as expected.
#'
#' @param species Character vector of species binomials, e.g. `"Buteo buteo"`.
#' @param taxonomy Integer vector of taxonomy versions: `1` = BirdLife,
#'   `2` = eBird, `3` = BirdTree. Recycled to the length of `species`.
#'
#' @return A data frame with one row per matched species and one column per
#'   queried field: `species_id`, `species_name`, `species_family`,
#'   `species_order`, `species_tax`, followed by the `eco_*`, `mass_*` and
#'   `geo_*` trait columns and their paired source columns. Species with no
#'   match in `species` for the given taxonomy are silently absent — callers
#'   are responsible for reporting them.
#' @keywords internal
#'
#' @seealso [get_species()] and [get_traits()], the exported wrappers;
#'   [get_metadata()] for resolving the returned source columns.
#'
#' @examples
#' \dontrun{
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#' connect_db(username = db_user, pw = db_password)
#'
#' # A single species
#' avonet:::query_species_traits(species = "Buteo buteo", taxonomy = 1)
#'
#' # Several species, one taxonomy version (recycled)
#' avonet:::query_species_traits(
#'   species  = c("Aquila chrysaetos", "Cardinalis cardinalis"),
#'   taxonomy = 1
#' )
#' }
query_species_traits <- function(species, taxonomy) {

  con <- get_con()

  ## Static statement -- species/taxonomy are bound as parameters below, never
  ## pasted into the text
  sql <- glue::glue_sql("
  SELECT
    sp.species_id,
    sp.species_name,
    sp.species_family,
    sp.species_order,
    sp.species_tax,
    ect.ect_habitat,
    ect.ect_habitat_src,
    ect.ect_habitat_density,
    ect.ect_habitat_density_src,
    ect.ect_migration,
    ect.ect_migration_src,
    ect.ect_trophic_level,
    ect.ect_trophic_level_src,
    ect.ect_trophic_niche,
    ect.ect_trophic_niche_src,
    ect.ect_primary_lifestyle,
    ect.ect_primary_lifestyle_src,
    ms.mass_value,
    ms.mass_trait_src,
    ms.mass_flag,
    gds.spd_min_latitude,
    gds.spd_max_latitude,
    gds.spd_centroid_lat,
    gds.spd_centroid_lon,
    gds.spd_range_size,
    gds.spd_spatial_source
  FROM
    species as sp
    left join eco_trait_species as ect on ect.species_id = sp.species_id
    left join mass_species      as ms  on ms.species_id  = sp.species_id
    left join geo_data_species  as gds on gds.species_id = sp.species_id
  WHERE
    sp.species_name = $1
  AND
    sp.species_tax = $2;", .con = con)

  ## Recycle the shorter argument so dbBind() receives two vectors of equal
  ## length -- typically many species against a single taxonomy version.
  if (length(species) > length(taxonomy)) {
    taxonomy <- rep(taxonomy, length(species))
  } else if (length(taxonomy) > length(species)) {
    species <- rep(species, length(taxonomy))
  }

  query <- DBI::dbSendQuery(con, sql)
  DBI::dbBind(query, list(species, taxonomy))
  result <- DBI::dbFetch(query)

  DBI::dbClearResult(query)

  ## Postgres enum columns come with an extra pq_* S3 class wrapping the
  ## underlying character vector -- convert those to plain factors
  enum_cols <- vapply(result, function(x) any(grepl("^pq_", class(x))), logical(1))
  result[enum_cols] <- lapply(result[enum_cols], function(x) factor(unclass(x)))

  return(result)
}
