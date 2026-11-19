## Builds the bundled example data: Accipitriformes (an order) and Sylviidae
## (a family), across every taxonomy that carries them.
##
## Run from the package root with a live connection:
##
##  devtools::load_all()
##  db_user <- keyring::key_list("avonet")[1, "username"]
##  connect_db(username = db_user, pw = keyring::key_get("avonet", username = db_user))
##  source("data-raw/make_example_data.R")
##
## It writes data/avonet_example.rda. Re-run it whenever the queries in
## query_species_traits() or get_morph_traits() change shape, since two of the
## bundled frames are snapshots of their output rather than of raw tables.

stopifnot(file.exists("DESCRIPTION"))

library(avonet)

con <- avonet:::get_con()

## get_con() above already failed if there is no connection, and with one the
## package always reads the database -- so this script cannot accidentally
## build the example data out of a previous copy of itself.

EXAMPLE_ORDER  <- "Accipitriformes"
EXAMPLE_FAMILY <- "Sylviidae"
TAXONOMIES     <- 1:3

# ---------------------------------------------------------------------------
# 1. The species backbone for both taxa, in every taxonomy that has them
# ---------------------------------------------------------------------------
species <- DBI::dbGetQuery(con, glue::glue_sql(
  "SELECT species_id, species_name, species_family, species_order, species_tax
     FROM species
    WHERE (species_order = {EXAMPLE_ORDER} OR species_family = {EXAMPLE_FAMILY})
      AND species_tax IN ({TAXONOMIES*})
    ORDER BY species_tax, species_name;",
  .con = con
))

message(sprintf("species backbone: %d rows", nrow(species)))
print(table(species$species_tax,
            ifelse(species$species_order == EXAMPLE_ORDER,
                   EXAMPLE_ORDER, EXAMPLE_FAMILY)))

if (nrow(species) == 0) stop("No species found for either example taxon.")

species_ids <- unique(species$species_id)

# ---------------------------------------------------------------------------
# 2. Snapshots of the two joined query outputs, per taxonomy
#    Built by calling the package's own functions, so the bundled frames match
#    what the functions return rather than a re-implementation of their SQL.
# ---------------------------------------------------------------------------
species_traits <- list()
specimens      <- list()

for (tax in sort(unique(species$species_tax))) {

  names_in_tax <- sort(unique(species$species_name[species$species_tax == tax]))
  message(sprintf("taxonomy %d: %d species", tax, length(names_in_tax)))

  species_traits[[as.character(tax)]] <-
    avonet:::query_species_traits(species = names_in_tax, taxonomy = tax)

  specimens[[as.character(tax)]] <-
    avonet:::get_morph_traits(species = names_in_tax, taxonomy = tax)
}

species_traits <- do.call(rbind, species_traits)
specimens      <- do.call(rbind, specimens)
rownames(species_traits) <- NULL
rownames(specimens)      <- NULL

message(sprintf("species_traits: %d rows x %d cols",
                nrow(species_traits), ncol(species_traits)))
message(sprintf("specimens:      %d rows x %d cols",
                nrow(specimens), ncol(specimens)))

## specimens carries no species_tax column, so it cannot be filtered by
## taxonomy later. Rows repeat across taxonomies for the same physical bird;
## de-duplicate on everything so the offline specimen counts match the live
## ones for a single-taxonomy query.
specimens <- unique(specimens)
message(sprintf("specimens after de-duplication: %d rows", nrow(specimens)))

# ---------------------------------------------------------------------------
# 3. Raw tables, keyed by the names list_traits() and modal_source() use
#    Per-species tables are scoped to the example species; the two lookup
#    tables are taxon-independent and bundled whole.
# ---------------------------------------------------------------------------
scoped <- c("eco_trait_species", "social_trait_species",
            "mass_species", "geo_data_species")

raw_tables <- lapply(scoped, function(tbl) {
  df <- DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT * FROM {`tbl`} WHERE species_id IN ({species_ids*});",
    .con = con
  ))
  message(sprintf("%-22s %6d rows", tbl, nrow(df)))
  df
})
names(raw_tables) <- scoped

## morph_trait_specimen links to species through source_specimen_species
raw_tables$morph_trait_specimen <- DBI::dbGetQuery(con, glue::glue_sql(
  "SELECT * FROM morph_trait_specimen
    WHERE source_id IN (SELECT sss.source_id
                          FROM source_specimen_species AS sss
                         WHERE sss.species_id IN ({species_ids*}));",
  .con = con
))
message(sprintf("%-22s %6d rows", "morph_trait_specimen",
                nrow(raw_tables$morph_trait_specimen)))

for (tbl in c("trait_info_detailed", "trait_source_detailed")) {
  raw_tables[[tbl]] <- DBI::dbGetQuery(con, glue::glue_sql(
    "SELECT * FROM {`tbl`};", .con = con
  ))
  message(sprintf("%-22s %6d rows (whole table)", tbl, nrow(raw_tables[[tbl]])))
}

# ---------------------------------------------------------------------------
# 4. Assemble and save
# ---------------------------------------------------------------------------
avonet_example <- list(
  taxa           = c(order = EXAMPLE_ORDER, family = EXAMPLE_FAMILY),
  extracted_on   = as.character(Sys.Date()),
  species        = species,
  species_traits = species_traits,
  specimens      = specimens,
  raw_tables     = raw_tables
)

dir.create("data", showWarnings = FALSE)

## version = 2 keeps the serialization readable by older R, so DESCRIPTION
## needs no Depends: R (>= 3.5) just for this.
save(avonet_example, file = "data/avonet_example.rda",
     compress = "xz", version = 2)

message(sprintf("\nwrote data/avonet_example.rda (%.1f KB)",
                file.size("data/avonet_example.rda") / 1024))
