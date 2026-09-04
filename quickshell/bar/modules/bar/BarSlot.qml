import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

Item {
    id: root
    property var modules: []
    property int alignment: Qt.AlignLeft
    property int spacing: Theme.groupPadding
    property bool wrapInCluster: true
    property var panelWindow
    property string screenName: ""
    property var niri
    property string focusedOutput: ""
    property bool launcherOpen: false

    visible: modules && modules.length > 0
    implicitHeight: Theme.barHeight
    implicitWidth: wrapInCluster ? cluster.implicitWidth : contentRow.implicitWidth

    BarCluster {
        id: cluster
        visible: root.wrapInCluster
        anchors.fill: parent
        spacing: root.spacing
        contentAlign: root.alignment

        RowLayout {
            spacing: root.spacing
            Repeater {
                model: root.wrapInCluster ? (root.modules || []) : []
                delegate: BarModuleLoader {
                    required property var modelData
                    moduleId: modelData
                    panelWindow: root.panelWindow
                    screenName: root.screenName
                    niri: root.niri
                    focusedOutput: root.focusedOutput
                    launcherOpen: root.launcherOpen
                }
            }
        }
    }

    RowLayout {
        id: contentRow
        visible: !root.wrapInCluster
        anchors.centerIn: parent
        spacing: root.spacing
        Repeater {
            model: !root.wrapInCluster ? (root.modules || []) : []
            delegate: BarModuleLoader {
                required property var modelData
                moduleId: modelData
                panelWindow: root.panelWindow
                screenName: root.screenName
                niri: root.niri
                focusedOutput: root.focusedOutput
                launcherOpen: root.launcherOpen
            }
        }
    }
}
