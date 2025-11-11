library(devtools)

# use_r("get_trait_groups")
# use_r("get_trait_list")
# use_r("list_traits")
# use_r("get_traits")
# use_r("query_species_id")
# use_r("get_metadata")
# use_r("helper_functions")
#
# install.packages("sos")
# library(sos)
# sos::findFn("env_unlock")

devtools::document()
check()

devtools::load_all()

con <- connect_db(username = "postgres", pw = "Frankfurterstr25!")

get_trait_groups()
get_trait_list("eco")
get_trait_list("geo")
get_trait_list("morpho")

get_traits("eco")



species <- "Buteo buteo"
my_birds <- c("Haliaeetus leucocephalus", "Aptenodytes forsteri",
              "Cardinalis cardinalis", "Nucifraga caryocatactes")
# taxonomy_1 <- 1
# taxonomy_2 <- rep(2, length(my_birds))
# tbl <- "species"
# vars <- c("species_id", "species_tax", "species_name", "species_family", "species_order")

library(glue)
sql_species <- glue_sql("
    SELECT {`vars`*}
    FROM {`tbl`}
    WHERE {`tbl`}.species_name = $1
    AND {`tbl`}.species_tax = $2
  ", .con = con)
query <- DBI::dbSendQuery(con, sql_species)
DBI::dbBind(query, list(species, taxonomy_1))
DBI::dbFetch(query)

DBI::dbBind(query, list(species, taxonomy_2[1]))
DBI::dbFetch(query)

DBI::dbBind(query, list(species, 3))
DBI::dbFetch(query)


DBI::dbBind(query, list(my_birds[1], 1))
DBI::dbFetch(query)

DBI::dbBind(query, list(my_birds[1], 2))
DBI::dbFetch(query)

DBI::dbBind(query, list(my_birds[1], 3))
DBI::dbFetch(query)


DBI::dbBind(query, list(my_birds[2], 1))
DBI::dbFetch(query)

DBI::dbBind(query, list(my_birds[2], 2))
DBI::dbFetch(query)

DBI::dbBind(query, list(my_birds[2], 3))
DBI::dbFetch(query)


DBI::dbBind(query, list(my_birds, taxonomy_2))
DBI::dbFetch(query)
DBI::dbClearResult(query)


fam1 <- "Cracidae"
fam2 <- "Scotocercidae"
sql_fam <- glue_sql("
    SELECT species_id
    FROM {`tbl`}
    WHERE {`tbl`}.species_family = $1
    AND {`tbl`}.species_tax = $2
  ", .con = con)
query_fam <- DBI::dbSendQuery(con, sql_fam)
DBI::dbBind(query_fam, list(fam1, taxonomy_1))
DBI::dbFetch(query_fam)

DBI::dbBind(query_fam, list(fam2, taxonomy_1))
test <- DBI::dbFetch(query_fam)
test_vec <- test[,1]

order1 <- "Passeriformes"
sql_order <- glue_sql("
    SELECT species_id
    FROM {`tbl`}
    WHERE {`tbl`}.species_order = $1
    AND {`tbl`}.species_tax = $2
  ", .con = con)
query_order <- DBI::dbSendQuery(con, sql_order)
test <- DBI::dbBind(query_order, list(order1, 1))
test_order <- DBI::dbFetch(query_order)
test_vec_order <- test_order[,1]

devtools::load_all()
library(glue)
con <- connect_db(username = "postgres", pw = "Frankfurterstr25!")
#query_species_id(con = con, species = "Buteo buteo", taxonomy = 1)
query_species_id(con = con, rank = "species", name = "Buteo buteo")
query_species_id(con = con, rank = "species", name = "Buteo buteo", taxonomy = 2)
query_species_id(con = con, rank = "species", name = "Buteo buteo", taxonomy = 3)

query_species_id(con = con, rank = "family", name = fam1)
query_species_id(con = con, rank = "family", name = fam1, taxonomy = 2)
query_species_id(con = con, rank = "order", name = fam1)

library(devtools)
use_r("get_eco_traits")

sql_habitat <- glue_sql("
    SELECT *
    FROM species as spc,
    eco_trait_species as ect
    WHERE spc.species_id = ect.species_id
    AND ect.ect_habitat = $1
    AND spc.species_tax = $2
  ", .con = con)
query_habitat <- DBI::dbSendQuery(con, sql_habitat)
DBI::dbBind(query_habitat, list("Forest", 1))
test <- DBI::dbFetch(query_habitat)

devtools::load_all()
forest_habitat <- get_eco_traits(con, trait = "habitat", value = "Forest", 1)
carnivore_trophic_level <- get_eco_traits(con, trait = "trophic_level", value = "Carnivore", 1)
frugivores <- get_eco_traits(con, trait = "trophic_niche", value = "Frugivore", 1)

get_eco_traits(con, trait = "havitat", value = "Forest", 1)
get_eco_traits(con, trait = "habitat", value = "Forest", 1)

"habitat" %in% eco_traits
"havitat" %in% eco_traits
"habitat_dens" %in% eco_traits
"habitat_density" %in% eco_traits




buteo <- get_morph_traits(con = con, species = "Buteo buteo", taxonomy = 1, aggregate = NULL)
buteo2 <- get_morph_traits(con = con, species = "Buteo buteo", taxonomy = 2, aggregate = NULL)
buteo3 <- get_morph_traits(con = con, species = "Buteo buteo", taxonomy = 3, aggregate = NULL)

baldeagle1 <- get_morph_traits(con = con, species = my_birds[1], taxonomy = 1, aggregate = NULL)
baldeagle2 <- get_morph_traits(con = con, species = my_birds[1], taxonomy = 2, aggregate = NULL)
baldeagle3 <- get_morph_traits(con = con, species = my_birds[1], taxonomy = 3, aggregate = NULL)

emppenguin1 <- get_morph_traits(con = con, species = my_birds[2], taxonomy = 1, aggregate = NULL)
emppenguin2 <- get_morph_traits(con = con, species = my_birds[2], taxonomy = 2, aggregate = NULL)
emppenguin3 <- get_morph_traits(con = con, species = my_birds[2], taxonomy = 3, aggregate = NULL)

cardinal1 <- get_morph_traits(con = con, species = my_birds[3], taxonomy = 1, aggregate = NULL)
cardinal2 <- get_morph_traits(con = con, species = my_birds[3], taxonomy = 2, aggregate = NULL)
cardinal3 <- get_morph_traits(con = con, species = my_birds[3], taxonomy = 3, aggregate = NULL)

nutcracker1 <- get_morph_traits(con = con, species = my_birds[4], taxonomy = 1, aggregate = NULL)
nutcracker2 <- get_morph_traits(con = con, species = my_birds[4], taxonomy = 2, aggregate = NULL)
nutcracker3 <- get_morph_traits(con = con, species = my_birds[4], taxonomy = 3, aggregate = NULL)

table(buteo$sd_sex)
table(buteo$sd_life_stage)
mean(buteo$wing_length)
mean(buteo$kipps_distance, na.rm = T)
mean(buteo$beak_length_culmen)

library(dplyr)

buteo %>%
  group_by(sd_sex) %>%
  summarise(across(where(is.numeric) & !ends_with("_id"),
                   list(mean = ~ mean(., na.rm = T), n = ~ sum(!is.na(.))))) -> buteo_table_sex

buteo %>%
  group_by(sd_life_stage) %>%
  summarise(across(where(is.numeric) & !ends_with("_id"),
                   list(mean = ~ mean(., na.rm = T), n = ~ sum(!is.na(.))))) -> buteo_table_lifestage

buteo %>%
  group_by(sd_country_wri) %>%
  summarise(across(where(is.numeric) & !ends_with("_id"),
                   list(mean = ~ mean(., na.rm = T), n = ~ sum(!is.na(.))))) -> buteo_table_country



################################################################################
buteo %>%
  group_by(sd_sex) %>%
  summarise(across(where(is.numeric), ~ mean(.x, na.rm = T), .names = "mean_{.col}")) -> buteo_new

cols_new <- paste0("mean_", cols)
buteo_new <- buteo_new[, -which(names(buteo_new) %in% cols_new)]
################################################################################




















library(devtools)
library(glue)
library(dplyr)
load_all()

con <- connect_db(username = "postgres", pw = "Frankfurterstr25!")

get_trait_groups()
get_trait_list("eco")
get_trait_list("geo")
get_trait_list("morpho")
#2 issues with get_trait_list()
#1. include new col w/short description of trait (written by Matthias/Susanne, added to DB by Tanja)
#2. include new col w/"species-level" vs. "specimen or species level"

species <- "Buteo buteo"
my_birds <- c("Haliaeetus leucocephalus", "Aptenodytes forsteri", "Cardinalis cardinalis")
fam1 <- "Cracidae"
fam2 <- "Scotocercidae"
order1 <- "Passeriformes"

query_species_id(con = con, rank = "species", name = "Buteo buteo")
query_species_id(con = con, rank = "species", name = "Buteo buteo", taxonomy = 2)
query_species_id(con = con, rank = "species", name = "Buteo buteo", taxonomy = 3)

query_species_id(con = con, rank = "family", name = fam1)
query_species_id(con = con, rank = "family", name = fam1, taxonomy = 2)
# Error w/ tax 2: English names should be removed from DB (request sent to Tanja)
query_species_id(con = con, rank = "order", name = fam1)
query_species_id(con = con, rank = "order", name = order1)






get_traits("eco")
get_traits("geo")

forest_habitat <- get_eco_traits(con, trait = "habitat", value = "Forest", 1)
carnivore_trophic_level <- get_eco_traits(con, trait = "trophic_level", value = "Carnivore", 1)
frugivores <- get_eco_traits(con, trait = "trophic_niche", value = "Frugivore", 1)

get_eco_traits(con, trait = "havitat", value = "Forest", 1)
get_eco_traits(con, trait = "habitat", value = "Forest", 1)

sql_query(con, parameter1 = species, parameter2 = 1)


test_sex <- get_morph_traits(con = con, species = "Buteo buteo", taxonomy = 1, aggregate = "sex")
test_life_stage <- get_morph_traits(con = con, species = "Buteo buteo", taxonomy = 1, aggregate = "life stage")
test_country <- get_morph_traits(con = con, species = "Buteo buteo", taxonomy = 1, aggregate = "country")
test_source_type <- get_morph_traits(con = con, species = "Buteo buteo", taxonomy = 1, aggregate = "source type")
test_test <- get_morph_traits(con = con, species = "Buteo buteo", taxonomy = 1, aggregate = "test")
test_1 <- get_morph_traits(con = con, species = my_birds[1], taxonomy = 1, aggregate = "source type")
test_2 <- get_morph_traits(con = con, species = my_birds[2], taxonomy = 1, aggregate = "source type")
test_3 <- get_morph_traits(con = con, species = my_birds[3], taxonomy = 1, aggregate = "source type")

identical(test_sex, buteo_table_sex)
identical(test_life_stage, buteo_table_lifestage)
identical(test_country, buteo_table_country)

get_morph_traits(con = con, species = my_birds[1], taxonomy = 1, aggregate = "sex")
get_morph_traits(con = con, species = my_birds[1], taxonomy = 1, aggregate = "life stage")
get_morph_traits(con = con, species = my_birds[1], taxonomy = 1)
get_morph_traits(con = con, species = my_birds[1], taxonomy = 1, aggregate = "life stageee")

get_morph_traits(con = con, species = species, taxonomy = 1, aggregate = "sex")
get_morph_traits(con = con, species = species, taxonomy = 1, aggregate = "life stage")
get_morph_traits(con = con, species = species, taxonomy = 1)
get_morph_traits(con = con, species = species, taxonomy = 1, aggregate = "life stageee")
get_morph_traits(con = con, species = species, taxonomy = 1, aggregate = "country")
get_morph_traits(con = con, species = species, taxonomy = 1, aggregate = "measurer_comment")



##### building get_metadata() function ####
test1 <- get_eco_traits(con, trait = "habitat", value = "Forest", 1)
test2 <- get_eco_traits(con, trait = "trophic_niche", value = "Vertivore", 1)
test3 <- get_eco_traits(con, trait = "primary_lifestyle", value = "Insessorial", 1)

test4 <- get_morph_traits(con, species = "Buteo buteo", taxonomy = 1)
test5 <- get_morph_traits(con, species = "Buteo buteo", taxonomy = 2)
test6 <- get_morph_traits(con, species = "Buteo buteo", taxonomy = 3)

test1_metadata <- get_metadata(test1)
get_metadata(test2)
get_metadata(test3)
get_metadata(test4)

list1 <- list(test1_metadata, test1)
names(list1) <- c("metadata", "data")
list1[["metadata"]]

test |>
  select(ends_with("_src")) -> source_cols
vals <- unique(as.vector(as.matrix(source_cols)))

vals2 <- c(9:15)

#### Option1: Filter which metadata we query from DB ####
sql_metadata <- glue_sql("
         SELECT *
         FROM trait_source_detailed as tsd
         WHERE tsd.trait_src_id in ($1)",
         .con = con)
query_metadata <- DBI::dbSendQuery(con, sql_metadata)
DBI::dbBind(query_metadata, list(vals))
test_metadata <- DBI::dbFetch(query_metadata)

test_metadata[, colSums(is.na(test_metadata)) == 0]


DBI::dbBind(query_metadata, list(vals2))
test_metadata2 <- DBI::dbFetch(query_metadata)
test_metadata2[, colSums(is.na(test_metadata2)) == 0]

#### Option2: Query all metadata from DB and then filter ####
sql_metadata2 <- glue_sql("
         SELECT *
         FROM trait_source_detailed",
                          .con = con)
query_metadata2 <- DBI::dbSendQuery(con, sql_metadata2)
DBI::dbBind(query_metadata2)
test_metadata2 <- DBI::dbFetch(query_metadata2)

test_metadata2[, colSums(is.na(test_metadata)) == 0]
test_metadata2[20,]


#### Get traits function ####
buteo <- get_traits(con, "Buteo buteo", 1)
mybirds1_1 <- get_traits(con, my_birds[1], 1)
mybirds1_2 <- get_traits(con, my_birds[1], 2) # tax2 returns no result?
mybirds1_3 <- get_traits(con, my_birds[1], 3)
mybirds2_1 <- get_traits(con, my_birds[2], 1)
mybirds2_2 <- get_traits(con, my_birds[2], 2) #tax2 returns no result?
mybirds2_3 <- get_traits(con, my_birds[2], 3)

#### getting all col values for list_traits ####
prefixes <- c("ect_", "sd_", "geo_")
bigdf <- DBI::dbGetQuery(con, "SELECT * FROM eco_trait_species ORDER BY ect_id ASC;")
bigdf <- remove_suffix_columns(bigdf, c("_id"))
bigdf <- remove_prefixes(bigdf, prefixes)


traits_list <- lapply(bigdf, function(x) paste0(unique(x), collapse = ", "))


output <- data.frame(
  trait = rep(names(traits_list), times = lengths(traits_list)),
  value = unlist(traits_list, use.names = FALSE)
)
output

as_tibble(output)
