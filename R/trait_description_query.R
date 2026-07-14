#' Retrieve trait descriptions
#'
#' `trait_description_query()` retrieves the descriptions and possible values of
#' each trait.
#'
#' @return A dataframe with descriptions and possible values of each trait,
#'   specifically columns \code{trait_name}, \code{trait_description},
#'   \code{trait_value} as well as \code{value_desc_short} and
#'   \code{value_desc_long}.
#' @export
#'
#' @examples
#' trait_desc <- trait_description_query()
#' trait_desc
trait_description_query <- function() {

  con <- get_con()

  query <- DBI::dbSendQuery(con, glue::glue_sql("SELECT * FROM trait_info_detailed", .con = con))
  result <- DBI::dbFetch(query)
  DBI::dbClearResult(query)

  return(result)
}
