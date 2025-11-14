get_sources <- function(src_cols){

  vals <- unique(as.vector(as.matrix(src_cols)))

  sql_sources <- glue_sql("
         SELECT *
         FROM trait_source_detailed as tsd
         WHERE tsd.trait_src_id in ($1)",
                           .con = con)
  source_query <- DBI::dbSendQuery(con, sql_sources)
  DBI::dbBind(source_query, list(vals))
  source_output <- DBI::dbFetch(source_query)

  return(source_output)
}
