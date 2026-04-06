import QtQuick
import QtQuick.Shapes

Shape {
    id: root
    property bool isActive: false
    property real skew: 12
    property var colors

    ShapePath {
        strokeWidth: 0
        fillColor: root.isActive ? "#6a9eff" : "#333333"
        
        PathLine { x: root.skew; y: 0 }
        PathLine { x: root.width; y: 0 }
        PathLine { x: root.width - root.skew; y: root.height }
        PathLine { x: 0; y: root.height }
        PathLine { x: root.skew; y: 0 }
    }
}
