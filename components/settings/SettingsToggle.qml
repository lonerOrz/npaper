import QtQuick
import qs.services

Item {
  id: root
  width: parent ? parent.width : 300
  height: Style.settingsTabHeight

  property string text: ""
  property bool checked: false
  signal toggled(bool val)

  Rectangle {
    anchors.fill: parent
    radius: Style.radiusS
    color: mainHoverArea.containsMouse ? Qt.rgba(Color.mSurfaceContainerHigh.r, Color.mSurfaceContainerHigh.g, Color.mSurfaceContainerHigh.b, Style.childHoverAlpha) : "transparent"
    Behavior on color {
      ColorAnimation {
        duration: Style.animFast
      }
    }
  }

  Text {
    anchors.left: parent.left
    anchors.leftMargin: Style.spaceM
    anchors.right: toggleTrack.left
    anchors.rightMargin: Style.spaceM
    anchors.verticalCenter: parent.verticalCenter
    text: root.text
    color: root.checked ? Color.mOnSurface : Color.mOnSurfaceVariant
    font.pixelSize: Style.fontS
    font.weight: root.checked ? Font.Medium : Font.Normal
    elide: Text.ElideRight

    Behavior on color {
      ColorAnimation {
        duration: Style.animFast
      }
    }
  }

  Rectangle {
    id: toggleTrack
    width: 34
    height: 18
    anchors.right: parent.right
    anchors.rightMargin: Style.spaceM
    anchors.verticalCenter: parent.verticalCenter
    radius: height / 2

    color: root.checked ? Color.mPrimary : Qt.rgba(Color.mSurfaceContainerHighest.r, Color.mSurfaceContainerHighest.g, Color.mSurfaceContainerHighest.b, Style.childBgAlpha)
    border.width: root.checked ? 0 : 1
    border.color: root.checked ? "transparent" : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.4)

    Behavior on color {
      ColorAnimation {
        duration: Style.animFast
      }
    }
    Behavior on border.color {
      ColorAnimation {
        duration: Style.animFast
      }
    }

    Rectangle {
      id: knob
      width: 12
      height: 12
      anchors.verticalCenter: parent.verticalCenter
      radius: 6
      x: root.checked ? (parent.width - width - 3) : 3

      color: root.checked ? Color.mSurfaceContainerLowest : Color.mOutline
      scale: mainHoverArea.containsMouse ? 1.08 : 1.0

      Behavior on x {
        NumberAnimation {
          duration: 180
          easing.type: Easing.OutBack
          easing.overshoot: 1.15
        }
      }
      Behavior on scale {
        NumberAnimation {
          duration: Style.animFast
        }
      }
      Behavior on color {
        ColorAnimation {
          duration: Style.animFast
        }
      }
    }
  }

  MouseArea {
    id: mainHoverArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled(!root.checked)
  }
}
