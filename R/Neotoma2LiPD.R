#' create a TSid for a Neotoma Lipd
#'
#' @return a randomly generated TSid for this project
#' @export
createNeoTsid <- function(){
  tsid <- paste0("N2L",
                 format(Sys.time(), "%y%m%d"),
                 paste0(sample(c(letters,LETTERS,0:9),size = 16,replace = T),collapse = ""))
  return(tsid)

}

#' @export
#' @family LiPD manipulation
#' @title Estimate uncertainty estimates from high/low range
#' @description Estimate uncertainty (plus/minus values) from a range of values
#' @import matrixStats
#' @param MT LiPD "measurementTable"
#' @param range1 name of one of the range variables
#' @param range2 name of the other range variable
#' @return MT: a LiPD measurementTable with a new unc.estimate variable
#' @importFrom matrixStats rowDiffs
#'
estimateUncertaintyFromRange = function(MT,range1="age.young",range2="age.old"){
  val1=MT[[range1]]$values
  val2=MT[[range2]]$values
  diffVals=abs(matrixStats::rowDiffs(as.matrix(cbind(val1,val2)),na.rm=TRUE))
  uncVal = diffVals/2
  MT$unc.estimate$values = uncVal
  MT$unc.estimate$variableName = "unc.estimate"
  MT$unc.estimate$TSid <- createNeoTsid()

  MT$unc.estimate$units=MT[[range2]]$units
  return(MT)
}

