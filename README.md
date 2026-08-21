
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
comfortably from within an R session. It queries a Postgres database
directly, so there are no flat files to download or keep in sync: you
connect once, then pull traits for any taxon, filter them, and get the
literature sources needed to cite them back alongside the data.

## Installation

You can install the development version of `avonet` from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("kfrac/avonet")
```

## Connecting

Connecting to the AVONET database is as easy as entering your username
and password. We recommend using the `keyring` package to manage your
credentials.

``` r
library(avonet)
library(keyring)
db_user <- key_list("avonet")[1, "username"]
db_password <- key_get("avonet", username = db_user)
connect_db(username = db_user, pw = db_password)
```

Every function below assumes an open connection. Bird taxonomy is not
settled, so AVONET carries three parallel taxonomies and every query
takes one: BirdLife (`1`), eBird (`2`) or BirdTree (`3`).

## Finding out what is available

Traits are organised into groups, and each group can be listed with its
descriptions, possible values and primary source.

``` r
get_trait_groups()
#> [1] "eco"    "social" "morpho" "geo"
```

``` r
get_trait_list(group = "eco")
#> # A tibble: 6 × 5
#>   trait             resolution description                  value primary_source
#>   <chr>             <chr>      <chr>                        <chr> <chr>         
#> 1 habitat           species    Categorized habitat types    Coas… Tobias et al.…
#> 2 habitat_density   species    Categorized habitat density… 1, 2… Tobias et al.…
#> 3 migration         species    Migratory behavior types ca… 1, 2… Tobias & Pigo…
#> 4 trophic_level     species    Categorized trophic level t… Carn… Tobias et al.…
#> 5 trophic_niche     species    Categorized trophic niche t… Aqua… Tobias et al.…
#> 6 primary_lifestyle species    Categorized primary lifesty… Aeri… Tobias et al.…
```

For a categorical trait, the valid levels can be pulled directly —
useful for building a filter without guessing at spelling.

``` r
get_trait_levels("habitat")
#>  [1] "Coastal"        "Desert"         "Forest"         "Grassland"     
#>  [5] "Human modified" "Marine"         "Riverine"       "Rock"          
#>  [9] "Shrubland"      "Wetland"        "Woodland"
```

Passing `return_defs = TRUE` returns what each level actually means,
rather than just its name.

``` r
get_trait_levels("trophic_niche", return_defs = TRUE)
#> # A tibble: 10 × 3
#>    trait             short_description                          long_description
#>    <chr>             <chr>                                      <chr>           
#>  1 Aquatic Predator  species obtaining at least 60% of food re… species obtaini…
#>  2 Frugivore         species obtaining at least 60% of food re… species obtaini…
#>  3 Granivore         species obtaining at least 60% of food re… species obtaini…
#>  4 Herbivore         species obtaining at least 60% of food re… species obtaini…
#>  5 Herbivore aquatic species obtaining at least 60% of food re… species obtaini…
#>  6 Invertivore       species obtaining at least 60% of food re… species obtaini…
#>  7 Nectarivore       species obtaining at least 60% of food re… species obtaini…
#>  8 Omnivore          Species using multiple niches, within or … Species using m…
#>  9 Scavenger         species obtaining at least 60% of food re… species obtaini…
#> 10 Vertivore         species obtaining at least 60% of food re… species obtaini…
```

## Querying species-level data

`get_species()` is the lightweight path: give it species binomials and
it returns one row per species.

``` r
get_species("Buteo buteo", 1)
#>       species       family           order tax   habitat habitat_density
#> 1 Buteo buteo Accipitridae Accipitriformes   1 Grassland               3
#>   migration trophic_level trophic_niche primary_lifestyle mass_value mass_flag
#> 1         2     Carnivore     Vertivore       Insessorial      759.1      <NA>
#>   min_latitude max_latitude centroid_lat centroid_lon range_size
#> 1        14.89        67.81        52.89        40.23   11719424
```

Multiple species can also be queried simultaneously.

``` r
my_birds <- c("Haliaeetus leucocephalus", "Aptenodytes forsteri", "Cardinalis cardinalis")
get_species(my_birds, 1)
#>                    species       family           order tax   habitat
#> 1 Haliaeetus leucocephalus Accipitridae Accipitriformes   1   Wetland
#> 2     Aptenodytes forsteri Spheniscidae Sphenisciformes   1    Marine
#> 3    Cardinalis cardinalis Cardinalidae   Passeriformes   1 Shrubland
#>   habitat_density migration trophic_level    trophic_niche primary_lifestyle
#> 1               3         3     Carnivore         Omnivore        Generalist
#> 2               3         2     Carnivore Aquatic predator           Aquatic
#> 3               2         1     Herbivore         Omnivore       Insessorial
#>   mass_value mass_flag min_latitude max_latitude centroid_lat centroid_lon
#> 1    4700.58      <NA>        24.30        69.43        54.57      -113.86
#> 2   33569.33      <NA>       -78.26       -65.12       -71.04        50.53
#> 3      42.64      <NA>        15.65        47.34        34.85       -92.41
#>   range_size
#> 1 9351853.96
#> 2   83236.83
#> 3 5834572.06
```

Each trait in the database carries a source. These are stripped by
default, since they hold source IDs rather than values, but
`source_cols = TRUE` keeps them inline.

``` r
names(get_species("Buteo buteo", 1, source_cols = TRUE))
#>  [1] "id"                    "species"               "family"               
#>  [4] "order"                 "tax"                   "habitat"              
#>  [7] "habitat_src"           "habitat_density"       "habitat_density_src"  
#> [10] "migration"             "migration_src"         "trophic_level"        
#> [13] "trophic_level_src"     "trophic_niche"         "trophic_niche_src"    
#> [16] "primary_lifestyle"     "primary_lifestyle_src" "mass_value"           
#> [19] "mass_trait_src"        "mass_flag"             "min_latitude"         
#> [22] "max_latitude"          "centroid_lat"          "centroid_lon"         
#> [25] "range_size"            "spatial_source"
```

## Querying any taxonomic rank

`get_traits()` is the main entry point. Unlike `get_species()` it
accepts names at any rank — species, genus, family or order — and works
out which is which, so a single call can mix them.

``` r
buteo <- get_traits("Buteo buteo", taxonomy = 1)
#> Detected rank 'species' for taxon 'Buteo buteo'.
#> Resolved 'Buteo buteo' (species) to 1 species.
#> Querying 1 species in total.
#> Output contains data from 7 sources. Please refer to the metadata for details.
names(buteo)
#> [1] "metadata_summary" "data"             "detailed_sources"
```

The result is a list. `data` holds one row per species,
`metadata_summary` describes each trait and where it came from, and
`detailed_sources` holds the full literature references behind those
sources — so a result can be cited without a second lookup.

``` r
buteo$data[, c("species", "family", "habitat", "trophic_niche", "mass_value")]
#>       species       family   habitat trophic_niche mass_value
#> 1 Buteo buteo Accipitridae Grassland     Vertivore      759.1
```

``` r
head(buteo$metadata_summary, 4)
#>             trait
#> 1         habitat
#> 2 habitat_density
#> 3       migration
#> 4   trophic_level
#>                                                                description
#> 1                                                Categorized habitat types
#> 2                                        Categorized habitat density types
#> 3 Migratory behavior types categorized from 1 (sedentary) to 3 (migratory)
#> 4                                          Categorized trophic level types
#>          primary_source source
#> 1  Tobias et al. (2022)      1
#> 2  Tobias et al. (2016)      2
#> 3 Tobias & Pigot (2019)      3
#> 4  Tobias et al. (2022)      4
```

Ranks are detected per name, and reported so you can see how an
ambiguous name was read.

``` r
hawks <- get_traits("Accipitridae", taxonomy = 1)
#> Detected rank 'family' for taxon 'Accipitridae'.
#> Resolved 'Accipitridae' (family) to 250 species.
#> Querying 250 species in total.
#> Output contains data from 11 sources. Please refer to the metadata for details.
nrow(hawks$data)
#> [1] 250
```

## Filtering

Filters are a named list, applied to the data after it returns.
Categorical traits take a value or a set of values; numeric traits take
an operator and a value. Conditions combine with AND.

``` r
forest_hawks <- get_traits(
  "Accipitridae",
  taxonomy = 1,
  filter = list(habitat    = "Forest",
                range_size = list(op = "<", val = 5000000))
)

