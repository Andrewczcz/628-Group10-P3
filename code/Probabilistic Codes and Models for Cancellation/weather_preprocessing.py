import os
import pandas as pd
from datetime import datetime, timedelta

# Convert time to CST based on state and city
def cst_time_fixer(date_str, state, city):
    timevar = datetime.strptime(date_str, "%Y-%m-%dT%H:%M:%S")
    if state == "AK":
        timevar += timedelta(hours=5)
    elif state == "HI":
        timevar += timedelta(hours=6)
    elif state == "PR":
        timevar -= timedelta(hours=2)
    elif state in ["CT", "DE", "DC", "GA", "IN", "ME", "MD", "MA", "MI", "NH", "NJ", "NY", "NC", "OH", "PA", "RI", "SC",
                   "VT", "VA", "WV"]:
        timevar -= timedelta(hours=1)
    elif state == "FL":
        timevar -= timedelta(hours=1) if city != "Pensacola" else timedelta()
    elif state == "KY":
        timevar -= timedelta(hours=1) if city != "Paducah" else timedelta()
    elif state == "TN":
        timevar -= timedelta(hours=1) if city in ["Chattanooga", "Knoxville"] else timedelta()
    elif state == "SD":
        timevar += timedelta(hours=1) if city == "Rapid City" else timedelta()
    elif state == "TX":
        timevar += timedelta(hours=1) if city == "El Paso" else timedelta()
    elif state in ["AZ", "CO", "ID", "KS", "MT", "NM"]:
        timevar += timedelta(hours=1)
    elif state in ["CA", "NV", "OR", "WA"]:
        timevar += timedelta(hours=2)

    return timevar.strftime("%Y-%m-%dT%H:%M:%S")

# Process weather data
def process_weather_data(file_path):
    d = pd.read_csv(file_path)

    # Keep only the first 24 columns
    d = d.iloc[:, :24]

    # Drop unnecessary columns
    columns_to_drop = ['SOURCE', 'HourlyAltimeterSetting', 'HourlySkyConditions', 'HourlyWindGustSpeed']
    d = d.drop(columns=columns_to_drop, errors='ignore')

    # Remove rows where 'REPORT_TYPE' is 'SOD' or 'SOM'
    d = d[~d['REPORT_TYPE'].isin(['SOD', 'SOM'])]

    # Specify columns to fill with forward fill
    columns_to_fill = [
        'HourlyDewPointTemperature', 'HourlyDryBulbTemperature', 'HourlyPrecipitation',
        'HourlyPressureChange', 'HourlyPressureTendency', 'HourlyRelativeHumidity',
        'HourlySeaLevelPressure', 'HourlyStationPressure', 'HourlyVisibility',
        'HourlyWetBulbTemperature', 'HourlyWindDirection', 'HourlyWindSpeed'
    ]
    d[columns_to_fill] = d[columns_to_fill].ffill()

    return d

# Apply both time conversion and data processing
def process_all_weather_files(directory_path, airport_city_file):
    # Load airport city-state data
    airport_city_df = pd.read_csv(airport_city_file)

    for file_name in os.listdir(directory_path):
        if file_name.endswith(".csv"):
            file_path = os.path.join(directory_path, file_name)
            df = pd.read_csv(file_path)

            # Extract airport ID from filename
            airport_id = int(file_name.split("_")[1].split(".")[0])

            # Find corresponding state and city
            airport_info = airport_city_df[airport_city_df['AIRPORT_ID'] == airport_id]
            if not airport_info.empty:
                state = airport_info.iloc[0]['AIRPORT_STATE_CODE']
                city = airport_info.iloc[0]['CITY']

                # Apply time conversion to the DATE column
                df['DATE_CST'] = df['DATE'].apply(lambda date: cst_time_fixer(date, state, city))

                # Apply additional data processing
                processed_df = process_weather_data(file_path)
                df = df.merge(processed_df, left_index=True, right_index=True, how='left')

                # Save the processed file
                df.to_csv(file_path, index=False)

                # Print completion message for each file
                print(f"Time conversion and processing completed for file {file_name}.")

process_all_weather_files('weather/2018_weather', 'AIRPORT_CITY.csv')