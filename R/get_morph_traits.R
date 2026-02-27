get_morph_traits <- function(con, species, taxonomy, aggregate = NULL) {

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
  first_columns <- colnames(result)[1:7]
  beak_colnames <- colnames(result)[grepl('^beak_|^gape_', colnames(result))]
  dispersal_colnames <- colnames(result)[grepl('^wing_|^kipps_|^secondary', colnames(result))]
  locomotory_colnames <- colnames(result)[grepl('^tail_|^tarsus_', colnames(result))]
  #back_toe
  last_columns <- colnames(result)[23:27]

  new_column_order <- c(first_columns, beak_colnames, dispersal_colnames,
                        locomotory_colnames, "back_toe", last_columns)

  result[new_column_order]

  #### Agreggates ####

  aggregates <- c("sex", "life stage", "country", "source type", "all")

  if(is.null(aggregate)) {
    result <- result
  }
  else if(!is.null(aggregate) && aggregate %in% aggregates) {
    if(aggregate == "sex") {
      result %>%
        group_by("aggregated_by" = sd_sex) %>%
        summarize(across(where(is.numeric) & !ends_with("_id"),
                         list(mean = ~ mean(., na.rm = T), n = ~ sum(!is.na(.))))) -> result
    }
    else if(aggregate == "life stage") {
      result %>%
        group_by("aggregated_by" = sd_life_stage) %>%
        summarize(across(where(is.numeric) & !ends_with("_id"),
                         list(mean = ~ mean(., na.rm = T), n = ~ sum(!is.na(.))))) -> result
    }
    else if(aggregate == "country") {
      result %>%
        group_by("aggregated_by" = sd_country_wri) %>%
        summarize(across(where(is.numeric) & !ends_with("_id"),
                         list(mean = ~ mean(., na.rm = T), n = ~ sum(!is.na(.))))) -> result
    }
    else if(aggregate == "source type") {
      result %>%
        group_by("aggregated_by" = source_type) %>%
        summarize(across(where(is.numeric) & !ends_with("_id"),
                         list(mean = ~ mean(., na.rm = T), n = ~ sum(!is.na(.))))) -> result
    }
    else if(aggregate == "all") {
      result %>%
        summarize(across(where(is.numeric) & !ends_with("_id"),
                         list(mean = ~ mean(., na.rm = T), n = ~ sum(!is.na(.))))) -> result
    }
  } else stop("Invalid input for aggregate.")

  result <- cbind(species, result)

  return(result)
}
