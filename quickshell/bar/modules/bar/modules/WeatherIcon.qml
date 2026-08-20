import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property real latitude: Theme.weatherLat
    property real longitude: Theme.weatherLon
    property bool useCelsius: Theme.weatherCelsius

    property real temperature: 0
    property int weatherCode: -1
    property string iconName: "device_thermostat"
    property bool loading: true
    property bool error: false

    property real humidity: 0
    property real windSpeed: 0
    property real apparentTemperature: 0
    property var trendTemps: []
    property real trendMin: 0
    property real trendMax: 0
    property string condition: ""

    property string tempUnit: useCelsius ? "celsius" : "fahrenheit"

    onLatitudeChanged: updateWeather()
    onLongitudeChanged: updateWeather()
    onUseCelsiusChanged: { tempUnit = useCelsius ? "celsius" : "fahrenheit"; updateWeather() }

    function updateIcon() {
        if (weatherCode === 0) {
            iconName = "sunny"          // Clear
        } else if (weatherCode <= 3) {
            iconName = "partly_cloudy_day" // Cloudy
        } else if (weatherCode <= 48) {
            iconName = "foggy"          // Fog
        } else if (weatherCode <= 67) {
            iconName = "rainy"          // Rain
        } else if (weatherCode <= 77) {
            iconName = "ac_unit"        // Snow
        } else {
            iconName = "thunderstorm"   // Thunderstorm
        }
    }

    function updateCondition() {
        if (weatherCode === 0) {
            condition = "Clear"
        } else if (weatherCode === 1) {
            condition = "Mostly clear"
        } else if (weatherCode <= 3) {
            condition = "Partly cloudy"
        } else if (weatherCode <= 48) {
            condition = "Fog"
        } else if (weatherCode <= 57) {
            condition = "Drizzle"
        } else if (weatherCode <= 67) {
            condition = "Rain"
        } else if (weatherCode <= 77) {
            condition = "Snow"
        } else {
            condition = "Thunderstorm"
        }
    }

    function updateWeather() {
        loading = true
        error = false
        weatherProcess.running = true
    }

    Process {
        id: weatherProcess

        command: [
            "curl",
            "-s",
            "--fail",
            "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + root.latitude
            + "&longitude=" + root.longitude
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m"
            + "&hourly=temperature_2m"
            + "&forecast_days=1"
            + "&timezone=auto"
            + "&temperature_unit=" + root.tempUnit
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text)

                    root.temperature = data.current.temperature_2m
                    root.weatherCode = data.current.weather_code
                    root.humidity = data.current.relative_humidity_2m || 0
                    root.windSpeed = data.current.wind_speed_10m || 0
                    root.apparentTemperature = data.current.apparent_temperature ?? root.temperature
                    root.updateIcon()
                    root.updateCondition()

                    const hours = data.hourly && data.hourly.temperature_2m ? data.hourly.temperature_2m : []
                    if (hours.length > 0) {
                        root.trendTemps = hours
                        root.trendMax = Math.max.apply(null, hours)
                        root.trendMin = Math.min.apply(null, hours)
                    } else {
                        root.trendTemps = []
                    }

                    root.loading = false
                    root.error = false
                } catch (e) {
                    console.log("Weather: failed to parse response:", e)
                    root.loading = false
                    root.error = true
                }
            }
        }

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.loading = false
                root.error = true
                console.log("Weather: curl exited with code", exitCode)
            }
        }
    }

    Timer {
        interval: 10 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: root.updateWeather()
      } // refresh weather every 10 minutes
}