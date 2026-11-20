# A stand-in for query_species_traits() output: the prefixes, the paired
# source columns, the taxonomic backbone and the mass special case.
species_frame <- function() {
  data.frame(
    species_id            = 1:3,
    species_name          = c("Buteo buteo", "Buteo rufinus", "Milvus milvus"),
    species_family        = "Accipitridae",
    species_order         = "Accipitriformes",
    species_tax           = 1L,
    ect_habitat           = c("Forest", "Grassland", "Forest"),
    ect_habitat_src       = 1L,
    ect_trophic_niche     = c("Vertivore", "Vertivore", "Scavenger"),
    ect_trophic_niche_src = 2L,
    mass_value            = c(759, 1100, 1050),
    mass_trait_src        = 20L,
    mass_flag             = NA_character_,
    spd_range_size        = c(1e7, 5e6, 9e6),
    spd_spatial_source    = 6L,
    stringsAsFactors      = FALSE
  )
}

specimen_frame <- function() {
  data.frame(
    species     = c("Buteo buteo", "Buteo buteo", "Milvus milvus"),
    sex         = factor(c("male", "female", "male")),
    beak_width  = c(18, 24, 21),
    wing_length = c(390, 410, 400),
    avibase_id  = c("a", "b", "c"),
    stringsAsFactors = FALSE
  )
}


test_that("filterable_columns strips table prefixes and keeps mass readable", {
  lookup <- filterable_columns(species_frame())

  expect_equal(unname(lookup[["habitat"]]), "ect_habitat")
  expect_equal(unname(lookup[["trophic_niche"]]), "ect_trophic_niche")
  expect_equal(unname(lookup[["range_size"]]), "spd_range_size")
  expect_equal(unname(lookup[["mass"]]), "mass_value")   # the one special case
  expect_equal(unname(lookup[["mass_flag"]]), "mass_flag")
})

test_that("filterable_columns excludes bookkeeping and taxonomy", {
  lookup <- filterable_columns(species_frame())
  cols   <- unname(lookup)

  expect_false(any(grepl("(_id|_src|_source)$", cols)))
  expect_false(any(c("species_name", "species_family", "species_order",
                     "species_tax", "species_id") %in% cols))
})

test_that("filterable_columns describes the specimen frame too", {
  # The same code has to describe both resolutions, which is what lets
  # get_traits() work out which frame a filter name belongs to.
  lookup <- filterable_columns(specimen_frame())

  expect_true(all(c("sex", "beak_width", "wing_length") %in% unname(lookup)))
  expect_false("species" %in% unname(lookup))     # taxonomic
  expect_false("avibase_id" %in% unname(lookup))  # bookkeeping
})

test_that("filter_matches_frame answers for full and short names", {
  sp <- species_frame()

  expect_true(filter_matches_frame("habitat", sp))      # short
  expect_true(filter_matches_frame("ect_habitat", sp))  # full
  expect_true(filter_matches_frame("mass", sp))
  expect_false(filter_matches_frame("beak_width", sp))  # specimen-level
  expect_false(filter_matches_frame("nonsense", sp))
})

test_that("the two frames claim disjoint sets of filter names", {
  # If they ever overlapped, get_traits() would silently assign the filter to
  # whichever it checked first.
  sp_names   <- names(filterable_columns(species_frame()))
  spec_names <- names(filterable_columns(specimen_frame()))

  expect_length(intersect(sp_names, spec_names), 0)
})


test_that("apply_filters matches a single value and a set", {
  out <- silently(apply_filters(species_frame(), list(habitat = "Forest")))
  expect_equal(nrow(out), 2)

  out <- silently(apply_filters(species_frame(),
                                list(trophic_niche = c("Vertivore", "Scavenger"))))
  expect_equal(nrow(out), 3)
})

test_that("apply_filters applies numeric operators", {
  f <- function(op, val) {
    silently(apply_filters(species_frame(),
                           list(range_size = list(op = op, val = val))))
  }

  expect_equal(nrow(f("<",  9e6)), 1)
  expect_equal(nrow(f("<=", 9e6)), 2)
  expect_equal(nrow(f(">",  9e6)), 1)
  expect_equal(nrow(f("==", 5e6)), 1)
  expect_equal(nrow(f("!=", 5e6)), 2)
})

test_that("apply_filters combines conditions with AND", {
  out <- silently(apply_filters(
    species_frame(),
    list(habitat = "Forest", range_size = list(op = ">", val = 9.5e6))
  ))
  expect_equal(out$species_name, "Buteo buteo")
})

test_that("a filter matching nothing returns zero rows, not an error", {
  out <- silently(apply_filters(species_frame(), list(habitat = "Nonexistent")))
  expect_equal(nrow(out), 0)
  expect_equal(names(out), names(species_frame()))
})

test_that("apply_filters resolves a full column name as well as a short one", {
  short <- silently(apply_filters(species_frame(), list(habitat = "Forest")))
  full  <- silently(apply_filters(species_frame(), list(ect_habitat = "Forest")))
  expect_equal(short, full)
})

test_that("each apply_filters failure has its own condition class", {
  sp <- species_frame()

  expect_error(silently(apply_filters(sp, list(mating_system = "Polygamous"))),
               class = "avonet_error_unknown_filter")

  expect_error(silently(apply_filters(sp, list(species_name = "Buteo buteo"))),
               class = "avonet_error_taxonomic_filter")
  expect_error(silently(apply_filters(sp, list(family = "Accipitridae"))),
               class = "avonet_error_taxonomic_filter")

  expect_error(silently(apply_filters(sp, list(range_size = list(val = 1)))),
               class = "avonet_error_invalid_filter")

  expect_error(silently(apply_filters(sp,
                                      list(range_size = list(op = "~", val = 1)))),
               class = "avonet_error_invalid_operator")
})

test_that("NA values never survive a filter", {
  # LEFT joins leave NAs behind, and an NA comparison must not pass.
  sp <- species_frame()
  sp$ect_habitat[1] <- NA

  out <- silently(apply_filters(sp, list(habitat = "Forest")))
  expect_equal(out$species_name, "Milvus milvus")
})


test_that("an ambiguous short name is refused rather than guessed at", {
  # No two columns currently queried share a short name, so this is the one
  # apply_filters() error class that real data cannot reach -- it guards
  # against a future table whose prefix strips to a name already in use.
  frame <- data.frame(
    species_name = "Buteo buteo",
    ect_habitat  = "Forest",
    geo_habitat  = "Upland",
    stringsAsFactors = FALSE
  )

  lookup <- filterable_columns(frame)
  expect_equal(sum(names(lookup) == "habitat"), 2)

  expect_error(silently(apply_filters(frame, list(habitat = "Forest"))),
               class = "avonet_error_ambiguous_filter")

  # the full column name is still unambiguous
  expect_equal(nrow(silently(apply_filters(frame,
                                           list(ect_habitat = "Forest")))), 1)
})
