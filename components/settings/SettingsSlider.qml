import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services

Item {
  id: root
  height: 48
  width: parent ? parent.width : 300

  property alias text: label.text
  property real value: 0
  property real from: 0
  property real to: 100
  property real stepSize: 1

  signal userValueChanged(real val)

  RowLayout {
    anchors.fill: parent
    spacing: 16

    Text {
      id: label
      Layout.fillWidth: true
      color: Color.mOnSurface
      font.pixelSize: 13
      elide: Text.ElideRight
    }

    Text {
      id: valueDisplay
      text: value.toFixed(stepSize < 1 ? 1 : 0)
      color: Color.mPrimary
      font.pixelSize: 13
      font.family: "monospace"
    }

    Slider {
      id: slider
      width: 120
      Layout.alignment: Qt.AlignRight
      from: root.from
      to: root.to
      stepSize: root.stepSize
      value: root.value
      onMoved: root.userValueChanged(value)

      background: Rectangle {
        implicitWidth: 120
        implicitHeight: 4
        color: Color.mSurfaceContainer
        radius: 2
        Rectangle {
          width: slider.visualPosition * parent.width
          height: parent.height
          color: Color.mPrimary
          radius: 2
        }
      }
      handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        implicitWidth: 16
        implicitHeight: 16
        radius: 8
        color: slider.pressed ? Color.mPrimaryFixed : Color.mPrimary
        border.color: Color.mInverseSurface
        border.width: 2
        scale: slider.pressed ? 1.1 : 1.0
        Behavior on scale {
          NumberAnimation {
            duration: 100
          }
        }
      }
    }
  }
}
