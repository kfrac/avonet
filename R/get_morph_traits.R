get_morph_traits <- function(species, taxonomy, aggregate = NULL) {

  con <- get_con()

  sql <- c("select
mtd.*,
(SELECT species_id FROM species WHERE species_name = $1 and species_tax = $2) AS species_id
from
morph_trait_detailed as mtd
where
mtd.source_id in (select sss.source_id
                  from
                  source_specimen_species as sss,
                  species as sp
                  where
                  sp.species_name = $1 and sp.species_tax = $2
                  and
                  sss.species_id = sp.species_id);")

  if(length(species) > length(taxonomy)){
    taxonomy <- rep(taxonomy, length(species))
  } else if(length(taxonomy) > length(species)){
    species <- rep(species, length(taxonomy))
  }

  query <- DBI::dbSendQuery(con, sql)
  DBI::dbBind(query, list(species, taxonomy))
  result <- DBI::dbFetch(query)

  DBI::dbClearResult(query)

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

  ## Remaining identifying columns keep their original relative order and lead
  ## the table. species_id trails them until the name lookup below consumes it.
  id_colnames <- setdiff(colnames(result),
                         c(measurement_cols, admin_cols, trailing_cols))

  result <- result[unique(c(id_colnames, measurement_cols, trailing_cols))]

  #### Attach species names ####
  ## Species identity travels with the species_id attached by the SQL subquery
  ## above (one value per bound parameter set), so look the names up from it.
  ## Do NOT cbind() the input `species` vector on: it has one element per
  ## species while `result` has one row per specimen, so cbind() either errors
  ## or silently recycles names onto the wrong rows once length(species) > 1.
  if (nrow(result) > 0) {
    id_map <- DBI::dbGetQuery(con, glue::glue_sql(
      "SELECT species_id, species_name AS species
       FROM species
       WHERE species_id IN ({ids*});",
      ids = unique(result$species_id), .con = con
    ))
    result <- dplyr::left_join(result, id_map, by = "species_id")
    result <- result[c("species", setdiff(names(result), "species"))]
  }

  #### Drop the species_id key ####
  ## Retained through the reorder above only as the join key for the name
  ## lookup; the human-readable `species` column replaces it in the output.
  result <- result[, names(result) != "species_id", drop = FALSE]

  #### Agreggates ####

  aggregates <- c("sex", "life stage", "country", "source type", "all")

  if(is.null(aggregate)) {
    result <- result
  }
  else if(!is.null(aggregate) && aggregate %in% aggregates) {
    if(aggregate == "sex") {
      result |>
        dplyr::group_by(.data$species, "aggregated_by" = .data$sex) |>
        dplyr::summarize(dplyr::across(dplyr::where(is.numeric) & !dplyr::ends_with("_id"),
                         list(mean = ~ mean(., na.rm = T), n = ~ sum(!is.na(.))))) -> result
    }
    else if(aggregate == "life stage") {
      result |>
        dplyr::group_by(.data$species, "aggregated_by" = .data$life_stage) |>
        dplyr::summarize(dplyr::across(dplyr::where(is.numeric) & !dplyr::ends_with("_id"),
                         list(mean = ~ mean(., na.rm = T), n = ~ sum(!is.na(.))))) -> result
    }
    else if(aggregate == "country") {
      result |>
        dplyr::group_by(.data$species, "aggregated_by" = .data$country_wri) |>
        dplyr::summarize(dplyr::across(dplyr::where(is.numeric) & !dplyr::ends_with("_id"),
                         list(mean = ~ mean(., na.rm = T), n = ~ sum(!is.na(.))))) -> result
    }
    else if(aggregate == "source type") {
      result |>
        dplyr::group_by(.data$species, "aggregated_by" = .data$source_type) |>
        dplyr::summarize(dplyr::across(dplyr::where(is.numeric) & !dplyr::ends_with("_id"),
                         list(mean = ~ mean(., na.rm = T), n = ~ sum(!is.na(.))))) -> result
    }
    else if(aggregate == "all") {
      result |>
        dplyr::group_by(.data$species) |>
        dplyr::summarize(dplyr::across(dplyr::where(is.numeric) & !dplyr::ends_with("_id"),
                         list(mean = ~ mean(., na.rm = T), n = ~ sum(!is.na(.))))) -> result
    }
  } else stop("Invalid input for aggregate.")

  return(result)
}
