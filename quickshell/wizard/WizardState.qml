pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property int currentPage: 0
  property int totalPages: 3
  readonly property var pageTitles: ["Identity", "Machine", "Apply"]
  property bool busy: false
  property string error: ""
  property bool done: false
  property bool confirmationPending: false

  // Page 1: Identity
  property string username: ""
  property string password: ""
  property string confirmPassword: ""

  readonly property bool passwordsMatch: password !== "" && password === confirmPassword
  readonly property int passwordStrength: {
    var s = 0
    if (password.length >= 8) s++
    if (password.length >= 12) s++
    if (password !== password.toLowerCase()) s++
    if (/\d/.test(password)) s++
    if (/[^a-zA-Z0-9]/.test(password)) s++
    return Math.min(s, 4)
  }

  // Page 2: Machine
  property string hostname: ""
  property var monitorOutputs: []
  property var monitorModes: []      // array of [{mode, w, h, hz}] per output
  property var monitorPositions: []  // [{x, y}] per output
  property var monitorScales: []     // [float] per output
  property string timezone: "Europe/Berlin"

  readonly property string home: Quickshell.env("HOME")
  readonly property string nixconf: home + "/nixconf"
  readonly property string secretsDir: nixconf + "/secrets"
  readonly property string userConfigDir: nixconf + "/user-config"

  readonly property var timezones: [
    "Europe/Berlin", "Europe/London", "Europe/Paris", "Europe/Moscow",
    "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles",
    "Asia/Tokyo", "Asia/Shanghai", "Asia/Kolkata", "Australia/Sydney",
    "Pacific/Auckland", "UTC"
  ]

  // ponytail: escape value for safe embedding in bash double-quoted string
  function bashEscape(s) {
    if (!s) return ""
    return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\$/g, "\\$").replace(/`/g, "\\`").replace(/'/g, "'\\''")
  }

  property var discoveredMonitors: []
  property int selectedMonitor: -1

  function nextPage() {
    if (currentPage < totalPages - 1) {
      error = ""
      confirmationPending = false
      currentPage++
    }
  }

  function prevPage() {
    if (currentPage > 0) {
      error = ""
      confirmationPending = false
      currentPage--
    }
  }

  function pageValid(page) {
    switch (page) {
    case 0: return username !== "" && password !== "" && passwordsMatch
    case 2: return username !== "" && password !== "" && passwordsMatch
    default: return true
    }
  }

  function setMonitorOutput(idx, output) {
    var o = monitorOutputs.slice()
    o[idx] = output
    monitorOutputs = o
  }

  function setMonitorMode(idx, mode) {
    var m = monitorModes.slice()
    m[idx] = mode
    monitorModes = m
  }

  function setMonitorPosition(idx, pos) {
    var p = monitorPositions.slice()
    p[idx] = pos
    monitorPositions = p
  }

  function setMonitorScale(idx, scale) {
    var s = monitorScales.slice()
    s[idx] = scale
    monitorScales = s
  }

  function discoverMonitors() {
    monitorScanProc.running = true
  }

  // ponytail: QtObject doesn't support direct child objects in some QML
  // engines. All Process objects live here as children of the Item root.

  Process {
    id: monitorScanProc
    command: ["niri", "msg", "outputs"]
    stdout: StdioCollector {
      onStreamFinished: {
        var monitors = []
        var allModes = []
        var allPositions = []
        var allScales = []
        var blocks = text.trim().split("\n\n")
        for (var b = 0; b < blocks.length; b++) {
          var block = blocks[b]
          if (block.trim() === "") continue
          var lines = block.split("\n")
          // Output "Name" (DP-X)
          var nameMatch = lines[0].match(/^Output\s+"[^"]*"\s+\(([^)]+)\)/)
          if (!nameMatch) continue
          var outName = nameMatch[1]
          monitors.push(outName)
          var modes = []
          var pos = { x: 0, y: 0 }
          var scale = 1.0
          for (var i = 1; i < lines.length; i++) {
            var l = lines[i].trim()
            var cm = l.match(/^Current mode:\s+(\d+)x(\d+)\s+@\s+([\d.]+)\s+Hz/)
            var pm = l.match(/^Logical position:\s+(\d+),\s*(\d+)/)
            if (pm) { pos.x = parseInt(pm[1]); pos.y = parseInt(pm[2]) }
            var sm = l.match(/^Scale:\s+([\d.]+)/)
            if (sm) scale = parseFloat(sm[1])
            // Available modes: 1920x1080@165.003 (current, custom)
            var am = l.match(/^(\d+)x(\d+)@([\d.]+)/)
            if (am) {
              modes.push({ mode: am[1] + "x" + am[2] + "@" + am[3], w: parseInt(am[1]), h: parseInt(am[2]), hz: parseFloat(am[3]) })
            }
          }
          allModes.push(modes)
          allPositions.push(pos)
          allScales.push(scale)
        }
        root.discoveredMonitors = monitors
        root.monitorModes = allModes
        root.monitorPositions = allPositions
        root.monitorScales = allScales
        root.monitorOutputs = monitors.slice()
      }
    }
  }

  function writePassword() {
    error = ""
    if (!confirmationPending) {
      confirmationPending = true
      return
    }
    confirmationPending = false
    if (!username) { error = "Username is required"; return }
    if (!password) { error = "Password is required"; return }
    busy = true
    passwordHashProc.pw = password
    passwordHashProc.running = true
  }

  Process {
    id: passwordHashProc
    property string pw: ""
    command: ["bash", "-c", "printf '%s\\n' \"$PW\" | openssl passwd -6 -salt \"$(openssl rand -base64 16)\" -stdin"]
    environment: ({ PW: passwordHashProc.pw })
    stdout: StdioCollector {
      onStreamFinished: {
        var hash = text.trim()
        if (hash !== "" && hash.startsWith("$6$")) {
          writePersistProc.hash = hash
          writePersistProc.running = true
        } else {
          root.error = "Failed to hash password"
          root.busy = false
        }
      }
    }
  }

  Process {
    id: writePersistProc
    property string hash: ""
    command: ["pkexec", "sh", "-c", "printf '%s\\n' \"$HASH\" > /persist/passwd && chmod 600 /persist/passwd"]
    environment: ({ HASH: writePersistProc.hash })
    onRunningChanged: {
      if (!running) {
        if (exitCode === 0)
          root.writeUserConfig()
        else {
          root.error = "Failed to write /persist/passwd"
          root.busy = false
        }
      }
    }
  }

  function writeUserConfig() {
    var esc = root.bashEscape
    // ponytail: build _user.nix with username + monitor outputs for niri.nix
    var lines = []
    lines.push("{")
    lines.push("  name = \"" + esc(root.username) + "\";")
    lines.push("  timezone = \"" + esc(root.timezone) + "\";")
    lines.push("  outputs = {")
    for (var i = 0; i < root.monitorOutputs.length; i++) {
      var output = root.monitorOutputs[i]
      var mode = root.monitorModes[i] && root.monitorModes[i].length > 0 ? root.monitorModes[i][0].mode : "preferred"
      var pos = root.monitorPositions[i] || {x: 0, y: 0}
      var px = pos.x || 0
      var py = pos.y || 0
      var scale = parseFloat(root.monitorScales[i]) || 1.0
      lines.push("    \"" + esc(output) + "\" = {")
      lines.push("      mode = \"" + esc(mode) + "\";")
      lines.push("      position = _: { props = { x = " + px + "; y = " + py + "; }; };")
      lines.push("      scale = " + scale + ";")
      lines.push("    };")
    }
    lines.push("  };")
    lines.push("}")
    var nixContent = lines.join("\n")
    // ponytail: use heredoc to avoid quoting issues in the nix expression
    writeNixProc.cmd = "cat > '" + root.userConfigDir + "/_user.nix' <<'WIZARD_EOF'\n" + nixContent + "\nWIZARD_EOF\nprintf '%s\\n' \"" + esc(root.username) + "\" > '" + root.secretsDir + "/username'"
    writeFilesProc.running = true
  }

  Process {
    id: writeFilesProc
    command: ["bash", "-c", "mkdir -p '" + root.userConfigDir + "' && mkdir -p '" + root.secretsDir + "'"]
    onRunningChanged: {
      if (!running) {
        if (exitCode === 0)
          writeNixProc.running = true
        else {
          root.error = "Failed to create config directories"
          root.busy = false
        }
      }
    }
  }

  Process {
    id: writeNixProc
    property string cmd: ""
    command: ["bash", "-c", writeNixProc.cmd]
    onRunningChanged: {
      if (!running) {
        if (exitCode === 0) {
          root.done = true
          root.busy = false
        } else {
          root.error = "Failed to write user config"
          root.busy = false
        }
      }
    }
  }
}
