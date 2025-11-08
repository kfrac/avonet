get_eco_traits <- function(con, trait, value, taxonomy = 1){

  prefix <- "ect_"

  eco_traits <- c("habitat", "habitat_density", "migration",
                  "trophic_level", "trophic_niche", "primary_lifestyle")

  if (!trait %in% eco_traits) {
    stop("Invalid input for trait.")
  } else{
    var <- paste0(prefix, trait)
  }

  tbl1 <- "species"
  tbl2 <- "eco_trait_species"

  sql <- glue_sql("
    SELECT *
    FROM {`tbl1`}, {`tbl2`}
    WHERE {`tbl1`}.species_id = {`tbl2`}.species_id
    AND {`tbl2`}.{`var`} = $1
    AND {`tbl1`}.species_tax = $2
  ", .con = con)

  query <- DBI::dbSendQuery(con, sql)
  DBI::dbBind(query, list(value, taxonomy))
  res <- DBI::dbFetch(query)

  DBI::dbClearResult(query)

  return(res)
}