head(forest_hawks$data[, c("species", "habitat", "range_size", "mass_value")])
#>                 species habitat range_size mass_value
#> 1 Accipiter albogularis  Forest   37461.21     248.75
#> 4  Accipiter brachyurus  Forest   35580.71     142.00
#> 5    Accipiter brevipes  Forest 2936751.80     186.48
#> 6     Accipiter butleri  Forest     327.84     122.00
#> 7 Accipiter castanilius  Forest 2096401.63     157.51
#> 9    Accipiter collaris  Forest  253265.36      97.80
```

Trait names can be given in short form (`habitat`, `range_size`, `mass`)
or as their full database column names. Filtering on a column that was
not queried is an error rather than an empty result, and the message
lists what is available.

## Specimen-level measurements

Ecological, mass and geographic traits are recorded once per species.
Morphological measurements are recorded per measured individual, so
there are many rows per species. Rather than repeating every
species-level value across each specimen, `resolution = "specimen"`
returns the measurements as a separate element and leaves `data` at one
row per species.

``` r
specimens <- get_traits("Buteo buteo", taxonomy = 1, resolution = "specimen")
names(specimens)
#> [1] "metadata_summary" "data"             "detailed_sources" "specimen_data"
head(specimens$specimen_data)
#>       species source_code source_type        country_wri    sex life_stage
#> 1 Buteo buteo       NHMUK      museum        Netherlands   male      Adult
#> 2 Buteo buteo       NHMUK      museum     United Kingdom   male      Adult
#> 3 Buteo buteo       NHMUK      museum     United Kingdom   male      Adult
#> 4 Buteo buteo       NHMUK      museum            Germany female      Adult
#> 5 Buteo buteo       NHMUK      museum Republic of Serbia   male      Adult
#> 6 Buteo buteo       NHMUK      museum     United Kingdom   male      Adult
#>   beak_length_culmen beak_length_nares beak_width gape_width beak_depth_nares
#> 1               36.2              22.6       12.7         NA             12.2
#> 2               36.1              23.8       13.7         NA             16.3
#> 3               37.2              23.9       11.9         NA             16.3
#> 4                 NA                NA         NA         NA               NA
#> 5               34.9              21.5       13.2         NA             16.3
#> 6               34.8              19.9       12.1         NA             16.6
#>   beak_depth_max wing_length kipps_distance secondary_1 tail_length
#> 1             NA         394          155.0       239.0         207
#> 2             NA         369          144.0       225.0          NA
#> 3             NA         371          144.0       227.0         202
#> 4             NA         380          144.0       236.0          NA
#> 5             NA         389          161.0       228.0         221
#> 6             NA         376          134.9       241.1         208
#>   tail_graduation tarsus_length tarsus_diameter_sag tarsus_diameter_lat
#> 1              NA          70.3                  NA                  NA
#> 2              NA          59.7                  NA                  NA
#> 3              NA          73.1                  NA                  NA
#> 4              NA            NA                  NA                  NA
#> 5              NA          85.5                  NA                  NA
#> 6              NA          65.5                  NA                  NA
#>   back_toe specimen_identifier       avibase_id
#> 1       NA      1905.6.28.94_1 AVIBASE-3C6D4915
#> 2       NA      1913.5.13.21_1 AVIBASE-3C6D4915
#> 3       NA   1919.12.10.1310_1 AVIBASE-3C6D4915
#> 4       NA     1934.1.1.1113_1 AVIBASE-3C6D4915
#> 5       NA    1934.11.20.187_1 AVIBASE-3C6D4915
#> 6       NA       1965.M.1251_1 AVIBASE-3C6D4915
```

Supplying `aggregate` collapses those measurements into per-species
means and counts for a given grouping — `"sex"`, `"life stage"`,
`"country"`, `"source type"` or `"all"`.

``` r
by_sex <- get_traits(
  "Buteo buteo",
  taxonomy = 1,
  resolution = "specimen",
  aggregate  = "sex"
)

