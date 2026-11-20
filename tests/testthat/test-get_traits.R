# These counts are properties of the bundled snapshot, and both were checked
# against the live database: get_traits("Accipitridae", 1) returns 250 species
# and 1,452 specimen rows there too. If a re-extraction changes them, that is
# worth looking at rather than quietly accepting.
ACCIPITRIDAE_SPECIES   <- 250
ACCIPITRIDAE_SPECIMENS <- 1452


test_that("get_traits returns four elements, specimens included by default", {
  local_example_data()

  out <- silently(get_traits("Accipitridae", taxonomy = 1))

  expect_named(out, c("metadata_summary", "data", "detailed_sources",
                      "specimen_data"))
  expect_equal(nrow(out$data), ACCIPITRIDAE_SPECIES)
  expect_equal(nrow(out$specimen_data), ACCIPITRIDAE_SPECIMENS)
})

test_that("resolution = species skips the specimen query", {
  local_example_data()

  out <- silently(get_traits("Accipitridae", taxonomy = 1,
                             resolution = "species"))

  expect_named(out, c("metadata_summary", "data", "detailed_sources"))
  expect_equal(nrow(out$data), ACCIPITRIDAE_SPECIES)
})

test_that("data keeps one row per species and the documented columns", {
  local_example_data()

  out <- silently(get_traits("Accipitridae", taxonomy = 1,
                             resolution = "species"))

  expect_equal(anyDuplicated(out$data$species), 0L)
  expect_length(names(out$data), 17)
  expect_true(all(c("species", "family", "order", "habitat", "mass_value",
                    "range_size") %in% names(out$data)))
  expect_false(any(grepl("(_src|_source)$", names(out$data))))
})

test_that("source_cols = TRUE keeps the bookkeeping columns inline", {
  local_example_data()

  out <- silently(get_traits("Buteo buteo", taxonomy = 1,
                             resolution = "species", source_cols = TRUE))

  expect_length(names(out$data), 26)
})

test_that("every specimen row is labelled with its own species", {
  local_example_data()

  out <- silently(get_traits(c("Buteo buteo", "Milvus milvus"), taxonomy = 1))

  expect_false(anyNA(out$specimen_data$species))
  expect_setequal(unique(out$specimen_data$species),
                  c("Buteo buteo", "Milvus milvus"))
})

test_that("inferred is reserved and refuses anything but FALSE", {
  local_example_data()

  expect_error(get_traits("Buteo buteo", taxonomy = 1, inferred = TRUE),
               class = "avonet_error_not_implemented")
})
