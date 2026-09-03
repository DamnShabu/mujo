import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme"
import "../../components"
import "../../services"

// Coding-Agent CLIs, Local Ollama, OpenAI-compatible APIs, Keyring, and Privacy Guards Group.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    function bset(k, v) { SettingsBus.set(k, v) }

    readonly property string provider: SettingsBus.get("ai.provider", "ollama")
    readonly property string baseUrl: SettingsBus.get("ai.baseUrl", "")
    readonly property string model: SettingsBus.get("ai.model", "")
    readonly property int maxTokens: SettingsBus.get("ai.maxTokens", 1024)

    readonly property var presets: [
        { v: "ollama", l: "Ollama (local)", url: "http://127.0.0.1:11434/v1" },
        { v: "custom", l: "OpenAI-compatible", url: "" }
    ]

    readonly property var agents: (AI.agents || []).filter(function (a) { return a.available })
    readonly property bool usingAgent: root.provider === "agent"
    readonly property string activeAgentId: AI.activeAgent ? AI.activeAgent.id : ""

    Process {
        id: useProc
        command: ["mujo", "ai", "use", ""]
        onExited: (code) => { if (code === 0) AI.refreshAgents() }
    }
    function useAgent(id) {
        root.bset("ai.provider", "agent")
        root.bset("ai.agent", id)
        useProc.command = ["mujo", "ai", "use", id]
        useProc.running = true
    }

    // ── Connection test ──
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

    // ── Keyring API key ──
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

    // ── 1. Coding Assistant CLI Card ──────────────────────────────────────────
    MujoCard {
        title: "Coding Assistant CLI"
        iconName: "terminal"
        badgeText: root.usingAgent && AI.activeAgent ? AI.activeAgent.name.toUpperCase() : (root.agents.length > 0 ? (root.agents.length + " AVAILABLE") : "NONE")
        badgeColor: Theme.accent

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.agents.length > 0
                    ? "Answer “Ask AI” with an installed agent CLI. It runs in read-only mode from an isolated scratch directory and powers the desktop LLM usage widget."
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
                Text { text: "Custom CLI"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.preferredWidth: 90 }
                TextField {
                    id: agentCmdField
                    Layout.fillWidth: true
                    placeholder: "argv for CLI, e.g. aider --no-auto-commits --message"
                    text: SettingsBus.get("ai.agentCommand", "")
                    onAccepted: root.bset("ai.agentCommand", text.trim())
                }
                DialogButton { text: "Save"; onClicked: root.bset("ai.agentCommand", agentCmdField.text.trim()) }
            }
        }
    }

    // ── 2. API Provider & Endpoint Card ───────────────────────────────────────
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

            // Endpoint settings
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

    // ── 3. API Credentials & Keyring Card ─────────────────────────────────────
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
                    placeholder: "Stored in the keyring, not settings.json"
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

    // ── 4. Generation Parameters Card ─────────────────────────────────────────
    MujoCard {
        visible: !root.usingAgent
        title: "Generation Parameters"
        iconName: "tune"

        SettingRow {
            path: "ai.maxTokens"
            def: 1024
            kind: "slider"
            from: 256
            to: 8192
            format: " tokens"
            iconName: "pin"
            title: "Max Completion Tokens"
            description: "Maximum tokens generated per response in Ask AI palette."
        }
    }

    // ── 5. AI Privacy & Safety Guardrails Card ────────────────────────────────
    MujoCard {
        title: "AI Privacy & Safety Guardrails"
        iconName: "security"

        SettingRow {
            path: "ai.crashAssist"
            def: true
            kind: "toggle"
            iconName: "report_problem"
            title: "Crash Assistant"
            description: "Detect application crashes and offer automated debugging assistance."
        }

        SettingRow {
            path: "ai.allowCrashData"
            def: false
            kind: "toggle"
            iconName: "bug_report"
            title: "Share Sanitized Crash Logs"
            description: "Include sanitized core dump and backtrace info when asking about a crash."
        }
    }
}
