#' Example AVONET data, for use without a database connection
#'
#' A snapshot of two taxa from the AVONET database — the order
#' **Accipitriformes** (hawks, eagles and relatives) and the family
#' **Sylviidae** (sylviid warblers) — across every taxonomy that carries them.
#' It lets every function in the package run with no connection, which is what
#' makes the examples, the README and any test suite reproducible.
#'
#' @details
#' The package reads this whenever there is no usable connection, and the
#' database whenever there is one. There is nothing to configure:
#' [connect_db()] is what moves a session from the one to the other, and every
#' exported function reports which it used.
#'
#' Two of the elements are snapshots of function *output* rather than of raw
#' tables, so that the offline path filters a stored result instead of
#' re-implementing the joins that produced it. The trade-off is that they go
#' stale if those queries change shape: re-run `data-raw/make_example_data.R`
#' when they do.
#'
#' A taxon with nothing in the bundle returns no rows, exactly as an unknown
#' taxon would against the database. Both bundled taxa are complete, so any
#' species, genus or family at or below them is a faithful answer. A *wider*
#' taxon is not: the order Passeriformes matches the bundled Sylviidae rows,
#' since Sylviidae sits inside it, and would otherwise return 69 species as
#' though that were the order — so that case warns.
#'
#' Coverage is uneven across taxonomies, because the two names do not exist
#' everywhere. As extracted on 2026-11-19: BirdLife has 252 Accipitriformes
#' and 69 Sylviidae, eBird 252 and **none** (it carries no Sylviidae family
#' label), BirdTree 251 and 294.
#'
#' Functions that summarize whole tables — [get_trait_list()] in particular —
#' describe only this subset while it is in use, so the values and modal
#' sources they report are those of the example data, not of the full
#' database.
#'
#' @format A named list with six elements:
#' \describe{
#'   \item{`taxa`}{Named character vector of the two taxa covered, as
#'     `c(order = , family = )`.}
#'   \item{`extracted_on`}{Date of extraction, as a string. Reported by the
#'     message the package prints when it falls back to this data.}
#'   \item{`species`}{Data frame: the `species` backbone rows for both taxa,
#'     with `species_id`, `species_name`, `species_family`, `species_order` and
#'     `species_tax`. Backs rank detection and resolution.}
#'   \item{`species_traits`}{Data frame: a snapshot of
#'     `query_species_traits()` output, one row per species per taxonomy, with
#'     the ecological, mass and geographical trait columns and their `_src` /
#'     `_source` partners.}
#'   \item{`specimens`}{Data frame: a snapshot of unaggregated
#'     `get_morph_traits()` output, carrying the morphological measurements
#'     plus sex, life stage, country and source. One row per measured bird
#'     *per taxonomy that attaches it*, with a `species_tax` column to tell
#'     them apart: 269 of the example species names occur in more than one
#'     taxonomy, and where two taxonomies attach different specimens to the
#'     same name, filtering on the name alone would pool them.}
#'   \item{`raw_tables`}{Named list of raw table extracts, keyed by database
#'     table name: `eco_trait_species`, `social_trait_species`, `mass_species`,
#'     `geo_data_species` and `morph_trait_specimen` scoped to the example
#'     species, plus `trait_info_detailed` and `trait_source_detailed` whole,
#'     those two being taxon-independent lookups.}
#' }
#'
#' @source The AVONET Postgres database, extracted by
#'   `data-raw/make_example_data.R`. AVONET itself is published in Tobias et
#'   al. (2022) \doi{10.1111/ele.13898}.
#'
#' @seealso [connect_db()] for the full database, and [get_traits()] for the
#'   main entry point into either.
#'
#' @examples
#' # Works with no connection
#' avonet_example$taxa
#' nrow(avonet_example$species)
#' names(avonet_example$raw_tables)
#'
#' @name avonet_example
#' @docType data
#' @usage avonet_example
#' @keywords datasets
NULL
