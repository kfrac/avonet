
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
and password.

``` r
library(avonet)
con <- connect(username = "postgres", pw = "Frankfurterstr25!")
```

For now, you can query bird species according to 3 different taxonomies:
BirdLife (1), eBird (2) and BirdTree (3).

``` r
get_species(con, "Buteo buteo", 1)
#>   species_id species_name species_family   species_order species_tax
#> 1       1378  Buteo buteo   Accipitridae Accipitriformes           1
#>   ect_habitat ect_habitat_density ect_migration ect_trophic_level
#> 1   Grassland                   3             2         Carnivore
#>   ect_trophic_niche ect_primary_lifestyle mass_value mass_flag
#> 1         Vertivore           Insessorial      759.1      <NA>
```

Multiple species can also be queried simultaneously.

``` r
my_birds <- c("Haliaeetus leucocephalus", "Aptenodytes forsteri", "Cardinalis cardinalis")
result_df <- get_species(con, my_birds, 1)
```

Remember to disconnect from the database at the end!

``` r
DBI::dbDisconnect(con)
```
