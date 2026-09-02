import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Weather (WP-05) — live current conditions + 5-day forecast (from the shared
// Weather singleton) plus configuration, all reading/writing the unified store
// under weather.*. Location search (Open-Meteo geocoding), units segmented
// control, interval slider, style picker, detect-by-IP, and loading / error /
// stale states. This page is both control and live preview.
Item {
    id: root

    readonly property string wname: SettingsBus.get("weather.name", "")
    readonly property string units: SettingsBus.get("weather.units", "metric")
    readonly property int intervalMin: SettingsBus.get("weather.intervalMin", 30)
    readonly property string style: SettingsBus.get("weather.style", "detailed")
    function wset(k, v) { SettingsBus.set("weather." + k, v) }

    readonly property var wx: Weather.data

    // ── location search ──
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
    // Bound the spinner: if geocoding stalls (network down), kill it and show an
    // error instead of spinning forever.
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

    MujoFlickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48

        ColumnLayout {
            id: col
            x: 24
            y: 24
            width: parent.width - 48
            spacing: 16

            MujoHero {
                brand: "weather"
                title: "Weather"
                subtitle: "Live atmospheric conditions and multi-day meteorological forecasts via Open-Meteo."
                badgeText: Weather.stale ? "STALE DATA" : (root.wname !== "" ? root.wname.toUpperCase() : "AUTO IP")
                badgeColor: Weather.stale ? Theme.warning : Theme.accent
                activeState: !Weather.stale
            }

            // ── Current Weather Hero Card ──
            MujoCard {
                title: "Current Atmospheric Conditions"
                iconName: "thermostat"
                badgeText: root.wx ? (root.wx.temp + Weather.unitSymbol()) : ""
                badgeColor: Theme.accent

                actions: IconButton { iconName: "refresh"; onClicked: Weather.refresh(true) }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // data (muted when stale)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 20
                        visible: root.wx !== null && Weather.error === ""
                        opacity: Weather.stale ? 0.5 : 1
                        Behavior on opacity { NumberAnimation { duration: Anim.d(Anim.standard) } }

                        MaterialIcon { iconName: root.wx ? Weather.iconFor(root.wx.code) : "cloud"; pixelSize: 64; color: Theme.accent }
                        ColumnLayout {
                            spacing: 0
                            RowLayout {
                                spacing: 4
                                Text { text: root.wx ? root.wx.temp : "–"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 44; font.bold: true }
                                Text { text: Weather.unitSymbol(); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 20; Layout.topMargin: 6 }
                            }
                            Text { text: root.wx ? Weather.descFor(root.wx.code) : ""; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeTitle }
                            Text {
                                text: root.wx ? (root.wx.city + "  ·  feels " + root.wx.feels + Weather.unitSymbol() + "  ·  " + root.wx.humidity + "% humidity  ·  " + root.wx.wind + " " + root.wx.windUnit) : ""
                                color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    // loading skeleton
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12
                        visible: root.wx === null && Weather.error === ""
                        Spinner { size: 20 }
                        Text { text: "Loading atmospheric telemetry…"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
                    }

                    // error + retry
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: Weather.error !== "" && root.wx === null
                        Text { Layout.alignment: Qt.AlignHCenter; text: "Weather telemetry unavailable"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; font.bold: true }
                        Text { Layout.alignment: Qt.AlignHCenter; text: Weather.error; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                        DialogButton { Layout.alignment: Qt.AlignHCenter; text: "Retry Connection"; primary: true; onClicked: Weather.refresh(true) }
                    }
                }
            }

            // ── 5-day forecast Card ──
            MujoCard {
                visible: root.wx !== null && root.wx.daily !== undefined
                title: "5-Day Forecast"
                iconName: "calendar_month"

                RowLayout {
                    Layout.fillWidth: true
                    opacity: Weather.stale ? 0.5 : 1
                    spacing: 8

                    Repeater {
                        model: root.wx ? root.wx.daily : []
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: 90
                            radius: Theme.radiusMd
                            color: Theme.bg
                            border.color: Theme.border
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text { Layout.alignment: Qt.AlignHCenter; text: index === 0 ? "Today" : Qt.formatDate(new Date(modelData.date), "ddd"); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall }
                                MaterialIcon { Layout.alignment: Qt.AlignHCenter; iconName: Weather.iconFor(modelData.code); pixelSize: 24; color: Theme.text }
                                Text { Layout.alignment: Qt.AlignHCenter; text: modelData.max + "° / " + modelData.min + "°"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall }
                            }
                        }
                    }
                }
            }

            // ── Location Card ──
            MujoCard {
                title: "Location & Geocoding"
                iconName: "location_on"
                badgeText: root.wname !== "" ? root.wname : "AUTO IP"

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            placeholder: root.wname !== "" ? root.wname : "Search a city (e.g. Berlin, Tokyo, London)…"
                            onAccepted: root.doSearch(text)
                        }
                        DialogButton { text: "Search"; primary: true; onClicked: root.doSearch(searchField.text) }
                        DialogButton { text: "Detect by IP"; onClicked: root.detectByIp() }
                    }

                    Spinner { visible: root.searching; size: 16 }

                    Text {
                        visible: root.searchFailed && !root.searching
                        Layout.fillWidth: true
                        text: "Couldn't reach the location service. Check your connection and try again."
                        color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; wrapMode: Text.WordWrap
                    }

                    // results
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: root.searchResults.length > 0
                        Repeater {
                            model: root.searchResults
                            delegate: Rectangle {
                                id: resRow
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 40
                                radius: Theme.radiusMd
                                color: resHover.hovered ? Theme.surfaceHover : Theme.surface
                                border.color: Theme.border
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                                    MaterialIcon { iconName: "location_on"; pixelSize: 16; color: Theme.textSecondary }
                                    Text {
                                        Layout.fillWidth: true
                                        text: resRow.modelData.name + (resRow.modelData.admin1 ? ", " + resRow.modelData.admin1 : "") + (resRow.modelData.country ? " · " + resRow.modelData.country : "")
                                        color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight
                                    }
                                }
                                HoverHandler { id: resHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: root.pick(resRow.modelData) }
                            }
                        }
                    }
                }
            }

            // ── Units & Interval Preferences Card ──
            MujoCard {
                title: "Display Preferences & Update Frequency"
                iconName: "tune"

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Units
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text { text: "Temperature Units"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 140 }
                        MujoSegmented {
                            current: root.units
                            model: [
                                { id: "metric",   label: "Metric °C" },
                                { id: "imperial", label: "Imperial °F" }
                            ]
                            onSelected: function (id) { root.wset("units", id) }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    // Interval
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text { text: "Refresh Interval"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 140 }
                        Slider {
                            Layout.preferredWidth: 180
                            from: 15; to: 120
                            value: root.intervalMin
                            onMoved: function (v) { root.wset("intervalMin", Math.round(v)) }
                        }
                        Text { text: root.intervalMin + " min"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 60 }
                        Item { Layout.fillWidth: true }
                    }

                    // Style
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text { text: "Widget Detail"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 140 }
                        Flow {
                            spacing: 7
                            DisplayChip { label: "Compact"; selected: root.style === "compact"; onClicked: root.wset("style", "compact") }
                            DisplayChip { label: "Detailed"; selected: root.style === "detailed"; onClicked: root.wset("style", "detailed") }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Powered by Open-Meteo (no API key). Telemetry is cached and shared across the top bar, desktop widgets, and this control surface."
                color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; wrapMode: Text.WordWrap
            }

            Item { implicitHeight: 12 }
        }
    }
}
