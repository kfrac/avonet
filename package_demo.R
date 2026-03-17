library(devtools)
library(dplyr)
library(glue)
library(RPostgres)
library(keyring)

devtools::load_all()

#### Sample birds ####
species <- "Buteo buteo"
my_birds <- c("Haliaeetus leucocephalus", "Aptenodytes forsteri",
              "Cardinalis cardinalis", "Nucifraga caryocatactes")
family1 <- "Cracidae"
family2 <- "Scotocercidae"
order1 <- "Passeriformes"

#### Establish connection to database ####
db_user <- key_list("avonet")[1, "username"]
db_password <- key_get("avonet", username = db_user)
con <- connect_db(username = db_user, pw = db_password)

#### User-facing functions for finding groups ####
get_trait_groups()
get_trait_list("eco")
get_trait_list("geo")
get_trait_list("morpho")
get_trait_list() -> trait_list

#get_traits("eco")
get_traits(con, "Buteo buteo", 1)
test <- get_traits(con, "Buteo buteo", 1)

get_taxonomic_info(con, search_term = species, taxonomy = 1)
get_taxonomic_info(con, search_term = family1, taxonomy = 1)
get_taxonomic_info(con, search_term = "Buteo", taxonomy = 1)

get_taxonomic_info(con, search_term = "Haliaeetus", taxonomy = 1)
get_taxonomic_info(con, search_term = "Haliaeetus", taxonomy = 2)
get_taxonomic_info(con, search_term = "Haliaeetus", taxonomy = 3)
get_taxonomic_info(con, search_term = "Icthyophaga", taxonomy = 1)
get_taxonomic_info(con, search_term = "Grus", taxonomy = 1)
get_taxonomic_info(con, search_term = "Grus", taxonomy = 2)
get_taxonomic_info(con, search_term = "Grus", taxonomy = 3)
get_taxonomic_info(con, search_term = "Antigone", taxonomy = 1)

eagles <- get_taxonomic_info(con, search_term = "Haliaeetus", taxonomy = 1)
eagles_concat <- paste(eagles$species_name)
placeholders <- paste(rep("$1", nrow(eagles)), collapse = ", ")

cracidae <- get_taxonomic_info(con, search_term = family1, taxonomy = 1)
cracidae_concat <- paste(cracidae$species_name)
placeholders <- paste(rep("$1", nrow(cracidae)), collapse = ", ")

passeriformes <- get_taxonomic_info(con, search_term = order1, taxonomy = 1)
#passeriformes_concat <- paste(passeriformes$species_name)
placeholders <- paste(rep("$1", nrow(passeriformes)), collapse = ", ")


sql <- paste0(
"SELECT
sp.species_name,
sp.species_family,
sp.species_order,
sp.species_tax,
ect.ect_habitat,
ect.ect_trophic_level,
ect.ect_trophic_niche,
ect.ect_primary_lifestyle
FROM
species as sp,
eco_trait_species as ect
WHERE
sp.species_name IN (",
placeholders,
")
AND
sp.species_tax = $2
AND
ect.species_id = sp.species_id;")

tax_vec <- rep(1, nrow(eagles))
tax_vec <- rep(1, nrow(cracidae))
tax_vec <- rep(1, nrow(passeriformes))

DBI::dbGetQuery(con, sql, params = list(eagles_concat, tax_vec))
DBI::dbGetQuery(con, sql, params = list(cracidae_concat, tax_vec))
DBI::dbGetQuery(con, sql, params = list(passeriformes$species_name, tax_vec))

species_data <- sql_query(con = con, parameter1 = eagles_concat, parameter2 = taxonomy)

#### Parameterized specific functions ####
forest_dwellers <- get_eco_traits(con, trait = "habitat", value = "Forest", 1)
carnivores <- get_eco_traits(con, trait = "trophic_level", value = "Carnivore", 1)
frugivores <- get_eco_traits(con, trait = "trophic_niche", value = "Frugivore", 1)

#### Morphological traits ####
buteo_morph <- get_morph_traits(con = con, species = "Buteo buteo", taxonomy = 1, aggregate = "all")
eagle_morph <- get_morph_traits(con = con, species = my_birds[1], taxonomy = 1, aggregate = "all")
buteo_sex <- get_morph_traits(con = con, species = "Buteo buteo", taxonomy = 1, aggregate = "sex")
buteo_life_stage <- get_morph_traits(con = con, species = "Buteo buteo", taxonomy = 1, aggregate = "life stage")
buteo_country <- get_morph_traits(con = con, species = "Buteo buteo", taxonomy = 1, aggregate = "country")
buteo_source_type <- get_morph_traits(con = con, species = "Buteo buteo", taxonomy = 1, aggregate = "source type")
buteo_test <- get_morph_traits(con = con, species = "Buteo buteo", taxonomy = 1, aggregate = "test")

#### Get traits ####
buteo_traits <- get_traits(con, "Buteo buteo", 1)
eagle_traits1 <- get_traits(con, my_birds[1], 1)
eagle_traits2 <- get_traits(con, my_birds[1], 2) # tax2 returns no result --> due to family names
eagle_traits3 <- get_traits(con, my_birds[1], 3)
penguin_traits1 <- get_traits(con, my_birds[2], 1)
penguin_traits2 <- get_traits(con, my_birds[2], 2) #tax2 returns no result --> due to family names
penguin_traits3 <- get_traits(con, my_birds[2], 3)

src_in_dat <- get_traits(con, my_birds[3], 1, source_cols = T)
