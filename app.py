"""
Matze's Cite Network
================

Plot of connections between home institutions of authors citing Matze's papers and Matze's current home institution

Origin is in green; destinations are in blue.

Adapted from the deck.gl documentation.
"""

import streamlit as st
import pydeck as pdk
import pandas as pd
import datetime
import math
import time
from PIL import ImageColor
import random
import numpy as np

# Variable for date picker, default to Jan 1st 2020
date = datetime.date(2020,1,1)

# use full screen to display the app
st.set_page_config(
    layout="wide",
)

# GREAT_CIRCLE_LAYER_DATA = "https://raw.githubusercontent.com/visgl/deck.gl-data/master/website/flights.json"  # noqa
network_pairs = "https://github.com/floriancaro/matze_cite_network/blob/florian/network_pairs.csv?raw=true"
countries_data = "countries.geo.json"
# countries_data = "https://github.com/datasets/geo-countries/blob/master/data/countries.geojson?raw=true"

# df = pd.read_json(GREAT_CIRCLE_LAYER_DATA)
df = pd.read_csv(network_pairs)
df_countries = pd.read_json(countries_data)

## Use pandas to prepare data for tooltip
# df["from_name"] = df["from"].apply(lambda f: f["name"])
# df["to_name"] = df["to"].apply(lambda t: t["name"])

# Parse the geometry out in Pandas
df_countries["geometry"] = df_countries["features"].apply(lambda row: row["geometry"])
df_countries["coordinates"] = df_countries["features"].apply(lambda row: row["geometry"]["coordinates"])
# df_countries["country"] = df_countries["features"].apply(lambda row: row["properties"]["ADMIN"])
df_countries["country"] = df_countries["features"].apply(lambda row: row["properties"]["admin"])
df_countries = df_countries.drop(['features'], axis=1)

# add country geometry to main data
df = df.merge(df_countries, on=['country'], how='left') # , indicator=True
df.dropna(inplace=True)

# # get aggregate values by country
# df["cites_n_here_country"] = df.groupby(['country'])['cites_n_here'].transform(np.sum)

# convert colors to RGB
df["country_color_RGB"] = df["country_color"].apply(lambda x: ImageColor.getcolor(x, "RGB"))
df["continent_color_RGB"] = df["continent_color"].apply(lambda x: ImageColor.getcolor(x, "RGB"))
df["log_cites_n_here"] = df["cites_n_here"].apply(lambda x: math.log(x + 1) + 1)
df["log_cites_n_here_country"] = df["cites_n_here_country"].apply(lambda x: math.log(x + 1) + 1)

# create subsets
df_lon_lat = df.drop_duplicates(subset=['lon1', 'lat1'])
df_countries = df.drop_duplicates(subset=['country'])
df_countries["cites_n_here"] = df_countries["cites_n_here_country"]
df_countries["log_cites_n_here"] = df_countries["log_cites_n_here_country"]
df_countries["name"] = df_countries["country"]

# Define layers to display on a map
layer_greatCircles = pdk.Layer(
    "GreatCircleLayer",
    df_lon_lat,
    pickable=True,
    get_width="log_cites_n_here * 1.5",
    get_source_position="[lon1, lat1]",
    get_target_position="[lon2, lat2]",
    # get_source_color=[64, 255, 0],
    # get_source_color="continent_color_RGB",
    get_source_color="country_color_RGB",
    get_target_color=[0, 128, 200],
    # get_target_color="continent_color_RGB",
    auto_highlight=True,
)
geojson_layer = pdk.Layer(
    "GeoJsonLayer",
    df_countries,
    opacity=1,
    # opacity="0.1 * elevation",
    stroked=False,
    filled=True,
    extruded=True,
    wireframe=True,
    # get_elevation="elevation",
    get_elevation=10,
    # get_fill_color="country_color_RGB",
    get_fill_color="continent_color_RGB",
    auto_highlight=True,
    pickable=True,
)
scatter_layer = pdk.Layer(
    "ScatterplotLayer",
    df_lon_lat,
    pickable=True,
    opacity=0.8,
    stroked=True,
    filled=True,
    radius_scale=6,
    radius_min_pixels=5,
    radius_max_pixels=100,
    line_width_min_pixels=2,
    get_position="[lon1, lat1]",
    get_radius=20,
    # get_fill_color="continent_color_RGB",
    get_fill_color="country_color_RGB",
    get_line_color=[0, 0, 0],
)

# Set the viewport location
view_state = pdk.ViewState(
    latitude=29.15611,
    longitude=0,
    zoom=1.5,
    min_zoom=1.5,
    max_zoom=10,
    bearing=0,
    pitch=0,
    height=700,
    # width=1000
)

# Render
r = pdk.Deck(
    layers=[
        geojson_layer,
        scatter_layer,
        layer_greatCircles,
    ],
    initial_view_state=view_state,
    tooltip={
        "text": "{name}\nCiters: {cites_n_here}\nCountry: {country}",
        "style": {
            "backgroundColor": "steelblue",
            "color": "white"
        }
    },
    # map_style="mapbox://styles/mapbox/light-v10",
)
r.picking_radius=10
r.to_html("index.html")

# Render the deck.gl map in the Streamlit app as a Pydeck chart
btn_text = "Reveal"
reveal_hide = st.button(btn_text)
if reveal_hide:
    st.title("Matze's Citation Impact Network")
    btn_text = "Reveal"
else:
    st.title("Mystery Map")
    btn_text = "Hide"

map = st.pydeck_chart(
    r,
    use_container_width=True
)

# # Update the maps
# i = 0
# while True:
#     # update colors
#     df["continent_color_RGB"] = df["continent_color_RGB"].apply(lambda x: [x[0], x[1], x[2] * math.sin(i)])
#     # Update data in map layers
#     # layer_greatCircles.get_source_color=df["continent_color_RGB_updated"][1]
#     # layer_greatCircles.get_source_color=[random.randrange(0, 255), random.randrange(0, 255), random.randrange(0, 255)]
#     # Update the deck.gl map
#     r.update()
#     # Render the map
#     map.pydeck_chart(r)
#     # # Update the heading with current date
#     # subheading.subheader("%s on : %s" % (metric_to_show_in_covid_Layer, date.strftime("%B %d, %Y")))
#     i += .05
#     # wait 1 second before go onto next day
#     time.sleep(.05)
#     # st.table(df[["continent_color_RGB_updated", "continent_color_RGB"]])
