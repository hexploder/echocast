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
  readonly property var service: root.bar && root.bar.shell ? root.bar.shell.serviceFor("io.github.hexploder.echocast") : null
  readonly property bool backendInstalled: root.service ? root.service.backendInstalled : true
  readonly property string role: root.service ? root.service.role : ""
  readonly property bool passthroughEnabled: root.service ? root.service.passthroughEnabled : false
  readonly property string streamState: root.service ? root.service.streamState : ""

  readonly property string tooltip: {
    if (!root.backendInstalled) return "Echocast · not installed yet, click to see how"
    if (root.role !== "server" && root.role !== "client") return "Echocast · click to set up"
    if (!root.passthroughEnabled) return "Echocast · off"
    if (root.role === "server") return "Echocast · server, sharing " + (root.service ? root.service.device : "default")
    return "Echocast · " + (root.streamState === "redirect" ? "streaming to " + (root.service ? root.service.serverDisplay : "") : "playing locally")
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
    dimmed: !root.backendInstalled || root.role === "" || !root.passthroughEnabled
    tooltipText: root.tooltip

    onPressed: function(b) {
      if (b === Qt.LeftButton) root.togglePanel()
    }
  }
}
