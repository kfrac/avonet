remove_prefixes <- function(df, prefixes, ignore_case = FALSE) {
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
    setNames(
      data.frame(rep(names(pivot_cols), each = nrow(data))), names_to
    ),
    setNames(
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
#   con   - DBI connection object
#   taxon - character(1) taxon name to look up
#
# Returns character(1) rank string, or stops if no match is found.
# -----------------------------------------------------------------------------
detect_rank <- function(con, taxon) {

  taxon <- trimws(taxon)
  has_space <- grepl(" ", taxon, fixed = TRUE)

  if (has_space) {
    # Could only be a species binomial – check species_name directly
    hit <- DBI::dbGetQuery(
      con,
      "SELECT 1 FROM species WHERE species_name = $1 LIMIT 1;",
      params = list(taxon)
    )
    if (nrow(hit) > 0) return("species")
  } else {
    # Single word: try genus first (LIKE 'Taxon %'), then family, then order
    genus_pattern <- paste0(taxon, " %")
    hit <- DBI::dbGetQuery(
      con,
      "SELECT 1 FROM species WHERE species_name LIKE $1 LIMIT 1;",
      params = list(genus_pattern)
    )
    if (nrow(hit) > 0) return("genus")

    hit <- DBI::dbGetQuery(
      con,
      "SELECT 1 FROM species WHERE species_family = $1 LIMIT 1;",
      params = list(taxon)
    )
    if (nrow(hit) > 0) return("family")

    hit <- DBI::dbGetQuery(
      con,
      "SELECT 1 FROM species WHERE species_order = $1 LIMIT 1;",
      params = list(taxon)
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
#   con      - DBI connection object
#   taxon    - character(1) taxon name, e.g. "Buteo", "Accipitridae",
#              or "Buteo buteo"
#   rank     - character(1) or NULL. When NULL the rank is auto-detected via
#              detect_rank(). One of: "species", "genus", "family", "order".
#   taxonomy - integer taxonomy ID (species_tax) to filter results, matching
#              the `taxonomy` argument of get_traits(). NULL = no filter.
#
# Returns a character vector of species_name values (length >= 1).
# -----------------------------------------------------------------------------
resolve_taxa <- function(con, taxon, rank = NULL, taxonomy = NULL) {

  taxon <- trimws(taxon)

  if (is.null(rank)) {
    rank <- detect_rank(con, taxon)
    message(sprintf("Detected rank '%s' for taxon '%s'.", rank, taxon))
  }

  rank <- tolower(rank)
  valid_ranks <- c("species", "genus", "family", "order")
  if (!rank %in% valid_ranks) {
    stop(sprintf("Unknown rank '%s'. Valid ranks: %s.",
                 rank, paste(valid_ranks, collapse = ", ")))
  }

  # Build the WHERE clause appropriate for each rank.
  # Genus has no dedicated column: match the first word of species_name via LIKE.
  tax_clause  <- if (!is.null(taxonomy)) " AND species_tax = $2" else ""

  if (rank == "species") {
    where  <- "species_name = $1"
  } else if (rank == "genus") {
    taxon  <- paste0(taxon, " %")   # convert "Buteo" -> "Buteo %"
    where  <- "species_name LIKE $1"
  } else if (rank == "family") {
    where  <- "species_family = $1"
  } else {   # order
    where  <- "species_order = $1"
  }

  query <- sprintf(
    "SELECT DISTINCT species_name FROM species WHERE %s%s ORDER BY species_name;",
    where, tax_clause
  )

  params <- if (!is.null(taxonomy)) list(taxon, as.integer(taxonomy)) else list(taxon)
  result <- DBI::dbGetQuery(con, query, params = params)

  species_vec <- result[["species_name"]]

  if (length(species_vec) == 0) {
    stop(sprintf(
      "No species found for %s '%s'%s. Check the taxon name or rank.",
      rank, taxon,
      if (!is.null(taxonomy)) sprintf(" (taxonomy ID %d)", as.integer(taxonomy)) else ""
    ))
  }

  message(sprintf("Resolved '%s' (%s) to %d species.", taxon, rank, length(species_vec)))
  species_vec
}
