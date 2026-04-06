import QtQuick
import QtQuick.Controls

Row {
  id: root

  required property var model
  required property string activeFolder
  property real tabHeight: 32
  property string activeColor: "#ffffff"
  property string inactiveColor: "#aaaaaa"

  signal folderClicked(string folder)

  spacing: 4

  Repeater {
    model: root.model
    delegate: Item {
      required property string modelData
      property bool active: root.activeFolder === modelData

      width: tabText.implicitWidth + (active ? 24 : 12)
      height: root.tabHeight

      Rectangle {
        anchors.fill: parent
        radius: 6
        color: active ? root.activeColor : "transparent"
        visible: active
      }

      Text {
        id: tabText
        anchors.centerIn: parent
        text: modelData
        color: active ? "#000000" : root.inactiveColor
        font.pixelSize: 13
        font.weight: active ? Font.DemiBold : Font.Normal
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.folderClicked(modelData)
      }
    }
  }
}
