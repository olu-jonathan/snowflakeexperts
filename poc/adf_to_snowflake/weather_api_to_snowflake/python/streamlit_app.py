### REPLACE THE PLACEHOLDER <your_last_name> WITH YOUR LAST NAME or use the database you work with. 

DATABASE_NAME = "<your_last_name>_DB"
# ============================================================
# 🌤️ Global Weather Dashboard
# Azure Data Factory → Weather API → Snowflake → Streamlit
# ============================================================

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session


# ============================================================
# PAGE CONFIGURATION
# ============================================================

st.set_page_config(
    page_title="Global Weather Dashboard",
    page_icon="🌤️",
    layout="wide",
    initial_sidebar_state="expanded"
)


# ============================================================
# SNOWFLAKE SESSION
# ============================================================

session = get_active_session()


# ============================================================
# CUSTOM CSS
# ============================================================

st.markdown(
    """
    <style>

    /* Main page */
    .block-container {
        padding-top: 2rem;
        padding-bottom: 2rem;
    }

    /* Header */
    .dashboard-title {
        font-size: 2.5rem;
        font-weight: 700;
        margin-bottom: 0;
    }

    .dashboard-subtitle {
        font-size: 1.05rem;
        color: #6b7280;
        margin-top: 0.2rem;
    }

    /* Weather hero card */
    .weather-hero {
        padding: 1.5rem;
        border-radius: 18px;
        background: linear-gradient(
            135deg,
            #667eea 0%,
            #764ba2 100%
        );
        color: white;
        margin-bottom: 1rem;
    }

    .weather-city {
        font-size: 2rem;
        font-weight: 700;
        margin-bottom: 0.2rem;
    }

    .weather-country {
        font-size: 1rem;
        opacity: 0.85;
    }

    .weather-description {
        font-size: 1.25rem;
        margin-top: 0.75rem;
    }

    /* Footer */
    .footer {
        text-align: center;
        color: #6b7280;
        font-size: 0.85rem;
        padding-top: 2rem;
    }

    </style>
    """,
    unsafe_allow_html=True
)


# ============================================================
# DATA ACCESS
# ============================================================

@st.cache_data(ttl=60)
def load_weather_data():
    """
    Load the latest weather observation for each country
    from the Snowflake presentation layer.
    """

    query = """
        SELECT
            COUNTRY,
            AREA_NAME,
            HUMIDITY,
            TEMP_C,
            WEATHER_DESC
        FROM {DATABASE_NAME}.PRESENTATION.WEATHER_REPORT
        ORDER BY COUNTRY, AREA_NAME
    """

    return session.sql(query).to_pandas()


# ============================================================
# LOAD DATA
# ============================================================

df = load_weather_data()


# ============================================================
# VALIDATE DATA
# ============================================================

if df.empty:
    st.error(
        "No weather data is currently available. "
        "Please verify the ADF pipeline and Snowflake tables."
    )
    st.stop()


# Normalize data types
df["TEMP_C"] = pd.to_numeric(df["TEMP_C"], errors="coerce")
df["HUMIDITY"] = pd.to_numeric(df["HUMIDITY"], errors="coerce")

df["COUNTRY"] = df["COUNTRY"].fillna("Unknown")
df["AREA_NAME"] = df["AREA_NAME"].fillna("Unknown")
df["WEATHER_DESC"] = df["WEATHER_DESC"].fillna("Unknown")


# ============================================================
# HEADER
# ============================================================

header_col1, header_col2 = st.columns([5, 1])

with header_col1:

    st.markdown(
        '<div class="dashboard-title">🌤️ Global Weather Dashboard</div>',
        unsafe_allow_html=True
    )

    st.markdown(
        '<div class="dashboard-subtitle">'
        'Current weather observations for capital cities around the world'
        '</div>',
        unsafe_allow_html=True
    )

with header_col2:

    if st.button("🔄 Refresh", use_container_width=True):

        st.cache_data.clear()

        st.rerun()


st.divider()


# ============================================================
# SIDEBAR FILTERS
# ============================================================

with st.sidebar:

    st.header("🔎 Filters")

    st.caption("Select a location to view its latest weather.")

    # Country filter
    countries = sorted(df["COUNTRY"].unique())

    selected_country = st.selectbox(
        "🌎 Country",
        options=["All Countries"] + countries
    )

    # Filter country
    if selected_country != "All Countries":

        filtered_df = df[
            df["COUNTRY"] == selected_country
        ].copy()

    else:

        filtered_df = df.copy()


    # City filter
    cities = sorted(filtered_df["AREA_NAME"].unique())

    selected_city = st.selectbox(
        "🏙️ City",
        options=cities
    )

    st.divider()

    st.markdown("### 📊 Dashboard Statistics")

    st.metric(
        "Cities",
        f"{df['AREA_NAME'].nunique():,}"
    )

    st.metric(
        "Countries",
        f"{df['COUNTRY'].nunique():,}"
    )

    st.caption(
        "Data refreshes automatically every 60 seconds "
        "when the dashboard is accessed."
    )


# ============================================================
# SELECTED CITY DATA
# ============================================================

city_data = df[
    df["AREA_NAME"] == selected_city
]

