test_that("the bundle carries what the package expects of it", {
  b <- avonet_example

  expect_named(b, c("taxa", "extracted_on", "species", "species_traits",
                    "specimens", "raw_tables"))
  expect_equal(unname(b$taxa), c("Accipitriformes", "Sylviidae"))

  expect_true(all(c("species_id", "species_name", "species_family",
                    "species_order", "species_tax") %in% names(b$species)))

  # Without species_tax the specimen frame cannot be filtered back to one
  # taxonomy, which once inflated Accipitridae from 1,452 rows to 1,500.
  expect_true("species_tax" %in% names(b$specimens))

  expect_true(all(c("trait_info_detailed", "trait_source_detailed",
                    "morph_trait_specimen") %in% names(b$raw_tables)))
})

test_that("example_table refuses a table that is not bundled", {
  expect_error(example_table("nonexistent_table"),
               class = "avonet_error_example_table_missing")
})

test_that("with no connection the package reads the bundle", {
  local_example_data()
  expect_true(using_example_data())
})


test_that("match_example_taxa recognises each rank", {
  expect_equal(unique(match_example_taxa("Buteo buteo")$match_type), "species")
  expect_equal(unique(match_example_taxa("Buteo")$match_type), "genus")
  expect_equal(unique(match_example_taxa("Accipitridae")$match_type), "family")
  expect_equal(unique(match_example_taxa("Accipitriformes")$match_type), "order")
})

test_that("match_example_taxa is case-insensitive, as ILIKE is", {
  expect_equal(nrow(match_example_taxa("ACCIPITRIDAE")),
               nrow(match_example_taxa("Accipitridae")))
  expect_equal(nrow(match_example_taxa("  accipitridae  ")),
               nrow(match_example_taxa("Accipitridae")))
})

test_that("restricting ranks is how a caller asks a narrower question", {
  expect_equal(nrow(match_example_taxa("Accipitridae", ranks = "species")), 0)
  expect_gt(nrow(match_example_taxa("Accipitridae", ranks = "family")), 0)
})

test_that("match_example_taxa returns nothing for an unknown name", {
  expect_equal(nrow(match_example_taxa("Nonexistentia")), 0)
})

test_that("taxonomy restricts the match", {
  all_tax <- match_example_taxa("Accipitridae")
  one_tax <- match_example_taxa("Accipitridae", taxonomy = 1)

  expect_lt(nrow(one_tax), nrow(all_tax))
  expect_equal(unique(one_tax$species_tax), 1L)
})


test_that("detect_rank reads the bundle when offline", {
  local_example_data()

  expect_equal(detect_rank("Buteo buteo"), "species")
  expect_equal(detect_rank("Buteo"), "genus")
  expect_equal(detect_rank("Accipitridae"), "family")
  expect_equal(detect_rank("Accipitriformes"), "order")
  expect_error(detect_rank("Nonexistentia"))
})

test_that("resolve_taxa expands a taxon within one taxonomy", {
  local_example_data()

  hawks <- silently(resolve_taxa("Accipitridae", taxonomy = 1))
  expect_equal(length(hawks), 250)
  expect_true(all(!duplicated(hawks)))
  expect_equal(hawks, sort(hawks))

  buteos <- silently(resolve_taxa("Buteo", rank = "genus", taxonomy = 1))
  expect_true(all(startsWith(buteos, "Buteo ")))
})

test_that("resolve_taxa reports the taxon it was given, not a LIKE pattern", {
  # The genus branch used to overwrite `taxon` with "Buteo %", which reached
  # the progress message and the knitted README.
  local_example_data()

  expect_message(resolve_taxa("Buteo", rank = "genus", taxonomy = 1),
                 "Resolved 'Buteo' (genus)", fixed = TRUE)
})


test_that("a taxon wider than the bundle warns rather than looking complete", {
  # Sylviidae sits inside Passeriformes, so asking for that order offline
  # matches the bundled Sylviidae rows and would otherwise pass for the order.
  local_example_data()

  expect_warning(
    suppressMessages(resolve_taxa("Passeriformes", taxonomy = 1)),
    "reaches beyond"
  )
})

test_that("a bundled taxon, and anything inside one, does not warn", {
  local_example_data()

  expect_no_warning(suppressMessages(resolve_taxa("Accipitriformes", taxonomy = 1)))
  expect_no_warning(suppressMessages(resolve_taxa("Accipitridae", taxonomy = 1)))
  expect_no_warning(suppressMessages(resolve_taxa("Buteo", rank = "genus",
                                                  taxonomy = 1)))
})
