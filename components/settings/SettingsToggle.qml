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
Item {
  id: root
  width: parent ? parent.width : 300
  height: Style.settingsTabHeight

  property string text: ""
  property bool checked: false
  signal toggled(bool val)

  // Background hover
  Rectangle {
    anchors.fill: parent
    radius: Style.radiusM
    color: hoverArea.containsMouse ? Qt.lighter(Color.mSurfaceContainer, 1.08) : "transparent"
    opacity: 0.6
    Behavior on color { ColorAnimation { duration: Style.animFast } }
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: Style.spaceM
    anchors.rightMargin: Style.spaceM
    spacing: Style.spaceM

    Text {
      width: parent.width - 44
      text: root.text
      color: Color.mOnSurface
      font.pixelSize: Style.fontS
      font.weight: Font.Medium
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }

    // Toggle switch
    Item {
      width: 32
      height: 16
      anchors.verticalCenter: parent.verticalCenter

      // Track
      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Color.mPrimary : Color.mSurfaceContainerHighest
        border.width: root.checked ? 0 : 1
        border.color: Color.mOutline
        opacity: root.checked ? 1.0 : 0.7
        Behavior on color { ColorAnimation { duration: Style.animFast } }
      }

      // Knob
      Rectangle {
        width: 10
        height: 10
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3
        radius: height / 2
        color: Color.mInverseSurface
        opacity: 0.95
        Behavior on x { NumberAnimation { duration: Style.animFast; easing.type: Easing.OutCubic } }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
      }
    }
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled(!root.checked)
  }
}
