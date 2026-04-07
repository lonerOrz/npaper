import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services

Item {
  id: root
  height: 40
  width: parent ? parent.width : 300

  property alias text: label.text
  property bool checked: false
  signal toggled(bool val)

  RowLayout {
    anchors.fill: parent
    spacing: 12

    Text {
      id: label
      Layout.fillWidth: true
      color: Color.mOnSurface
      font.pixelSize: 13
    }

    MouseArea {
      Layout.alignment: Qt.AlignRight
      width: 40
      height: 22
      onClicked: root.toggled(!root.checked)

      Rectangle {
        anchors.fill: parent
        radius: 11
        color: root.checked ? Color.mPrimary : Color.mSurfaceContainerHighest
        Behavior on color {
          ColorAnimation {
            duration: 200
          }
        }
      }

      Rectangle {
        id: toggle
        x: root.checked ? 20 : 2
        y: 2
        width: 18
        height: 18
        radius: 9
        color: Color.mInverseSurface
        Behavior on x {
          NumberAnimation {
            duration: 200
            easing.type: Easing.OutBack
            easing.overshoot: 2.0
          }
        }
      }
    }
  }
}
