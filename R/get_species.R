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
#' db_user <- keyring::key_list("avonet")[1, "username"]
#' db_password <- keyring::key_get("avonet", username = db_user)
#' con <- connect_db(username = db_user, pw = db_password)
#'
#' # This works for a single species
#' get_species(con, "Buteo buteo", 1)
#'
#' # Or a list of several species
#' my_birds <- c("Haliaeetus leucocephalus", "Aptenodytes forsteri", "Cardinalis cardinalis")
#' get_species(con, my_birds, 1)
get_species <- function(con, x, y, inferred = FALSE) {
  if(inferred != FALSE){
    print("Inferred traits not implemented yet! Please set inferred to FALSE")
  } else {
    return(sql_query(con = con, parameter1 = x, parameter2 = y))
  }
}
