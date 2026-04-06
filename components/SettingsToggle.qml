import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  height: 40
  width: parent ? parent.width : 300

  property alias text: label.text
  property bool checked: false
  signal toggled(bool val)

  RowLayout {
    anchors.fill: parent
    spacing: 10

    Text {
      id: label
      Layout.fillWidth: true
      color: "#cccccc"
      font.pixelSize: 13
      elide: Text.ElideRight
    }

    Switch {
      id: toggle
      Layout.alignment: Qt.AlignRight
      checked: root.checked
      palette.midlight: "#4a9eff"
      // Use onToggled (Qt6) or onCheckStateChanged
      onToggled: root.toggled(checked)
    }
  }
}
