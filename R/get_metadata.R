get_metadata <- function(src_cols){

  suffixes <- c("_trait_src", "_src")
  pattern <- paste0("(", paste(suffixes, collapse = "|"), ")$")

  src_cols <- remove_prefixes(src_cols, prefixes = prefixes)
  names(src_cols) <- sub(pattern, "", names(src_cols))

  metadata_output <- arrange_metadata(src_cols, names(src_cols))

  return(metadata_output)

}
