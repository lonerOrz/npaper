import QtQuick
import qs.utils

Item {
  id: root
  height: 24
  width: parent ? parent.width : 300

  property alias text: title.text

  Text {
    id: title
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    color: Color.mPrimary
    font.pixelSize: 11
    font.bold: true
    font.letterSpacing: 0.8
  }
}
