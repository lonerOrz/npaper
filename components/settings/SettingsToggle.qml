import QtQuick
import qs.services

/*
* SettingsToggle — labeled toggle switch with animated knob.
*
* Usage:
*   SettingsToggle {
*     width: parent.width
*     text: "Border Glow"
*     checked: root.showBorderGlow
*     onToggled: function (val) { root._emit("showBorderGlow", val) }
*   }
*/
Row {
  id: root
  width: parent ? parent.width : 300
  height: Style.settingsTabHeight
  spacing: Style.spaceM

  property string text: ""
  property bool checked: false
  signal toggled(bool val)

  Text {
    width: parent.width - 48
    text: root.text
    color: Color.mOnSurface
    font.pixelSize: Style.fontS
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }

  Item {
    width: 40
    height: 20
    anchors.verticalCenter: parent.verticalCenter

    // Track
    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: root.checked ? Color.mPrimary : Color.mSurfaceContainerHighest
      border.width: 1
      border.color: root.checked ? Color.mPrimary : Color.mOutline
      opacity: root.checked ? 1.0 : 0.6
      Behavior on color {
        ColorAnimation {
          duration: Style.animFast
        }
      }
    }

    // Knob
    Rectangle {
      width: 16
      height: 14
      anchors.verticalCenter: parent.verticalCenter
      x: root.checked ? parent.width - width - 2 : 2
      radius: height / 2
      color: Color.mInverseSurface
      Behavior on x {
        NumberAnimation {
          duration: Style.animFast
          easing.type: Easing.OutCubic
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggled(!root.checked)
    }
  }
}
