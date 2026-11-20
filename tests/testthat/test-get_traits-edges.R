test_that("a filter that removes every species returns an empty result", {
  # This used to crash in get_metadata(): "arguments imply differing number of
  # rows: 1, 0".
  local_example_data()

  out <- silently(get_traits("Accipitridae", taxonomy = 1,
                             resolution = "species",
                             filter = list(habitat = "Nonexistent")))

  expect_equal(nrow(out$data), 0)
  expect_equal(nrow(out$metadata_summary), 0)
  expect_equal(nrow(out$detailed_sources), 0)
})

test_that("an empty specimen filter result is empty everywhere", {
  local_example_data()

  out <- silently(get_traits("Accipitridae", taxonomy = 1,
                             filter = list(beak_width = list(op = ">", val = 9999))))

  expect_equal(nrow(out$data), 0)
  expect_equal(nrow(out$specimen_data), 0)
  expect_equal(nrow(out$metadata_summary), 0)
})

test_that("metadata_summary names real traits, not source columns", {
  # It used to derive trait names by stripping suffixes off the source
  # columns, which produced a row called "spatial_source" and left the five
  # geographic traits unmentioned.
  local_example_data()

  out <- silently(get_traits("Buteo buteo", taxonomy = 1,
                             resolution = "species"))
  traits <- out$metadata_summary$trait

  expect_false("spatial_source" %in% traits)
  expect_true(all(c("habitat", "mass_value", "min_latitude", "max_latitude",
                    "centroid_lat", "centroid_lon", "range_size") %in% traits))
})

test_that("an unsourced trait names no source rather than two", {
  # trait_source_detailed holds two rows with no trait_src_id, and dplyr
  # treats NA as equal to NA when joining.
  local_example_data()

  out <- silently(get_traits("Bermuteo avivorus", taxonomy = 1,
                             resolution = "species"))

  expect_equal(anyDuplicated(out$metadata_summary$trait), 0L)
  expect_true(all(is.na(out$metadata_summary$primary_source)))
})

test_that("a species with no trait data at all is named in a warning", {
  local_example_data()

  expect_warning(
    suppressMessages(get_traits("Bermuteo avivorus", taxonomy = 1,
                                resolution = "species")),
    "no ecological, mass or geographical trait data"
  )
})
