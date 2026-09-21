import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Open-Meteo Live Atmospheric Conditions, 5-Day Forecast, and Geocoding Group.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    readonly property string wname: SettingsBus.get("weather.name", "")
    readonly property string units: SettingsBus.get("weather.units", "metric")
    readonly property int intervalMin: SettingsBus.get("weather.intervalMin", 30)
    readonly property string style: SettingsBus.get("weather.style", "detailed")
    function wset(k, v) { SettingsBus.set("weather." + k, v) }

    readonly property var wx: Weather.data

    property var searchResults: []
    property bool searching: false
    property bool searchFailed: false
    property Process locProc: Process {
        id: locProc
        stdout: StdioCollector {
            onStreamFinished: {
                locTimeout.stop()
                root.searching = false
                try { root.searchResults = JSON.parse(this.text) || [] }
                catch (e) { root.searchResults = []; root.searchFailed = true }
            }
        }
    }
    property Timer locTimeout: Timer {
        id: locTimeout
        interval: 8000
        onTriggered: {
            locProc.running = false
            root.searching = false
            root.searchResults = []
            root.searchFailed = true
        }
    }
    function doSearch(q) {
        if (q.trim() === "") return
        root.searching = true
        root.searchFailed = false
        locProc.command = ["mujo", "weather", "locations", q]
        locProc.running = true
        locTimeout.restart()
    }
    function pick(r) {
        SettingsBus.set("weather.name", r.name)
        SettingsBus.set("weather.lat", r.latitude)
        SettingsBus.set("weather.lon", r.longitude)
        root.searchResults = []
        searchField.text = ""
        Weather.refresh(true)
    }
    function detectByIp() {
        SettingsBus.set("weather.name", "")
        SettingsBus.set("weather.lat", null)
        SettingsBus.set("weather.lon", null)
        root.searchResults = []
        Weather.refresh(true)
    }

    // ── 1. Current Weather Live Conditions Card ───────────────────────────────
    MujoCard {
        title: "Current Atmospheric Conditions"
        badgeText: root.wx ? (root.wx.temp + Weather.unitSymbol()) : ""

        actions: IconButton { iconName: "refresh"; onClicked: Weather.refresh(true) }

        // The reading is the hero here, the way the health score is on the
        // System page: one big number, the conditions beside it, nothing else.
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 20
            visible: root.wx !== null && Weather.error === ""
            opacity: Weather.stale ? 0.5 : 1
            Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.standard) } }

            MaterialIcon {
                iconName: root.wx ? Weather.iconFor(root.wx.code) : "cloud"
                pixelSize: 52
                color: Theme.accent
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                RowLayout {
                    spacing: 4

                    Text {
                        text: root.wx ? root.wx.temp : "–"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 38
                        font.weight: Font.DemiBold
                        font.letterSpacing: -1
                    }

                    Text {
                        text: Weather.unitSymbol()
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        Layout.topMargin: 5
                    }
                }

                Text {
                    text: root.wx ? Weather.descFor(root.wx.code) : ""
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeTitle
                }

                Text {
                    text: root.wx
                        ? root.wx.city + " · feels " + root.wx.feels + Weather.unitSymbol()
                          + " · " + root.wx.humidity + "% humidity · " + root.wx.wind + " " + root.wx.windUnit
                        : ""
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16
            Layout.bottomMargin: 16
            spacing: 12
            visible: root.wx === null && Weather.error === ""

            Spinner { size: 18 }

            Text {
                text: "Fetching the forecast…"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
            }
        }

        EmptyState {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            visible: Weather.error !== "" && root.wx === null
            iconName: "cloud_off"
            title: "No weather right now"
            hint: Weather.error

            DialogButton { text: "Try again"; primary: true; onClicked: Weather.refresh(true) }
        }
    }

    // ── Forecast ──────────────────────────────────────────────────────────────
    MujoCard {
        visible: root.wx !== null && root.wx.daily !== undefined
        title: "5-Day Forecast"

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            opacity: Weather.stale ? 0.5 : 1
            spacing: 8

            Repeater {
                model: root.wx ? root.wx.daily : []

                delegate: InsetPanel {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: 82

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: index === 0 ? "Today" : Qt.formatDate(new Date(modelData.date), "ddd")
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            iconName: Weather.iconFor(modelData.code)
                            pixelSize: 22
                            color: Theme.accent
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.max + "° / " + modelData.min + "°"
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }
        }
    }

    // ── Location ──────────────────────────────────────────────────────────────
    MujoCard {
        title: "Location & Geocoding"
        badgeText: root.wname !== "" ? root.wname.toUpperCase() : "AUTO IP"

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8

            TextField {
                id: searchField
                Layout.fillWidth: true
                a11yName: "City search"
                placeholder: root.wname !== "" ? root.wname : "Search a city — Berlin, Tokyo, London"
                onAccepted: root.doSearch(text)
            }

            DialogButton { text: "Search"; primary: true; onClicked: root.doSearch(searchField.text) }
            DialogButton { text: "Use my IP"; onClicked: root.detectByIp() }
        }

        Spinner { visible: root.searching; size: 16; Layout.topMargin: 6 }

        Text {
            visible: root.searchFailed && !root.searching
            Layout.fillWidth: true
            Layout.topMargin: 6
            text: "Could not reach the location service. Check the connection and search again."
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.searchResults

            delegate: ListRow {
                required property var modelData
                interactive: true
                onClicked: root.pick(modelData)

                MaterialIcon { iconName: "location_on"; pixelSize: 16; color: Theme.textSecondary }

                Text {
                    Layout.fillWidth: true
                    text: modelData.name
                        + (modelData.admin1 ? ", " + modelData.admin1 : "")
                        + (modelData.country ? " · " + modelData.country : "")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ── 4. Units & Display Preferences Card ───────────────────────────────────
    MujoCard {
        title: "Display Preferences & Frequency"
        iconName: "tune"

        MujoSettingRow {
            iconName: "thermostat"
            title: "Temperature Units"
            description: "Format used for temperatures across the bar and widgets."

            MujoSegmented {
                model: [
                    { id: "metric", label: "Metric (°C)" },
                    { id: "imperial", label: "Imperial (°F)" }
                ]
                current: root.units
                onSelected: function(id) { root.wset("units", id) }
            }
        }

        SettingRow {
            path: "weather.intervalMin"
            def: 30
            kind: "slider"
            from: 15
            to: 120
            format: " min"
            iconName: "timer"
            title: "Refresh Interval"
            description: "Minutes between Open-Meteo weather telemetry updates."
        }

        MujoSettingRow {
            iconName: "style"
            title: "Widget Detail Level"
            description: "Display layout in bar and popup widgets."

            MujoSegmented {
                model: [
                    { id: "compact", label: "Compact" },
                    { id: "detailed", label: "Detailed" }
                ]
                current: root.style
                onSelected: function(id) { root.wset("style", id) }
            }
        }
    }
}
