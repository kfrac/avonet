trait_description_query <- function() {
  query <- paste(
  "SELECT
  cls.relname AS table_name,
  att.attname AS column_name,
  typ.typname AS data_type,
  des.description AS data_type_comment,
  col_des.description AS column_comment,
  CASE
    WHEN typ.typtype IN ('e','d','c') THEN 'user-defined'
    ELSE 'built-in'
  END AS type_origin
  FROM
  pg_class AS cls
  JOIN pg_namespace AS ns ON ns.oid = cls.relnamespace
  JOIN pg_attribute AS att ON att.attrelid = cls.oid
  JOIN pg_type AS typ ON typ.oid = att.atttypid
  LEFT JOIN pg_description AS des ON des.objoid = typ.oid AND des.classoid = 'pg_type'::regclass
  LEFT JOIN pg_description AS col_des
  ON col_des.objoid = att.attrelid
  AND col_des.objsubid = att.attnum
  AND col_des.classoid = 'pg_class'::regclass
  WHERE
  cls.relkind = 'r'
  AND att.attnum > 0
  --AND ns.nspname NOT IN ('pg_catalog', 'information_schema')
  AND cls.relname IN ('eco_trait_species', 'geo_data_species', 'reproduction_trait_species', 'social_trait_species')
  AND att.attname NOT LIKE '%\\_id%' ESCAPE '\\'
  AND att.attname NOT LIKE '%\\_src%' ESCAPE '\\'
  AND att.attname NOT LIKE '%\\_source%' ESCAPE '\\'
  ORDER BY
  cls.relname, att.attnum;")

  query <- DBI::dbSendQuery(con, query)
  result <- DBI::dbFetch(query)
  DBI::dbClearResult(query)

  # Use data_type_comment if it contains "[Long]",
  # otherwise use column_comment
  source_text <- ifelse(
    grepl("\\[LONG\\]", result$data_type_comment),
    result$data_type_comment,
    result$column_comment
  )
  # Remove trailing newline(s) at end of string
  source_text <- sub("\n+$", "", source_text)
  # Replace the last newline character in each string with a space
  source_text <- sub("\n([^\n]*)$", " \\1", source_text)
  # Split into Long / Short columns
  # "\\s*" allows for zero or more spaces after "[Short]:"
  parts <- strsplit(source_text, " \\[SHORT\\]:\\s*")
  # Create new columns
  result[c("long_description", "short_description")] <- do.call(
    rbind,
    lapply(parts, function(x) {
      c(
        # Remove "[Long]:" plus any optional whitespace after it
        sub("^\\[LONG\\]:\\s*", "", x[1]),
        x[2]
      )
    })
  )

  result <- remove_prefixes(result, prefixes = c("ect", "spd", "rts", "sts"))
  names(result)[names(result) == 'column_name'] <- 'trait'

  result <- result[,c("trait", "short_description", "long_description")]

  return(result)
}
# Alternative method for using SQL file directly in R
# file <- "C:/Users/kfrac/Senckenberg Dropbox/Kevin Frac/AVONET_DB/Result Queries/Query_traits_types_meta_data.sql"
# df <- dbGetQuery(con, statement = readr::read_file(file))
# df
