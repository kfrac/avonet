# ---------------------------------------------------------------------------
# Where data comes from
#
# Every query in the package goes through one of the accessors below rather
# than reaching for get_con() directly, so there is a single place that
# decides between the live database and the bundled example data.
#
# There is deliberately nothing to configure: a usable connection means the
# database, no connection means the bundle. The database always wins when it
# is there, so a snapshot can never shadow live data.
# ---------------------------------------------------------------------------


# TRUE when there is a usable connection. get_con() errors for both "never
# connected" and "connection went stale", and here neither is exceptional --
# they are simply the signal to fall back.
has_connection <- function() {
  !is.null(tryCatch(get_con(), error = function(e) NULL))
}


#' Decide whether to read the bundled example data
#'
#' Internal policy function behind every query in the package: `TRUE` means
#' read the bundled `avonet_example` data, `FALSE` means query the database.
#'
#' @details
#' The rule is just "is there a usable connection?". With one the database is
#' used, without one the bundle. Nothing can override it, which is the point:
#' the bundle is a snapshot taken on a particular day, so letting it take
#' precedence over a live connection would mean silently serving stale rows as
#' soon as the database moved on.
#'
#' The consequence to keep in mind is that the bundle covers two taxa, so an
#' unconnected session can answer questions about those and no others. Every
#' exported function reports which source it used.
#'
#' @return A single logical.
#' @keywords internal
#'
#' @seealso [connect_db()], which is what switches a session from the bundle
#'   to the database.
using_example_data <- function() {
  !has_connection()
}


# Fetches the bundled data from the namespace rather than referring to
# `avonet_example` directly, which keeps R CMD check from reading it as an
# undeclared global and turns a package built without data/ into a clear
# error instead of "object not found".
example_bundle <- function() {

  bundle <- tryCatch(
    get("avonet_example", envir = asNamespace("avonet")),
    error = function(e) NULL
  )

  if (is.null(bundle)) {
    rlang::abort(
      paste0(
        "The bundled example data is not available in this build of avonet. ",
        "Run data-raw/make_example_data.R against a live connection to ",
        "create data/avonet_example.rda."
      ),
      class = "avonet_error_no_example_data"
    )
  }

  bundle
}


# One raw table out of the bundle, keyed by the database table name, so
# callers can use the same name offline that they put in their SQL.
example_table <- function(table_name) {

  tables <- example_bundle()$raw_tables

  if (!table_name %in% names(tables)) {
    rlang::abort(
      sprintf(
        "Table '%s' is not in the bundled example data. Available: %s.",
        table_name, paste(sort(names(tables)), collapse = ", ")
      ),
      class = "avonet_error_example_table_missing"
    )
  }

  tables[[table_name]]
}


# One whole table, from the bundle or the database. Every SELECT * in the
# package goes through here, so adding a table to the example data is the only
# thing needed to make its callers work offline. Callers pass the database
# table name either way, so the two paths read the same.
db_table <- function(table_name) {

  if (using_example_data()) return(example_table(table_name))

  con <- get_con()

  DBI::dbGetQuery(con, glue_sql("SELECT * FROM {`table_name`};", .con = con))
}


