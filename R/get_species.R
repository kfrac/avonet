get_species <- function(x, y, inferred = FALSE) {
  if(inferred != FALSE){
    print("Inferred traits not implemented yet! Please set inferred to FALSE")
  } else {
    return(sql_query(parameter1 = x, parameter2 = y))
  }
}
