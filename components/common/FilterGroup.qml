import QtQuick
import QtQuick.Layouts
import qs.services

/* FilterGroup — labeled container for a row of filter pills. */
Item {
  id: root

  required property string label
  default property alias content: rowLayout.data

  height: rowLayout.implicitHeight + Style.spaceM
  width: rowLayout.implicitWidth + Style.spaceL

  Rectangle {
    anchors.fill: parent
    radius: Style.barRadius
    color: Color.mSurfaceContainerLow
  }

  RowLayout {
    id: rowLayout
    anchors.verticalCenter: parent.verticalCenter
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.spaceS

    Text {
      text: root.label
      font.pixelSize: Style.fontXXS
      font.weight: Font.Bold
      color: Color.mOutline
    }
  }
}
