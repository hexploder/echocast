import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

// Loaded once per session (manifest keepLoaded:true). Polls the echocast
// CLI's `status` subcommand and exposes it as plain properties; every bar
// surface's Panel.qml reads the same instance via bar.shell.serviceFor(),
// so there's one poll loop and one source of truth regardless of how many
// monitors are showing the bar.
Item {
  id: root

  property var shell: null

  property bool backendChecked: false
  property bool backendInstalled: false

  property string role: ""
  property bool enabled: false
  property string state: ""
  property string device: "default"
  property string serverIp: ""
  property string serverUser: ""
  property int serverPort: 22
  property var clients: []
  property bool statusKnown: false

  readonly property string serverDisplay: serverIp === "" ? "" : (serverUser !== "" ? serverUser + "@" + serverIp : serverIp)
  readonly property string installCommand: "curl -fsSL https://raw.githubusercontent.com/hexploder/echocast/main/install.sh | bash"

  // Real output devices only (hardware/virtual sinks, not individual
  // playback streams), for the server role's device picker.
  readonly property var sinks: {
    var out = []
    var nodes = Pipewire.nodes ? Pipewire.nodes.values : []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && n.isSink && !n.isStream) {
        out.push({ value: n.name, label: n.description || n.nickname || n.name })
      }
    }
    return out
  }

  function refresh() { statusProc.running = true }

  // bash -lc for a login-shell PATH (so ~/.local/bin/echocast resolves
  // regardless of how quickshell itself was launched); args are passed
  // positionally via "$@" rather than interpolated into the script
  // string, so nothing here needs shell-escaping.
  function _run(args) {
    mutateProc.command = ["bash", "-lc", "exec echocast \"$@\"", "_"].concat(args)
    mutateProc.running = true
  }

  function setRole(r) { _run(["set-role", r]) }
  function setEnabled(v) { _run([role === "server" ? "server-set-enabled" : "client-set-enabled", v ? "true" : "false"]) }
  function setDevice(name) { _run(["server-set-device", name]) }
  function setServerIp(ip) { _run(["client-set-server", ip]) }

  Process {
    id: checkProc
    command: ["bash", "-lc", "command -v echocast"]
    onExited: function(exitCode) {
      root.backendInstalled = exitCode === 0
      root.backendChecked = true
      if (root.backendInstalled) root.refresh()
    }
  }

  Process {
    id: statusProc
    command: ["bash", "-lc", "exec echocast status"]
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      try {
        var data = JSON.parse(statusOutput.text)
        root.role = data.role || ""
        root.enabled = data.enabled === true
        root.state = data.state || ""
        root.device = data.device || "default"
        root.serverIp = data.server_ip || ""
        root.serverUser = data.server_user || ""
        root.serverPort = data.server_port || 22
        root.clients = data.clients || []
        root.statusKnown = true
      } catch (e) {
        // Transient (empty/partial stdout mid-write) — next poll recovers.
      }
    }
  }

  Process {
    id: mutateProc
    onExited: function() { root.refresh() }
  }

  Component.onCompleted: checkProc.running = true

  Timer {
    interval: 2000
    running: root.backendInstalled
    repeat: true
    onTriggered: root.refresh()
  }
}
