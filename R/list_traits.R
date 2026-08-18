# -----------------------------------------------------------------------------
# list_traits()
# -----------------------------------------------------------------------------
# Internal helper behind get_trait_list(). Summarizes every trait column in a
# table: its possible values ("numeric" or a comma-separated list of unique
# categorical values), its resolution (species vs. specimen), a description
# (joined from get_trait_values()), and its primary_source.
#
# primary_source is derived differently depending on the table:
#   - morph_trait_specimen: there is no per-trait or per-specimen source
#     column in the DB (source_id/lit_id are record-level, not tied to any
#     individual measurement), so it's hardcoded to "Tobias et al. (2022)"
#     for every morphological trait, plus mass_value (queried separately from
#     mass_species, but reported from the same source for the same reason).
#   - all other tables: derived from observed data via .derive_source_map()
#     (see helper_functions.R) plus a per-source-column query for the most
#     frequently cited trait_src_id (all tied sources are kept, comma-joined,
#     on a tie; NA if a source column is always NULL).
#
# Rows with a NA or "AVOTRAITS"-only primary_source are dropped, matching the
# filtering the Excel-based version of this function used to apply.
# -----------------------------------------------------------------------------
list_traits <- function(table_name) {

  con <- get_con()

  raw_df <- DBI::dbGetQuery(con, glue::glue_sql("SELECT * FROM {`table_name`}", .con = con))

  if (table_name == "morph_trait_specimen") {

    drop_cols <- c("sd_id", "source_id", "measure_date", "measurer_id",
                   "measurer_comment", "lit_id")
    df <- raw_df[, !(names(raw_df) %in% drop_cols), drop = FALSE]
    df <- remove_suffix_columns(df, c("_id", "_src", "_source"))

    value_summary <- vapply(df, .summarize_trait_value, character(1))

    output <- data.frame(
      trait          = names(value_summary),
      value          = unname(value_summary),
      resolution     = "specimen",
      primary_source = "Tobias et al. (2022)",
      stringsAsFactors = FALSE
    )

    mass_df <- DBI::dbGetQuery(con, "SELECT mass_value FROM mass_species")

    output <- rbind(output, data.frame(
      trait          = "mass_value",
      value          = .summarize_trait_value(mass_df$mass_value),
      resolution     = "species",
      primary_source = "Tobias et al. (2022)",
      stringsAsFactors = FALSE
    ))

  } else {

    prefixes <- c("ect_", "spd_", "geo_", "rts_", "sts_")

    source_map <- .derive_source_map(table_name, names(raw_df))

    raw_trait_cols <- names(raw_df)[!grepl("(_id|_src|_source)$", names(raw_df))]

    df <- remove_suffix_columns(raw_df, c("_id", "_src", "_source"))
    df <- remove_column_prefixes(df, prefixes)

    value_summary <- vapply(df, .summarize_trait_value, character(1))

    src_lookup <- DBI::dbGetQuery(con, "SELECT trait_src_id, lit_abbrev FROM trait_source_detailed")

    unique_src_cols <- unique(source_map)
    primary_source_by_col <- stats::setNames(
      vapply(unique_src_cols, function(src_col) {
        counts <- DBI::dbGetQuery(con, glue::glue_sql(
          "SELECT {`src_col`} AS src_id, COUNT(*) AS n
           FROM {`table_name`}
           WHERE {`src_col`} IS NOT NULL
           GROUP BY {`src_col`}
           ORDER BY n DESC",
          .con = con
        ))
        if (nrow(counts) == 0) return(NA_character_)
        top_ids <- counts$src_id[counts$n == max(counts$n)]
        abbrevs <- src_lookup$lit_abbrev[match(top_ids, src_lookup$trait_src_id)]
        paste(sort(unique(abbrevs)), collapse = ", ")
      }, character(1)),
      unique_src_cols
    )

    output <- data.frame(
      trait          = names(value_summary),
      value          = unname(value_summary),
      resolution     = "species",
      primary_source = unname(primary_source_by_col[source_map[raw_trait_cols]]),
      stringsAsFactors = FALSE
    )
  }

  trait_desc <- get_trait_values()[, c("trait_name", "trait_description")]
  trait_desc <- trait_desc[!duplicated(trait_desc), ]
  names(trait_desc)[names(trait_desc) == "trait_description"] <- "description"

  output <- dplyr::left_join(output, trait_desc, by = c("trait" = "trait_name"))

  ## Drop rows with no attributable source
  output <- output[!(is.na(output$primary_source) | output$primary_source == "AVOTRAITS"), ]

  output <- output[, c("trait", "resolution", "description", "value", "primary_source")]

  output
}