if city_data.empty:
    st.warning("No weather data found for the selected city.")
    st.stop()

city = city_data.iloc[0]


# ============================================================
# WEATHER HERO
# ============================================================

# ============================================================
# WEATHER HERO
# ============================================================

with st.container(border=True):

    st.markdown(f"## 📍 {city['AREA_NAME']}")

    st.markdown(
        f"### ☁️ {city['WEATHER_DESC']}"
    )

    st.caption(
        f"{city['COUNTRY']} · Current weather conditions"
    )


# ============================================================
# CURRENT WEATHER METRICS
# ============================================================

temp = city["TEMP_C"]
humidity = city["HUMIDITY"]
description = city["WEATHER_DESC"]


col1, col2, col3 = st.columns(3)


with col1:

    if pd.notna(temp):

        st.metric(
            label="🌡️ Temperature",
            value=f"{temp:.0f} °C"
        )

    else:

        st.metric(
            label="🌡️ Temperature",
            value="N/A"
        )


with col2:

    if pd.notna(humidity):

        st.metric(
            label="💧 Humidity",
            value=f"{humidity:.0f}%"
        )

    else:

        st.metric(
            label="💧 Humidity",
            value="N/A"
        )


with col3:

    st.metric(
        label="☁️ Conditions",
        value=str(description)
    )


# ============================================================
# COMFORT INDICATOR
# ============================================================

st.markdown("### 🌡️ Comfort Indicator")


if pd.notna(temp):

    if temp >= 30:

        comfort = "🥵 Hot"
        comfort_message = "Stay hydrated and take breaks from the heat."

    elif temp >= 20:

        comfort = "😊 Comfortable"
        comfort_message = "Great conditions for outdoor activities."

    elif temp >= 10:

        comfort = "🧥 Cool"
        comfort_message = "You may want a light jacket."

    else:

        comfort = "🥶 Cold"
        comfort_message = "Bundle up and stay warm."

    st.info(
        f"**{comfort}** — {comfort_message}"
    )


if pd.notna(humidity) and humidity > 80:

    st.warning(
        "💧 **High humidity:** "
        "The weather may feel warmer than the measured temperature."
    )


# ============================================================
# GLOBAL STATISTICS
# ============================================================

st.divider()

st.markdown("### 🌍 Global Weather Overview")


stat1, stat2, stat3, stat4 = st.columns(4)


with stat1:

    st.metric(
        "🌎 Countries",
        f"{df['COUNTRY'].nunique():,}"
    )


with stat2:

    st.metric(
        "🏙️ Cities",
        f"{df['AREA_NAME'].nunique():,}"
    )


with stat3:

    if df["TEMP_C"].notna().any():

        avg_temp = df["TEMP_C"].mean()

        st.metric(
            "🌡️ Avg Temperature",
            f"{avg_temp:.1f} °C"
        )

    else:

        st.metric(
            "🌡️ Avg Temperature",
            "N/A"
        )


with stat4:

    if df["HUMIDITY"].notna().any():

        avg_humidity = df["HUMIDITY"].mean()

        st.metric(
            "💧 Avg Humidity",
            f"{avg_humidity:.0f}%"
        )

    else:

        st.metric(
            "💧 Avg Humidity",
            "N/A"
        )


# ============================================================
# TEMPERATURE DISTRIBUTION
# ============================================================

st.markdown("### 🌡️ Temperature by City")


chart_df = (
    df[
        ["AREA_NAME", "TEMP_C"]
    ]
    .dropna()
    .sort_values("TEMP_C")
    .set_index("AREA_NAME")
)


if not chart_df.empty:

    st.bar_chart(
        chart_df,
        y="TEMP_C",
        x_label="City",
        y_label="Temperature (°C)"
    )


# ============================================================
# ALL CITIES TABLE
# ============================================================

st.markdown("### 📋 All Cities")


display_df = df.rename(
    columns={
        "COUNTRY": "Country",
        "AREA_NAME": "City",
        "TEMP_C": "Temperature (°C)",
        "HUMIDITY": "Humidity (%)",
        "WEATHER_DESC": "Conditions"
    }
)


st.dataframe(
    display_df,
    use_container_width=True,
    hide_index=True,
    height=500,

    column_config={

        "Country":
            st.column_config.TextColumn(
                "Country"
            ),

        "City":
            st.column_config.TextColumn(
                "City"
            ),

        "Temperature (°C)":
            st.column_config.NumberColumn(
                "Temperature",
                format="%.0f °C"
            ),

        "Humidity (%)":
            st.column_config.ProgressColumn(
                "Humidity",
                min_value=0,
                max_value=100,
                format="%d%%"
            ),

        "Conditions":
            st.column_config.TextColumn(
                "Conditions"
            )
    }
)


# ============================================================
# DATA REFRESH INFORMATION
# ============================================================

st.divider()

st.caption(
    "❄️ Data source: Snowflake "
    "`PRESENTATION.WEATHER_REPORT` | "
    "ADF ingestion frequency: every 30 minutes | "
    "Dashboard cache: 60 seconds"
)


st.markdown(
    """
    <div class="footer">
        Built with Azure Data Factory, Snowflake & Streamlit
    </div>
    """,
    unsafe_allow_html=True
)