#' Get neotoma doi from dataset
#'get neotoma doi from dataset name.
#' @param datasetId a list returned from get_neotoma_json or a dataset id
#'
#' @return Neotoma DOI
#' @export
#'
#' @examples
#' get_neotoma_doi(12)

get_neotoma_doi <- function(dataset){

  if(all(is.na(dataset))){#just pass it on
    return(NA)
  }

  if(!is.list(dataset)){
    apidata <- get_neotoma_json(dataset)
  }else{
    apidata <- dataset
  }

  doi <- apidata[["data"]][["frozendata"]][["data"]][["dataset"]][["dataset"]][["doi"]][[1]]

  if(is.null(doi)){
    doi <- NA
  }

  return(doi)
}

#' Get JSON data from Neotoma API v2.0
#'
#' @param datasetId numeric or string dataset id
#'
#' @return list of parsed data
#' @export
#'
#' @examples
#' apidata <- get_neotoma_json(12)
get_neotoma_json <- function(datasetId){
  apidata <- jsonlite::fromJSON(paste0("http://api-dev.neotomadb.org/v2.0/data/download/",as.character(datasetId)))
  #check for success
  if(apidata$status != "success"){
    stop("API call failed")
  }

  #check for data
  if(length(apidata$data) == 0){
    warning(paste0("Dataset ", as.character(datasetId)) ," appears to contain no data. It may not exist.")
  }

  #report success and dataset name
  sitename <- apidata[["data"]][["frozendata"]][["data"]][["dataset"]][["site"]][["sitename"]]
  print(paste("Successfully retrieved",sitename))
  return(apidata)
}


#get multiple metadata
get_neotoma_meta <- function(dataset){

  if(all(is.na(dataset))){#just pass it on
    return(NA)
  }

  if(!is.list(dataset)){
    apidata <- get_neotoma_json(dataset)
  }else{
    apidata <- dataset
  }

if(length(apidata$data)==0){#return all NAs if it's empty
  return(data.frame(doi = NA,
             datasetType = NA,
             siteName = NA,
             coords = NA,
             authorLastNames = NA))
}

doi <- apidata[["data"]][["frozendata"]][["data"]][["dataset"]][["dataset"]][["doi"]][[1]]
datasettype <- apidata[["data"]][["frozendata"]][["data"]][["dataset"]][["dataset"]][["datasettype"]]
siteName <- apidata[["data"]][["frozendata"]][["data"]][["dataset"]][["site"]][["sitename"]]
coordString <- apidata[["data"]][["frozendata"]][["data"]][["dataset"]][["site"]][["geography"]]
authorLastNames <- apidata[["data"]][["frozendata"]][["data"]][["dataset"]][["dataset"]][["datasetpi"]][[1]][["familyname"]]

cstart <- stringr::str_locate(pattern = "coordinates\":",coordString)[1,2]+1
cend <- stringr::str_locate(pattern = "]",coordString)[1,2]
meta <- data.frame(doi = paste(doi,collapse = ", "),
                   datasetType = paste(datasettype,collapse = ", "),
                   siteName = paste(siteName,collapse = ", "),
                   coords = stringr::str_remove_all(stringr::str_remove_all(stringr::str_sub(coordString,start = cstart,end = cend),pattern = "\\]"),pattern = "\\["),
                   authorLastNames = paste(authorLastNames,collapse = "; ")
                   )

return(meta)

}
