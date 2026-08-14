# -----------------------------------------------------------------------------
# .summarize_trait_value()
# -----------------------------------------------------------------------------
# Collapses a trait column into the summary string used by list_traits():
# "numeric" for numeric columns, or a sorted comma-separated list of unique
# values for categorical columns.
# -----------------------------------------------------------------------------
.summarize_trait_value <- function(x) {
  if (is.numeric(x)) {
    "numeric"
  } else {
    paste0(sort(unique(x), na.last = TRUE), collapse = ", ")
  }
}


# -----------------------------------------------------------------------------
# .derive_source_map()
# -----------------------------------------------------------------------------
# Maps each trait column in a table to the `_src`/`_source` column that holds
# its literature-source reference, for use by list_traits().
#
# Most trait columns have a dedicated source column formed by suffixing
# "_src" or "_source" onto the trait column's name (e.g. ect_habitat ->
# ect_habitat_src). Where no dedicated column exists, remaining trait columns
# fall back to a single shared "leftover" source column, if exactly one
# exists (e.g. geo_data_species' spatial columns all share
# spd_spatial_source). If that's ambiguous (zero or multiple leftover source
# columns for the remaining traits), this errors rather than guessing.
#
# Arguments:
#   table_name - character(1), used only for the error message
#   raw_cols   - character vector of all column names in the table (as
#                returned by `SELECT *`, before any suffix/prefix stripping)
#
# Returns a named character vector: names are trait columns, values are their
# resolved source columns.
# -----------------------------------------------------------------------------
.derive_source_map <- function(table_name, raw_cols) {

  id_cols    <- grep("_id$", raw_cols, value = TRUE)
  src_cols   <- grep("(_src|_source)$", raw_cols, value = TRUE)
  trait_cols <- setdiff(raw_cols, c(id_cols, src_cols))

  source_map <- stats::setNames(rep(NA_character_, length(trait_cols)), trait_cols)

  for (tc in trait_cols) {
    candidates <- c(paste0(tc, "_src"), paste0(tc, "_source"))
    hit <- intersect(candidates, src_cols)
    if (length(hit) == 1) source_map[[tc]] <- hit
  }

  unmatched     <- names(source_map)[is.na(source_map)]
  claimed_src   <- unname(stats::na.omit(source_map))
  leftover_src  <- setdiff(src_cols, claimed_src)

  if (length(unmatched) > 0) {
    if (length(leftover_src) == 1) {
      source_map[unmatched] <- leftover_src
    } else {
      rlang::abort(
        sprintf(
          "Can't determine source column(s) for trait(s) %s in table '%s' (leftover source columns: %s).",
          paste(unmatched, collapse = ", "),
          table_name,
          if (length(leftover_src) == 0) "none" else paste(leftover_src, collapse = ", ")
        ),
        class = "avonet_error_unresolved_source"
      )
    }
  }

  source_map
}


remove_column_prefixes <- function(df, prefixes, ignore_case = FALSE) {
  # Build regex pattern from prefix list
  pattern <- paste0("^(", paste(prefixes, collapse = "|"), ")")

  # Remove matching prefixes from column names
  names(df) <- sub(pattern, "", names(df), ignore.case = ignore_case)

  return(df)
}


remove_suffix_columns <- function(df, suffixes, ignore_case = FALSE) {
  # Build regex pattern from suffix list
  pattern <- paste0("(", paste(suffixes, collapse = "|"), ")$")

  # Identify columns that do NOT end with any of the suffixes
  keep <- !grepl(pattern, names(df), ignore.case = ignore_case)

  # Subset dataframe to keep only desired columns
  df <- df[, keep, drop = FALSE]

  return(df)
}


arrange_metadata <- function(data, cols, names_to = "trait", values_to = "source") {

  # Get the columns to pivot
  pivot_cols <- data[cols]

  # All non-pivoted columns (kept as repeating rows)
  id_cols <- data[setdiff(names(data), cols)]

  # Stack the pivoted columns
  long <- data.frame(
    id_cols[rep(seq_len(nrow(id_cols)), times = length(cols)), ],
    stats::setNames(
      data.frame(rep(names(pivot_cols), each = nrow(data))), names_to
    ),
    stats::setNames(
      data.frame(unlist(pivot_cols, use.names = FALSE)), values_to
    ),
    row.names = NULL
  )

  return(long)
}


