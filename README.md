
<!-- README.md is generated from README.Rmd. Please edit that file -->

# avonet

<!-- badges: start -->
<!-- badges: end -->

[AVONET](https://figshare.com/s/b990722d72a26b5bfead) is a
morphological, ecological and geographical dataset for all birds. For
more information on how the dataset was compiled, please refer to
[Tobias, et
al. 2022](https://onlinelibrary.wiley.com/doi/10.1111/ele.13898).

The goal of the `avonet` package is to give users access to AVONET data
comfortably from within an R session. For now, it provides functions for
connecting to the database and querying data. Future work will include
functions to filter and aggregate data on different taxonomic levels.

## Installation

You can install the development version of `avonet` from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("kfrac/avonet")
```

## Usage

Connecting to the AVONET database is as easy as entering your username
and password. We recommend using the `keyring` package to manage your
credentials.

``` r
library(avonet)
library(keyring)
db_user <- key_list("avonet")[1, "username"]
db_password <- key_get("avonet", username = db_user)
con <- connect_db(username = db_user, pw = db_password)
```

For now, you can query bird species according to 3 different taxonomies:
BirdLife (1), eBird (2) and BirdTree (3).

``` r
get_species(con, "Buteo buteo", 1)
#>   species_id species_name species_family   species_order species_tax
#> 1       1378  Buteo buteo   Accipitridae Accipitriformes           1
#>   ect_habitat ect_habitat_src ect_habitat_density ect_habitat_density_src
#> 1   Grassland               1                   3                       2
#>   ect_migration ect_migration_src ect_trophic_level ect_trophic_level_src
#> 1             2                 3         Carnivore                     4
#>   ect_trophic_niche ect_trophic_niche_src ect_primary_lifestyle
#> 1         Vertivore                     4           Insessorial
#>   ect_primary_lifestyle_src mass_value mass_trait_src mass_flag
#> 1                         5      759.1             20      <NA>
#>   spd_min_latitude spd_max_latitude spd_centroid_lat spd_centroid_lon
#> 1            14.89            67.81            52.89            40.23
#>   spd_range_size spd_spatial_source
#> 1       11719424                  6
```

Multiple species can also be queried simultaneously.

``` r
my_birds <- c("Haliaeetus leucocephalus", "Aptenodytes forsteri", "Cardinalis cardinalis")
get_species(con, my_birds, 1)
#>   species_id             species_name species_family   species_order
#> 1       4569 Haliaeetus leucocephalus   Accipitridae Accipitriformes
#> 2        799     Aptenodytes forsteri   Spheniscidae Sphenisciformes
#> 3       1692    Cardinalis cardinalis   Cardinalidae   Passeriformes
#>   species_tax ect_habitat ect_habitat_src ect_habitat_density
#> 1           1     Wetland               1                   3
#> 2           1      Marine               1                   3
#> 3           1   Shrubland               1                   2
#>   ect_habitat_density_src ect_migration ect_migration_src ect_trophic_level
#> 1                       2             3                 3         Carnivore
#> 2                       2             2                 3         Carnivore
#> 3                       2             1                 3         Herbivore
#>   ect_trophic_level_src ect_trophic_niche ect_trophic_niche_src
#> 1                     4          Omnivore                     4
#> 2                     4  Aquatic predator                     4
#> 3                     4          Omnivore                     4
#>   ect_primary_lifestyle ect_primary_lifestyle_src mass_value mass_trait_src
#> 1            Generalist                         5    4700.58             20
#> 2               Aquatic                         5   33569.33             20
#> 3           Insessorial                         5      42.64             20
#>   mass_flag spd_min_latitude spd_max_latitude spd_centroid_lat spd_centroid_lon
#> 1      <NA>            24.30            69.43            54.57          -113.86
#> 2      <NA>           -78.26           -65.12           -71.04            50.53
#> 3      <NA>            15.65            47.34            34.85           -92.41
#>   spd_range_size spd_spatial_source
#> 1     9351853.96                  6
#> 2       83236.83                  6
#> 3     5834572.06                  6
```

Remember to disconnect from the database at the end!

``` r
DBI::dbDisconnect(con)
```
