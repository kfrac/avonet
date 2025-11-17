library(devtools)
library(dplyr)

devtools::load_all()

#### Sample birds ####
species <- "Buteo buteo"
my_birds <- c("Haliaeetus leucocephalus", "Aptenodytes forsteri",
              "Cardinalis cardinalis", "Nucifraga caryocatactes")
family1 <- "Cracidae"
family2 <- "Scotocercidae"
order1 <- "Passeriformes"

#### Establish connection to database ####
con <- connect_db(username = "postgres", pw = "Frankfurterstr25!")

#### User-facing functions for finding groups ####
get_trait_groups()
get_trait_list("eco")
get_trait_list("geo")
get_trait_list("morpho")
get_trait_list() -> trait_list

get_traits("eco")

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
