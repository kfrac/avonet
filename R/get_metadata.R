get_metadata <- function(species_data){
  species_data %>%
    select(ends_with("_src")) -> source_cols

  vals <- unique(as.vector(as.matrix(source_cols)))

  sql_metadata <- glue_sql("
         SELECT *
         FROM trait_source_detailed as tsd
         WHERE tsd.trait_src_id in ($1)",
                           .con = con)
  metadata_query <- DBI::dbSendQuery(con, sql_metadata)
  DBI::dbBind(metadata_query, list(vals))
  metadata_output <- DBI::dbFetch(metadata_query)

  return(metadata_output)
}
