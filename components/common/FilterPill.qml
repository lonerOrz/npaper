import QtQuick
import qs.services

MouseArea {
  id: root

  property string label: ""
  property bool active: false

  implicitWidth: labelText.implicitWidth + Style.spaceXXXL
  implicitHeight: Style.barSearchHeight
  width: implicitWidth
  height: implicitHeight

  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
  hoverEnabled: true

  function _colorWithAlpha(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a);
  }

  Item {
    id: pillVisual
    anchors.fill: parent

    scale: {
      if (!root.enabled)
        return 1.0;
      if (root.pressed)
        return 0.95;
      if (root.containsMouse)
        return 1.04;
      return 1.0;
    }

    Behavior on scale {
      NumberAnimation {
        duration: Style.animFast
        easing.type: Easing.OutCubic
      }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: -2
      radius: height / 2
      color: root.active ? Color.mPrimary : "transparent"
      opacity: root.active ? 0.22 : 0.0
      Behavior on opacity {
        NumberAnimation {
          duration: Style.animFast
        }
      }
    }

    Rectangle {
      id: bodyRect
      anchors.fill: parent
      radius: height / 2
      opacity: !root.enabled ? 0.45 : 1.0

      color: {
        if (!root.enabled)
          return root._colorWithAlpha(Color.mSurfaceContainer, Style.childBgAlpha);
        if (root.active)
          return root._colorWithAlpha(Color.mPrimary, 0.75);
        if (root.containsMouse)
          return root._colorWithAlpha(Color.mSurfaceContainerHigh, Style.childHoverAlpha);
        return root._colorWithAlpha(Color.mSurfaceContainer, Style.childBgAlpha);
      }

      border.width: root.active ? 0 : 1
      border.color: root.containsMouse ? Color.mPrimaryContainer : root._colorWithAlpha(Color.mOutlineVariant, Style.childBgAlpha)

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
    }

    Text {
      id: labelText
      anchors.centerIn: parent
      text: root.label
      color: {
        if (!root.enabled)
          return root._colorWithAlpha(Color.mOutlineVariant, 0.5);
        if (root.active)
          return Color.mSurfaceContainerLowest;
        return root.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant;
      }
      font.pixelSize: Style.barTabFontSize
      font.weight: root.active ? Font.Bold : Font.Medium
      Behavior on color {
        ColorAnimation {
          duration: Style.animFast
        }
      }
    }
  }
}
