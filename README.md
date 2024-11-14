# Flight Delay and Cancellation Prediction Project

## Overview

This project aims to predict flight delays and cancellations using various data sources, including flight details, weather, and airport information. The repository contains code for analysis and modeling, raw and processed data, images for visualizations, and files for the Shiny application interface. Some additional data files are available via a web disk linked on the project homepage.

## Folder Structure

### `code/`
This folder contains all the code and model files for analyzing and predicting flight cancellation and delay probabilities, as well as delay time predictions.

- **Canceling Probabilities**: Contains code and models used to predict the probability of flight cancellations based on factors such as weather and holiday periods.
- **Delay Probabilities**: Includes code and models for predicting the probability of flight delays, based on factors like carrier performance and departure/arrival times.
- **Delay Time Modeling**: Houses scripts and models to estimate the expected delay time for flights that are predicted to experience a delay.

### `data/`
This folder holds a selection of data files used in the project. Additional data, including raw and processed datasets, is available for download through a link provided in the main README file on the project homepage.

- **Core Data Files**: Contains essential data files used by the models and analysis scripts.
- **Other Data**
- Raw data: https://drive.google.com/drive/folders/1xrS0qNdUAesgwKYYcqXSC7H8w8iNao9Z?usp=drive_link
- Processed data: https://drive.google.com/drive/folders/1Xz6Fz9pkGlwMvnBs4PhJi2Hq9oGpZzUf?usp=drive_link

### `images/`
This folder includes visualizations generated from the analysis, providing insights into cancellation and delay trends.

- **Cancelation Rate by Unique Carrier (sorted).png**: A sorted visualization showing the cancellation rates by carrier.
- **Cancellation Rate by Holiday Period.png**: A chart detailing cancellation rates during holiday periods.
- **Cancellation Rate by Time Category (Arrival and Departure).png**: Shows cancellation rates by time of day for arrivals and departures.
- **ROC Curve.png**: Displays the ROC curve to assess model performance.
- **Additional Images**: Includes other visualizations and charts used to support project findings.

### `shiny/`
Contains all files required to run the Shiny application. This app provides a user-friendly interface where users can input flight information to receive real-time predictions for cancellation and delay probabilities, as well as estimated delay times.

### Additional Files

- **STAT628_AirlineProject_Group10.pdf** and **STAT628_AirlineProject_Group10.pptx**: A PowerPoint presentation providing an overview of the project for presentation purposes.
- **STAT628_Module3.pdf**: The project report summarizing methods, findings, and insights.


## Installation and Usage Guide

### Prerequisites

- **R** with the following packages:
  ```R
  install.packages(c("shiny", "reticulate", "httr", "jsonlite", "lubridate", "dplyr", "leaflet"))
  ```
- **Python 3.x** with the following libraries:
  ```bash
  pip install pandas numpy joblib scikit-learn torch
  ```

### Setup

1. Clone the repository to your local directory:
   ```bash
   git clone https://github.com/yourusername/flight-delay-prediction.git
   cd flight-delay-prediction
   ```
2. Install the required R packages:
   ```R
   install.packages(c("shiny", "reticulate", "httr", "jsonlite", "lubridate", "dplyr", "leaflet"))
   ```
3. Set up a Python virtual environment and install necessary libraries:
   ```bash
   virtualenv python3_env
   source python3_env/bin/activate
   pip install pandas numpy joblib scikit-learn torch
   ```

### Running the Application

1. Ensure all `.csv`, `.pkl`, and `.pth` files are in the same directory as `app.R`.
2. Start the Shiny application from R:
   ```R
   shiny::runApp("app.R")
   ```
3. Access the application in your browser, enter flight details, view the flight path on the map, and receive delay and cancellation predictions.

## User Guide

1. **Input Flight Information**: Users can enter the departure and destination airport codes, scheduled departure time, and select an airline.
2. **Map Visualization**: Based on the input airport codes, the app displays the flight route and marks the departure and arrival locations on an interactive map.
3. **Prediction Results**: The application outputs the cancellation probability, delay probability, estimated delay time (if any), and adjusted arrival time.

## Known Issues and Recommendations

### Shiny Application Instability

The integration of R and Python machine learning models, along with large datasets and complex processing, may lead to occasional instability in the Shiny app. During testing, we observed that:

- **Initial Execution**: The first click on the prediction button typically produces results without issue.
- **Subsequent Clicks**: After the first prediction, rapid subsequent clicks can sometimes cause the Shiny interface to crash or restart. We suspect this is due to the time-intensive nature of data loading and processing, which may be too demanding for Shiny’s real-time environment.

**Recommendation**: After the first prediction, if the page appears to restart (e.g., the page dims), please wait approximately 40 seconds before clicking the “Restart” button at the bottom left or refreshing the browser page. This pause allows the backend processes to complete, which should help ensure a stable experience for the next prediction attempt.

### Additional Notes

1. Ensure `test.py` and `app.R` have appropriate file permissions for reading and writing CSV files.
2. The `scaler2.pkl` and `onehot_encoder_model.pkl` files are crucial for data preprocessing. Altering or missing these files may lead to inaccurate predictions.
3. Compatibility issues between R and Python may cause application errors. Before launching the Shiny app, confirm that the Python environment and R environment are correctly configured.

### Shortcomings & Improvements
Our Shiny app seems to run with some instability. After each run, the first click works as expected, but we suspect that backend data loading may not be completed, or the data size is too large, causing the app to crash if clicked again immediately after the first run. It takes around 40 seconds before the app can reliably handle the next prediction. This may not be due to our code but rather a server-related issue.

For instructors, TAs, or other users testing the app, we recommend waiting a bit after the first click. If the app appears to restart (with the page dimming), please wait briefly, then click the restart button in the bottom left or refresh the browser. This should ensure the app runs smoothly for the next prediction.
