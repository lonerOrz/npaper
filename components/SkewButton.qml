import QtQuick
import QtQuick.Shapes
import qs.utils

Shape {
  id: root
  property bool active: false
  property real skew: 12

  ShapePath {
    strokeWidth: 0
    fillColor: root.active ? Color.mPrimary : Color.mSurfaceContainerHighest
    Behavior on fillColor {
      ColorAnimation {
        duration: 150
      }
    }

    PathLine {
      x: root.skew
      y: 0
    }
    PathLine {
      x: root.width
      y: 0
    }
    PathLine {
      x: root.width - root.skew
      y: root.height
    }
    PathLine {
      x: 0
      y: root.height
    }
    PathLine {
      x: root.skew
      y: 0
    }
  }
}
