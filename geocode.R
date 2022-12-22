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

# # load author locations
# df <- fromJSON(file = here("author_locations.json"))

# load raw text files
file_names <- list.files(here("raw_texts"), pattern = ".*[.]txt")
raw_texts <- lapply(file_names, function(x) readLines(here(paste0("raw_texts/", x))))


# filter institutional affiliations of authors -----
# I'd expect affiliations to be within the first 500 lines
filtered_texts <- lapply(raw_texts, function(x) x[1:500])
# filtered_texts <- lapply(filtered_texts, function(x) x[grepl(pattern = "[A-Za-z]+, .+[0-9]{0,8}, [A-Za-z]+", x = x)])
filtered_texts <- lapply(filtered_texts, function(x) x[grepl(pattern = "(Department|School|Institute|Universit|College|Laboratory|Faculty|Labs|Ltd|Inc[.]|Centre|Center|\\bGoogle\\b|Amazon|Microsoft|\\bIBM\\b|\\bMIT\\b)", x = x, ignore.case = T) | grepl(pattern = "\\b(USA|United States of America|UK|United Kingdom|Germany|Australia|China|Taiwan|Japan|Canada|France|Italy|Spain|Singapore)\\b", x = x)]) # Research|Group
filtered_texts <- lapply(filtered_texts, function(x) x[!str_detect(x, pattern = "(Authorized licensed use limited to)|(Published by )|(Journal of )")])
# filtered_texts <- lapply(filtered_texts, function(x) x[nchar(x) < 150])

# combine list of institutional affiliatons into a tibble
author_affiliations <- filtered_texts %>% unlist() %>% tibble()
colnames(author_affiliations) <- "affiliation"
author_affiliations$addr <- str_replace_all(author_affiliations$affiliation, pattern = ".*?,(.+,.+,.+)", replacement = "\\1") %>% str_trim()
author_affiliations$addr <- str_replace_all(author_affiliations$addr, pattern = "^[0-9]", replacement = "")
author_affiliations$name <- paste0("placeholder", 1:nrow(author_affiliations))
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

# save geocoded locations
fwrite(author_addresses, here("author_addresses.csv"))
write_parquet(x = author_addresses, sink = here("author_addresses.parquet"))

gc()
