#' Summarize a trait column as a single string
#'
#' Internal helper behind [list_traits()]. Collapses one column of a trait
#' table into the summary string reported in the `value` column of a trait
#' list.
#'
#' @details
#' Categorical levels are read from the data rather than from the Postgres enum
#' definition, so a level that exists in the schema but is never used will not
#' appear in the summary. `NA` sorts last and is rendered as the literal string
#' `"NA"` when present.
#'
#' @param x A trait column: a numeric vector, or a character or factor vector
#'   of categorical values.
#'
#' @return Character(1). `"numeric"` for numeric input, otherwise the sorted
#'   unique values collapsed into a comma-separated string.
#' @keywords internal
#'
#' @seealso [list_traits()], the only caller.
#'
#' @examples
#' \dontrun{
#' avonet:::summarize_trait_value(c(1.2, 3.4))
#' avonet:::summarize_trait_value(c("Forest", "Desert", "Forest"))
#' }
summarize_trait_value <- function(x) {
  if (is.numeric(x)) {
    "numeric"
  } else {
    paste0(sort(unique(x), na.last = TRUE), collapse = ", ")
  }
}


#' Map trait columns to their literature-source columns
#'
#' Internal helper behind [list_traits()]. Works out which `_src` / `_source`
#' column holds the literature reference for each trait column in a table.
#'
#' @details
#' Most trait columns have a dedicated source column formed by suffixing
#' `_src` or `_source` onto the trait column's own name, e.g. `ect_habitat`
#' pairs with `ect_habitat_src`.
#'
#' Trait columns with no such match fall back to a single shared "leftover"
#' source column, provided exactly one is available — this is how the spatial
#' columns of `geo_data_species` all resolve to `spd_spatial_source`. If that
#' fallback would be ambiguous, meaning zero or several leftover source
#' columns remain for the unmatched traits, the function raises an error of
#' class `avonet_error_unresolved_source` rather than guessing.
#'
#' @param table_name Character(1) table name. Used only to make the error
#'   message specific; no query is issued against it here.
#' @param raw_cols Character vector of every column name in the table, as
#'   returned by `SELECT *`, before any prefix or suffix stripping.
#'
#' @return A named character vector: names are the trait columns, values are
#'   the source columns they resolve to.
#' @keywords internal
#'
#' @seealso [list_traits()], the only caller.
#'
#' @examples
#' \dontrun{
#' cols <- c("species_id", "spd_min_latitude", "spd_range_size",
#'           "spd_spatial_source")
#'
#' # all three spatial traits share the one leftover source column
#' avonet:::derive_source_map("geo_data_species", cols)
#' }
derive_source_map <- function(table_name, raw_cols) {

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


#' Harmonize species-level column names
#'
#' Shared column clean-up for species-level query output, so that
#' [get_species()] and the `data` element of [get_traits()] always return the
#' same set of columns. Kept in one place because the two entry points
#' otherwise drift apart silently.
#'
#' @details
#' Three steps, in order:
#'
#' 1. Strip the table prefixes (`ect_`, `spd_`, `geo_`, `species_`) that exist
#'    only to keep column names unique across the joined tables.
#' 2. Rename the resulting `name` column to `species`.
#' 3. Unless `source_cols = TRUE`, drop the bookkeeping columns: every
#'    per-trait `_src` / `_source` column, plus `species_id`, which matches the
#'    `"id"` suffix once its prefix has been stripped.
#'
#' Note that `mass_value` and `mass_flag` keep their prefix, since `mass_` is
#' not in the strip list — the column is named for the trait itself rather than
#' for its table.
#'
#' @param df Data frame of raw `query_species_traits()` output.
#' @param source_cols Logical. Keep the `_src` / `_source` columns inline?
#'   Defaults to `FALSE`. `TRUE` also retains the `id` column, because step 3
#'   removes both under the same suffix rule.
#'
#' @return The data frame with cleaned-up column names: 17 columns when
#'   `source_cols = FALSE`, 26 when `TRUE`.
#' @keywords internal
#'
#' @seealso [get_species()] and [get_traits()], the two callers.
#'
#' @examples
#' \dontrun{
#' # assumes an open connection, see connect_db()
#' raw <- avonet:::query_species_traits(species = "Buteo buteo", taxonomy = 1)
#'
#' names(avonet:::tidy_species_columns(raw))
#' names(avonet:::tidy_species_columns(raw, source_cols = TRUE))
#' }
tidy_species_columns <- function(df, source_cols = FALSE) {

  prefixes <- c("ect_", "spd_", "geo_", "species_")
  suffixes <- c("id", "_src", "_source")

  df <- remove_column_prefixes(df, prefixes = prefixes)
  names(df)[names(df) == "name"] <- "species"

  if (!source_cols) {
    df <- remove_suffix_columns(df, suffixes = suffixes)
  }

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


#' Infer the taxonomic rank of a name
#'
#' Internal helper behind [resolve_taxa()]. Probes the `species` table to work
#' out whether a supplied name is a species binomial, a genus, a family or an
#' order.
#'
#' @details
#' Detection uses the shape of the name first, then a lookup:
#'
#' * `"species"` — the name contains a space, i.e. is a `Genus species`
#'   binomial, and matches `species_name` exactly.
#' * `"genus"` — a single word, and `species_name LIKE 'Word %'` returns a
#'   hit, i.e. the name is the first word of at least one binomial.
#' * `"family"` — a single word matching `species_family` exactly.
#' * `"order"` — a single word matching `species_order` exactly.
#'
#' Single-word names are tried in that order and the first hit wins, so a name
#' that is both a genus and a family resolves as a genus. Each check is a
#' separate `LIMIT 1` query, so detection costs up to three round trips.
#'
#' @param taxon Character(1) taxon name to look up. Surrounding whitespace is
#'   trimmed.
#'
#' @return Character(1): one of `"species"`, `"genus"`, `"family"` or
#'   `"order"`. Errors if nothing matches, prompting the caller to supply
#'   `rank` explicitly or check the spelling.
#' @keywords internal
#'
#' @seealso [resolve_taxa()], which calls this whenever its `rank` argument is
#'   `NULL`.
#'
#' @examples
#' \dontrun{
#' # assumes an open connection, see connect_db()
#' avonet:::detect_rank("Buteo buteo")   # "species"
#' avonet:::detect_rank("Buteo")         # "genus"
#' avonet:::detect_rank("Accipitridae")  # "family"
#' }
detect_rank <- function(taxon) {

  con <- get_con()

  taxon <- trimws(taxon)
  has_space <- grepl(" ", taxon, fixed = TRUE)

  if (has_space) {
    # Could only be a species binomial -- check species_name directly
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


#' Resolve a taxon name to the species it contains
#'
#' Internal helper behind [get_traits()]. Expands a name at any supported rank
#' into the vector of species names it covers, restricted to one taxonomy
#' version.
#'
#' @details
#' When `rank` is `NULL` it is auto-detected with [detect_rank()], and the
#' detected rank is reported via a message so the caller can see how an
#' ambiguous name was read.
#'
#' Genus has no dedicated column in the `species` table, so a genus is matched
#' with `LIKE 'Genus %'` against `species_name`. The other ranks match
#' `species_name`, `species_family` or `species_order` exactly. Results are
#' deduplicated and returned in alphabetical order.
#'
#' @param taxon Character(1) taxon name, e.g. `"Buteo buteo"`, `"Buteo"` or
#'   `"Accipitridae"`. Surrounding whitespace is trimmed.
#' @param rank Character(1) or `NULL`. One of `"species"`, `"genus"`,
#'   `"family"` or `"order"`, matched case-insensitively. `NULL` (the default)
#'   auto-detects the rank.
#' @param taxonomy Integer taxonomy ID matched against `species_tax`, the same
#'   value passed to [get_traits()].
#'
#' @return Character vector of `species_name` values, of length 1 or more.
#'   Errors if `rank` is not one of the four valid ranks, or if the taxon
#'   matches no species under the requested taxonomy.
#' @keywords internal
#'
#' @seealso [detect_rank()] for the auto-detection step; [get_traits()], which
#'   calls this once per supplied name.
#'
#' @examples
#' \dontrun{
#' # assumes an open connection, see connect_db()
#' avonet:::resolve_taxa("Buteo", taxonomy = 1)
#' avonet:::resolve_taxa("Accipitridae", rank = "family", taxonomy = 1)
#' }
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


#' Filter species-level trait data with a named list of conditions
#'
#' Internal helper behind [get_traits()]. Applies post-query filters to the raw
#' data frame returned by `query_species_traits()`, while the table prefixes
#' are still attached to the column names.
#'
#' @details
#' The set of filterable columns is derived from `data` itself rather than
#' being listed here, so it always matches what was actually queried. Columns
#' are excluded when they hold taxonomic identity (`species_name`,
#' `species_family` and friends) or bookkeeping (`_id`, `_src`, `_source`);
#' everything left is a trait and can be filtered on.
#'
#' Deriving the list this way matters because a filter naming a column that is
#' not in `data` cannot be applied: the comparison collapses to zero rows and
#' the result looks like "no species matched" rather than "that column was
#' never queried". Such a filter is now rejected up front instead.
#'
#' Element names in `filter` may be either the full SQL column name or the
#' short name left once the table prefix is stripped. Short names are resolved
#' automatically:
#'
#' ```
#' habitat        ->  ect_habitat
#' trophic_niche  ->  ect_trophic_niche
#' min_latitude   ->  spd_min_latitude
#' range_size     ->  spd_range_size
#' mass           ->  mass_value
#' ```
#'
#' Taxonomic columns are deliberately not filterable: restricting which taxa
#' are returned is the job of the `species` and `rank` arguments of
#' [get_traits()], applied upstream by [resolve_taxa()].
#'
#' ## Filter syntax
#'
#' Character columns take a single value or a set of values; numeric columns
#' take a `list(op = , val = )` pair. Multiple conditions are combined with
#' AND, and rows where any condition evaluates to `NA` are dropped rather than
#' kept.
#'
#' ```
#' habitat       = "Forest"
#' trophic_niche = c("Frugivore", "Nectarivore")
#' min_latitude  = list(op = ">",  val = 40)
#' range_size    = list(op = "<",  val = 1000)
#' mass          = list(op = ">=", val = 500)
#' ```
#'
#' Supported operators are `"=="`, `"!="`, `"<"`, `"<="`, `">"` and `">="`.
#'
#' ## Errors
#'
#' All conditions are raised with [rlang::abort()] and carry a class:
#'
#' * `avonet_error_unknown_filter` -- the column is not in `data`. The message
#'   lists the full and short names that are available.
#' * `avonet_error_taxonomic_filter` -- the column exists but holds taxonomic
#'   identity; the message points at the `species` argument instead.
#' * `avonet_error_ambiguous_filter` -- a short name matches more than one
#'   column, so the full name is required.
#' * `avonet_error_invalid_filter` -- a list condition is missing `op` or `val`.
#' * `avonet_error_invalid_operator` -- `op` is not one of the six supported
#'   comparisons.
#'
#' @param data Data frame of raw `query_species_traits()` output, with column
#'   prefixes still intact.
#' @param filter Named list of filter conditions; see Details.
#'
#' @return The filtered data frame. A message reports how many of the original
#'   rows were retained.
#' @keywords internal
#'
#' @seealso [get_traits()], which exposes this through its `filter` argument.
#'
#' @examples
#' \dontrun{
#' # assumes an open connection, see connect_db()
#' raw <- avonet:::query_species_traits(species = c("Buteo buteo", "Aquila chrysaetos"),
#'                                      taxonomy = 1)
#'
#' avonet:::apply_filters(raw, list(habitat = "Forest"))
#' avonet:::apply_filters(raw, list(range_size = list(op = "<", val = 1000)))
#'
#' # errors, listing the columns that were actually queried
#' avonet:::apply_filters(raw, list(mating_system = "Polygamous"))
#' }
apply_filters <- function(data, filter) {

  valid_ops <- c("==", "!=", "<", "<=", ">", ">=")

  # Taxonomic identity is filtered upstream by resolve_taxa(), so those columns
  # are recognized but refused rather than silently unavailable.
  taxon_cols  <- c("species_id", "species_name", "species_family",
                   "species_order", "species_tax")
  taxon_short <- sub("^species_", "", taxon_cols)

  # Filterable columns are whatever `data` actually holds, minus taxonomic and
  # bookkeeping columns. Derived rather than hardcoded so the list cannot drift
  # away from what query_species_traits() selects.
  sql_cols <- setdiff(names(data), taxon_cols)
  sql_cols <- sql_cols[!grepl("(_id|_src|_source)$", sql_cols)]

  # Prefixes stripped to form short names (mass_ intentionally excluded)
  col_prefixes <- c("ect_", "rts_", "sts_", "spd_", "geo_")

  # Build a lookup: short_name -> full SQL column name.
  # - table prefixes are stripped normally.
  # - mass_value is a special case: the _value suffix is stripped so the
  #   user-facing name is simply "mass". mass_flag keeps its full name.
  short_to_full <- stats::setNames(
    sql_cols,
    vapply(sql_cols, function(col) {
      if (col == "mass_value") return("mass")          # special case
      matched_prefix <- Filter(function(p) startsWith(col, p), col_prefixes)
      if (length(matched_prefix) > 0) {
        sub(matched_prefix[[1]], "", col)              # strip table prefix
      } else {
        col                                            # no prefix: short == full
      }
    }, character(1))
  )

  # ---- Resolve user-supplied name to full SQL column name ----
  resolve_col <- function(user_col) {
    # Accept full SQL name directly
    if (user_col %in% sql_cols) return(user_col)

    # Try short-name lookup
    matches <- short_to_full[names(short_to_full) == user_col]
    if (length(matches) == 1)  return(unname(matches))
    if (length(matches)  > 1) {
      rlang::abort(
        sprintf(
          "Short name '%s' is ambiguous: matches %s. Please use the full column name.",
          user_col, paste(unname(matches), collapse = ", ")
        ),
        class = "avonet_error_ambiguous_filter"
      )
    }

    # Recognisable, but filtering on taxonomy is handled upstream
    if (user_col %in% c(taxon_cols, taxon_short)) {
      rlang::abort(
        sprintf(
          paste0("'%s' is a taxonomic column, not a filterable trait.\n",
                 "Restrict which taxa are returned with the `species` and ",
                 "`rank` arguments of get_traits() instead."),
          user_col
        ),
        class = "avonet_error_taxonomic_filter"
      )
    }

    # Not found -- list what this data frame actually offers
    rlang::abort(
      sprintf(
        paste0("Filter column '%s' not recognised.\n",
               "Available full column names: %s\n",
               "Available short names:       %s"),
        user_col,
        paste(sql_cols,             collapse = ", "),
        paste(names(short_to_full), collapse = ", ")
      ),
      class = "avonet_error_unknown_filter"
    )
  }

  n_before <- nrow(data)
  mask     <- rep(TRUE, n_before)

  for (user_col in names(filter)) {

    col  <- resolve_col(user_col)
    cond <- filter[[user_col]]

    if (is.list(cond)) {
      # ---- Numeric comparison ----
      if (!all(c("op", "val") %in% names(cond))) {
        rlang::abort(
          sprintf(
            "Numeric filter for '%s' must be list(op = <operator>, val = <value>), e.g. list(op = '>', val = 40).",
            user_col
          ),
          class = "avonet_error_invalid_filter"
        )
      }
      op  <- cond[["op"]]
      val <- cond[["val"]]
      if (!op %in% valid_ops) {
        rlang::abort(
          sprintf(
            "Invalid operator '%s' for '%s'. Valid operators: %s.",
            op, user_col, paste(valid_ops, collapse = ", ")
          ),
          class = "avonet_error_invalid_operator"
        )
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

