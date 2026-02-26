list_traits <- function(table_name) {

  #table_name <- "eco_trait_species"
  #table_name <- "geo_data_species"
  #table_name <- "morph_trait_specimen"

  query <- DBI::dbSendQuery(con, sprintf("SELECT * FROM %s", table_name))
  df <- DBI::dbFetch(query)
  DBI::dbClearResult(query)

  df <- remove_suffix_columns(df, c("_id", "_src", "_source"))

  prefixes <- c("ect_", "spd_", "geo_")
  df <- remove_prefixes(df, prefixes)

  traits_list <- lapply(df, function(x) {
    if (is.numeric(x)) {
      "numeric"
    } else {
      paste0(sort(unique(x), na.last = TRUE), collapse = ", ")
    }
  })

  if(table_name == "morph_trait_specimen"){
    mass_query <- DBI::dbSendQuery(con, "SELECT * FROM mass_species")
    mass_df <- DBI::dbFetch(mass_query)
    DBI::dbClearResult(mass_query)

    mass_df <- remove_suffix_columns(mass_df, c("_id", "_src", "_source"))

    mass_list <- lapply(mass_df, function(x) {
      if (is.numeric(x)) {
        "numeric"
      } else {
        paste0(sort(unique(x), na.last = TRUE), collapse = ", ")
      }
    })

    traits_list <- append(traits_list, mass_list)

  }

  output <- data.frame(
    trait = rep(names(traits_list), times = lengths(traits_list)),
    value = unlist(traits_list, use.names = FALSE)
  )

  output$resolution <- ifelse(
    table_name == "morph_trait_specimen" & !startsWith(output$trait, "mass_"), "specimen", "species")

  #reorder columns
  output <- output[,c("trait", "resolution", "value")]

  #### Workaround for short descriptions from Excel spreadsheet ####
  trait_sheet <- readxl::read_xlsx("C:/Users/kfrac/Downloads/AVONET_Traits_MS_SF_KF_JAT.xlsx")
  trait_sheet <- trait_sheet[c("trait_name_R", "short_description_R", "primary_source_R")]

  ## Join to output
  output <- left_join(output, trait_sheet, by = join_by("trait" == "trait_name_R"))

  ## Rename column
  names(output)[names(output) == "short_description_R"] <- "description"
  names(output)[names(output) == "primary_source_R"] <- "primary_source"

  ## Reorder columns again
  output <- output[,c("trait", "resolution", "description", "value", "primary_source")]
  #### END ####

  return(output)

}
