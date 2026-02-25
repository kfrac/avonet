get_taxonomic_info <- function(con, search_term, taxonomy) {
  query <- paste("
  SELECT *,
    CASE
      WHEN species_name ILIKE $1 THEN 'genus'
      WHEN species_family ILIKE $2 THEN 'family'
      WHEN species_order ILIKE $3 THEN 'order'
    END AS match_type
  FROM species as sp
  WHERE (
    sp.species_name ILIKE $1
    OR
    sp.species_family ILIKE $2
    OR
    sp.species_order ILIKE $3
    )
  AND
  sp.species_tax = $4;
  ")

  genus_pattern <- paste0(search_term, " %")

  result <- DBI::dbGetQuery(con, query, params = list(genus_pattern, search_term, search_term, taxonomy))

  result <- result[c("species_name", "species_family", "species_order", "match_type")]

  return(result)
}
