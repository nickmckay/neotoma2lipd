library(neotoma)

library(neotoma2lipd)
#remotes::install_github("nickmckay/neotoma2lipd")
library(lipdR)
#remotes::install_github("nickmckay/LiPD-Utilities", subdir = "R")

library(geoChronR)
#remotes::install_github("nickmckay/geoChronR")

#search for a site
site = get_site("Moose Lake")

#restrict to just the site of interest as needed
site <- site[2,]

#use that to drive neotoma2Lipd
L <- neotoma2Lipd(site)

#test the file quickly.
geoChronR::mapLipd(L)

#write the file
lipdR::writeLipd(L)

#open try opening it at lipd.net/playground