# -----------------------------------------------------------------------------
# detect_rank()
# -----------------------------------------------------------------------------
# Infers the taxonomic rank of a supplied name by probing the `species` table.
#
# Rank detection logic:
#   "species" – name contains a space (i.e. "Genus species" binomial) AND
#               an exact match exists in species_name.
#   "genus"   – single word AND species_name LIKE 'Word %' returns a hit
#               (the name matches the first word of at least one binomial).
#   "family"  – exact match in species_family.
#   "order"   – exact match in species_order.
#
# Arguments:
#   taxon - character(1) taxon name to look up
#
# Returns character(1) rank string, or stops if no match is found.
# -----------------------------------------------------------------------------
detect_rank <- function(taxon) {

  con <- get_con()

  taxon <- trimws(taxon)
  has_space <- grepl(" ", taxon, fixed = TRUE)

  if (has_space) {
    # Could only be a species binomial – check species_name directly
    hit <- DBI::dbGetQuery(
      con,
      glue::glue_sql("SELECT 1 FROM species WHERE species_name = {taxon} LIMIT 1;", .con = con)
    )
    if (nrow(hit) > 0) return("species")
  } else {
    # Single word: try genus first (LIKE 'Taxon %'), then family, then order
    genus_pattern <- paste0(taxon, " %")
    hit <- DBI::dbGetQuery(
      con,
      glue::glue_sql("SELECT 1 FROM species WHERE species_name LIKE {genus_pattern} LIMIT 1;", .con = con)
    )
    if (nrow(hit) > 0) return("genus")

    hit <- DBI::dbGetQuery(
      con,
      glue::glue_sql("SELECT 1 FROM species WHERE species_family = {taxon} LIMIT 1;", .con = con)
    )
    if (nrow(hit) > 0) return("family")

    hit <- DBI::dbGetQuery(
      con,
      glue::glue_sql("SELECT 1 FROM species WHERE species_order = {taxon} LIMIT 1;", .con = con)
    )
    if (nrow(hit) > 0) return("order")
  }

  stop(sprintf(
    "Could not detect a taxonomic rank for '%s'. Supply the `rank` argument explicitly or check the taxon spelling.",
    taxon
  ))
}


