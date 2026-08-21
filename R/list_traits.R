#' Summarize the traits in one database table
#'
#' Internal helper behind [get_trait_list()]. Reads a single trait table and
#' returns one row per trait column, recording what the trait is, what values
#' it can take, whether it is measured per species or per specimen, and which
#' publication most of its values are attributed to.
#'
#' @details
#' Bookkeeping columns are excluded before summarizing: anything ending in
#' `_id`, `_src` or `_source`, plus the record-level columns of
#' `morph_trait_specimen` (`measure_date`, `measurer_id`, `measurer_comment`
#' and friends). Remaining column names are stripped of their table prefix
#' (`ect_`, `spd_`, `geo_`, `rts_`, `sts_`) so they match the names users see
#' in [get_traits()] output.
#'
#' Descriptions are joined on trait name from [get_trait_values()]; a trait
#' with no matching entry there keeps a `NA` description rather than being
#' dropped.
#'
#' ## Possible values
#'
#' The `value` column summarizes what a trait can contain: the literal string
#' `"numeric"` for numeric columns, or a comma-separated, alphabetically
#' sorted list of the distinct values actually observed for categorical ones.
#' This is derived from the data rather than from the Postgres enum
#' definition, so a level that exists in the schema but is never used will not
#' appear.
#'
#' ## Where `primary_source` comes from
#'
#' The database records sources differently depending on the table, so this is
#' derived in two ways:
#'
#' * `morph_trait_specimen` has no per-trait or per-measurement source column
#'   — its `source_id` and `lit_id` are record-level, not tied to an
#'   individual measurement — so every morphological trait is attributed to
#'   `"Tobias et al. (2022)"`. The same applies to `mass_value`, which is
#'   queried separately from `mass_species` but reported from that source for
#'   the same reason.
#' * Every other table pairs each trait with its own source column via
#'   `derive_source_map()`, then queries that column for its most frequently
#'   cited `trait_src_id` and resolves it to a `lit_abbrev` from
#'   `trait_source_detailed`. Where several sources tie for most cited, all of
#'   them are kept and comma-joined. A source column that is `NULL` throughout
#'   yields `NA`.
#'
#' ## Dropped rows
#'
#' Traits whose `primary_source` resolves to `NA`, or to `"AVOTRAITS"` alone,
#' are removed from the result on the grounds that a trait with no
#' attributable external source is not citable.
#'
#' @param table_name Character(1). Name of a trait table in the AVONET
#'   database, interpolated as a quoted identifier. [get_trait_list()] calls
#'   this with `"eco_trait_species"`, `"social_trait_species"`,
#'   `"morph_trait_specimen"` and `"geo_data_species"`. A name that is not a
#'   table raises a Postgres error.
#'
#' @return A data frame with one row per trait and the columns:
#'   \describe{
#'     \item{`trait`}{Trait name, with its table prefix stripped.}
#'     \item{`resolution`}{`"species"` or `"specimen"`, i.e. whether the trait
#'       is recorded once per species or once per measured individual.}
#'     \item{`description`}{Free-text description from [get_trait_values()],
#'       or `NA` where none is recorded.}
#'     \item{`value`}{`"numeric"`, or the observed categorical levels as a
#'       comma-separated string.}
#'     \item{`primary_source`}{Abbreviated citation for the publication most
#'       of the trait's values come from; see Details.}
#'   }
#'   Traits with no attributable source are absent, so the result can be
#'   shorter than the number of trait columns in the table.
#'
#' @keywords internal
#'
#' @seealso [get_trait_list()], the exported wrapper that calls this once per
#'   trait group; [get_trait_values()] for the underlying trait descriptions;
#'   [get_trait_levels()] for the valid levels of a single categorical trait.
#'
#' @examples
#' \dontrun{
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#' connect_db(username = db_user, pw = db_password)
#'
#' # Species-level ecological traits, sources derived from the data
#' avonet:::list_traits("eco_trait_species")
#'
#' # Specimen-level morphology, all attributed to Tobias et al. (2022)
#' avonet:::list_traits("morph_trait_specimen")
#'
#' disconnect_db()
#' }
list_traits <- function(table_name) {

  con <- get_con()

  raw_df <- DBI::dbGetQuery(con, glue::glue_sql("SELECT * FROM {`table_name`}", .con = con))

  if (table_name == "morph_trait_specimen") {

    drop_cols <- c("sd_id", "source_id", "measure_date", "measurer_id",
                   "measurer_comment", "lit_id")
    df <- raw_df[, !(names(raw_df) %in% drop_cols), drop = FALSE]
    df <- remove_suffix_columns(df, c("_id", "_src", "_source"))

    value_summary <- vapply(df, summarize_trait_value, character(1))

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
      value          = summarize_trait_value(mass_df$mass_value),
      resolution     = "species",
      primary_source = "Tobias et al. (2022)",
      stringsAsFactors = FALSE
    ))

  } else {

    prefixes <- c("ect_", "spd_", "geo_", "rts_", "sts_")

    source_map <- derive_source_map(table_name, names(raw_df))

    raw_trait_cols <- names(raw_df)[!grepl("(_id|_src|_source)$", names(raw_df))]

    df <- remove_suffix_columns(raw_df, c("_id", "_src", "_source"))
    df <- remove_column_prefixes(df, prefixes)

    value_summary <- vapply(df, summarize_trait_value, character(1))

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
