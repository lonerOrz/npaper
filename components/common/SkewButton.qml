import QtQuick
import QtQuick.Shapes
import qs.services

Item {
  id: root
  implicitWidth: textEl.implicitWidth + skew * 2
  implicitHeight: 24

  property string text: ""
  property bool active: false
  property real skew: 12
  property int fontSize: 10

  Shape {
    anchors.fill: parent

    ShapePath {
      strokeWidth: 0
      fillColor: root.active ? Color.mPrimary : Color.mSurfaceContainerHighest
      Behavior on fillColor {
        ColorAnimation { duration: 150 }
      }

      startX: root.skew
      startY: 0
      PathLine { x: root.width; y: 0 }
      PathLine { x: root.width - root.skew; y: root.height }
      PathLine { x: 0; y: root.height }
      PathLine { x: root.skew; y: 0 }
    }
  }

  Text {
    id: textEl
    anchors.centerIn: parent
    text: root.text
    color: root.active ? Color.mSurfaceContainerLowest : Color.mOnSurfaceVariant
    font.pixelSize: root.fontSize
    font.weight: Font.Medium
  }
}
