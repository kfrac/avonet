get_sources <- function(src_cols){

  vals <- unique(as.vector(as.matrix(src_cols)))

  if (using_example_data()) {

    sources <- db_table("trait_source_detailed")

    ## NA is "unknown source", never something to match on -- the same rule
    ## the SQL path gets for free, since NULL never matches NULL.
    keep <- !is.na(sources$trait_src_id) &
            as.character(sources$trait_src_id) %in% as.character(stats::na.omit(vals))

    result <- sources[keep, , drop = FALSE]
    rownames(result) <- NULL

    return(convert_enum_columns(result))
  }

  con <- get_con()

  sql_sources <- glue_sql("
         SELECT *
         FROM trait_source_detailed as tsd
         WHERE tsd.trait_src_id in ($1)",
                           .con = con)
  source_query <- DBI::dbSendQuery(con, sql_sources)
  DBI::dbBind(source_query, list(vals))
  source_output <- DBI::dbFetch(source_query)

  DBI::dbClearResult(source_query)

  ## Postgres enum columns (trait_src type, lit_type) carry an extra pq_* S3
  ## class -- unwrap to factors so `detailed_sources` matches the other
  ## elements of get_traits().
  source_output <- convert_enum_columns(source_output)

  return(source_output)
}
