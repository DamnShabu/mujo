import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

// LauncherEmptyState: Atmospheric, bespoke empty and initial guidance state for Mujo (無常).
// Blends procedural living Ensō flow geometry with clean typographic hierarchy and
// intuitive keyboard shortcut navigation chips.
Item {
    id: root

    property string mode: "initial" // "initial" | "no-results" | "no-apps"
    // What this view is empty OF. The launcher reuses this component for the
    // clipboard and command tabs, which are not searching applications.
    property string subject: "applications"
    property string subjectHint: "Try searching by name, keyword, or executable"
    property string query: ""
    property color accentColor: Theme.accent

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 16

        // Procedural atmospheric icon illustration
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 84
            implicitHeight: 84

            // Luminous ambient glow
            Rectangle {
                anchors.centerIn: parent
                width: 72
                height: 72
                radius: 36
                color: Theme.withAlpha(root.accentColor, root.visible && Anim.ambient ? Anim.breath(0.06, 0.16) : 0.08)
                visible: !Anim.reduceMotion
            }

            Canvas {
                id: emptyCanvas
                anchors.fill: parent
                renderTarget: Canvas.Image

                property real phase: 0.0

                NumberAnimation on phase {
                    running: Anim.ambient && !Anim.reduceMotion && root.visible
                    from: 0.0
                    to: Math.PI * 2
                    duration: Anim.cycleDuration(9000)
                    loops: Animation.Infinite
                }

                onPhaseChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    var cx = width / 2
                    var cy = height / 2
                    var r = 28
                    var p = Anim.reduceMotion ? 0.0 : phase
                    var acc = root.accentColor

                    ctx.save()

                    // Ensō open transformation arc
                    ctx.beginPath()
                    var startAngle = p
                    var endAngle = startAngle + Math.PI * 1.55
                    ctx.arc(cx, cy, r, startAngle, endAngle, false)

                    var grad = ctx.createLinearGradient(0, 0, width, height)
                    grad.addColorStop(0, Qt.rgba(acc.r, acc.g, acc.b, 0.75))
                    grad.addColorStop(0.7, Qt.rgba(acc.r, acc.g, acc.b, 0.25))
                    grad.addColorStop(1, "transparent")

                    ctx.strokeStyle = grad
                    ctx.lineWidth = 2.2
                    ctx.lineCap = "round"
                    ctx.stroke()

                    // Counter-orbit inner crescent
                    ctx.beginPath()
                    var iStart = -p + Math.PI * 0.4
                    var iEnd = iStart + Math.PI * 0.95
                    ctx.arc(cx, cy, r * 0.65, iStart, iEnd, false)
                    ctx.strokeStyle = Qt.rgba(acc.r, acc.g, acc.b, 0.35)
                    ctx.lineWidth = 1.4
                    ctx.stroke()

                    // Focal point
                    var fx = cx + Math.cos(startAngle) * r
                    var fy = cy + Math.sin(startAngle) * r
                    ctx.beginPath()
                    ctx.arc(fx, fy, 2.5, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.rgba(acc.r, acc.g, acc.b, 0.9)
                    ctx.fill()

                    ctx.restore()
                }
            }

            // Center Symbol / Icon
            MaterialIcon {
                anchors.centerIn: parent
                iconName: root.mode === "no-results" ? "search_off" : (root.mode === "no-apps" ? "apps" : "travel_explore")
                pixelSize: 24
                color: root.mode === "no-results" ? Theme.textDim : Theme.accent
                opacity: 0.9
            }
        }

        // Title and Subtitle
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.mode === "no-results"
                      ? "No " + root.subject + " found"
                      : (root.mode === "no-apps" ? "No " + root.subject + " discovered" : "Explore Mujo")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitle + 1
                font.bold: true
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.mode === "no-results"
                      ? (root.query !== "" ? "No matches for \"" + root.query + "\"" : root.subjectHint)
                      : "Type to search applications, evaluate math, or press / for system commands"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.maximumWidth: 420
            }
        }

        // Quick Shortcut Guidance Chips (shown on initial state)
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            spacing: 8
            visible: root.mode === "initial"

            // Chip 1: / Commands
            Rectangle {
                implicitHeight: 24
                implicitWidth: r1.implicitWidth + 14
                radius: Theme.radiusSm
                color: Theme.surface
                border.color: Theme.border

                RowLayout {
                    id: r1
                    anchors.centerIn: parent
                    spacing: 5
                    Rectangle {
                        implicitWidth: 16; implicitHeight: 16
                        radius: 3
                        color: Theme.surfaceActive
                        border.color: Theme.borderStrong
                        Text {
                            anchors.centerIn: parent
                            text: "/"
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            font.bold: true
                        }
                    }
                    Text {
                        text: "Commands"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // Chip 2: Tab Mode
            Rectangle {
                implicitHeight: 24
                implicitWidth: r2.implicitWidth + 14
                radius: Theme.radiusSm
                color: Theme.surface
                border.color: Theme.border

                RowLayout {
                    id: r2
                    anchors.centerIn: parent
                    spacing: 5
                    Rectangle {
                        implicitWidth: tTxt.implicitWidth + 8; implicitHeight: 16
                        radius: 3
                        color: Theme.surfaceActive
                        border.color: Theme.borderStrong
                        Text {
                            id: tTxt
                            anchors.centerIn: parent
                            text: "Tab"
                            color: Theme.textSecondary
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel - 1
                        }
                    }
                    Text {
                        text: "Grid View"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // Chip 3: Ctrl+K Actions
            Rectangle {
                implicitHeight: 24
                implicitWidth: r3.implicitWidth + 14
                radius: Theme.radiusSm
                color: Theme.surface
                border.color: Theme.border

                RowLayout {
                    id: r3
                    anchors.centerIn: parent
                    spacing: 5
                    Rectangle {
                        implicitWidth: kTxt.implicitWidth + 8; implicitHeight: 16
                        radius: 3
                        color: Theme.surfaceActive
                        border.color: Theme.borderStrong
                        Text {
                            id: kTxt
                            anchors.centerIn: parent
                            text: "Ctrl K"
                            color: Theme.textSecondary
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel - 1
                        }
                    }
                    Text {
                        text: "Actions"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // Chip 4: Ctrl+F Favorite
            Rectangle {
                implicitHeight: 24
                implicitWidth: r4.implicitWidth + 14
                radius: Theme.radiusSm
                color: Theme.surface
                border.color: Theme.border

                RowLayout {
                    id: r4
                    anchors.centerIn: parent
                    spacing: 5
                    Rectangle {
                        implicitWidth: fTxt.implicitWidth + 8; implicitHeight: 16
                        radius: 3
                        color: Theme.surfaceActive
                        border.color: Theme.borderStrong
                        Text {
                            id: fTxt
                            anchors.centerIn: parent
                            text: "Ctrl F"
                            color: Theme.textSecondary
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel - 1
                        }
                    }
                    Text {
                        text: "Favorite"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }
        }
    }
}
