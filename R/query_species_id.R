query_species_id <- function(con, rank, name, taxonomy = 1){

  tbl <- "species"

  if (rank == "species") {
    sql <- glue_sql("
    SELECT species_id
    FROM {`tbl`}
    WHERE {`tbl`}.species_name = $1
    AND {`tbl`}.species_tax = $2
  ", .con = con)
  } else if (rank == "family") { #need to rework bc families in tax2 have subgroups in ()
    sql <- glue_sql("
    SELECT species_id
    FROM {`tbl`}
    WHERE {`tbl`}.species_family = $1
    AND {`tbl`}.species_tax = $2
  ", .con = con)
  } else if (rank == "order") {
    sql <- glue_sql("
    SELECT species_id
    FROM {`tbl`}
    WHERE {`tbl`}.species_order = $1
    AND {`tbl`}.species_tax = $2
  ", .con = con)
  }

  query <- DBI::dbSendQuery(con, sql)
  DBI::dbBind(query, list(name, taxonomy))
  species_id <- DBI::dbFetch(query)
  species_id <- species_id[,1]

  return(species_id)

}
