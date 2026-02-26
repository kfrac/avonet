get_metadata <- function(src_cols){

  prefixes <- c("ect_", "spd_", "geo_", "species_")
  suffixes <- c("_trait_src", "_src")
  pattern <- paste0("(", paste(suffixes, collapse = "|"), ")$")

  src_cols <- remove_prefixes(src_cols, prefixes = prefixes)
  names(src_cols) <- sub(pattern, "", names(src_cols))

  metadata_output <- arrange_metadata(src_cols, names(src_cols))

  #### Temp fix from Excel sheet and list_traits ####
  trait_sheet <- readxl::read_xlsx("C:/Users/kfrac/Downloads/AVONET_Traits_MS_SF_KF_JAT.xlsx")
  trait_sheet <- trait_sheet[c("trait_name_R", "short_description_R", "primary_source_R")]
  trait_sheet <- trait_sheet[complete.cases(trait_sheet),]

  ## Join to metadata output
  metadata_output <- left_join(metadata_output, trait_sheet, by = join_by("trait" == "trait_name_R"))

  ## Rename columns
  names(metadata_output)[names(metadata_output) == "short_description_R"] <- "description"
  names(metadata_output)[names(metadata_output) == "primary_source_R"] <- "primary_source"
  #### END ####

  return(metadata_output)

}