# -----------------------------------------------------------------------------
# resolve_taxa()
# -----------------------------------------------------------------------------
# Resolves a taxon name (at any supported rank) to a character vector of
# species names found in the `species` table.
#
# Arguments:
#   taxon    - character(1) taxon name, e.g. "Buteo", "Accipitridae",
#              or "Buteo buteo"
#   rank     - character(1) or NULL. When NULL the rank is auto-detected via
#              detect_rank(). One of: "species", "genus", "family", "order".
#   taxonomy - integer taxonomy ID (species_tax) to filter results, matching
#              the `taxonomy` argument of get_traits().
#
# Returns a character vector of species_name values (length >= 1).
# -----------------------------------------------------------------------------
resolve_taxa <- function(taxon, rank = NULL, taxonomy) {

  con <- get_con()

  taxon <- trimws(taxon)

  if (is.null(rank)) {
    rank <- detect_rank(taxon)
    message(sprintf("Detected rank '%s' for taxon '%s'.", rank, taxon))
  }

  rank <- tolower(rank)
  valid_ranks <- c("species", "genus", "family", "order")
  if (!rank %in% valid_ranks) {
    stop(sprintf("Unknown rank '%s'. Valid ranks: %s.",
                 rank, paste(valid_ranks, collapse = ", ")))
  }

  # Build the query appropriate for each rank.
  # Genus has no dedicated column: match the first word of species_name via LIKE.
  if (rank == "species") {
    query <- glue::glue_sql("SELECT DISTINCT species_name
                            FROM species
                            WHERE species_name = {taxon}
                            AND species_tax = {as.integer(taxonomy)}
                            ORDER BY species_name;", .con = con)
  } else if (rank == "genus") {
    taxon <- paste0(taxon, " %")   # convert "Buteo" -> "Buteo %"
    query <- glue::glue_sql("SELECT DISTINCT species_name
                            FROM species
                            WHERE species_name LIKE {taxon}
                            AND species_tax = {as.integer(taxonomy)}
                            ORDER BY species_name;", .con = con)
  } else if (rank == "family") {
    query <- glue::glue_sql("SELECT DISTINCT species_name
                            FROM species
                            WHERE species_family = {taxon}
                            AND species_tax = {as.integer(taxonomy)}
                            ORDER BY species_name;", .con = con)
  } else {   # order
    query <- glue::glue_sql("SELECT DISTINCT species_name
                            FROM species
                            WHERE species_order = {taxon}
                            AND species_tax = {as.integer(taxonomy)}
                            ORDER BY species_name;", .con = con)
  }

  result <- DBI::dbGetQuery(con, query)

  species_vec <- result[["species_name"]]

  if (length(species_vec) == 0) {
    stop(sprintf(
      "No species found for %s '%s' (taxonomy ID %d). Check the taxon name or rank.",
      rank, taxon, as.integer(taxonomy)
    ))
  }

  message(sprintf("Resolved '%s' (%s) to %d species.", taxon, rank, length(species_vec)))
  species_vec
}


# -----------------------------------------------------------------------------
# apply_filters()
# -----------------------------------------------------------------------------
# Filters a data frame returned by sql_query() using a named list of
# conditions. Each list element name can be either the full SQL column name
# or a user-friendly short name.
#
# Short names are resolved automatically, e.g.:
#   habitat        -> ect_habitat       (ect_ prefix stripped)
#   trophic_niche  -> ect_trophic_niche (ect_ prefix stripped)
#   min_latitude   -> spd_min_latitude  (spd_ prefix stripped)
#   range_size     -> spd_range_size    (spd_ prefix stripped)
#   mass           -> mass_value        (_value suffix stripped)
#
# Species/family/order columns are intentionally excluded — filtering on
# taxonomic identity is handled upstream by resolve_taxa().
#
# If a short name matches more than one SQL column an error is raised asking
# the user to supply the full column name.
#
# Filter syntax:
#   Exact / set match (character columns):
#     habitat       = "Forest"
#     trophic_niche = c("Frugivore", "Nectarivore")
#
#   Numeric comparison:
#     min_latitude  = list(op = ">",  val = 40)
#     range_size    = list(op = "<",  val = 1000)
#     mass          = list(op = ">=", val = 500)
#
#   Supported operators: "==", "!=", "<", "<=", ">", ">="
#
# Arguments:
#   data   - data frame (raw sql_query() output, before prefix stripping)
#   filter - named list of filter conditions as described above
#
# Returns the filtered data frame, with a message reporting rows retained.
# -----------------------------------------------------------------------------
apply_filters <- function(data, filter) {

  valid_ops <- c("==", "!=", "<", "<=", ">", ">=")

  # Filterable trait/geo columns only — taxonomic identity columns excluded
  sql_cols <- c(
    "ect_habitat", "ect_habitat_density", "ect_migration",
    "ect_trophic_level", "ect_trophic_niche", "ect_primary_lifestyle",
    "ect_aerial_lifestyle", "ect_aerial_lifestyle_cert", "ect_flight_mode",
    "rts_sexual_selection", "rts_mating_system_certainty", "rts_mating_system",
    "rts_nest_placement", "rts_log_clutch_size",
    "sts_communal_signalling", "sts_duet", "sts_chorus", "sts_social_bond",
    "sts_uncertainty_social", "sts_territoriality",
    "mass_value", "mass_flag",
    "spd_min_latitude", "spd_max_latitude", "spd_centroid_lat", "spd_centroid_lon",
    "spd_range_size", "spd_max_elevation_1", "spd_min_elevation_1",
    "spd_max_elevation_2", "spd_min_elevation_2", "spd_island_association",
    "spd_island_endemic"
  )

  # Prefixes stripped to form short names (mass_ intentionally excluded)
  col_prefixes <- c("ect_", "rts_", "sts_", "spd_")

  # Build a lookup: short_name -> full SQL column name.
  # - ect_ and spd_ prefixes are stripped normally.
  # - mass_value is a special case: the _value suffix is stripped so the
  #   user-facing name is simply "mass". mass_flag keeps its full name.
  short_to_full <- stats::setNames(
    sql_cols,
    sapply(sql_cols, function(col) {
      if (col == "mass_value") return("mass")          # special case
      matched_prefix <- Filter(function(p) startsWith(col, p), col_prefixes)
      if (length(matched_prefix) > 0) {
        sub(matched_prefix[[1]], "", col)              # strip table prefix
      } else {
        col                                            # no prefix: short == full
      }
    })
  )

  # ---- Resolve user-supplied name to full SQL column name ----
  resolve_col <- function(user_col) {
    # Accept full SQL name directly
    if (user_col %in% sql_cols) return(user_col)

    # Try short-name lookup
    matches <- short_to_full[names(short_to_full) == user_col]
    if (length(matches) == 1)  return(unname(matches))
    if (length(matches)  > 1) {
      stop(sprintf(
        "Short name '%s' is ambiguous: matches %s. Please use the full column name.",
        user_col, paste(unname(matches), collapse = ", ")
      ))
    }

    # Not found — build a helpful error listing both full and short names
    short_names <- names(short_to_full)
    stop(sprintf(
      paste0("Filter column '%s' not recognised.\n",
             "Use a full column name: %s\n",
             "Or a short name:        %s"),
      user_col,
      paste(sql_cols,    collapse = ", "),
      paste(short_names, collapse = ", ")
    ))
  }

  n_before <- nrow(data)
  mask     <- rep(TRUE, n_before)

  for (user_col in names(filter)) {

    col  <- resolve_col(user_col)
    cond <- filter[[user_col]]

    if (is.list(cond)) {
      # ---- Numeric comparison ----
      if (!all(c("op", "val") %in% names(cond))) {
        stop(sprintf(
          "Numeric filter for '%s' must be list(op = '<operator>', val = <value>), e.g. list(op = '>', val = 40).",
          user_col
        ))
      }
      op  <- cond[["op"]]
      val <- cond[["val"]]
      if (!op %in% valid_ops) {
        stop(sprintf(
          "Invalid operator '%s' for '%s'. Valid operators: %s.",
          op, user_col, paste(valid_ops, collapse = ", ")
        ))
      }
      col_vals <- suppressWarnings(as.numeric(data[[col]]))
      mask <- mask & do.call(op, list(col_vals, val))

    } else {
      # ---- Exact / set match ----
      mask <- mask & (data[[col]] %in% cond)
    }
  }

  # Replace NA comparisons (from LEFT JOIN NAs) with FALSE
  mask[is.na(mask)] <- FALSE

  filtered <- data[mask, , drop = FALSE]
  message(sprintf("Filter retained %d of %d rows.", nrow(filtered), n_before))
  filtered
}

