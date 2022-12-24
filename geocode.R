# ++++++++++++++++++++++++++++++
# GEOCODE AUTHOR LOCATIONS -----
# ++++++++++++++++++++++++++++++
# FCC20221204

# https://cran.r-project.org/web/packages/tidygeocoder/readme/README.html
library(tidyverse)
library(tidygeocoder)
library(here)
library(rjson)
library(ggplot2)
library(hrbrthemes)
library(data.table)
library(arrow)
library(sp)
library(rworldmap)
library(xml2)
library(rvest)

# # load author locations
# df <- fromJSON(file = here("author_locations.json"))

# load raw text files
file_names <- list.files(here("raw_texts"), pattern = ".*[.]txt")
raw_texts <- lapply(file_names, function(x) readLines(here(paste0("raw_texts/", x))))

file_names_html <- list.files(here("data"), pattern = ".*[.]html")
raw_html <- lapply(file_names_html, function(x) read_html(here(paste0("data/", x))))


# parse html -----#
author_affiliations_html <- tibble(matrix(nrow = 0, ncol = 1))
colnames(author_affiliations_html) <- c("affiliation")
for(i in 1:length(raw_html)) {
  citers_from_htmls1 <- tibble(
    affiliation = raw_html[[i]] %>% html_nodes(".c-article-author-affiliation__address") %>% html_text(),
  )
  citers_from_htmls2 <- tibble(
    affiliation = raw_html[[i]] %>% html_nodes(".affiliations") %>% html_children() %>% html_text(),
  )
  citers_from_htmls3 <- tibble(
    affiliation = raw_html[[i]] %>% html_nodes(".affiliation-name") %>% html_text(),
  )
  author_affiliations_html <- rbind(author_affiliations_html, citers_from_htmls1, citers_from_htmls2, citers_from_htmls3)
}
rm(citers_from_htmls1, citers_from_htmls2, citers_from_htmls3)


# filter institutional affiliations of authors -----
# I'd expect affiliations to be within the first 500 lines
filtered_texts <- lapply(raw_texts, function(x) x[1:500])
# filtered_texts <- lapply(filtered_texts, function(x) x[grepl(pattern = "[A-Za-z]+, .+[0-9]{0,8}, [A-Za-z]+", x = x)])
filtered_texts <- lapply(filtered_texts, function(x) x[grepl(pattern = "(Department|School|Institute|Universit|College|Laboratory|Faculty|Labs|Ltd|Inc[.]|Centre|Center|\\bGoogle\\b|Amazon|Microsoft|\\bIBM\\b|\\bMIT\\b)", x = x, ignore.case = T) | grepl(pattern = "\\b(USA|United States of America|UK|United Kingdom|Germany|Australia|China|Taiwan|Japan|Canada|France|Italy|Spain|Singapore)\\b", x = x)]) # Research|Group
filtered_texts <- lapply(filtered_texts, function(x) x[!str_detect(x, pattern = "(Authorized licensed use limited to)|(Published by )|(Journal of )")])
# filtered_texts <- lapply(filtered_texts, function(x) x[nchar(x) < 150])

# combine list of institutional affiliatons into a tibble
author_affiliations_raw_text <- filtered_texts %>% unlist() %>% tibble()
colnames(author_affiliations_raw_text) <- "affiliation"
author_affiliations <- rbind(author_affiliations_raw_text, author_affiliations_html) 

# extract addresses
author_affiliations$affiliation <- str_replace_all(author_affiliations$affiliation, pattern = "^[^[A-Za-z]]", replacement = "") %>% str_trim()
author_affiliations$affiliation <- str_replace_all(author_affiliations$affiliation, pattern = "[^[A-Za-z0-9]]$", replacement = "") %>% str_trim()
author_affiliations$addr <- str_replace_all(author_affiliations$affiliation, pattern = ".*?,(.+)", replacement = "\\1") %>% str_trim()
author_affiliations$addr <- str_replace_all(author_affiliations$addr, pattern = ".*?,(.+,.+,.+)", replacement = "\\1") %>% str_trim()
author_affiliations$addr <- str_replace_all(author_affiliations$addr, pattern = "[Ee][-]{0,1}mail|[^[A-Za-z0-9, ]]", replacement = "") %>% str_trim()
author_affiliations$name <- str_replace_all(author_affiliations$affiliation, pattern = "(.*?(,.+?){0,1})(,.+){0,1},.+", replacement = "\\1") %>% str_trim()
# author_affiliations$name <- paste0("placeholder", 1:nrow(author_affiliations))
author_affiliations <- author_affiliations[nchar(author_affiliations$addr) < 100,]
author_affiliations <- author_affiliations[str_detect(author_affiliations$addr, pattern = ",") | str_detect(author_affiliations$addr, pattern = "University"), ]

# # create a dataframe with addresses
# some_addresses <- tibble::tribble(
#   ~name,                  ~addr,
#   # "White House",          "1600 Pennsylvania Ave NW, Washington, DC",
#   # "Transamerica Pyramid", "600 Montgomery St, San Francisco, CA 94111",
#   # "Willis Tower",         "233 S Wacker Dr, Chicago, IL 60606",
#   "Theoretical Division", "Los Alamos National Laboratory, Los Alamos, New Mexico 87545, USA",
#   "Department of Mathematics", "University of California Davis, Davis, California 95616, USA"
# )


# geocode addresses -----
author_addresses <- author_affiliations %>%
  geocode(addr, method = 'osm', lat = latitude , long = longitude)
# lat_longs <- some_addresses %>%
#   geocode(addr, method = 'osm', lat = latitude , long = longitude)
# #> Passing 3 addresses to the Nominatim single address geocoder
# #> Query completed in: 3 seconds
# lat_longs

# generate ids
author_addresses$id <- 1:nrow(author_addresses)


# get countries and continents from lon-lat -----#
# (see https://stackoverflow.com/questions/21708488/get-country-and-continent-from-longitude-and-latitude-point-in-r)

# The single argument to this function, points, is a data.frame in which:
#   - column 1 contains the longitude in degrees
#   - column 2 contains the latitude in degrees
get_countries_continents <- function(points) {
  countriesSP <- getMap(resolution = 'low')
  # countriesSP <- getMap(resolution='high') # you could use high res map from rworldxtra if you were concerned about detail
  
  # take only coords
  coords <- points[, c("longitude", "latitude")]
  
  # converting points to a SpatialPoints object
  # setting CRS directly to that from rworldmap
  pointsSP <- SpatialPoints(coords, proj4string = CRS(proj4string(countriesSP)))  
  
  # use 'over' to get indices of the Polygons object containing each point 
  indices <- over(pointsSP, countriesSP)
  
  # add id back
  indices$id <- points$id
  
  # indices$continent # returns the continent (6 continent model)
  # indices$REGION # returns the continent (7 continent model)
  # indices$ADMIN #returns country name
  # indices$ISO3 # returns the ISO3 code 
  return(indices)
}
input_points <- author_addresses[!is.na(author_addresses$longitude), c("id", "longitude", "latitude")]
countries_continents <- get_countries_continents(input_points)

# add country and continent information to main df
author_locations <- left_join(author_addresses, countries_continents[, c("id", "ADMIN", "REGION")], by = "id")
author_locations <- rename(
  author_locations,
  country = ADMIN,
  continent = REGION
)


# save geocoded locations -----#
fwrite(author_locations, here("author_addresses.csv"))
# author_locations <- fread(here("author_addresses.csv"))
write_parquet(x = author_locations, sink = here("author_addresses.parquet"))

gc()
