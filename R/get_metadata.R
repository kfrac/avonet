#' Retrieve metadata for an AVONET query
#'
#' @param src_cols Source columns
#'
#' @returns A dataframe
#' @export
#'
#' @examples
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#' con <- connect_db(username = db_user, pw = db_password)
#'
#' species_data <- sql_query(con = con, parameter1 = "Buteo buteo", parameter2 = 1)
#'
#' src_pattern  <- "(_source|src)$"
#' src_cols     <- species_data[, grep(src_pattern, names(species_data))]
#'
#' metadata <- get_metadata(src_cols = src_cols)
#'
#' metadata
get_metadata <- function(src_cols){

  prefixes <- c("ect_", "spd_", "geo_", "species_")
  suffixes <- c("_trait_src", "_src")
  pattern <- paste0("(", paste(suffixes, collapse = "|"), ")$")

  src_cols <- remove_column_prefixes(src_cols, prefixes = prefixes)
  names(src_cols) <- sub(pattern, "", names(src_cols))

  metadata_output <- arrange_metadata(src_cols, names(src_cols))

  #### Temp fix from Excel sheet and list_traits ####
  trait_sheet <- readxl::read_xlsx("C:/Users/kfrac/Downloads/AVONET_Traits_MS_SF_KF_JAT.xlsx")
  trait_sheet <- trait_sheet[c("trait_name_R", "short_description_R", "primary_source_R")]
  trait_sheet <- trait_sheet[stats::complete.cases(trait_sheet),]

  ## Join to metadata output
  metadata_output <- dplyr::left_join(metadata_output, trait_sheet, by = dplyr::join_by("trait" == "trait_name_R"))

  ## Rename columns
  names(metadata_output)[names(metadata_output) == "short_description_R"] <- "description"
  names(metadata_output)[names(metadata_output) == "primary_source_R"] <- "primary_source"
  #### END ####

  return(metadata_output)

}
