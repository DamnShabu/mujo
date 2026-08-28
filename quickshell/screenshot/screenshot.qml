//@ pragma UseQApplication
//@ pragma IconTheme Colloid-Dark
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../bar/theme"
import "../bar/components"
import "."

ShellRoot {
    id: root

    readonly property string rawImagePath: "file:///tmp/mujo-snip-raw.png"
    readonly property string helperScript: {
        var envScript = Quickshell.env("MUJO_SCREENSHOT_HELPER") || ""
        if (envScript !== "") return envScript
        return "/tmp/mujo-snip-helper.sh"
    }

    // Global state
    property int activeScreenX: 0
    property int activeScreenY: 0
    property int selX: 0
    property int selY: 0
    property int selWidth: 0
    property int selHeight: 0
    property bool isDragging: false
    property bool hasSelection: selWidth > 5 && selHeight > 5

    readonly property int globalSelX: activeScreenX + selX
    readonly property int globalSelY: activeScreenY + selY

    // Modals & Tools state
    property bool showOcrCard: false
    property bool showTranslateCard: false
    property bool showAnnotations: false

    property string ocrResultText: ""
    property bool ocrBusy: false
    property string ocrError: ""

    property string transSourceText: ""
    property string transResultText: ""
    property string transTargetLang: "en"
    property bool transBusy: false
    property string transError: ""

    // Initial load: fetch configured default target language
    Process {
        id: configLoader
        command: ["mujo-screenshot", "config-get", "targetLanguage", "en"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() !== "") root.transTargetLang = line.trim()
            }
        }
    }

    Component.onCompleted: {
        configLoader.running = true
    }

    // Backend Execution Processes
    Process {
        id: copyProc
        property var cb: null
        running: false
        onExited: function(code) {
            if (cb) cb()
            Qt.quit()
        }
    }

    Process {
        id: saveProc
        running: false
        onExited: function(code) {
            Qt.quit()
        }
    }

    Process {
        id: ocrProc
        running: false
        property string accumulatedOutput: ""
        stdout: SplitParser {
            onRead: function(line) {
                ocrProc.accumulatedOutput += (ocrProc.accumulatedOutput === "" ? "" : "\n") + line
            }
        }
        onExited: function(code) {
            root.ocrBusy = false
            if (code === 0) {
                root.ocrResultText = ocrProc.accumulatedOutput.trim()
                if (root.ocrResultText === "") {
                    root.ocrError = "No readable text detected in selection."
                }
            } else {
                root.ocrError = "OCR extraction failed."
            }
        }
    }

    Process {
        id: transProc
        running: false
        property string accumulatedOutput: ""
        stdout: SplitParser {
            onRead: function(line) {
                transProc.accumulatedOutput += (transProc.accumulatedOutput === "" ? "" : "\n") + line
            }
        }
        onExited: function(code) {
            root.transBusy = false
            if (code === 0) {
                root.transResultText = transProc.accumulatedOutput.trim()
            } else {
                root.transError = "Translation failed."
            }
        }
    }

    function doCopy() {
        if (!hasSelection) return
        copyProc.command = ["mujo-screenshot", "copy", Math.round(globalSelX), Math.round(globalSelY), Math.round(selWidth), Math.round(selHeight)]
        copyProc.running = true
    }

    function doSave() {
        if (!hasSelection) return
        saveProc.command = ["mujo-screenshot", "save", Math.round(globalSelX), Math.round(globalSelY), Math.round(selWidth), Math.round(selHeight)]
        saveProc.running = true
    }

    function doOcr() {
        if (!hasSelection) return
        root.showOcrCard = true
        root.showTranslateCard = false
        root.ocrBusy = true
        root.ocrError = ""
        root.ocrResultText = ""
        ocrProc.accumulatedOutput = ""
        ocrProc.command = ["mujo-screenshot", "ocr", Math.round(globalSelX), Math.round(globalSelY), Math.round(selWidth), Math.round(selHeight)]
        ocrProc.running = true
    }

    function doTranslate(text, lang) {
        root.showTranslateCard = true
        root.showOcrCard = false
        root.transBusy = true
        root.transError = ""
        root.transResultText = ""
        root.transSourceText = text
        if (lang) root.transTargetLang = lang

        transProc.accumulatedOutput = ""
        transProc.command = ["mujo-screenshot", "translate", root.transTargetLang, text]
        transProc.running = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: screenWindow
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "mujo-screenshot"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Keyboard Shortcuts
            Item {
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: Qt.quit()
                Keys.onReturnPressed: root.doCopy()
                Keys.onEnterPressed: root.doCopy()

                Keys.onPressed: function(event) {
                    if (event.matches(StandardKey.Copy)) {
                        root.doCopy()
                        event.accepted = true
                    } else if (event.matches(StandardKey.Save)) {
                        root.doSave()
                        event.accepted = true
                    } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_O) {
                        root.doOcr()
                        event.accepted = true
                    } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_T) {
                        if (root.ocrResultText !== "") {
                            root.doTranslate(root.ocrResultText, root.transTargetLang)
                        } else {
                            // OCR first then translate
                            root.showTranslateCard = true
                            root.transBusy = true
                            ocrProc.accumulatedOutput = ""
                            ocrProc.command = ["mujo-screenshot", "ocr", Math.round(root.selX), Math.round(root.selY), Math.round(root.selWidth), Math.round(root.selHeight)]
                            ocrProc.onExited = function(c) {
                                if (c === 0 && ocrProc.accumulatedOutput.trim() !== "") {
                                    root.doTranslate(ocrProc.accumulatedOutput.trim(), root.transTargetLang)
                                } else {
                                    root.transBusy = false
                                    root.transError = "No text detected to translate."
                                }
                            }
                            ocrProc.running = true
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_A) {
                        root.showAnnotations = !root.showAnnotations
                        event.accepted = true
                    }
                }
            }

            // Frozen background frame
            Image {
                id: bgImage
                x: -(screenWindow.modelData.x || 0)
                y: -(screenWindow.modelData.y || 0)
                source: root.rawImagePath
                asynchronous: false
                cache: false
            }

            // ─── 4-Rectangle Dimmed Mask (Cutout around selection) ───────────────
            readonly property color dimColor: "#99000000"

            // Top Dim
            Rectangle {
                x: 0
                y: 0
                width: parent.width
                height: root.hasSelection ? root.selY : parent.height
                color: screenWindow.dimColor
            }
            // Bottom Dim
            Rectangle {
                x: 0
                y: root.selY + root.selHeight
                width: parent.width
                height: parent.height - (root.selY + root.selHeight)
                visible: root.hasSelection
                color: screenWindow.dimColor
            }
            // Left Dim
            Rectangle {
                x: 0
                y: root.selY
                width: root.selX
                height: root.selHeight
                visible: root.hasSelection
                color: screenWindow.dimColor
            }
            // Right Dim
            Rectangle {
                x: root.selX + root.selWidth
                y: root.selY
                width: parent.width - (root.selX + root.selWidth)
                height: root.selHeight
                visible: root.hasSelection
                color: screenWindow.dimColor
            }

            // ─── Main Drag Mouse Area (New Selection) ────────────────────────────
            MouseArea {
                id: dragArea
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                enabled: !root.showOcrCard && !root.showTranslateCard

                property int startX: 0
                property int startY: 0

                onPressed: function(mouse) {
                    root.activeScreenX = screenWindow.modelData.x || 0
                    root.activeScreenY = screenWindow.modelData.y || 0
                    startX = mouse.x
                    startY = mouse.y
                    root.selX = mouse.x
                    root.selY = mouse.y
                    root.selWidth = 0
                    root.selHeight = 0
                    root.isDragging = true
                    root.showAnnotations = false
                }

                onPositionChanged: function(mouse) {
                    if (root.isDragging) {
                        root.selX = Math.min(startX, mouse.x)
                        root.selY = Math.min(startY, mouse.y)
                        root.selWidth = Math.abs(mouse.x - startX)
                        root.selHeight = Math.abs(mouse.y - startY)
                    }
                }

                onReleased: function(mouse) {
                    root.isDragging = false
                }
            }

            // ─── Interactive Selection Area (Resize & Move Handles) ──────────────
            SelectionArea {
                selX: root.selX
                selY: root.selY
                selWidth: root.selWidth
                selHeight: root.selHeight
                resizable: !root.isDragging && !root.showOcrCard && !root.showTranslateCard

                onMoved: function(nx, ny) {
                    root.selX = nx
                    root.selY = ny
                }

                onResized: function(nx, ny, nw, nh) {
                    root.selX = nx
                    root.selY = ny
                    root.selWidth = nw
                    root.selHeight = nh
                }

                // Annotations layer inside selection
                AnnotationCanvas {
                    active: root.showAnnotations
                }
            }

            // ─── Magnifier Loupe ────────────────────────────────────────────────
            Loupe {
                rawSource: root.rawImagePath
                cursorX: dragArea.mouseX
                cursorY: dragArea.mouseY
                selectionWidth: root.selWidth
                selectionHeight: root.selHeight
                isSelecting: root.isDragging
            }

            // ─── Floating Action Toolbar ─────────────────────────────────────────
            FloatingToolbar {
                selX: root.selX
                selY: root.selY
                selWidth: root.selWidth
                selHeight: root.selHeight
                annotateActive: root.showAnnotations
                visible: root.hasSelection && !root.isDragging && !root.showOcrCard && !root.showTranslateCard

                onCopyRequested: root.doCopy()
                onSaveRequested: root.doSave()
                onOcrRequested: root.doOcr()
                onTranslateRequested: {
                    root.showTranslateCard = true
                    root.showOcrCard = false
                    root.transBusy = true
                    ocrProc.accumulatedOutput = ""
                    ocrProc.command = ["mujo-screenshot", "ocr", Math.round(root.selX), Math.round(root.selY), Math.round(root.selWidth), Math.round(root.selHeight)]
                    ocrProc.onExited = function(code) {
                        if (code === 0 && ocrProc.accumulatedOutput.trim() !== "") {
                            root.doTranslate(ocrProc.accumulatedOutput.trim(), root.transTargetLang)
                        } else {
                            root.transBusy = false
                            root.transError = "No text found in selection."
                        }
                    }
                    ocrProc.running = true
                }
                onAnnotateToggled: root.showAnnotations = !root.showAnnotations
                onPinRequested: {
                    // Save and copy, then notify
                    root.doCopy()
                }
                onCancelRequested: Qt.quit()
            }

            // ─── OCR Card Popover ───────────────────────────────────────────────
            OcrCard {
                anchors.centerIn: parent
                visible: root.showOcrCard
                busy: root.ocrBusy
                recognizedText: root.ocrResultText
                errorMessage: root.ocrError

                onCopyRequested: function(text) {
                    // Copy to clipboard
                    copyProc.command = ["wl-copy", text]
                    copyProc.running = true
                    root.showOcrCard = false
                    Qt.quit()
                }

                onTranslateRequested: function(text) {
                    root.doTranslate(text, root.transTargetLang)
                }

                onCloseRequested: {
                    root.showOcrCard = false
                }
            }

            // ─── Translation Card Popover ───────────────────────────────────────
            TranslateCard {
                anchors.centerIn: parent
                visible: root.showTranslateCard
                busy: root.transBusy
                sourceText: root.transSourceText
                translatedText: root.transResultText
                targetLang: root.transTargetLang
                errorMessage: root.transError

                onLanguageChanged: function(newLang) {
                    root.transTargetLang = newLang
                    root.doTranslate(root.transSourceText, newLang)
                }

                onCopyRequested: function(text) {
                    copyProc.command = ["wl-copy", text]
                    copyProc.running = true
                    root.showTranslateCard = false
                    Qt.quit()
                }

                onCopyBothRequested: function(orig, trans) {
                    var both = orig + "\n\n" + trans
                    copyProc.command = ["wl-copy", both]
                    copyProc.running = true
                    root.showTranslateCard = false
                    Qt.quit()
                }

                onCloseRequested: {
                    root.showTranslateCard = false
                }
            }
        }
    }
}
