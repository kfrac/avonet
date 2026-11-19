
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

No database credentials? The package bundles a snapshot of two taxa and
runs without a connection — see [Working without a
connection](#working-without-a-connection) at the end.

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

Every function below assumes an open connection to the database. AVONET
carries three parallel taxonomies and every query must provide one:
BirdLife (`1`), eBird (`2`) or BirdTree (`3`).

## Two kinds of data

AVONET holds trait data at two resolutions, and the difference shapes
every query.

**Species-level** traits — habitat, trophic niche, mass, range size and
the rest — are recorded once per species, so a query returns one row per
species.

**Specimen-level** morphology — beak, wing, tarsus and tail measurements
— is recorded per individual bird that was measured, so a species may
have one row or dozens. These measurements are what distinguishes AVONET
from a species checklist: they carry the within-species variation that a
single published mean throws away, and each one comes with the sex, life
stage, country and source of the bird it was taken from.

`get_traits()` returns both. The species-level traits come back in
`data`, one row per species; the measurements come back separately in
`specimen_data`, one row per specimen. Keeping them apart avoids
repeating every species-level value across each specimen of that
species. Pass `resolution = "species"` to skip the specimen query when
you do not need it.

## Getting your bearings

Traits are organized into groups, and each group can be listed with its
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

## Querying traits

`get_traits()` is the single entry point for trait data. It accepts
names at any rank — species, genus, family or order — and works out
which is which, so one call can mix them.

``` r
buteo <- get_traits("Buteo", taxonomy = 1)
#> Detected rank 'genus' for taxon 'Buteo'.
#> Resolved 'Buteo' (genus) to 27 species.
#> Querying 27 species in total.
#> Retrieved 164 specimen rows.
#> Output contains data from 9 sources. Please refer to the metadata for details.
names(buteo)
#> [1] "metadata_summary" "data"             "detailed_sources" "specimen_data"
```

The result is a list: `data` holds one row per species, `specimen_data`
holds the individual measurements behind those species,
`metadata_summary` describes each trait and where it came from, and
`detailed_sources` holds the full literature references behind those
sources — so a result can be cited without a second lookup.

``` r
buteo$data[, c("species", "family", "habitat", "trophic_niche", "mass_value")]
#>                species       family   habitat trophic_niche mass_value
#> 1       Buteo albigula Accipitridae    Forest     Vertivore     524.99
#> 2    Buteo albonotatus Accipitridae    Forest     Vertivore     745.92
#> 3          Buteo augur Accipitridae  Woodland     Vertivore    1099.18
#> 4      Buteo auguralis Accipitridae    Forest     Vertivore     663.92
#> 5   Buteo brachypterus Accipitridae    Forest     Vertivore     511.00
#> 6     Buteo brachyurus Accipitridae    Forest     Vertivore     496.01
#> 7          Buteo buteo Accipitridae Grassland     Vertivore     759.10
#> 8  Buteo galapagoensis Accipitridae  Woodland     Vertivore    1137.44
#> 9     Buteo hemilasius Accipitridae Grassland     Vertivore    1358.89
#> 10   Buteo jamaicensis Accipitridae  Woodland     Vertivore    1101.16
#> 11     Buteo japonicus Accipitridae Grassland     Vertivore         NA
#> 12       Buteo lagopus Accipitridae Grassland     Vertivore     949.76
#> 13      Buteo lineatus Accipitridae  Woodland     Vertivore     603.72
#> 14       Buteo nitidus Accipitridae    Forest     Vertivore     519.04
#> 15    Buteo oreophilus Accipitridae    Forest     Vertivore     699.99
#> 16     Buteo plagiatus Accipitridae    Forest     Vertivore         NA
#> 17   Buteo platypterus Accipitridae    Forest     Vertivore     453.65
#> 18      Buteo refectus Accipitridae Grassland     Vertivore         NA
#> 19       Buteo regalis Accipitridae Grassland     Vertivore    1437.18
#> 20      Buteo ridgwayi Accipitridae    Forest     Vertivore     315.00
#> 21       Buteo rufinus Accipitridae Grassland     Vertivore    1166.18
#> 22    Buteo rufofuscus Accipitridae Grassland     Vertivore    1530.00
#> 23  Buteo socotraensis Accipitridae Grassland     Vertivore         NA
#> 24    Buteo solitarius Accipitridae    Forest     Vertivore     500.88
#> 25     Buteo swainsoni Accipitridae Grassland     Vertivore     946.61
#> 26    Buteo trizonatus Accipitridae    Forest     Vertivore     568.00
#> 27     Buteo ventralis Accipitridae    Forest     Vertivore    1190.52
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

Taxonomic ranks are detected per name, and reported, so you can see how
an ambiguous name was read. Here `resolution = "species"` keeps the call
to the species-level traits alone.

``` r
hawks <- get_traits("Accipitridae", taxonomy = 1, resolution = "species")
#> Detected rank 'family' for taxon 'Accipitridae'.
#> Resolved 'Accipitridae' (family) to 250 species.
#> Querying 250 species in total.
#> Warning: 1 of 250 resolved species have no ecological, mass or geographical trait data:
#>   - Bermuteo avivorus
#> Output contains data from 11 sources. Please refer to the metadata for details.
nrow(hawks$data)
#> [1] 250
```

Each trait carries a source. These are stripped from `data` by default,
since the same information is summarized in `metadata_summary`, but
`source_cols = TRUE` keeps them inline.

``` r
names(get_traits("Buteo buteo", taxonomy = 1, source_cols = TRUE)$data)
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
#> Warning: 1 of 250 resolved species have no ecological, mass or geographical trait data:
#>   - Bermuteo avivorus

head(forest_hawks$data[, c("species", "habitat", "range_size", "mass_value")])
#>                 species habitat range_size mass_value
#> 1 Accipiter albogularis  Forest   37461.21     248.75
#> 4  Accipiter brachyurus  Forest   35580.71     142.00
#> 5    Accipiter brevipes  Forest 2936751.80     186.48
#> 6     Accipiter butleri  Forest     327.84     122.00
#> 7 Accipiter castanilius  Forest 2096401.63     157.51
#> 9    Accipiter collaris  Forest  253265.36      97.80
```

Filtering on a column that was not queried is an error rather than an
empty result, and the message lists what is available.

Species-level and specimen-level conditions can be mixed in one list,
with nothing to declare — each name is matched against the species-level
columns first and the specimen-level ones second.

``` r
wide_billed <- get_traits(
  "Accipitridae",
  taxonomy = 1,
  filter = list(habitat    = "Forest",
                beak_width = list(op = ">", val = 20))
)

nrow(wide_billed$data)            # forest species with a wide-billed specimen
#> [1] 6
nrow(wide_billed$specimen_data)   # and only those specimens
#> [1] 13
```

The two are applied in that order, so specimens are fetched only for the
species that passed the species-level conditions. A specimen-level
condition then narrows both elements: `specimen_data` keeps the matching
specimens, and `data` keeps the species that still have at least one —
so the two always describe the same set of species. `aggregate` runs
after both.

## Working with the measurements

`specimen_data` holds one row per measured bird, with the species it
belongs to in the first column.

``` r
specimens <- get_traits("Buteo buteo", taxonomy = 1)
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
`"country"`, `"source type"` or `"all"`. Grouping is always by species
first, so a call covering several species never pools their measurements
together.

``` r
by_sex <- get_traits("Buteo buteo", taxonomy = 1, aggregate = "sex")

by_sex$specimen_data
#> # A tibble: 3 × 32
#>   species     aggregated_by beak_length_culmen_mean beak_length_culmen_n
#>   <chr>       <fct>                           <dbl>                <int>
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

## Working without a connection

The package bundles a snapshot of two taxa — the order Accipitriformes
and the family Sylviidae — across every taxonomy that carries them.
Everything works against it with no database at all, which is what makes
these examples reproducible and lets you try the package before asking
for credentials.

The connection was closed in the section above, and yet:

``` r
hawks <- get_traits("Accipitriformes", taxonomy = 1)
#> No database connection: reading bundled example data (Accipitriformes and Sylviidae; extracted 2026-11-20). These cover only those taxa -- call connect_db() for the full database.
#> Detected rank 'order' for taxon 'Accipitriformes'.
#> Resolved 'Accipitriformes' (order) to 252 species.
#> Querying 252 species in total.
#> Warning: 1 of 252 resolved species have no ecological, mass or geographical trait data:
#>   - Bermuteo avivorus
#> Warning: 2 of 252 species have no specimen records:
#>   - Bermuteo avivorus
#>   - Milvus aegyptius
#> Retrieved 1472 specimen rows.
#> Output contains data from 11 sources. Please refer to the metadata for details.
nrow(hawks$data)
#> [1] 252
nrow(hawks$specimen_data)
#> [1] 1472
```

``` r
head(get_taxonomic_info("Sylviidae", taxonomy = 1))
#> No database connection: reading bundled example data (Accipitriformes and Sylviidae; extracted 2026-11-20). These cover only those taxa -- call connect_db() for the full database.
#>                         species    family         order match_type
#> 1              Chamaea fasciata Sylviidae Passeriformes     family
#> 2 Chleuasicus atrosuperciliaris Sylviidae Passeriformes     family
#> 3           Cholornis paradoxus Sylviidae Passeriformes     family
#> 4            Cholornis unicolor Sylviidae Passeriformes     family
#> 5          Chrysomma altirostre Sylviidae Passeriformes     family
#> 6             Chrysomma sinense Sylviidae Passeriformes     family
```

There is nothing to switch on. With no usable connection the package
reads the bundled data and says so; with one it reads the database.
`connect_db()` is the only thing that changes which, so a snapshot can
never shadow live data.

Both taxa are bundled complete, so any species, genus or family at or
below them is a faithful answer, and a taxon with nothing bundled
returns no rows just as an unknown one would against the database. A
taxon *wider* than either — the order Passeriformes, say, which contains
Sylviidae — returns only the bundled part of itself and warns that it
has. `get_trait_list()` describes only the bundled subset while this is
in force.

Coverage is uneven across taxonomies, since the names themselves differ:
BirdLife has 252 Accipitriformes and 69 Sylviidae, eBird 252 and none
(it carries no Sylviidae family label at all), BirdTree 251 and 294.
