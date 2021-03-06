% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/getNeotomaDoi.R
\name{get_neotoma_json}
\alias{get_neotoma_json}
\title{Get JSON data from Neotoma API v2.0}
\usage{
get_neotoma_json(datasetId)
}
\arguments{
\item{datasetId}{numeric or string dataset id}
}
\value{
list of parsed data
}
\description{
Get JSON data from Neotoma API v2.0
}
\examples{
apidata <- get_neotoma_json(12)
}
