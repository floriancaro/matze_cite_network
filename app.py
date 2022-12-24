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
df_countries["fill_color"] = 1
df_countries["elevation"] = 1
df_countries = df_countries.drop(['features'], axis=1)

# add country geometry to main data
df = df.merge(df_countries, on=['country'], how='left') # , indicator=True
df.dropna(inplace=True)

# Define layers to display on a map
layer_greatCircles = pdk.Layer(
    "GreatCircleLayer",
    df,
    pickable=True,
    get_stroke_width=25,
    get_source_position="[lon1, lat1]",
    get_target_position="[lon2, lat2]",
    get_source_color=[64, 255, 0],
    get_target_color=[0, 128, 200],
    auto_highlight=True,
)
geojson_layer = pdk.Layer(
    "GeoJsonLayer",
    df,
    opacity=0.8,
    stroked=False,
    filled=True,
    extruded=True,
    wireframe=True,
    get_elevation=3,
    # get_elevation="elevation",
    get_fill_color=[50, 100, 200],
    # get_fill_color="country",
    get_line_color=[0, 0, 0],
    get_line_width=15,
    auto_highlight=True,
    # pickable=True,
)
# Set the viewport location
view_state = pdk.ViewState(
    latitude=31.15611,
    longitude=0,
    zoom=1.35,
    min_zoom=1.35,
    max_zoom=1.35,
    bearing=0,
    pitch=0,
    height=600,
    # width=1000
)

# Render
r = pdk.Deck(
    layers=[
        geojson_layer,
        layer_greatCircles
    ],
    initial_view_state=view_state,
    tooltip={
        "text": "{name}",
        "style": {
            "backgroundColor": "steelblue",
            "color": "white"
        }
    },
    # tooltip={"text": "placeholder"},
    map_style="mapbox://styles/mapbox/light-v10",
)
r.picking_radius = 17
r.to_html("index.html")

# Render the deck.gl map in the Streamlit app as a Pydeck chart
st.title("Matze's Citation Impact Network")
map = st.pydeck_chart(
    r,
    use_container_width=True
)

# Update the maps and the subheading each day for 90 days
for i in range(0, 20, 1):
    # Increment day by 1
    date += datetime.timedelta(days=1)
    # Update data in map layers
    layer_greatCircles.data = get_fill_color=[50, 100 + i, 200],
    # Update the deck.gl map
    r.update()
    # Render the map
    map.pydeck_chart(r)
    # # Update the heading with current date
    # subheading.subheader("%s on : %s" % (metric_to_show_in_covid_Layer, date.strftime("%B %d, %Y")))

    # wait 1 second before go onto next day
    time.sleep(.1)
