library(shiny)
library(reticulate)
library(httr)
library(jsonlite)
library(lubridate)
library(dplyr)
library(leaflet)
library(rsconnect)
options(rsconnect.max.bundle.size = 8 * 1024^3) 

virtualenv_create("python3_env")
virtualenv_install("python3_env", packages = c("pandas","numpy", "joblib", "scikit-learn", "pip", "wheel", "setuptools"))  # 安装所需的 Python 包
use_virtualenv("python3_env", required = TRUE)


py_run_string("import joblib")
py_run_string("model = joblib.load('model.pkl')")
py_run_string("model_columns = joblib.load('model_columns.pkl')")
py_run_string("logistic_model = joblib.load('logistic_model.pkl')")
py_run_string("model_columns2 = joblib.load('model_columns2.pkl')")
py_run_string("scaler2 = joblib.load('scaler2.pkl')")

origin_others_airports <- c('YAK', 'BFM', 'ESC', 'CKB', 'BLV', 'AKN', 'OWB', 
                            'LBL', 'LBE', 'RFD', 'PUB', 'OGD', 'YNG', 'HGR', 
                            'PIR', 'DRT', 'FOD', 'BKG', 'SJT', 'IFP', 'SLN', 
                            'STX', 'ROP', 'DLG', 'OME', 'STC', 'SHR', 'BQK', 
                            'EAU', 'EKO', 'EAR', 'SMX', 'APN', 'ADK', 'ATY', 
                            'IAG', 'BFF', 'GGG', 'PSM', 'LCK', 'HGR', 'MCW')

dest_others_airports <- c('BIH', 'GGG', 'BFM', 'FOD', 'DRT', 'ROP', 'LBE', 
                          'OGD', 'BKG', 'ACT', 'CKB', 'RIW', 'PIR', 'HOB', 
                          'SPS', 'GUM', 'MKK', 'ATY', 'YAK', 'EAU', 'OWB', 
                          'EAR', 'RFD', 'PUB', 'STX', 'PSM', 'VCT', 'AKN', 
                          'MCW', 'SMX', 'DEC', 'ADK', 'USA', 'EKO', 'LCK', 
                          'BFF', 'YNG', 'IFP')

convert_airport_to_others <- function(origin_airport, dest_airport) {
  if (origin_airport %in% origin_others_airports) {
    origin_airport <- "ORIGIN_OTHERS"
  }
  if (dest_airport %in% dest_others_airports) {
    dest_airport <- "DEST_OTHERS"
  }
  return(list(origin = origin_airport, destination = dest_airport))
}

# 机场经纬度
airport_data <- read.csv("AIRPORT_filtered_full.csv")
airport_coords <- setNames(
  lapply(seq_len(nrow(airport_data)), function(i) {
    list(lat = airport_data$LATITUDE[i], lon = airport_data$LONGITUDE[i])
  }),
  airport_data$AIRPORT
)

# 计算飞行时间和飞行距离
earth_radius_km <- 6371 

calculate_distance <- function(origin, destination) {
  if (is.null(airport_coords[[origin]]) || is.null(airport_coords[[destination]])) {
    return(NA)
  }
  
  lat1 <- airport_coords[[origin]]$lat * pi / 180
  lon1 <- airport_coords[[origin]]$lon * pi / 180
  lat2 <- airport_coords[[destination]]$lat * pi / 180
  lon2 <- airport_coords[[destination]]$lon * pi / 180
  
  delta_lat <- lat2 - lat1
  delta_lon <- lon2 - lon1
  
  a <- sin(delta_lat / 2)^2 + cos(lat1) * cos(lat2) * sin(delta_lon / 2)^2
  c <- 2 * atan2(sqrt(a), sqrt(1 - a))
  distance <- earth_radius_km * c
  
  return(distance)
}

estimate_flight_time <- function(distance) {
  average_speed_kmh <- 800  # 假设航班平均速度为800公里/小时
  flight_time <- (distance / average_speed_kmh) * 60  # 转换为分钟
  return(flight_time)
}

