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
connect_db(username = db_user, pw = db_password)

#### Get taxonomic info of target species ####
get_taxonomic_info(species, 1)
get_taxonomic_info(my_birds, 1)
get_taxonomic_info(family2, 1)

#### User-facing functions for finding groups ####
get_trait_groups()
get_trait_list("eco")
get_trait_list("reproductive")
get_trait_list("social")
get_trait_list("morpho")
get_trait_list("geo")
get_trait_list() -> trait_list

#get_traits("eco")
get_traits("Buteo buteo", 1)$data
get_traits(family1, 1)$data
test <- get_traits("Buteo buteo", 1)

time1 <- Sys.time()
passeriformes <- get_traits(order1, taxonomy = 1)
time2 <- Sys.time()
time2 - time1

ncol(test$detailed_sources)
detailed_sources <- subset(test$detailed_sources, select =-c(source, description))
duplicated(detailed_sources)

fam1 <- get_traits(family1, 1)$data
fam1_forest <- fam1[which(fam1$habitat == "Forest"),]
test_forest <- get_traits(family1, 1, filter = list(habitat = "Forest"))$data
identical(fam1_forest, test_forest)

test2_forest <- get_traits(family1, 1, filter = list(habitat = "Forest", trophic_niche = "Omnivore"))$data

test3_forest <- get_traits(family1, 1, filter = list(habitat = "Forest", primary_lifestyle = "Generalist"))$data


fam1_omnivore <- fam1[which(fam1$trophic_niche == "Omnivore"),]
test_omnivore <- get_traits(family1, 1, filter = list(trophic_niche = "Omnivore"))$data
identical(fam1_omnivore, test_omnivore)

fam1_non_tropic <- fam1[which(fam1$max_latitude > 23.5),]
test_non_tropic <- get_traits(family1, 1, filter = list(max_latitude = list(op = ">",  val = 23.5)))$data
identical(fam1_non_tropic, test_non_tropic)

fam1_small <- fam1[which(fam1$mass_value < 1000),]
test_small <- get_traits(family1, 1, filter = list(mass_value = list(op = "<", val = 1000)))$data
identical(fam1_small, test_small)

get_taxonomic_info(search_term = species, taxonomy = 1)
get_taxonomic_info(search_term = family1, taxonomy = 1)
get_taxonomic_info(search_term = "Buteo", taxonomy = 1)

get_taxonomic_info(search_term = "Haliaeetus", taxonomy = 1)
get_taxonomic_info(search_term = "Haliaeetus", taxonomy = 2)
get_taxonomic_info(search_term = "Haliaeetus", taxonomy = 3)
get_taxonomic_info(search_term = "Icthyophaga", taxonomy = 1)
get_taxonomic_info(search_term = "Grus", taxonomy = 1)
get_taxonomic_info(search_term = "Grus", taxonomy = 2)
get_taxonomic_info(search_term = "Grus", taxonomy = 3)
get_taxonomic_info(search_term = "Antigone", taxonomy = 1)
get_taxonomic_info(search_term = "accipitridae", taxonomy = 1)
get_taxonomic_info(search_term = "ACCIPITRIDAE", taxonomy = 1)

eagles <- get_taxonomic_info(search_term = "Haliaeetus", taxonomy = 1)
eagles_concat <- paste(eagles$species_name)
placeholders <- paste(rep("$1", nrow(eagles)), collapse = ", ")

cracidae <- get_taxonomic_info(search_term = family1, taxonomy = 1)
cracidae_concat <- paste(cracidae$species_name)
placeholders <- paste(rep("$1", nrow(cracidae)), collapse = ", ")

passeriformes <- get_taxonomic_info(search_term = order1, taxonomy = 1)
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

tax_vec_eagles <- rep(1, nrow(eagles))
tax_vec_cracidae <- rep(1, nrow(cracidae))
tax_vec <- rep(1, nrow(passeriformes))

DBI::dbGetQuery(con, sql, params = list(eagles_concat, tax_vec_eagles))
DBI::dbGetQuery(con, sql, params = list(cracidae_concat, tax_vec_cracidae))
time1 <- Sys.time()
DBI::dbGetQuery(con, sql, params = list(passeriformes$species_name, tax_vec))
time2 <- Sys.time()
time2 - time1

species_data <- avonet:::query_species_traits(species = eagles_concat, taxonomy = 1)

#### Morphological traits ####
buteo_morph <- get_morph_traits(species = "Buteo buteo", taxonomy = 1, aggregate = "all")
eagle_morph <- get_morph_traits(species = my_birds[1], taxonomy = 1, aggregate = "all")
buteo_sex <- get_morph_traits(species = "Buteo buteo", taxonomy = 1, aggregate = "sex")
buteo_life_stage <- get_morph_traits(species = "Buteo buteo", taxonomy = 1, aggregate = "life stage")
buteo_country <- get_morph_traits(species = "Buteo buteo", taxonomy = 1, aggregate = "country")
buteo_source_type <- get_morph_traits(species = "Buteo buteo", taxonomy = 1, aggregate = "source type")
buteo_test <- get_morph_traits(species = "Buteo buteo", taxonomy = 1, aggregate = "test")

#### Get traits ####
buteo_traits <- get_traits("Buteo buteo", 1)
eagle_traits1 <- get_traits(my_birds[1], 1)
eagle_traits2 <- get_traits(my_birds[1], 2) # tax2 returns no result --> due to family names
eagle_traits3 <- get_traits(my_birds[1], 3)
penguin_traits1 <- get_traits(my_birds[2], 1)
penguin_traits2 <- get_traits(my_birds[2], 2) #tax2 returns no result --> due to family names
penguin_traits3 <- get_traits(my_birds[2], 3)

src_in_dat <- get_traits(my_birds[3], 1, source_cols = T)
