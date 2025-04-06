#' Get species data
#'
#' @param con Connection to the AVONET database
#' @param x Latin name of species, e.g. "Buteo buteo"
#' @param y Taxonomy. 1 = BirdLife, 2 = eBird and 3 = BirdTree
#' @param inferred Include inferred traits? Defaults to FALSE. For now, only FALSE is implemented.
#'
#' @return A dataframe.
#' @export
#'
#' @examples
#'
#' get_species("Buteo buteo", 1)
#'
#' my_birds <- c("Haliaeetus leucocephalus", "Aptenodytes forsteri", "Cardinalis cardinalis")
#' get_species(my_birds, 1)
#'
get_species <- function(con, x, y, inferred = FALSE) {
  if(inferred != FALSE){
    print("Inferred traits not implemented yet! Please set inferred to FALSE")
  } else {
    return(sql_query(con = con, parameter1 = x, parameter2 = y))
  }
}