#' @export
#' @title Create a LiPD object from Neotoma
#' @description Uses the Neotoma API to create a LiPD file?
#' @details
#' get site fist
#' site = get_site("Potato Lake")
#' @param site  the site object from the R Neotoma package, output of  neotoma::get_site()
#' @return A LiPD object
#' @import neotoma
neotoma2Lipd = function(site){
  ## wrap this around the search , such that multiple datasets go to multiple paleoData and chronData tables


  #test for multiple actual sites
  if(nrow(site) > 1){
    #compare lat longs
    if(any(abs(site$long[1]-site$long[-1]) > 0.5 | abs(site$lat[1]-site$lat[-1]) > 0.5)){
      #ask the user
      yn <- readline(prompt = "It looks like this dataset table includes multiple sites. Typically you wouldn't want to put multiple sites into a single LiPD file. Do you want to continue?")
      if(tolower(substr(yn,1,1)) != "y"){
        stop("Stopping")
      }
    }
  }

  allPubs = c()
  acceptedDatasetTypes = c("plant macrofossil","pollen","loss-on-ignition","charcoal","diatom")
  allData = neotoma::get_dataset(site)
  allTypes = sapply(allData, FUN = function(x){x$dataset.meta$dataset.type})

  toInclude= which(allTypes %in% acceptedDatasetTypes)

  if(length(toInclude) == 0){
    stop("No plant macrofossil, pollen, LOI, charcoal, or diatom datasets found at this location")
  }
  dsIDs =  sapply(allData, FUN = function(x){x$dataset.meta$dataset.id})[toInclude]


  neo = neotoma::get_download(dsIDs)

  #initialize
  L=list()
  L$paleoData = vector(mode = "list",length=length(dsIDs))
  L$chronData = vector(mode = "list",length=length(dsIDs))

  for(n in 1:length(dsIDs)){

    dataSetID = dsIDs[n]

    #get site metadata
    sd=neo[[n]]$dataset$site.data

    L$geo$latitude=sd$lat
    L$geo$longitude=sd$long
    L$geo$elevation=sd$elev
    L$geo$siteName=sd$site.name
    if(!is.na(neo[[n]]$dataset$site.data$description)){
      L$geo$description = neo[[n]]$dataset$site.data$description
    }

    #take a guess at archive type
    if(grepl(L$geo$siteName,pattern = "lake",ignore.case = T)){
      L$archiveType <- "LakeSediment"
    }else if(grepl(L$geo$siteName,pattern = "bog",ignore.case = T) |
             grepl(L$geo$siteName,pattern = "fen",ignore.case = T) |
             grepl(L$geo$siteName,pattern = "peat",ignore.case = T)){
      L$archiveType <- "Peat"
    }else{
      L$archiveType <- "unknown"
    }

    #get PI
    L$investigators = neo[[n]]$dataset$pi.data$ContactName

    #get publication metadata
    pub = get_publication(datasetid = dataSetID)
    newPub=vector(mode="list",length=length(pub))
    for(p in 1:length(pub)){
      if(!pub[[p]]$meta$id %in% allPubs){
        newPub[[p]]$pubYear = pub[[p]]$meta$year
        newPub[[p]]$neotomaPubID=pub[[p]]$meta$id
        newPub[[p]]$citation = pub[[p]]$meta$citation
        if(length(pub[[p]]$authors$Order)>0){
          pubdf=pub[[p]]$authors[order(pub[[p]]$authors$Order),]
          newPub[[p]]$author = pubdf$ContactName
        }
        allPubs = append(allPubs,pub[[p]]$meta$id)
      }
    }
    if(!is.null(newPub[[1]])){
      if(n==1){
        L$pub = newPub
      }else{
        L$pub = append(L$pub,newPub)
      }
    }


    #Dataset name
    firstAuthor = strsplit(L$pub[[1]]$author,",")[[1]][1]
    L$dataSetName = paste(L$geo$siteName,firstAuthor,L$pub[[1]]$pubYear,sep = ".")
    L$dataSetName=gsub(" ","",L$dataSetName)




    #paleodata...
    co = as.data.frame(neo[[n]]$counts)
    sm = neo[[n]]$sample.meta
    tl = neo[[n]]$taxon.list


    #pmt
    #sample.meta table
    pmt=list()
    smNames = names(sm)
    #neotoma id
    L$paleoData[[n]]$neotomaDatasetID= dataSetID
    L$paleoData[[n]]$neotomaChronID= unique(sm$chronology.id)

    for (s in 1:length(smNames)){
      if(!all(is.na(sm[[smNames[s]]]))){
        pmt[[smNames[s]]]$values = as.matrix(sm[smNames[s]])
        pmt[[smNames[s]]]$variableName =smNames[s]
        pmt[[smNames[s]]]$TSid = createNeoTsid()

        if("depth"==smNames[s]){
          pmt[[smNames[s]]]$units = "cm"
        }else if("age"==smNames[s]){
          pmt[[smNames[s]]]$units = unique(sm$age.type)
        }
      }
    }

    #counts table
    cNames = names(co)


    if(length(cNames)>0){
      for (s in 1:length(cNames)){
        if(!all(is.na(co[[cNames[s]]]))){
          pmt[[cNames[s]]]$values = as.matrix(co[cNames[s]])
          pmt[[cNames[s]]]$variableName =cNames[s]
          pmt[[cNames[s]]]$TSid = createNeoTsid()

          wtl= which(cNames[s]==tl$taxon.name)
          if (length(wtl)==1){
            pmt[[cNames[s]]]$units = tl$variable.units[wtl]
            pmt[[cNames[s]]]$description = tl$variable.element[wtl]
            pmt[[cNames[s]]]$notes = tl$variable.context[wtl]
            pmt[[cNames[s]]]$taxonGroup = tl$taxon.group[wtl]
          }
        }
      }
    }

    #add in any alternate ages
    if (length(neo[[n]]$chronologies)>1){
      #figure out which is the default?
      defChronId=unique(neo[[n]]$sample.meta$chronology.id)
      cc=1
      for(ch in 1:length(neo[[n]]$chronologies)){
        if(any(defChronId != neo[[n]]$chronologies[[ch]]$chronology.id)){
          #then this is not the default
          pmt[[paste0("age_alt",cc)]]$TSid = createNeoTsid()
          pmt[[paste0("age_alt",cc)]]$variableName <- paste0("age_alt",cc)
          pmt[[paste0("age_alt",cc)]]$units = unique(neo[[n]]$chronologies[[ch]]$age.type)
          pmt[[paste0("age_alt",cc)]]$values = as.matrix(neo[[n]]$chronologies[[ch]]$age)
          pmt[[paste0("age_alt",cc)]]$chronName = paste(unique(neo[[n]]$chronologies[[ch]]$chronology.name),"-",dataSetID)
          cc=cc+1
        }else{
          pmt$age$chronName = paste(unique(neo[[n]]$chronologies[[ch]]$chronology.name),"-",dataSetID)
        }
      }
    }

    chronData = vector(mode = "list",length =length(neo[[n]]$chronologies) )
    #chronData
    for(ch in 1:length(neo[[n]]$chronologies)){
      chron=get_chroncontrol(unique(neo[[n]]$chronologies[[ch]]$chronology.id))

      #chron metadata
      chronData[[ch]]$chronName = paste0(chron$meta$name,"-",dataSetID)
      chronData[[ch]]$defaultTable = chron$meta$default
      chronData[[ch]]$neotomaDatasetID = dataSetID
      chronData[[ch]]$neotomaChronID = chron$meta$chron.id

      #chron measurement table

      cmt = list()
      cNames = names(chron$chron.control)
      for(s in 1:length(cNames)){


        if(!all(is.na(chron$chron.control[[cNames[s]]]))){
          cmt[[cNames[s]]]$values = as.matrix(chron$chron.control[cNames[s]])
          cmt[[cNames[s]]]$variableName =cNames[s]
          cmt[[cNames[s]]]$TSid = createNeoTsid()

          if("depth"==smNames[s] |"thickness"==smNames[s]){
            cmt[[smNames[s]]]$units = "cm"
            #}else if(grepl("age",smNames[s])){
            cmt[[smNames[s]]]$units = unique(sm$age.type)
          }
        }
      }


      #if there are age.young and age.old variables, estimate uncertainty from that range
      if("age.young" %in% names(cmt) & "age.old" %in% names(cmt)){
        cmt <- estimateUncertaintyFromRange(cmt)
      }

      chronData[[ch]]$measurementTable[[1]] = cmt

      chronData[[ch]]$model[[1]]$method$notes = chron$meta$age.model





      if(n==1){
        L$chronData = chronData
      }else if(any(!sapply(chronData,"[[","neotomaChronID") %in% sapply(L$chronData,"[[","neotomaChronID"))) {
        wc = which(!sapply(chronData,"[[","neotomaChronID") %in% sapply(L$chronData,"[[","neotomaChronID"))

        NC = chronData[wc]
        L$chronData = append(L$chronData,NC)
      }
      #     if(!is.null(chronData)){
      #     L$chronData = append(L$chronData,chronData)
      #     }
    }

    L$paleoData[[n]]$measurementTable[[1]]=pmt
  }
  L$createdBy <- "neotoma2Lipd"
  L$lipdVersion <- 1.3


  return(L)
}