#' Match taxon names against the bundled species backbone
#'
#' The one place offline taxon matching happens. Returns the rows of
#' `avonet_example$species` that match `terms`, with a `match_type` column
#' saying which rank matched each row.
#'
#' @details
#' [detect_rank()], [resolve_taxa()] and [get_taxonomic_info()] all read this
#' when there is no connection, so the matching rules exist once instead of
#' once per caller. Each of those three mirrors a different query, and keeping
#' three reimplementations of the same ILIKE and CASE semantics in step with
#' the SQL is not something a package without tests can promise.
#'
#' The rules follow the SQL they stand in for: matching is case-insensitive,
#' as ILIKE is; a genus matches on the first word of a binomial, as
#' `LIKE 'Genus %'` does; and where a term could match at more than one rank,
#' precedence runs species, genus, family, order, as the CASE expression in
#' [get_taxonomic_info()] does.
#'
#' @param terms Character vector of taxon names, at any of the ranks named in
#'   `ranks`. Leading and trailing whitespace is trimmed.
#' @param taxonomy Integer or `NULL`. Restrict to one taxonomy version.
#'   `NULL` (default) searches all of them, which is what rank detection
#'   wants, since it asks only whether a name exists at all.
#' @param ranks Character vector of the ranks to try, in precedence order.
#'   Defaults to all four. Restricting it is how a caller asks whether a name
#'   is a family, rather than what rank the name is.
#'
#' @return A data frame of the matching backbone rows -- `species_id`,
#'   `species_name`, `species_family`, `species_order`, `species_tax` -- plus
#'   `match_type`, one of `"species"`, `"genus"`, `"family"` or `"order"`.
#'   Zero rows when nothing matches.
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' avonet:::match_example_taxa("Accipitridae")
#' avonet:::match_example_taxa("Buteo", ranks = "genus", taxonomy = 1)
#' }
match_example_taxa <- function(terms,
                               taxonomy = NULL,
                               ranks = c("species", "genus", "family", "order")) {

  sp <- example_bundle()$species

  if (!is.null(taxonomy)) {
    sp <- sp[sp$species_tax == as.integer(taxonomy), , drop = FALSE]
  }

  terms <- tolower(trimws(terms))
  none  <- rep(FALSE, nrow(sp))

  species_hit <- if ("species" %in% ranks) {
    tolower(sp$species_name) %in% terms
  } else none

  genus_hit <- if ("genus" %in% ranks) {
    vapply(
      tolower(sp$species_name),
      function(nm) any(startsWith(nm, paste0(terms, " "))),
      logical(1), USE.NAMES = FALSE
    )
  } else none

  family_hit <- if ("family" %in% ranks) {
    tolower(sp$species_family) %in% terms
  } else none

  order_hit <- if ("order" %in% ranks) {
    tolower(sp$species_order) %in% terms
  } else none

  keep <- species_hit | genus_hit | family_hit | order_hit
  out  <- sp[keep, , drop = FALSE]

  out$match_type <- ifelse(
    species_hit[keep], "species",
    ifelse(genus_hit[keep], "genus",
           ifelse(family_hit[keep], "family", "order"))
  )

  rownames(out) <- NULL

  out
}


# Says once per user-facing call that the answer came from the bundle rather
# than the database. Called from the exported entry points only, so a single
# get_traits() call does not repeat it for each internal query it makes.
notify_example_data <- function() {

  if (!using_example_data()) return(invisible(FALSE))

  bundle <- example_bundle()

  message(sprintf(
    paste0(
      "No database connection: reading bundled example data (%s; extracted ",
      "%s). These cover only those taxa -- call connect_db() for the full ",
      "database."
    ),
    paste(unname(bundle$taxa), collapse = " and "),
    bundle$extracted_on
  ))

  invisible(TRUE)
}


# Warns when a request reaches past what the bundle covers.
#
# Both bundled taxa are complete, so any species, genus or family at or below
# them is a faithful answer -- a family inside Accipitriformes is wholly
# present, and so is any genus inside Sylviidae. A wider taxon is not: asking
# for the order Passeriformes offline matches the bundled Sylviidae rows,
# because Sylviidae sits inside Passeriformes, and returns 69 species as
# though that were the order. That is the one case where the offline answer
# looks complete and is not.
warn_example_coverage <- function(taxon, rank, n_hits) {

  if (n_hits == 0L) return(invisible(FALSE))

  taxa <- example_bundle()$taxa

  if (!identical(rank, "order") ||
      identical(taxon, unname(taxa[["order"]]))) {
    return(invisible(FALSE))
  }

  warning(sprintf(
    paste0(
      "The bundled example data covers the order %s and the family %s. ",
      "'%s' reaches beyond them, so these %d species are only the bundled ",
      "part of that order, not the whole of it. Connect to the database for ",
      "the rest."
    ),
    taxa[["order"]], taxa[["family"]], taxon, n_hits
  ), call. = FALSE)

  invisible(TRUE)
}
