import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.hexploder.echocast"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property var service: bar && bar.shell ? bar.shell.serviceFor("io.github.hexploder.echocast") : null
  readonly property bool backendInstalled: service ? service.backendInstalled : true
  readonly property string role: service ? service.role : ""
  readonly property bool enabled: service ? service.enabled : false
  readonly property string state: service ? service.state : ""

  readonly property string tooltip: {
    if (!backendInstalled) return "Echocast · not installed yet, click to see how"
    if (role !== "server" && role !== "client") return "Echocast · click to set up"
    if (!enabled) return "Echocast · off"
    if (role === "server") return "Echocast · server, sharing " + (service ? service.device : "default")
    return "Echocast · " + (state === "redirect" ? "streaming to " + (service ? service.serverDisplay : "") : "playing locally")
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰝚"
    dimmed: !backendInstalled || role === "" || !enabled
    tooltipText: root.tooltip

    onPressed: function(b) {
      if (b === Qt.LeftButton) root.togglePanel()
    }
  }
}
