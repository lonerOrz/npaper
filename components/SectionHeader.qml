import QtQuick

Item {
  id: root
  height: 30
  width: parent ? parent.width : 300

  property alias text: title.text

  Text {
    id: title
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    color: "#6a9eff"
    font.pixelSize: 12
    font.bold: true
    font.letterSpacing: 1
    text: "SECTION"
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 1
    color: "#333333"
  }
}
