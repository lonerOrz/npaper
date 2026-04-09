import QtQuick
import QtQuick.Layouts
import qs.services

/* FilterGroup — labeled container for a row of filter pills.
* Enhanced with gradient background and subtle border.
*/
Item {
  id: root

  required property string label
  default property alias content: pillRow.data

  // Explicit dimensions
  height: Style.barSearchHeight + Style.spaceM
  width: pillRow.implicitWidth + Style.spaceXXL

  // Background with subtle gradient
  Rectangle {
    anchors.fill: parent
    radius: Style.barRadius
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: Qt.lighter(Color.mSurfaceContainerLow, 1.03)
      }
      GradientStop {
        position: 1.0
        color: Color.mSurfaceContainerLow
      }
    }
    border.width: 1
    border.color: Qt.tint(Color.mOutlineVariant, Color.mSurfaceContainerLow)
    opacity: 0.8
  }

  Row {
    id: pillRow
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: Style.spaceM
    anchors.right: parent.right
    anchors.rightMargin: Style.spaceM
    spacing: Style.spaceS
    layoutDirection: Qt.LeftToRight

    // Label with underline
    Item {
      height: Style.barSearchHeight
      width: labelText.implicitWidth + Style.spaceM

      Text {
        id: labelText
        anchors.centerIn: parent
        text: root.label
        font.pixelSize: Style.fontXXS
        font.weight: Font.Bold
        font.letterSpacing: 1.5
        color: Color.mOutline
      }

      Rectangle {
        anchors.horizontalCenter: labelText.horizontalCenter
        anchors.top: labelText.bottom
        anchors.topMargin: 2
        width: labelText.contentWidth
        height: 1
        color: Color.mOutlineVariant
        opacity: 0.3
      }
    }
  }
}