get_elevation <- function(airport_code) {
  # 读取 elevation.csv 文件
  file_path <- "elevation.csv"
  elevation_data <- read.csv(file_path)
  
  # 查找指定机场的海拔
  filtered_data <- elevation_data[elevation_data$AIRPORT == airport_code, "DEST_ELEVATION"]
  
  # 检查是否找到了匹配的机场代码
  if (length(filtered_data) > 0) {
    airport_elevation <- filtered_data[1]  # 如果有多个匹配，只返回第一个
  } else {
    # 如果未找到匹配的机场，将海拔设置为默认值 0
    airport_elevation <- 0
  }
  
  return(airport_elevation)
}

# 定义感恩节和其他假期范围
thanksgiving_ranges <- list(
  `2018` = c(as.Date("2018-11-21"), as.Date("2018-11-26")),
  `2019` = c(as.Date("2019-11-27"), as.Date("2019-12-02")),
  `2020` = c(as.Date("2020-11-25"), as.Date("2020-11-30")),
  `2021` = c(as.Date("2021-11-24"), as.Date("2021-11-29")),
  `2022` = c(as.Date("2022-11-23"), as.Date("2022-11-28")),
  `2023` = c(as.Date("2023-11-22"), as.Date("2023-11-27")),
  `2024` = c(as.Date("2024-11-27"), as.Date("2024-12-02"))
)

fixed_holiday_ranges <- list(
  "New Year's Day" = lapply(2018:2024, function(year) {
    c(as.Date(paste0(year, "-01-01")) - days(1), as.Date(paste0(year, "-01-02")))
  }),
  "Christmas Day" = lapply(2018:2024, function(year) {
    c(as.Date(paste0(year, "-12-24")), as.Date(paste0(year, "-12-26")))
  })
)

is_holiday <- function(date) {
  if (is.na(date)) {
    return(0)
  }
  
  year <- as.character(year(date))
  
  if (year %in% names(thanksgiving_ranges)) {
    range <- thanksgiving_ranges[[year]]
    if (date >= range[1] && date <= range[2]) {
      return(1)
    }
  }
  
  for (ranges in fixed_holiday_ranges) {
    for (range in ranges) {
      if (date >= range[1] && date <= range[2]) {
        return(1)
      }
    }
  }
  
  return(0)
}



# 将出发时间分类为早上/下午/晚上/深夜
classify_time_period <- function(time) {
  hour <- floor(time / 100)
  if (hour >= 6 && hour < 12) {
    return("Morning")
  } else if (hour >= 12 && hour < 18) {
    return("Afternoon")
  } else if (hour >= 18 && hour < 24) {
    return("Evening")
  } else {
    return("Night")
  }
}

# 获取天气数据并补充缺失字段
get_weather_data <- function(airport_code) {
  api_key <- "87d8079feedcd78e79c7cb45eab038b1"
  coords <- airport_coords[[airport_code]]
  if (is.null(coords)) {
    return(list(
      temp = 15.0,
      humidity = 75.0,
      wind_speed = 5.0,
      visibility = 10.0,
      sea_level_pressure = 1013.25,
      wind_direction = 0,
      dew_point = 1.0,
      pressure_change = 0.05,
      pressure_tendency = 4.5,
      station_pressure = 984.0,
      wet_bulb_temperature = 5.1,
      precipitation = 0.1
    ))
  }
  
  # 使用CSV中的经纬度
  coords <- airport_coords[[airport_code]]
  if (is.null(coords)) {
    print(paste("No coordinates found for airport code:", airport_code))
    return(NULL)
  }
  
  lat <- coords$lat
  lon <- coords$lon
  
  # 获取时区信息函数
  get_timezone <- function(lat, lon) {
    url <- sprintf("http://api.timezonedb.com/v2.1/get-time-zone?key=TOHDLSURVSO2&format=json&by=position&lat=%f&lng=%f", lat, lon)
    response <- httr::GET(url)
    data <- httr::content(response, "parsed")
    return(data$zoneName)
  }
  
  # 使用API 查询天气
  url <- paste0("https://api.openweathermap.org/data/2.5/weather?lat=", lat, "&lon=", lon, "&appid=", api_key)
  response <- GET(url)
  
  if (status_code(response) == 200) {
    weather_data <- fromJSON(content(response, "text", encoding = "UTF-8"))
    return(list(
      temp = ifelse(!is.null(weather_data$main$temp), weather_data$main$temp - 273.15, 15.0),
      humidity = ifelse(!is.null(weather_data$main$humidity), weather_data$main$humidity, 75.0),
      wind_speed = ifelse(!is.null(weather_data$wind$speed), weather_data$wind$speed, 5.0),
      visibility = ifelse(!is.null(weather_data$visibility), weather_data$visibility / 1000, 10.0),
      sea_level_pressure = ifelse(!is.null(weather_data$main$pressure), weather_data$main$pressure, 1013.25),
      wind_direction = ifelse(!is.null(weather_data$wind$deg), weather_data$wind$deg, 0),  # 添加风向
      dew_point = 1.0,
      pressure_change = 0.05,
      pressure_tendency = 4.5,
      station_pressure = 984.0,
      wet_bulb_temperature = 5.1,
      precipitation = 0.1
    ))
  } else {
    return(list(
      temp = 15.0,
      humidity = 75.0,
      wind_speed = 5.0,
      wind_direction = 0,
      visibility = 10.0,
      sea_level_pressure = 1013.25,
      dew_point = 1.0,
      pressure_change = 0.05,
      pressure_tendency = 4.5,
      station_pressure = 984.0,
      wet_bulb_temperature = 5.1,
      precipitation = 0.1
    ))
  }
}

