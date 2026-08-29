import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    property bool active: false
    property bool standalone: false
    property string imageTimestamp: ""
    readonly property string rawImagePath: active ? ("file:///tmp/mujo-snip-raw.png?t=" + imageTimestamp) : ""

    // Global state
    property int activeScreenX: 0
    property int activeScreenY: 0
    property int selX: 0
    property int selY: 0
    property int selWidth: 0
    property int selHeight: 0
    property bool isDragging: false
    property bool hasSelection: selWidth > 5 && selHeight > 5

    // grim writes one image spanning the bounding box of every output, so its
    // pixel (0,0) is the top-left-most output corner — not compositor (0,0).
    // Niri hands out whatever origin it likes (a dual-monitor stack here sits at
    // 3610,1330), so screen coordinates have to be rebased onto the frame before
    // they can index into it. Without this, `magick -crop` was handed an offset
    // past the right edge of the capture and answered with a 1x1 placeholder.
    readonly property point frameOrigin: {
        const list = Quickshell.screens
        let ox = 0
        let oy = 0
        for (let i = 0; i < list.length; i++) {
            if (i === 0 || list[i].x < ox)
                ox = list[i].x
            if (i === 0 || list[i].y < oy)
                oy = list[i].y
        }
        return Qt.point(ox, oy)
    }

    readonly property int frameSelX: activeScreenX - frameOrigin.x + selX
    readonly property int frameSelY: activeScreenY - frameOrigin.y + selY

    // Modals & Tools state
    property bool showOcrCard: false
    property bool showAnnotations: false

    property string ocrResultText: ""
    property bool ocrBusy: false
    property string ocrError: ""

    // Translation is painted onto the selection rather than shown in a window,
    // so its state is a list of placed lines instead of a blob of result text.
    property bool showTranslation: false
    property var translationLines: []
    property string transTargetLang: "en"
    property bool transBusy: false
    property string transError: ""

    // The OCR pass behind the current translation: source lines with their boxes
    // plus the crop they were measured in. Kept so a language change re-runs only
    // the translate call, not tesseract.
    property var srcLines: []
    property int srcWidth: 0
    property int srcHeight: 0

    function open() {
        imageTimestamp = String(Date.now())
        resetState()
        configLoader.running = true
        active = true
    }

    function close() {
        active = false
        resetState()
        if (standalone) {
            Qt.quit()
        }
    }

    function toggle() {
        if (active) {
            close()
        } else {
            open()
        }
    }

    function resetState() {
        selX = 0
        selY = 0
        selWidth = 0
        selHeight = 0
        isDragging = false
        showOcrCard = false
        showAnnotations = false
        ocrBusy = false
        ocrError = ""
        ocrResultText = ""
        clearTranslation()
    }

    function clearTranslation() {
        showTranslation = false
        translationLines = []
        srcLines = []
        srcWidth = 0
        srcHeight = 0
        transBusy = false
        transError = ""
    }

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

    // Backend Execution Processes
    Process {
        id: copyProc
        property var cb: null
        running: false
        onExited: function(code) {
            if (cb) cb()
            root.close()
        }
    }

    Process {
        id: saveProc
        running: false
        onExited: function(code) {
            root.close()
        }
    }

    Process {
        id: ocrProc
        property var cb: null
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
            if (ocrProc.cb) {
                var callback = ocrProc.cb
                ocrProc.cb = null
                callback()
            }
        }
    }

    // OCR that keeps the boxes, so the translation can be placed on the words it
    // came from. The backend emits compact JSON (`jq -c`), so this is one line.
    Process {
        id: ocrLinesProc
        running: false
        property string accumulatedOutput: ""
        stdout: SplitParser {
            onRead: function(line) {
                ocrLinesProc.accumulatedOutput += line
            }
        }
        onExited: function(code) {
            if (code !== 0) {
                root.transBusy = false
                root.transError = "Could not read text in the selection."
                return
            }
            var data = null
            try {
                data = JSON.parse(ocrLinesProc.accumulatedOutput)
            } catch (e) {
                root.transBusy = false
                root.transError = "Could not read text in the selection."
                return
            }
            root.srcLines = data.lines || []
            root.srcWidth = data.w || 0
            root.srcHeight = data.h || 0
            if (root.srcLines.length === 0) {
                root.transBusy = false
                root.transError = "No readable text detected in selection."
                return
            }
            root.runTranslate()
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
            if (code !== 0) {
                root.transError = "Translation failed."
                return
            }
            root.placeTranslation(transProc.accumulatedOutput)
        }
    }

    function doCopy() {
        if (!hasSelection) return
        copyProc.command = ["mujo-screenshot", "copy", Math.round(frameSelX), Math.round(frameSelY), Math.round(selWidth), Math.round(selHeight)]
        copyProc.running = true
    }

    function doSave() {
        if (!hasSelection) return
        saveProc.command = ["mujo-screenshot", "save", Math.round(frameSelX), Math.round(frameSelY), Math.round(selWidth), Math.round(selHeight)]
        saveProc.running = true
    }

    function doOcr() {
        if (!hasSelection) return
        root.showOcrCard = true
        root.showTranslation = false
        root.ocrBusy = true
        root.ocrError = ""
        root.ocrResultText = ""
        ocrProc.accumulatedOutput = ""
        ocrProc.cb = null
        ocrProc.command = ["mujo-screenshot", "ocr", Math.round(frameSelX), Math.round(frameSelY), Math.round(selWidth), Math.round(selHeight)]
        ocrProc.running = true
    }

    // Ctrl+T / toolbar: OCR the selection with boxes, then translate every line
    // in one call. `trans -b` answers newline-for-newline, so the results zip
    // back onto the boxes by index.
    function doTranslate() {
        if (!hasSelection) return
        root.showOcrCard = false
        root.showAnnotations = false
        root.showTranslation = true
        root.translationLines = []
        root.transError = ""
        root.transBusy = true
        ocrLinesProc.accumulatedOutput = ""
        ocrLinesProc.command = ["mujo-screenshot", "ocr-lines", Math.round(frameSelX), Math.round(frameSelY), Math.round(selWidth), Math.round(selHeight)]
        ocrLinesProc.running = true
    }

    // Re-translates the OCR result already in hand — used when the language
    // changes, so switching targets costs one network call and no tesseract pass.
    function runTranslate() {
        if (root.srcLines.length === 0) return
        var joined = root.srcLines.map(function(l) { return l.text }).join("\n")
        root.translationLines = []
        root.transError = ""
        root.transBusy = true
        transProc.accumulatedOutput = ""
        transProc.command = ["mujo-screenshot", "translate", root.transTargetLang, joined]
        transProc.running = true
    }

    function setTargetLang(lang) {
        if (!lang || lang === root.transTargetLang) return
        root.transTargetLang = lang
        if (root.showTranslation)
            root.runTranslate()
    }

    function placeTranslation(result) {
        var out = result.split("\n")
        if (out.length === root.srcLines.length) {
            root.translationLines = root.srcLines.map(function(l, i) {
                return { x: l.x, y: l.y, w: l.w, h: l.h, text: out[i] }
            })
            return
        }
        // `trans` merged or split lines, so index N no longer means line N.
        // Pinning text to the wrong words is worse than not pinning it: fall back
        // to one plate over the whole selection. Same path covers a selection
        // whose text OCR could not break into lines.
        root.translationLines = [{
            x: 0,
            y: 0,
            w: root.srcWidth,
            h: root.srcHeight,
            text: result.trim()
        }]
    }

    // ─── Multi-Monitor Fullscreen Overlays ───────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: screenWindow
            required property var modelData
            screen: modelData
            visible: root.active

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.namespace: "qs-screenshot"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            // Global Keyboard Shortcuts
            Item {
                anchors.fill: parent
                focus: root.active

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        if (root.showOcrCard || root.showTranslation) {
                            root.showOcrCard = false
                            root.clearTranslation()
                        } else {
                            root.close()
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.hasSelection && !root.showOcrCard && !root.showTranslation) {
                            root.doCopy()
                        }
                        event.accepted = true
                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_C) {
                        if (root.hasSelection && !root.showOcrCard && !root.showTranslation) {
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
                        root.doTranslate()
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
                x: -((screenWindow.screen ? screenWindow.screen.x : 0) - root.frameOrigin.x)
                y: -((screenWindow.screen ? screenWindow.screen.y : 0) - root.frameOrigin.y)
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
                enabled: !root.showOcrCard && !root.showTranslation

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
                resizable: !root.isDragging && !root.showOcrCard && !root.showTranslation

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
                translateActive: root.showTranslation
                targetLang: root.transTargetLang

                onCopyRequested: root.doCopy()
                onSaveRequested: root.doSave()
                onOcrRequested: root.doOcr()
                onTranslateRequested: root.doTranslate()
                onLanguageSelected: function(lang) { root.setTargetLang(lang) }
                onAnnotateToggled: root.showAnnotations = !root.showAnnotations
                onPinRequested: root.doCopy()
                onCancelRequested: root.close()
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
                    root.showOcrCard = false
                    root.doTranslate()
                }
            }

            // ─── In-place Translation Plates ─────────────────────────────────────
            TranslationOverlay {
                visible: root.showTranslation
                selX: root.selX
                selY: root.selY
                selWidth: root.selWidth
                selHeight: root.selHeight
                sourceWidth: root.srcWidth
                sourceHeight: root.srcHeight
                lines: root.translationLines
                busy: root.transBusy
                errorMessage: root.transError
            }
        }
    }
}
