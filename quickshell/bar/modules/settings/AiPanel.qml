import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// AI settings (WP-08). Provider presets, model/base URL, API key → keyring,
// connection test, and privacy toggles. All config lives in the unified store
// under ai.*; the AI singleton and `mujo ai chat` read the same keys. The key
// itself never touches settings.json — it goes straight to the keyring.
//
// Two kinds of provider share the picker: the OpenAI-compatible endpoints
// (Ollama, custom) and the agent CLIs detected by `mujo ai agents`. Choosing an
// agent also writes llm-default.json via `mujo ai use`, so the bar's LLM widget
// and everything behind "Ask AI" follow the same single selection.
Item {
    id: root

    function bset(k, v) { SettingsBus.set(k, v) }

    readonly property string provider: SettingsBus.get("ai.provider", "ollama")
    readonly property string baseUrl: SettingsBus.get("ai.baseUrl", "")
    readonly property string model: SettingsBus.get("ai.model", "")
    readonly property int maxTokens: SettingsBus.get("ai.maxTokens", 1024)

    readonly property var presets: [
        { v: "ollama", l: "Ollama (local)", url: "http://127.0.0.1:11434/v1" },
        { v: "custom", l: "OpenAI-compatible", url: "" }
    ]

    // Agent CLIs, detected once by the AI singleton. Only installed ones are
    // offered — the rest would just fail at ask time.
    readonly property var agents: (AI.agents || []).filter(function (a) { return a.available })
    readonly property bool usingAgent: root.provider === "agent"
    readonly property string activeAgentId: AI.activeAgent ? AI.activeAgent.id : ""

    // Selecting an agent is one action across two stores: ai.provider/ai.agent
    // in settings.json, and llm-default.json (shared with the bar widget).
    Process {
        id: useProc
        command: ["mujo", "ai", "use", ""]
        onExited: (code) => {
            if (code === 0) AI.refreshAgents()
        }
    }
    function useAgent(id) {
        root.bset("ai.provider", "agent")
        root.bset("ai.agent", id)
        useProc.command = ["mujo", "ai", "use", id]
        useProc.running = true
    }

    // ── connection test ──
    property string testState: ""   // "", "running", "ok", "error"
    property string testMsg: ""
    Process {
        id: testProc
        command: ["mujo", "ai", "test"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    if (d.ok) {
                        root.testState = "ok"
                        // The agent path reports one "model": the CLI version.
                        root.testMsg = root.usingAgent
                            ? ((d.models && d.models.length ? d.models[0] + " · " : "") + d.latencyMs + " ms")
                            : (d.latencyMs + " ms · " + (d.models ? d.models.length : 0) + " model" + ((d.models && d.models.length === 1) ? "" : "s"))
                    } else {
                        root.testState = "error"
                        root.testMsg = d.error || "connection failed"
                    }
                } catch (e) {
                    root.testState = "error"
                    root.testMsg = "unexpected response"
                }
            }
        }
        onExited: (code, status) => { if (root.testState === "running") { root.testState = "error"; root.testMsg = "test failed" } }
    }
    function runTest() { root.testState = "running"; root.testMsg = ""; testProc.running = true }

    // ── save API key → keyring (secret on stdin, never in settings.json) ──
    property string keyState: ""
    Process {
        id: keyProc
        property string payload: ""
        property bool sent: false
        stdout: StdioCollector {}
        onRunningChanged: { if (running && !sent) { write(keyProc.payload); stdinEnabled = false; sent = true } }
        onExited: (code, status) => { root.keyState = code === 0 ? "saved" : "failed" }
    }
    function saveKey(secret) {
        if (secret.trim() === "") return
        keyProc.payload = secret
        keyProc.sent = false
        keyProc.stdinEnabled = true
        keyProc.command = ["mujo-keyring", "add", "AI: " + root.provider, root.provider + "-api-key", "qsshell"]
        keyProc.running = true
        root.keyState = "saving"
    }

    component PrivacyToggle: RowLayout {
        property string skey
        property string title
        property string subtitle
        property bool def: false
        Layout.fillWidth: true; spacing: 12
        ColumnLayout {
            Layout.fillWidth: true; spacing: 1
            Text { text: title; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody }
            Text { text: subtitle; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        }
        ToggleSwitch { Layout.alignment: Qt.AlignVCenter; checked: SettingsBus.get(skey, def); onToggled: function (c) { root.bset(skey, c) } }
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
                brand: "ai"
                title: "AI & Assistant"
                subtitle: "Coding-agent CLIs, local Ollama models, OpenAI-compatible APIs, keyring secrets, and privacy guardrails."
                badgeText: root.usingAgent && AI.activeAgent ? AI.activeAgent.name.toUpperCase()
                    : (root.testState === "ok" ? "CONNECTED" : (root.testState === "error" ? "OFFLINE" : root.provider.toUpperCase()))
                badgeColor: root.testState === "ok" ? Theme.success : (root.testState === "error" ? Theme.error : Theme.accent)
                activeState: root.testState === "running" || root.testState === "ok"
            }

            // ── Assistant CLI Card ──
            MujoCard {
                title: "Assistant CLI"
                iconName: "terminal"
                badgeText: root.usingAgent && AI.activeAgent ? AI.activeAgent.name : (root.agents.length > 0 ? (root.agents.length + " AVAILABLE") : "NONE")
                badgeColor: Theme.accent

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: root.agents.length > 0
                            ? "Answer “Ask AI” with an installed coding agent. It runs in its read-only mode from an empty scratch directory, and the same choice drives the bar's usage widget."
                            : "No agent CLI found on PATH. Install one (Claude Code, opencode, Antigravity, Codex, Gemini CLI, Pi) or set a custom command below."
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 7
                        visible: root.agents.length > 0

                        Repeater {
                            model: root.agents
                            delegate: DisplayChip {
                                required property var modelData
                                label: modelData.name
                                selected: root.usingAgent && (root.activeAgentId === modelData.id || SettingsBus.get("ai.agent", "") === modelData.id)
                                onClicked: root.useAgent(modelData.id)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "Custom"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 90 }
                        TextField {
                            id: agentCmdField
                            Layout.fillWidth: true
                            placeholder: "argv for any other CLI, e.g. aider --no-auto-commits --message"
                            text: SettingsBus.get("ai.agentCommand", "")
                            onAccepted: root.bset("ai.agentCommand", text.trim())
                        }
                        DialogButton { text: "Save"; onClicked: root.bset("ai.agentCommand", agentCmdField.text.trim()) }
                    }
                }
            }

            // ── API Provider Card ──
            MujoCard {
                title: "API Provider & Endpoint"
                iconName: "cloud"
                badgeText: root.provider.toUpperCase()
                badgeColor: Theme.accent

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Flow {
                        Layout.fillWidth: true
                        spacing: 7

                        Repeater {
                            model: root.presets
                            delegate: DisplayChip {
                                required property var modelData
                                label: modelData.l
                                selected: root.provider === modelData.v
                                onClicked: {
                                    root.bset("ai.provider", modelData.v)
                                    if (modelData.v === "ollama" && root.baseUrl === "") root.bset("ai.baseUrl", modelData.url)
                                }
                            }
                        }
                    }

                    // Endpoint settings (when not using agent)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: !root.usingAgent

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: "Base URL"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 90 }
                            TextField {
                                id: urlField
                                Layout.fillWidth: true
                                placeholder: "http://127.0.0.1:11434/v1"
                                text: root.baseUrl
                                onAccepted: root.bset("ai.baseUrl", text.trim())
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: "Model"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 90 }
                            TextField {
                                id: modelField
                                Layout.fillWidth: true
                                placeholder: "e.g. llama3.2, gpt-4o-mini"
                                text: root.model
                                onAccepted: root.bset("ai.model", text.trim())
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            DialogButton { text: "Save endpoint"; primary: true; onClicked: { root.bset("ai.baseUrl", urlField.text.trim()); root.bset("ai.model", modelField.text.trim()) } }
                            DialogButton {
                                text: root.testState === "running" ? "Testing…" : (root.usingAgent ? "Check assistant" : "Test connection")
                                enabled: root.testState !== "running"
                                onClicked: root.runTest()
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                visible: root.testState === "ok" || root.testState === "error"
                                MaterialIcon { iconName: root.testState === "ok" ? "check_circle" : "error"; pixelSize: 15; color: root.testState === "ok" ? Theme.success : Theme.error }
                                Text { text: root.testMsg; color: root.testState === "ok" ? Theme.success : Theme.error; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }

            // ── API Key Card ──
            MujoCard {
                visible: !root.usingAgent
                title: "API Credentials & Keyring"
                iconName: "key"

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "API Key"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 90 }
                        TextField {
                            id: keyField
                            Layout.fillWidth: true
                            password: true
                            placeholder: "Stored in the keyring, not settings.json (optional for local Ollama)"
                            onAccepted: { root.saveKey(text); text = "" }
                        }
                        DialogButton { text: "Save to keyring"; onClicked: { root.saveKey(keyField.text); keyField.text = "" } }
                    }

                    Text {
                        visible: root.keyState !== ""
                        text: root.keyState === "saved" ? "Key saved to keyring for “" + root.provider + "”."
                            : root.keyState === "failed" ? "Failed to save key (is the keyring unlocked?)."
                            : "Saving…"
                        color: root.keyState === "failed" ? Theme.error : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // ── Generation Parameters Card ──
            MujoCard {
                visible: !root.usingAgent
                title: "Generation Parameters"
                iconName: "tune"

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "Max tokens"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 90 }
                        TextField {
                            id: maxTokField
                            Layout.preferredWidth: 120
                            text: String(root.maxTokens)
                            onAccepted: root.bset("ai.maxTokens", parseInt(text) || 1024)
                        }
                        DialogButton { text: "Save"; onClicked: root.bset("ai.maxTokens", parseInt(maxTokField.text) || 1024) }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ── Privacy & Guardrails Card ──
            MujoCard {
                title: "Privacy & Safety Guardrails"
                iconName: "security"

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    PrivacyToggle { skey: "ai.crashAssist"; title: "Crash assistant"; subtitle: "Detect application crashes and offer help. On by default (sending crash data to AI still needs the toggle below)."; def: true }
                    PrivacyToggle { skey: "ai.allowShellContext"; title: "Share shell context"; subtitle: "Let the assistant see the current window / recent commands when you ask. Off by default."; def: false }
                    PrivacyToggle { skey: "ai.allowCrashData"; title: "Share crash details"; subtitle: "Allow “Ask AI” on a crash to include sanitized coredump info. Off by default."; def: false }
                    PrivacyToggle { skey: "ai.confirmActions"; title: "Confirm before applying"; subtitle: "Require a confirmation before applying any AI-suggested action. On by default."; def: true }
                }
            }

            Item { implicitHeight: 12 }
        }
    }
}
