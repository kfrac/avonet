test_that("a species-level filter narrows both elements", {
  local_example_data()

  out <- silently(get_traits("Accipitridae", taxonomy = 1,
                             filter = list(habitat = "Forest")))

  expect_lt(nrow(out$data), 250)
  expect_true(all(out$data$habitat == "Forest", na.rm = TRUE))
  expect_true(all(unique(out$specimen_data$species) %in% out$data$species))
})

test_that("a specimen-level filter narrows the species as well", {
  local_example_data()

  out <- silently(get_traits("Accipitridae", taxonomy = 1,
                             filter = list(beak_width = list(op = ">", val = 20))))

  expect_true(all(out$specimen_data$beak_width > 20, na.rm = TRUE))
  expect_setequal(out$data$species, unique(out$specimen_data$species))
})

test_that("the two resolutions can be filtered in one call", {
  local_example_data()

  out <- silently(get_traits(
    "Accipitridae",
    taxonomy = 1,
    filter = list(habitat = "Forest", beak_width = list(op = ">", val = 20))
  ))

  expect_true(all(out$data$habitat == "Forest", na.rm = TRUE))
  expect_true(all(out$specimen_data$beak_width > 20, na.rm = TRUE))
  expect_setequal(out$data$species, unique(out$specimen_data$species))

  species_only <- silently(get_traits("Accipitridae", taxonomy = 1,
                                      filter = list(habitat = "Forest")))
  expect_lt(nrow(out$data), nrow(species_only$data))
})

test_that("a specimen-level filter needs the specimens", {
  local_example_data()

  expect_error(
    silently(get_traits("Accipitridae", taxonomy = 1, resolution = "species",
                        filter = list(beak_width = list(op = ">", val = 20)))),
    class = "avonet_error_specimen_filter_resolution"
  )
})

test_that("a filter name matching neither resolution is reported once", {
  local_example_data()

  expect_error(
    silently(get_traits("Buteo buteo", taxonomy = 1,
                        filter = list(beak_wdith = 20))),
    class = "avonet_error_unknown_filter"
  )
})

test_that("aggregation summarizes the specimens that survived the filter", {
  local_example_data()

  out <- silently(get_traits("Accipitridae", taxonomy = 1,
                             filter = list(beak_width = list(op = ">", val = 20)),
                             aggregate = "sex"))

  expect_true("aggregated_by" %in% names(out$specimen_data))
  expect_true(any(grepl("_mean$", names(out$specimen_data))))
  expect_true(any(grepl("_n$", names(out$specimen_data))))
  expect_gt(nrow(out$specimen_data), 1)
})

test_that("aggregate is ignored, with a warning, at species resolution", {
  local_example_data()

  expect_warning(
    suppressMessages(get_traits("Buteo buteo", taxonomy = 1,
                                resolution = "species", aggregate = "sex")),
    "ignored"
  )
})

test_that("aggregate is validated before anything is queried", {
  local_example_data()

  expect_error(get_traits("Buteo buteo", taxonomy = 1, aggregate = "test"),
               class = "avonet_error_invalid_aggregate")
})
