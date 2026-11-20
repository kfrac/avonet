test_that("get_taxonomic_info resolves names offline and says how they matched", {
  local_example_data()

  one <- silently(get_taxonomic_info("Buteo buteo", taxonomy = 1))
  expect_equal(one$match_type, "species")
  expect_named(one, c("species", "family", "order", "match_type"))

  many <- silently(get_taxonomic_info(c("Accipitridae", "Sylviidae"),
                                      taxonomy = 1))
  expect_setequal(unique(many$match_type), "family")
  expect_setequal(unique(many$family), c("Accipitridae", "Sylviidae"))
})

test_that("get_taxonomic_info refuses a mix of ranks", {
  local_example_data()

  expect_error(
    silently(get_taxonomic_info(c("Buteo buteo", "Accipitridae"), taxonomy = 1)),
    class = "avonet_error_mixed_rank"
  )
})

test_that("get_taxonomic_info warns about terms that matched nothing", {
  local_example_data()

  expect_warning(
    suppressMessages(get_taxonomic_info(c("Accipitridae", "Nonexistentia"),
                                        taxonomy = 1)),
    "No matches found"
  )
})

test_that("get_trait_list works offline and errors on an unknown group", {
  local_example_data()

  morpho <- silently(get_trait_list("morpho"))
  expect_true(all(c("trait", "resolution", "description", "value",
                    "primary_source") %in% names(morpho)))

  expect_error(silently(get_trait_list("nonsense")),
               class = "avonet_error_unknown_group")
})

test_that("empty traits are advertised as empty, not as numeric", {
  local_example_data()

  morpho <- silently(get_trait_list("morpho"))
  empty  <- morpho$trait[morpho$value == "no values"]

  expect_true(all(c("gape_width", "beak_depth_max", "tail_graduation",
                    "tarsus_diameter_sag", "tarsus_diameter_lat",
                    "back_toe") %in% empty))
  expect_false("beak_width" %in% empty)
})

test_that("mass is attributed to the source the data gives, not the dataset", {
  # get_trait_list() hardcoded "Tobias et al. (2022)", which sources none of
  # the mass values.
  local_example_data()

  morpho <- silently(get_trait_list("morpho"))
  mass   <- morpho[morpho$trait == "mass_value", ]

  expect_equal(nrow(mass), 1)
  expect_false(grepl("Tobias", mass$primary_source))
})

test_that("get_trait_levels lists a categorical trait and refuses others", {
  local_example_data()

  expect_true("Forest" %in% silently(get_trait_levels("habitat")))

  defs <- silently(get_trait_levels("habitat", return_defs = TRUE))
  expect_named(defs, c("trait", "short_description", "long_description"))

  expect_error(silently(get_trait_levels("mass_value")),
               class = "avonet_error_unknown_trait")
  expect_error(silently(get_trait_levels("min_latitude")),
               class = "avonet_error_not_categorical")
})
