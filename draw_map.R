# ++++++++++++++
# DRAW MAP -----
# ++++++++++++++
# FCC20221207
# lots of code shamelessly copied from https://www.data-to-viz.com/story/MapConnection.html#

# https://cran.r-project.org/web/packages/tidygeocoder/readme/README.html
library(tidyverse)
library(tidygeocoder)
library(here)
library(rjson)
library(ggplot2)
library(hrbrthemes)
library(data.table)
library(maps)
library(geosphere)
library(viridis)
library(DT)
library(kableExtra)
options(knitr.table.format = "html")
library(jpeg)
library(grid)
library(RColorBrewer)
set.seed(47)

# Download NASA night lights image
download.file("https://www.nasa.gov/specials/blackmarble/2016/globalmaps/BlackMarble_2016_01deg.jpg", 
              destfile = "BlackMarble_2016_01deg.jpg", mode = "wb")
# Load picture and render
earth <- readJPEG("BlackMarble_2016_01deg.jpg", native = TRUE)
earth <- rasterGrob(earth, interpolate = TRUE)

# load author locations
authors <- fread(here("author_addresses.csv"))

# Generate all pairs of coordinates (between Matze (Pasadena) and the citing author's home institution)
pasadena <- c("lat2" =	34.156113, "lon2" = -118.131943) %>% data.frame() %>% t()
all_pairs <- cbind(authors[, c("latitude", "longitude")], pasadena, authors[, c("country", "continent", "name")]) %>% as.data.frame()
colnames(all_pairs) <- c("lat1", "lon1", "lat2", "lon2", "country", "continent", "name")

# drop NAs
all_pairs <- all_pairs[!is.na(all_pairs$lat1), ]

# assign unique colors to continents and countries
uniq_continents <- unique(all_pairs$continent)
n <- length(uniq_continents)
qual_col_pals = brewer.pal.info[brewer.pal.info$category == 'qual',]
col_vector = unlist(mapply(brewer.pal, qual_col_pals$maxcolors, rownames(qual_col_pals)))
random_colors <- sample(col_vector, n)
for(i in 1:n) {
  all_pairs$continent_color[all_pairs$continent == uniq_continents[i]] <- random_colors[i]
}

uniq_countries <- unique(all_pairs$country)
n <- length(uniq_countries)
qual_col_pals = brewer.pal.info[brewer.pal.info$category == 'qual',]
col_vector = unlist(mapply(brewer.pal, qual_col_pals$maxcolors, rownames(qual_col_pals)))
random_colors <- sample(col_vector, n)
for(i in 1:n) {
  all_pairs$country_color[all_pairs$country == uniq_countries[i]] <- random_colors[i]
}

# get elevation as number of citations from that continent
all_pairs <- all_pairs %>%
  group_by(continent) %>% 
  mutate(elevation = length(name))
all_pairs <- all_pairs %>%
  group_by(lon1, lat1) %>% 
  mutate(cites_n_here = length(name))
all_pairs <- all_pairs %>%
  group_by(country) %>% 
  mutate(cites_n_here_country = length(name))

# save as csv
fwrite(all_pairs[!is.na(all_pairs$lon1), ], "network_pairs.csv")

# select lon-lat columns
all_pairs <- all_pairs[, c("lat1", "lon1", "lat2", "lon2")]

# create groups for longitude ranges as substitute for continents
all_pairs$lon_range <- round(all_pairs$lon1 / 50)

# A function to plot connections
plot_my_connection <- function( dep_lon, dep_lat, arr_lon, arr_lat, ...){
  inter <- gcIntermediate(c(dep_lon, dep_lat), c(arr_lon, arr_lat), n=50, addStartEnd = TRUE, breakAtDateLine = F)             
  inter = data.frame(inter)
  diff_of_lon = abs(dep_lon) + abs(arr_lon)
  if(diff_of_lon > 180) {
    lines(subset(inter, lon >= 0), ...)
    lines(subset(inter, lon < 0), ...)
  } else {
    lines(inter, ...)
  }
}