by_sex$specimen_data
#> # A tibble: 3 × 32
#> # Groups:   species [1]
#>   species     aggregated_by beak_length_culmen_mean beak_length_culmen_n
#>   <chr>       <pq_sex>                        <dbl>                <int>
#> 1 Buteo buteo female                           37.2                    4
#> 2 Buteo buteo male                             35.6                    9
#> 3 Buteo buteo unknown                          34.8                    2
#> # ℹ 28 more variables: beak_length_nares_mean <dbl>, beak_length_nares_n <int>,
#> #   beak_width_mean <dbl>, beak_width_n <int>, gape_width_mean <dbl>,
#> #   gape_width_n <int>, beak_depth_nares_mean <dbl>, beak_depth_nares_n <int>,
#> #   beak_depth_max_mean <dbl>, beak_depth_max_n <int>, wing_length_mean <dbl>,
#> #   wing_length_n <int>, kipps_distance_mean <dbl>, kipps_distance_n <int>,
#> #   secondary_1_mean <dbl>, secondary_1_n <int>, tail_length_mean <dbl>,
#> #   tail_length_n <int>, tail_graduation_mean <dbl>, tail_graduation_n <int>, …
```

## Checking a name before querying

Taxonomies disagree, and names get split, merged and renamed.
`get_taxonomic_info()` shows what a search term resolves to, and how it
matched.

``` r
get_taxonomic_info(search_term = "Buteo buteo", taxonomy = 1)
#>       species       family           order match_type
#> 1 Buteo buteo Accipitridae Accipitriformes    species
```

``` r
head(get_taxonomic_info(search_term = "Buteo", taxonomy = 1))
#>              species       family           order match_type
#> 1     Buteo albigula Accipitridae Accipitriformes      genus
#> 2  Buteo albonotatus Accipitridae Accipitriformes      genus
#> 3        Buteo augur Accipitridae Accipitriformes      genus
#> 4    Buteo auguralis Accipitridae Accipitriformes      genus
#> 5 Buteo brachypterus Accipitridae Accipitriformes      genus
#> 6   Buteo brachyurus Accipitridae Accipitriformes      genus
```

## Disconnecting

Remember to disconnect from the database at the end!

``` r
disconnect_db()
```
