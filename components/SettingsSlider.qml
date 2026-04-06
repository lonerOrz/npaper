import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  height: 40
  width: parent ? parent.width : 300

  property alias text: label.text
  property real value: 0
  property real from: 0
  property real to: 100
  property real stepSize: 1
  
  signal userValueChanged(real val)

  RowLayout {
    anchors.fill: parent
    spacing: 10

    Text { id: label; Layout.fillWidth: true; color: "#cccccc"; font.pixelSize: 13; elide: Text.ElideRight }
    Text { id: valueDisplay; text: value.toFixed(stepSize < 1 ? 2 : 0); color: "#6a9eff"; font.pixelSize: 12; font.family: "monospace" }

    Slider {
      id: slider
      width: 120; Layout.alignment: Qt.AlignRight
      from: root.from; to: root.to; stepSize: root.stepSize
      value: root.value
      onMoved: root.userValueChanged(value)
      
      background: Rectangle {
        implicitWidth: 100; implicitHeight: 4
        color: "#444444"
        radius: 2
        Rectangle {
          width: slider.visualPosition * parent.width
          height: parent.height
          color: "#6a9eff"
          radius: 2
        }
      }
      handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        implicitWidth: 14; implicitHeight: 14
        radius: 7
        color: slider.pressed ? "#88b8ff" : "#6a9eff"
        border.color: "#ffffff"
        border.width: 2
      }
    }
  }
}