# A function that makes a dateframe per connection (we will use these connections to plot each lines)
data_for_connection=function( dep_lon, dep_lat, arr_lon, arr_lat, group){
  inter <- gcIntermediate(c(dep_lon, dep_lat), c(arr_lon, arr_lat), n = 50, addStartEnd = TRUE, breakAtDateLine = F)             
  inter=data.frame(inter)
  inter$group=NA
  diff_of_lon=abs(dep_lon) + abs(arr_lon)
  if(diff_of_lon > 180){
    inter$group[ which(inter$lon>=0)]=paste(group, "A",sep="")
    inter$group[ which(inter$lon<0)]=paste(group, "B",sep="")
  }else{
    inter$group=group
  }
  return(inter)
}

# Count how many times we have each unique connexion + order by importance
summary_data <- all_pairs %>% 
  dplyr::count(lat1, lon1,
               lon_range,
               # homecontinent,
               # travelcontinent,
               lat2, lon2
               ) %>%
  arrange(n)

data_ready_plot <- data.frame()
for(i in c(1:nrow(summary_data))){
  tmp = data_for_connection(summary_data$lon1[i], summary_data$lat1[i], summary_data$lon2[i], summary_data$lat2[i], i)
  tmp$lon_range = summary_data$lon_range[i] %>% factor()
  tmp$n = summary_data$n[i]
  data_ready_plot = rbind(data_ready_plot, tmp)
}
# data_ready_plot$homecontinent <- factor(data_ready_plot$homecontinent, levels=c("Asia","Europe","Australia","Africa","North America","South America","Antarctica"))

# A function that keeps the good part of the great circle, by Jeff Leek:
getGreatCircle <- function(userLL, relationLL){
  tmpCircle = greatCircle(userLL, relationLL, n = 200)
  start = which.min(abs(tmpCircle[,1] - data.frame(userLL)[1,1]))
  end = which.min(abs(tmpCircle[,1] - relationLL[1]))
  greatC = tmpCircle[start:end,]
  return(greatC)
}


# Plotting -----
# draw empty map
par(mar=c(0,0,0,0)) # No margin
map('world', # World map
    col = "#f2f2f2", fill = TRUE, bg = "white", lwd = 0.05,
    mar = rep(0, 4), border = 0, ylim = c(-80, 80) 
)
points(
  x = all_pairs$lon1, 
  y = all_pairs$lat1, 
  col = "slateblue", cex = 3, pch = 20) # add institutions as points

# add every connections
for(i in 1:nrow(all_pairs)) {
  # great <- getGreatCircle(all_pairs[i, c("lon1", "lat1")], all_pairs[i, c("lon2", "lat2")])
  # lines(great, col = "skyblue", lwd = 2)
  plot_my_connection(all_pairs$lon1[i], all_pairs$lat1[i], all_pairs$lon2[i], all_pairs$lat2[i], col = "skyblue", lwd = 2)
}

# # add points and names of cities
# points(x = data$lon, y = data$lat, col = "slateblue", cex = 2, pch = 20)
# text(rownames(data), x = data$lon, y = data$lat,  col = "slateblue", cex = 1, pos = 4)


# version with background image -----#
p <- ggplot() +
  annotation_custom(earth, xmin = -180, xmax = 180, ymin = -90, ymax = 90) +
  geom_line(data = data_ready_plot, aes(
    x = lon, y = lat, 
    group = group,
    colour = lon_range,
    # color = "skyblue",
    alpha = n
  ), 
  size = 1.5) +
  scale_color_brewer(palette = "Set3") +
  theme_void() +
  theme(
    legend.position = "none",
    panel.background = element_rect(fill = "black", colour = "black"), 
    panel.spacing = unit(c(0,0,0,0), "null"),
    plot.margin = grid::unit(c(0,0,0,0), "cm"),
  ) +
  # ggplot2::annotate("text", x = -150, y = -45, hjust = 0, size = 11, label = paste("Where surfers travel."), color = "white") +
  # ggplot2::annotate("text", x = -150, y = -51, hjust = 0, size = 8, label = paste("data-to-viz.com | NASA.gov | 10,000 #surf tweets recovered"), color = "white", alpha = 0.5) +
  #ggplot2::annotate("text", x = 160, y = -51, hjust = 1, size = 7, label = paste("Cacedédi Air-Guimzu 2018"), color = "white", alpha = 0.5) +
  xlim(-180,180) +
  ylim(-60,80) +
  scale_x_continuous(expand = c(0.006, 0.006)) +
  coord_equal() 

# Save at PNG
ggsave("Matze_cite_network.png", width = 36, height = 15.22, units = "in", dpi = 90)

