import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var weather
    property string wallpaperPath: ""
    property string cityName: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        OverviewClock {
            Layout.fillWidth: true
            Layout.fillHeight: true
            weather: root.weather
            wallpaperPath: root.wallpaperPath
            cityName: root.cityName
        }

        OverviewPlayer {
            Layout.fillWidth: true
            Layout.preferredHeight: 90
        }
    }
}
