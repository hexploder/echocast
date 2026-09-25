import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.hexploder.echocast"
  ipcTarget: "io.github.hexploder.echocast"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor("io.github.hexploder.echocast") : null
  readonly property bool backendInstalled: service ? service.backendInstalled : true
  readonly property bool backendChecked: service ? service.backendChecked : false
  readonly property string role: service ? service.role : ""
  readonly property bool enabled: service ? service.enabled : false
  readonly property string streamState: service ? service.state : ""
  readonly property var sinks: service ? service.sinks : []
  readonly property var deviceOptions: [{ value: "default", label: "Default" }].concat(root.sinks)

  // The field's text is set imperatively (below), not bound to the
  // service, so typing never fights the poll loop; reopening the popup
  // refreshes it to whatever the service last knew.
  onOpenedChanged: if (opened && service) serverField.text = service.serverDisplay

  PopupCard {
    id: card
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.barIdentity
    open: root.opened
    contentWidth: card.fittedContentWidth(Style.space(280))
    contentHeight: card.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      width: parent.width
      spacing: Style.space(12)

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: "Echocast"
        color: root.barForeground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.bold: true
        font.pixelSize: Style.font.subtitle
      }

      Column {
        visible: root.backendChecked && !root.backendInstalled
        width: parent.width
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          text: "The backend isn't installed on this machine yet. Open a terminal and run:"
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        TextEdit {
          width: parent.width
          text: root.service ? root.service.installCommand : ""
          color: root.barForeground
          font.family: "monospace"
          font.pixelSize: Style.font.caption
          wrapMode: Text.WrapAnywhere
          readOnly: true
          selectByMouse: true
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Then reopen this panel — it picks the backend up automatically, no reload needed."
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Column {
        visible: root.backendInstalled && root.role !== "server" && root.role !== "client"
        width: parent.width
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Set what this machine does: shares its own speakers (server), or sends its audio to a server (client)."
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        Button {
          width: parent.width
          text: "This is the server (has the speakers)"
          onClicked: if (root.service) root.service.setRole("server")
        }

        Button {
          width: parent.width
          text: "This is the client (sends its audio)"
          onClicked: if (root.service) root.service.setRole("client")
        }
      }

      Column {
        visible: root.backendInstalled && root.role === "client"
        width: parent.width
        spacing: Style.space(8)

        Toggle {
          width: parent.width
          label: "Passthrough"
          description: root.streamState === "redirect"
            ? "Streaming to " + (root.service ? root.service.serverDisplay : "")
            : "Playing locally"
          checked: root.enabled
          foreground: root.barForeground
          onClicked: if (root.service) root.service.setEnabled(!root.enabled)
        }

        Text {
          textFormat: Text.PlainText
          text: "Server (user@ip)"
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        TextField {
          id: serverField
          width: parent.width
          placeholderText: "user@192.168.1.50"
          foreground: root.barForeground
          onEditingFinished: if (root.service) root.service.setServerIp(text)
        }
      }

      Column {
        visible: root.backendInstalled && root.role === "server"
        width: parent.width
        spacing: Style.space(8)

        Toggle {
          width: parent.width
          label: "Share this device"
          description: root.service && root.service.clients.length > 0
            ? root.service.clients.length + " client(s) registered"
            : "No clients registered — run: echocast add-client"
          checked: root.enabled
          foreground: root.barForeground
          onClicked: if (root.service) root.service.setEnabled(!root.enabled)
        }

        Dropdown {
          width: parent.width
          label: "Output device"
          value: root.service ? root.service.device : "default"
          options: root.deviceOptions
          foreground: root.barForeground
          onChanged: function(v) { if (root.service) root.service.setDevice(v) }
        }
      }
    }
  }
}
