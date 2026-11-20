test_that("summarize_trait_value describes a column by its contents", {
  expect_equal(summarize_trait_value(c(1.2, 3.4)), "numeric")
  expect_equal(summarize_trait_value(c("Forest", "Desert", "Forest")),
               "Desert, Forest")
})

test_that("an empty column says so rather than naming its type", {
  # Six of the fifteen morphological traits hold nothing across the whole
  # database. "numeric" made them indistinguishable in get_trait_list() from
  # the nine that carry measurements.
  expect_equal(summarize_trait_value(c(NA_real_, NA_real_)), "no values")
  expect_equal(summarize_trait_value(c(NA_character_, NA_character_)),
               "no values")
  expect_equal(summarize_trait_value(numeric(0)), "no values")
})

test_that("NA among real values still sorts last", {
  expect_equal(summarize_trait_value(c("Forest", NA, "Desert")),
               "Desert, Forest, NA")
})

test_that("factor levels are read from the data, not the schema", {
  x <- factor(c("Forest", "Forest"), levels = c("Desert", "Forest", "Marine"))
  expect_equal(summarize_trait_value(x), "Forest")
})


test_that("convert_enum_columns unwraps pq_* columns to factors", {
  df <- data.frame(a = 1:2, stringsAsFactors = FALSE)
  df[["sex"]] <- structure(c("male", "female"), class = "pq_sex")

  out <- convert_enum_columns(df)

  expect_s3_class(out$sex, "factor")
  expect_equal(levels(out$sex), c("female", "male"))
  expect_type(out$a, "integer")
})

test_that("convert_enum_columns leaves a frame without enums alone", {
  df <- data.frame(a = 1:2, b = c("x", "y"), stringsAsFactors = FALSE)
  expect_equal(convert_enum_columns(df), df)
})


test_that("validate_aggregate accepts NULL and the documented names", {
  expect_null(validate_aggregate(NULL))
  for (a in names(morph_aggregate_columns())) {
    expect_equal(validate_aggregate(a), a)
  }
})

test_that("validate_aggregate rejects anything else with a classed error", {
  expect_error(validate_aggregate("test"), class = "avonet_error_invalid_aggregate")
  expect_error(validate_aggregate(c("sex", "all")),
               class = "avonet_error_invalid_aggregate")
  expect_error(validate_aggregate(1), class = "avonet_error_invalid_aggregate")
})


test_that("the group-to-table lookup is the single source of truth", {
  # get_trait_groups() reads trait_group_tables(), which is what stops the two
  # drifting -- "social" once went missing from the get_trait_list() docs.
  expect_equal(get_trait_groups(), names(trait_group_tables()))
  expect_true(all(c("eco", "social", "morpho", "geo") %in% get_trait_groups()))
})

test_that("morph_aggregate_columns maps every name to a column or NA", {
  map <- morph_aggregate_columns()
  expect_true("all" %in% names(map))
  expect_true(is.na(map[["all"]]))                 # species only
  expect_equal(unname(map[["life stage"]]), "life_stage")
  expect_false(any(is.na(map[setdiff(names(map), "all")])))
})
