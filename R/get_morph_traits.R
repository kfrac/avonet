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
