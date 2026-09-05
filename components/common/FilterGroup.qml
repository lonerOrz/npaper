import QtQuick
import QtQuick.Layouts
import qs.services

Item {
  id: root

  required property string label
  default property alias content: pillRow.data

  implicitWidth: pillRow.implicitWidth + Style.spaceM * 2
  implicitHeight: Style.barSearchHeight + Style.spaceM
  width: implicitWidth
  height: implicitHeight

  Rectangle {
    anchors.fill: parent
    radius: Style.barRadius
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: Qt.rgba(Qt.lighter(Color.mSurfaceContainerLow, 1.03).r, Qt.lighter(Color.mSurfaceContainerLow, 1.03).g, Qt.lighter(Color.mSurfaceContainerLow, 1.03).b, Style.childBgAlpha)
      }
      GradientStop {
        position: 1.0
        color: Qt.rgba(Color.mSurfaceContainerLow.r, Color.mSurfaceContainerLow.g, Color.mSurfaceContainerLow.b, Style.childBgAlpha)
      }
    }
    border.width: 1
    border.color: Qt.rgba(Color.mOutlineVariant.r, Color.mOutlineVariant.g, Color.mOutlineVariant.b, Style.childBgAlpha * 0.5)
    opacity: 0.85
  }

  Row {
    id: pillRow
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: Style.spaceM
    spacing: Style.spaceS
    layoutDirection: Qt.LeftToRight

    Item {
      height: Style.barSearchHeight
      width: labelText.implicitWidth + Style.spaceM * 2

      Text {
        id: labelText
        anchors.left: parent.left
        anchors.leftMargin: Style.spaceXS
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.pixelSize: Style.fontXXS
        font.weight: Font.Bold
        font.letterSpacing: 1.5
        color: Color.mOutline
      }

      Rectangle {
        anchors.left: labelText.left
        anchors.top: labelText.bottom
        anchors.topMargin: 2
        width: labelText.contentWidth
        height: 1
        color: Color.mOutlineVariant
        opacity: 0.35
      }

      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 14
        color: Color.mOutlineVariant
        opacity: 0.25
      }
    }
  }
}
