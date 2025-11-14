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


arrange_metadata <- function(data, cols, names_to = "trait", values_to = "source") {

  # Get the columns to pivot
  pivot_cols <- data[cols]

  # All non-pivoted columns (kept as repeating rows)
  id_cols <- data[setdiff(names(data), cols)]

  # Stack the pivoted columns
  long <- data.frame(
    id_cols[rep(seq_len(nrow(id_cols)), times = length(cols)), ],
    setNames(
      data.frame(rep(names(pivot_cols), each = nrow(data))), names_to
    ),
    setNames(
      data.frame(unlist(pivot_cols, use.names = FALSE)), values_to
    ),
    row.names = NULL
  )

  return(long)
}

