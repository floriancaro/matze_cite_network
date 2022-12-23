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

# use full screen to display the app
st.set_page_config(
    layout="wide",
)

# GREAT_CIRCLE_LAYER_DATA = "https://raw.githubusercontent.com/visgl/deck.gl-data/master/website/flights.json"  # noqa
network_pairs = "https://github.com/floriancaro/matze_cite_network/blob/florian/network_pairs.csv?raw=true"
countries_data = "https://github.com/datasets/geo-countries/blob/master/data/countries.geojson?raw=true"

# df = pd.read_json(GREAT_CIRCLE_LAYER_DATA)
df = pd.read_csv(network_pairs)
df_countries = pd.read_json(countries_data)

## Use pandas to prepare data for tooltip
# df["from_name"] = df["from"].apply(lambda f: f["name"])
# df["to_name"] = df["to"].apply(lambda t: t["name"])

# Parse the geometry out in Pandas
df_countries["coordinates"] = df_countries["features"].apply(lambda row: row["geometry"]["coordinates"])
df_countries["country"] = df_countries["features"].apply(lambda row: row["properties"]["ADMIN"])

# add country geometry to main data
df_plot = df.merge(df_countries[["coordinates", "country"]], on=['country'], how='left') # , indicator=True

# Define layers to display on a map
# layer_greatCircles = pdk.Layer(
#     "GreatCircleLayer",
#     df_plot,
#     pickable=True,
#     get_stroke_width=15,
#     # get_source_position="from.coordinates",
#     get_source_position="[lon1, lat1]",
#     # get_target_position="to.coordinates",
#     get_target_position="[lon2, lat2]",
#     get_source_color=[64, 255, 0],
#     get_target_color=[0, 128, 200],
#     auto_highlight=True,
# )
layer_countries = pdk.Layer(
    "PolygonLayer",
    df_plot,
    id="geojson",
    opacity=0.8,
    stroked=False,
    get_polygon="coordinates",
    filled=True,
    extruded=True,
    wireframe=True,
    # get_elevation="elevation",
    get_fill_color=[64, 255, 0],
    getLineColor=[80, 80, 80],
    getLineWidth=1,
    auto_highlight=True,
    pickable=True,
)

# Set the viewport location
view_state = pdk.ViewState(
    latitude=34.15611,
    longitude=-30.1319,
    zoom=2,
    min_zoom=2,
    max_zoom=2,
    bearing=0,
    pitch=.3,
    height=600,
    # width=1000
    )
# view_state = pdk.ViewState(latitude=34.15611, longitude=-118.1319, zoom=.8, bearing=0, pitch=.1)

# Render
r = pdk.Deck(
    layers=[layer_greatCircles, layer_countries],
    initial_view_state=view_state,
    # tooltip={"text": "{from_name} to {to_name}"},
    tooltip={"text": "placeholder"},
)
r.picking_radius = 13

# r.update_layout(
#     title_text="Matze's Citation Network",
#     margin={"r": 0, "t": 0, "l": 0, "b": 0},
#     height=800
# )

# r.to_html("index.html")

# display with streamlit
st.pydeck_chart(r, use_container_width=True)