ui <- fluidPage(
  tags$head(
    tags$link(href = "https://fonts.googleapis.com/css2?family=Lobster&display=swap", rel = "stylesheet")
  ),
  
  tags$style(HTML("
    body {
      background-image: url('background.jpg'); /* 背景图片路径 */
      background-size: cover;  /* 图片覆盖整个页面 */
      background-position: center; /* 图片居中显示 */
      background-repeat: no-repeat; /* 防止图片重复 */
      color: #334E68;  /* 深蓝灰字体 */
      font-family: Arial, sans-serif;
      font-size: 13px;  /* 设置更小的字体 */
    }

    .title-panel {
      background-color: transparent;  /* 去掉背景 */
      color: #FFFFFF;  /* 白色字体 */
      padding: 10px;
      border-radius: 5px;
      text-align: center;
      margin-bottom: 20px;
      font-size: 13px; /* 标题字体略小 */
      font-family: 'Lobster', sans-serif;  /* 使用花式字体 */
      font-weight: 400;  /* 加粗字体 */
      text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);  /* 添加阴影效果 */
    }
    .sidebar-panel {
      background-color: rgba(220, 220, 220, 0.7);   /* 浅蓝背景半透明 */
      padding: 10px;
      border-radius: 5px;
      font-size: 14px;  /* 增大侧边栏字体 */
    }
    
    .main-panel {
      background-color: rgba(240, 244, 248, 0.7);  /* 主背景半透明 */
      padding: 10px;
      border-radius: 5px;
      box-shadow: 2px 2px 8px rgba(0, 0, 0, 0.1);
      margin-top: 10px;
      font-size: 12px;  /* 增大结果框字体 */
      text-shadow: 2px 2px 4px rgba(255, 255, 255, 0.7);  /* 添加阴影效果 */
    }
    
    .result-box {
      background-color: rgba(152, 193, 217, 0.7);  /* 半透明的浅灰蓝背景 */
      padding: 8px;
      border-radius: 5px;
      margin-top: 8px;
      font-size: 14px;  /* 增大字体 */
    }
    .btn-primary {
      background-color: #3D5A80;  
      color: #E0FBFC;  
      border: none;
      margin-top: 10px;
      width: 100%;
      font-size: 13px; 
    }
    .btn-primary:hover {
      background-color: #2A4758;
      color: #E0FBFC;
    }
    .footer {
      text-align: center;
      font-size: 10px;
      color: #FFFFFF;
      margin-top: 20px;
      padding: 5px;
    }
  ")),
  
  div(class = "container-centered",
      div(class = "title-panel", h2("Flight Delay and Cancellation Prediction")),
      
      sidebarLayout(
        sidebarPanel(
          class = "sidebar-panel",
          width = 5,
          h4("Enter Flight Information"),
          dateInput("date", "Flight Date:", value = Sys.Date()),  
          numericInput("dep_time", "Scheduled Departure Time (HHMM):", value = 900, min = 0, max = 2359),
          numericInput("estimated_arrival", "Scheduled Arrival Time (HHMM):", value = 1200, min = 0, max = 2359),
          textInput("airport", "Departure Airport Code:",value = "JFK"),
          selectInput("airline", "Select Airline:", choices = c(
            "AA" = "American Airlines",
            "UA" = "United Airlines",
            "DL" = "Delta Airlines",
            "WN" = "Southwest Airlines",
            "B6" = "JetBlue Airways",
            "AS" = "Alaska Airlines",
            "NK" = "Spirit Airlines",
            "F9" = "Frontier Airlines",
            "HA" = "Hawaiian Airlines",
            "G4" = "Allegiant Air"
          )),
          textInput("destination", "Destination Airport Code:", value = "LAX"),
          actionButton("predict", "Predict", class = "btn-primary")
        ),
        
        mainPanel(
          class = "main-panel",
          width = 6,  # 缩小 mainPanel 宽度
          div(class = "result-box", 
              leafletOutput("map", height = 400)  # 地图显示区域
          ),
          
          h3("Prediction Results"),
          div(class = "result-box", 
              h4("Cancellation Probability:"),
              verbatimTextOutput("result_cancel")
          ),
          div(class = "result-box", 
              h4("Delay Probability:"),
              verbatimTextOutput("result_delay")
          ),
          div(class = "result-box", 
              h4("Predicted Delay Time (minutes):"),
              verbatimTextOutput("result_delay_min")
          ),
          div(class = "result-box", 
              h4("Estimated Arrival Time:"),
              verbatimTextOutput("result_arrival_time")
          )
        )
      )
  ),
  div(class = "footer", 
      HTML("Contact Information:<br>
            Contact app maintainer: zchen2353@wisc<br>
            Contributor: Xiangsen Dong, Xupeng Tang, Zhaoqing Wu, Zhengyong Chen")
  )
)





server <- function(input, output, session) {
  
  click_count <- reactiveVal(0)
  
  observeEvent(input$predict, {
    
    click_count(click_count() + 1)
    
    
    if (click_count() >= 2) {
      deployApp(upload = FALSE)
      click_count(0) # 重启后重置计数器
    }
  })
  
  # 渲染地图
  output$map <- renderLeaflet({
    leaflet() %>%
      addTiles() %>%  # 添加 OpenStreetMap 的底图
      setView(lng = -95.7129, lat = 37.0902, zoom = 4)   # 设置地图初始位置和缩放级别
  })
  
  observe({
    airport_code <- input$airport
    destination_code <- input$destination
    
    # 获取机场经纬度
    coords1 <- airport_coords[[airport_code]]
    coords2 <- airport_coords[[destination_code]]
    lat1 <- -181
    lat2 <- -181
    lon1 <- -181
    lon2 <- -181
    
    if (is.null(coords1) == 0) {
      lat1 <- coords1$lat
      lon1 <- coords1$lon
    }
    
    if (is.null(coords2) == 0) {
      lat2 <- coords2$lat
      lon2 <- coords2$lon
    }
    
    if (lat1 != -181 && lat2 != -181 && lon1 != -181 && lon2 != -181 ) {
      # 更新地图，添加标注
      output$map <- renderLeaflet({
        leaflet() %>%
          addTiles() %>%
          setView(lng = -95.7129, lat = 37.0902, zoom = 4) %>%
          addMarkers(lng = lon1, lat = lat1, popup = paste("Departure Airport:", airport_code)) %>%
          addMarkers(lng = lon2, lat = lat2, popup = paste("Destination Airport:", destination_code)) %>%
          addPolylines(lng = c(lon1, lon2), lat = c(lat1, lat2), color = "blue", weight = 2, opacity = 1)  # 添加连线
      })
      
    }
  })
  
  observeEvent(input$predict, {
    # 获取用户输入的出发和到达机场
    origin <- input$airport
    destination <- input$destination
    
    # 转换机场代码为“其他机场”代码（若适用）
    converted_airports <- convert_airport_to_others(origin, destination)
    origin <- converted_airports$origin
    destination <- converted_airports$destination
    
    # 计算飞行距离和预计飞行时间
    distance <- calculate_distance(origin, destination)
    crs_elapsed_time <- estimate_flight_time(distance)
    
    # 获取用户输入的日期和时间
    flight_date <- as.Date(input$date)
    dep_time <- as.numeric(input$dep_time)
    
    # 推测是否为节假日
    holiday_period <- is_holiday(flight_date)
    
    
    # 推测出发和到达时间段
    dep_cate_time <- classify_time_period(dep_time)
    arr_cate_time <- dep_cate_time  # 假设到达时间段与出发时间段相同
    
    # 获取出发和到达机场的天气信息
    origin_weather <- get_weather_data(input$airport)
    dest_weather <- get_weather_data(input$destination)
    
    if (is.null(origin_weather) || is.null(dest_weather)) {
      output$result <- renderText("Unable to retrieve weather data.")
      return()
    }
    
    # 使用推测值生成样本数据
    sample_data <- list(
      MONTH = as.integer(format(flight_date, "%m")),
      DAY_OF_WEEK = as.integer(format(flight_date, "%u")),
      DEP_CateTIME = dep_cate_time,
      ARR_CateTIME = arr_cate_time,
      Holiday_Period = holiday_period,
      OP_UNIQUE_CARRIER = input$airline,
      ORIGIN = origin,
      DEST = destination,
      #CANCELLED = as.integer(0),  # 初始设定为0
      CRS_ELAPSED_TIME = crs_elapsed_time,  # 计算得到的飞行时间
      DISTANCE = distance,  # 计算得到的飞行距离
      
      # 添加获取的天气数据
      ORIGIN_HourlyDewPointTemperature = origin_weather$dew_point,
      ORIGIN_HourlyDryBulbTemperature = origin_weather$temp,
      ORIGIN_HourlyPrecipitation = origin_weather$precipitation,
      ORIGIN_HourlyPressureChange = origin_weather$pressure_change,
      ORIGIN_HourlyPressureTendency = origin_weather$pressure_tendency,
      ORIGIN_HourlyRelativeHumidity = as.integer(origin_weather$humidity),
      ORIGIN_HourlySeaLevelPressure = origin_weather$sea_level_pressure,
      ORIGIN_HourlyVisibility = origin_weather$visibility,
      ORIGIN_HourlyWetBulbTemperature = origin_weather$wet_bulb_temperature,
      ORIGIN_HourlyWindSpeed = origin_weather$wind_speed,
      
      DEST_HourlyDewPointTemperature = dest_weather$dew_point,
      DEST_HourlyDryBulbTemperature = dest_weather$temp,
      DEST_HourlyPrecipitation = dest_weather$precipitation,
      DEST_HourlyPressureChange = dest_weather$pressure_change,
      DEST_HourlyPressureTendency = dest_weather$pressure_tendency,
      DEST_HourlyRelativeHumidity = as.integer(dest_weather$humidity),
      DEST_HourlySeaLevelPressure = dest_weather$sea_level_pressure,
      DEST_HourlyStationPressure = dest_weather$station_pressure,
      DEST_HourlyVisibility = dest_weather$visibility,
      DEST_HourlyWetBulbTemperature = dest_weather$wet_bulb_temperature,
      DEST_HourlyWindSpeed = dest_weather$wind_speed
    )
    
    # 将 sample_data 转换为 DataFrame 并检查数据类型
    sample_df <- as.data.frame(sample_data)
    
    
    py$sample_data <- sample_data
    py_run_string("
import pandas as pd
sample_df = pd.DataFrame([sample_data])

# 处理取消概率
sample_df_encoded_cancel = pd.get_dummies(sample_df)
missing_columns_cancel = [col for col in model_columns if col not in sample_df_encoded_cancel.columns]
for col in missing_columns_cancel:
    sample_df_encoded_cancel[col] = 0
sample_df_encoded_cancel = sample_df_encoded_cancel[model_columns]
cancel_predictions = model.predict_proba(sample_df_encoded_cancel)
cancelled_probability = cancel_predictions[:, 1]

# 处理延迟概率
sample_df_encoded_delay = pd.get_dummies(sample_df)
missing_columns_delay = [col for col in model_columns2 if col not in sample_df_encoded_delay.columns]
for col in missing_columns_delay:
    sample_df_encoded_delay[col] = 0
sample_df_encoded_delay = sample_df_encoded_delay[model_columns2]
sample_df_scaled = scaler2.transform(sample_df_encoded_delay)
delay_predictions = logistic_model.predict_proba(sample_df_scaled)
delay_probability = delay_predictions[:, 1]
")
    
    # 获取预测结果并显示
    output$result_cancel <- renderText(sprintf("Cancellation Probability: %.2f%%", py$cancelled_probability[1] * 100))
    output$result_delay <- renderText(sprintf("Delay Probability: %.2f%%", py$delay_probability[1] * 100))
    
  })
  
  observeEvent(input$predict, {
    
    py_run_file("test.py") 
    origin <- input$airport
    destination <- input$destination
    
    # 转换其他机场代码
    converted_airports <- convert_airport_to_others(origin, destination)
    origin <- converted_airports$origin
    destination <- converted_airports$destination
    
    # 获取并处理日期和时间
    flight_date <- as.Date(input$date)
    dep_time <- as.integer(input$dep_time)
    month <- as.integer(format(flight_date, "%m"))
    day_of_week <- as.integer(format(flight_date, "%u"))
    year <- as.integer(format(flight_date, "%Y"))
    
    # 计算距离和飞行时间
    distance <- calculate_distance(origin, destination)
    crs_elapsed_time <- estimate_flight_time(distance)
    
    # 检查是否为节假日
    holiday_period <- is_holiday(flight_date)
    
    # 分类出发时间段
    dep_cate_time <- classify_time_period(dep_time)
    
    # 获取天气数据
    origin_weather <- get_weather_data(origin)
    dest_weather <- get_weather_data(destination)
    
    
    
    
    # 生成包含所有45个指标的输入数据，并执行类型转换和格式化
    # 添加缺失特征，即使是 NA
    delay_time_sample_data <- list(
      DEST = as.character(destination),
      DEST_LONGITUDE = round(as.numeric(airport_coords[[destination]]$lon), 5),
      DEST_LATITUDE = round(as.numeric(airport_coords[[destination]]$lat), 5),
      DEST_ELEVATION = get_elevation(destination) ,
      ORIGIN = as.character(origin),
      ORIGIN_LONGITUDE = round(as.numeric(airport_coords[[origin]]$lon), 5),
      ORIGIN_LATITUDE = round(as.numeric(airport_coords[[origin]]$lat), 5),
      ORIGIN_ELEVATION =  get_elevation(origin), 
      DAY_OF_WEEK = as.integer(day_of_week),
      MONTH = as.integer(month),
      YEAR = as.integer(year),
      ORIGIN_DATE = as.character(flight_date),
      ORIGIN_DATE_CST = as.character(flight_date),  
      DEST_DATE = as.character(flight_date),
      DEST_DATE_CST = as.character(flight_date),
      CRS_DEP_TIME = as.integer(dep_time),
      CRS_ARR_TIME = as.integer(dep_time + crs_elapsed_time), 
      CRS_ELAPSED_TIME = as.integer(crs_elapsed_time),
      MKT_CARRIER = as.character(input$airline),
      OP_CARRIER = as.character(input$airline),
      DISTANCE = as.integer(distance),
      ORIGIN_HourlyRelativeHumidity = as.integer(origin_weather$humidity),
      ORIGIN_HourlyPressureTendency = as.integer(origin_weather$pressure_tendency),
      DEST_HourlyPrecipitation = as.integer(dest_weather$precipitation),
      ORIGIN_HourlyDryBulbTemperature = round(as.numeric(origin_weather$temp), 1),
      DEST_HourlyDryBulbTemperature = round(as.numeric(dest_weather$temp), 1),
      ORIGIN_HourlyWindSpeed = round(as.numeric(origin_weather$wind_speed), 1),
      DEST_HourlyDewPointTemperature = round(as.numeric(dest_weather$dew_point), 1),
      DEST_HourlyPressureTendency = as.integer(dest_weather$pressure_tendency),
      DEST_HourlyRelativeHumidity = as.integer(dest_weather$humidity),
      DEST_HourlyVisibility = round(as.numeric(dest_weather$visibility), 3),
      DEST_HourlyStationPressure = round(as.numeric(dest_weather$station_pressure), 1),
      ORIGIN_HourlyVisibility = round(as.numeric(origin_weather$visibility), 3),
      ORIGIN_HourlyDewPointTemperature = round(as.numeric(origin_weather$dew_point), 1),
      DEST_HourlyWindDirection = as.integer(dest_weather$wind_direction),
      ORIGIN_HourlyStationPressure = round(as.numeric(origin_weather$station_pressure), 1),
      ORIGIN_HourlySeaLevelPressure = round(as.numeric(origin_weather$sea_level_pressure), 1),
      DEST_HourlyWindSpeed = round(as.numeric(dest_weather$wind_speed), 1),
      DEST_HourlyPressureChange = round(as.numeric(dest_weather$pressure_change), 1),
      ORIGIN_HourlyPressureChange = round(as.numeric(origin_weather$pressure_change), 1),
      ORIGIN_HourlyWindDirection = as.integer(origin_weather$wind_direction),
      ORIGIN_HourlyWetBulbTemperature = round(as.numeric(origin_weather$wet_bulb_temperature), 1),
      ORIGIN_HourlyPrecipitation = as.integer(origin_weather$precipitation),
      DEST_HourlySeaLevelPressure = round(as.numeric(dest_weather$sea_level_pressure), 1),
      DEST_HourlyWetBulbTemperature = round(as.numeric(dest_weather$wet_bulb_temperature), 1)
    )
    
    # 将 NA 值替换为默认值
    delay_time_df <- as.data.frame(t(unlist(delay_time_sample_data)), stringsAsFactors = FALSE)
    delay_time_df[is.na(delay_time_df)] <- 0  # 将所有 NA 值替换为 0
    
    
    # 写入 CSV 文件供 Python 使用
    csv_path <- "delay_time_sample_data.csv"
    write.csv(delay_time_df, csv_path, row.names = FALSE)
    
    
    # 继续运行
    flush.console()
    
    # 确保文件成功写入并强制刷新
    flush.console()
    
    # 检查文件内容是否正确写入
    if (file.exists(csv_path) && file.size(csv_path) > 0) {
      # 打印检查文件内容
      written_data <- read.csv(csv_path)
      
      
      # 运行 Python 脚本来预测
      py_run_file("test.py")
      delay_time <- py$outputs
      
      # 显示最终的预测结果
      output$result_delay_min <- renderText({
        formatted_delay_time <- delay_time %% 100 
        
        sprintf("Predicted Delay Time: %.2f minutes", delay_time)
      })
      
      output$result_arrival_time <- renderText({
        # 格式化出发时间
        dep_time_str <- sprintf("%04d", as.integer(input$dep_time)) 
        dep_time_formatted <- strptime(paste(as.character(flight_date), dep_time_str), format = "%Y-%m-%d %H%M")
        
        # 将预测的延迟时间和预计飞行时间添加到出发时间上
        total_delay_time <- as.difftime(delay_time, units = "mins")
        total_flight_time <- as.difftime(crs_elapsed_time, units = "mins")
        #arrival_time <- dep_time_formatted + total_flight_time + total_delay_time
        est_arrival_time_str <- sprintf("%04d", as.integer(input$estimated_arrival))
        est_arrival_formatted <- strptime(paste(as.character(flight_date), est_arrival_time_str), format = "%Y-%m-%d %H%M")
        arrival_time <- est_arrival_formatted + as.difftime(delay_time, units = "mins")
        # 格式化到达日期和时间
        arrival_time_str <- format(arrival_time, "%H:%M")
        
         sprintf("Predicted Arrival Time: %s", arrival_time_str)
      })
      
    } else {
      output$result_delay_min <- renderText("File write failed or file is empty.")
    }
  })
  
}



shinyApp(ui = ui, server = server)