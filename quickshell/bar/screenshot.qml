//@ pragma UseQApplication
//@ pragma IconTheme Colloid-Dark
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./theme"
import "./services"
import "./components"
import "./modules/screenshot"

ShellRoot {
    id: root

    readonly property string rawImagePath: "file:///tmp/mujo-snip-raw.png"

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

    function doTranslate(text, targetLang) {
        if (!text || text.trim() === "") return
        root.showTranslateCard = true
        root.showOcrCard = false
        root.transBusy = true
        root.transError = ""
        root.transSourceText = text
        root.transResultText = ""
        root.transTargetLang = targetLang || root.transTargetLang
        transProc.accumulatedOutput = ""
        transProc.command = ["mujo-screenshot", "translate", root.transTargetLang, text]
        transProc.running = true
    }

    // ─── Multi-Monitor Fullscreen Overlays ───────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: screenWindow
            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            // Global Keyboard Shortcuts
            Item {
                anchors.fill: parent
                focus: true

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        if (root.showOcrCard || root.showTranslateCard) {
                            root.showOcrCard = false
                            root.showTranslateCard = false
                        } else {
                            Qt.quit()
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.hasSelection && !root.showOcrCard && !root.showTranslateCard) {
                            root.doCopy()
                        }
                        event.accepted = true
                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_C) {
                        if (root.hasSelection && !root.showOcrCard && !root.showTranslateCard) {
                            root.doCopy()
                        }
                        event.accepted = true
                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
                        if (root.hasSelection) {
                            root.doSave()
                        }
                        event.accepted = true
                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_O) {
                        if (root.hasSelection) {
                            root.doOcr()
                        }
                        event.accepted = true
                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_T) {
                        if (root.hasSelection) {
                            root.showTranslateCard = true
                            root.showOcrCard = false
                            root.transBusy = true
                            root.transError = ""
                            root.ocrBusy = true
                            root.ocrResultText = ""
                            ocrProc.accumulatedOutput = ""
                            ocrProc.command = ["mujo-screenshot", "ocr", Math.round(globalSelX), Math.round(globalSelY), Math.round(selWidth), Math.round(selHeight)]
                            ocrProc.cb = function() {
                                if (ocrProc.accumulatedOutput.trim() !== "") {
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
                x: -(screenWindow.screen ? screenWindow.screen.x : 0)
                y: -(screenWindow.screen ? screenWindow.screen.y : 0)
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
                    root.activeScreenX = screenWindow.screen ? screenWindow.screen.x : 0
                    root.activeScreenY = screenWindow.screen ? screenWindow.screen.y : 0
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

            // ─── Pixel Loupe Magnifier ───────────────────────────────────────────
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

                onCopyRequested: root.doCopy()
                onSaveRequested: root.doSave()
                onOcrRequested: root.doOcr()
                onTranslateRequested: {
                    if (root.hasSelection) {
                        root.showTranslateCard = true
                        root.showOcrCard = false
                        root.transBusy = true
                        root.transError = ""
                        ocrProc.accumulatedOutput = ""
                        ocrProc.command = ["mujo-screenshot", "ocr", Math.round(globalSelX), Math.round(globalSelY), Math.round(selWidth), Math.round(selHeight)]
                        ocrProc.cb = function() {
                            if (ocrProc.accumulatedOutput.trim() !== "") {
                                root.doTranslate(ocrProc.accumulatedOutput.trim(), root.transTargetLang)
                            } else {
                                root.transBusy = false
                                root.transError = "No text detected to translate."
                            }
                        }
                        ocrProc.running = true
                    }
                }
                onAnnotateToggled: root.showAnnotations = !root.showAnnotations
                onPinRequested: root.doCopy()
                onCancelRequested: Qt.quit()
            }

            // ─── OCR Result Card Modal ───────────────────────────────────────────
            OcrCard {
                visible: root.showOcrCard
                anchors.centerIn: parent
                recognizedText: root.ocrResultText
                busy: root.ocrBusy
                errorMessage: root.ocrError

                onCloseRequested: root.showOcrCard = false
                onCopyRequested: function(text) {
                    copyProc.command = ["wl-copy", text]
                    copyProc.running = true
                }
                onTranslateRequested: function(text) {
                    root.doTranslate(text, root.transTargetLang)
                }
            }

            // ─── Translation Card Modal ──────────────────────────────────────────
            TranslateCard {
                visible: root.showTranslateCard
                anchors.centerIn: parent
                sourceText: root.transSourceText
                translatedText: root.transResultText
                targetLang: root.transTargetLang
                busy: root.transBusy
                errorMessage: root.transError

                onCloseRequested: root.showTranslateCard = false
                onCopyRequested: function(text) {
                    copyProc.command = ["wl-copy", text]
                    copyProc.running = true
                }
                onCopyBothRequested: function(orig, trans) {
                    var combined = "Original:\n" + orig + "\n\nTranslation:\n" + trans
                    copyProc.command = ["wl-copy", combined]
                    copyProc.running = true
                }
                onLanguageChanged: function(lang) {
                    root.transTargetLang = lang
                    root.doTranslate(root.transSourceText, lang)
                }
            }
        }
    }
}
