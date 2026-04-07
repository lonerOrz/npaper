import QtQuick
import qs.services

/* FilterPill — rounded pill toggle button (npaper style). */
MouseArea {
  id: root

  property string label: ""
  property bool active: false
  property bool hovered: false
  property bool enabled: true  // MouseArea has built-in enabled, but we expose for clarity

  width: labelText.implicitWidth + Style.spaceXXXL
  height: Style.barSearchHeight
  cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
  hoverEnabled: true
  onContainsMouseChanged: root.hovered = containsMouse

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: !root.enabled ? Color.mSurfaceContainer : (root.active ? Color.mPrimary : (root.hovered ? Color.mSurfaceContainerHigh : Color.mSurfaceContainer))
    Behavior on color { ColorAnimation { duration: Style.animFast } }
  }

  Text {
    id: labelText
    anchors.centerIn: parent
    text: root.label
    color: !root.enabled ? Color.mOutline : (root.active ? Color.mSurfaceContainerLowest : Color.mOutlineVariant)
    font.pixelSize: Style.barTabFontSize
    font.weight: Font.Medium
  }
}
