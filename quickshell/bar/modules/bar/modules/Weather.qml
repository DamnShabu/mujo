pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared weather data service. One instance per process; every consumer (bar,
// widgets, settings page) reads from here instead of hitting the API itself.
// The actual fetch goes through `mujo weather fetch`, which caches to disk and
// serves fresh cache — so even across processes the network is hit at most once
// per interval. WMO code → icon/description mapping lives here too.
QtObject {
    id: weather

    property var data: null        // normalized {temp, code, humidity, wind, city, daily…}
    property bool loading: false
    property string error: ""
    property int intervalMs: 900000

    readonly property string configPath: (Quickshell.env("HOME") || "/tmp") + "/.config/quickshell/weather.json"

    function refresh(force) {
        weather.loading = (weather.data === null)
        fetchProc.command = force ? ["mujo", "weather", "fetch", "--force"] : ["mujo", "weather", "fetch"]
        fetchProc.running = true
    }

    property Process _fetch: Process {
        id: fetchProc
        stdout: StdioCollector {
            onStreamFinished: {
                weather.loading = false
                try {
                    var d = JSON.parse(this.text)
                    if (d.error) { weather.error = d.error }
                    else { weather.data = d; weather.error = "" }
                } catch (e) { weather.error = "parse error" }
            }
        }
    }

    property FileView _cfg: FileView {
        path: weather.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var c = JSON.parse(text())
                weather.intervalMs = Math.max(300, c.interval || 900) * 1000
            } catch (e) {}
            weather.refresh(false)
        }
    }

    property Timer _poll: Timer {
        interval: weather.intervalMs
        running: true
        repeat: true
        onTriggered: weather.refresh(false)
    }

    Component.onCompleted: refresh(false)

    // ── WMO code → identity ──────────────────────────────────────────────────
    function iconFor(code) {
        if (code === 0) return "clear_day"
        if (code <= 2) return "partly_cloudy_day"
        if (code === 3) return "cloud"
        if (code <= 48) return "foggy"
        if (code <= 57) return "rainy"
        if (code <= 67) return "rainy"
        if (code <= 77) return "weather_snowy"
        if (code <= 82) return "rainy"
        if (code <= 86) return "weather_snowy"
        return "thunderstorm"
    }
    function descFor(code) {
        if (code === 0) return "Clear"
        if (code === 1) return "Mainly clear"
        if (code === 2) return "Partly cloudy"
        if (code === 3) return "Overcast"
        if (code <= 48) return "Fog"
        if (code <= 55) return "Drizzle"
        if (code <= 57) return "Freezing drizzle"
        if (code <= 65) return "Rain"
        if (code <= 67) return "Freezing rain"
        if (code <= 77) return "Snow"
        if (code <= 82) return "Rain showers"
        if (code <= 86) return "Snow showers"
        if (code === 95) return "Thunderstorm"
        return "Thunderstorm, hail"
    }
    function unitSymbol() {
        if (!data) return "°"
        return data.units === "fahrenheit" ? "°F" : "°C"
    }
}
