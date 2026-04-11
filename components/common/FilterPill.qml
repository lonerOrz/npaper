import QtQuick
import qs.services

/* FilterPill — rounded pill toggle button (npaper style).
* Enhanced with gradient, glow, and scale animation.
*/
MouseArea {
  id: root

  property string label: ""
  property bool active: false

  width: labelText.implicitWidth + Style.spaceXXXL
  height: Style.barSearchHeight
  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
  hoverEnabled: true

  // Scale animation on hover
  scale: enabled && containsMouse ? 1.05 : 1.0
  Behavior on scale {
    NumberAnimation {
      duration: Style.animFast
      easing.type: Easing.OutCubic
    }
  }

  // Background pill
  Rectangle {
    anchors.fill: parent
    anchors.margins: -2
    radius: height / 2
    color: root.active ? Color.mPrimary : "transparent"
    opacity: root.active ? 0.2 : 0
    Behavior on opacity {
      NumberAnimation {
        duration: Style.animFast
      }
    }
  }

  // Main pill body
  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: {
      function toRgba(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
      }
      if (!enabled)
        return toRgba(Color.mSurfaceContainer, Style.childBgAlpha);
      if (root.active)
        return toRgba(Color.mPrimary, 0.7);
      if (containsMouse)
        return toRgba(Color.mSurfaceContainerHigh, Style.childHoverAlpha);
      return toRgba(Color.mSurfaceContainer, Style.childBgAlpha);
    }
    border.width: root.active ? 0 : 1
    border.color: containsMouse ? Color.mPrimaryContainer : Qt.rgba(Color.mOutlineVariant.r, Color.mOutlineVariant.g, Color.mOutlineVariant.b, Style.childBgAlpha)
    opacity: !enabled ? 0.5 : 1.0

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
      if (!enabled)
        return Qt.rgba(Color.mOutlineVariant.r, Color.mOutlineVariant.g, Color.mOutlineVariant.b, 0.5);
      if (root.active)
        return Color.mSurfaceContainerLowest;
      return containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant;
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
