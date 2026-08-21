#' Retrieve metadata for an AVONET query
#'
#' @param src_cols Source columns (a dataframe of `_src` / `_source` columns).
#'
#' @returns A dataframe with columns \code{trait}, \code{description},
#' \code{primary_source} and \code{source}, which references the trait_source_id
#' column in the AVONET database table trait_source_detailed.
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#' connect_db(username = db_user, pw = db_password)
#'
#' species_data <- sql_query(parameter1 = "Buteo buteo", parameter2 = 1)
#'
#' src_pattern  <- "(_source|src)$"
#' src_cols     <- species_data[, grep(src_pattern, names(species_data))]
#'
#' metadata <- avonet:::get_metadata(src_cols = src_cols)
#'
#' metadata
#' }
get_metadata <- function(src_cols) {

  prefixes <- c("ect_", "spd_", "geo_", "species_")
  suffixes <- c("_trait_src", "_src")
  pattern  <- paste0("(", paste(suffixes, collapse = "|"), ")$")

  src_cols        <- remove_column_prefixes(src_cols, prefixes = prefixes)
  names(src_cols) <- sub(pattern, "", names(src_cols))

  metadata <- arrange_metadata(src_cols, names(src_cols))

  # --- Source lookup from trait_source_detailed ---
  # metadata$source holds trait_src_id values (one per row, from
  # arrange_metadata). Look each up in trait_source_detailed to get the
  # human-readable source_description and the lit_abbrev for primary_source.
  con <- get_con()

  src_query <- DBI::dbSendQuery(con, "SELECT trait_src_id, lit_abbrev FROM trait_source_detailed")
  src_lookup <- DBI::dbFetch(src_query)
  DBI::dbClearResult(src_query)

  metadata <- dplyr::left_join(
    metadata,
    src_lookup,
    by = c("source" = "trait_src_id")
  )

  # If source_comment is desired, "trait_src_description" needs to be readded
  # to SELECT statement in SQL
  #names(metadata)[names(metadata) == "trait_src_description"] <- "source_comment"
  names(metadata)[names(metadata) == "lit_abbrev"] <- "primary_source"

  # --- short_description from DB metadata ---
  trait_descriptions <- get_trait_values()
  trait_descriptions <- trait_descriptions[, c("trait_name", "trait_description")]
  trait_descriptions <- trait_descriptions[!duplicated(trait_descriptions),]
  names(trait_descriptions)[names(trait_descriptions) == "trait_name"] <- "trait"
  names(trait_descriptions)[names(trait_descriptions) == "trait_description"] <- "description"

  metadata <- dplyr::left_join(metadata, trait_descriptions, by = "trait")

  metadata_output <- metadata[, c("trait", "description", "primary_source", "source")]

  return(metadata_output)

}

