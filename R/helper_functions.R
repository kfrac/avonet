remove_prefixes <- function(df, prefixes, ignore_case = FALSE) {
  # Build regex pattern from prefix list
  pattern <- paste0("^(", paste(prefixes, collapse = "|"), ")")

  # Remove matching prefixes from column names
  names(df) <- sub(pattern, "", names(df), ignore.case = ignore_case)

  return(df)
}

remove_suffix_columns <- function(df, suffixes, ignore_case = FALSE) {
  # Build regex pattern from suffix list
  pattern <- paste0("(", paste(suffixes, collapse = "|"), ")$")

  # Identify columns that do NOT end with any of the suffixes
  keep <- !grepl(pattern, names(df), ignore.case = ignore_case)

  # Subset dataframe to keep only desired columns
  df <- df[, keep, drop = FALSE]

  return(df)
}
