pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Shared cava spectrum source (WP-15/16). One cava process feeds `levels`;
// CavaOverlay (desktop) and the island's cava-mini module both render from it.
// Runs only when something wants it AND audio is actually playing/unmuted.
QtObject {
    id: cava

    readonly property bool overlayWants: SettingsBus.get("cava.enabled", false)
    readonly property bool islandWants:
        SettingsBus.get("island.enabled", true) &&
        (SettingsBus.get("island.modules", []).indexOf("cava-mini") >= 0)

    property PwObjectTracker _tracker: PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool sinkMuted: sink && sink.audio ? sink.audio.muted : false

    property int streamCount: 0
    function _recount() {
        if (!Pipewire.nodes) { streamCount = 0; return }
        streamCount = Pipewire.nodes.values.filter(function (n) {
            return n && n.isStream && (n.type & PwNodeType.AudioOutStream) === PwNodeType.AudioOutStream
        }).length
    }
    property Connections _nodesConn: Connections { target: Pipewire.nodes; function onValuesChanged() { cava._recount() } }

    readonly property bool active: (overlayWants || islandWants) && !Lock.locked && !sinkMuted && streamCount > 0
    property var levels: []
    onActiveChanged: if (!active) levels = []

    property Process _proc: Process {
        running: cava.active
        // Config passed as $1 to sh -c (dodges heredoc quoting). Fixed 44 bars.
        command: ["sh", "-c", "f=$(mktemp) || exit 1; printf '%s' \"$1\" > \"$f\"; exec cava -p \"$f\"", "sh",
            "[general]\nframerate = 30\nbars = 44\n[input]\nmethod = pipewire\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nchannels = mono\n"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) {
                var parts = line.split(";")
                var out = []
                for (var i = 0; i < parts.length; i++) {
                    if (parts[i] === "") continue
                    var v = parseInt(parts[i])
                    out.push(isNaN(v) ? 0 : v)
                }
                if (out.length) cava.levels = out
            }
        }
    }

    Component.onCompleted: _recount()
}
