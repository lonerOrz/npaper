import QtQuick
import QtQuick.Controls
import qs.services

Column {
  id: root
  width: parent ? parent.width : 300
  spacing: Style.spaceM

  property string label: ""
  property real value: 0.0
  property real min: 0.0
  property real max: 1.0
  property real step: 0.05
  signal commit(real val)

  Row {
    width: parent.width
    spacing: Style.spaceM

    Text {
      width: Math.max(10, parent.width - 64)
      text: root.label
      color: Color.mOnSurface
      font.pixelSize: Style.fontS
      font.weight: Font.Medium
      verticalAlignment: Text.AlignVCenter
    }

    Rectangle {
      width: valueText.implicitWidth + Style.spaceL * 2
      height: Style.fontS + 6
      radius: height / 2
      color: Color.mPrimary
      opacity: 0.15

      Text {
        id: valueText
        anchors.centerIn: parent
        color: Color.mPrimary
        font.pixelSize: Style.fontXS
        font.family: "monospace"
        font.weight: Font.Bold
        text: slider.value.toFixed(root.step < 1 ? 2 : 0)
      }
    }
  }

  Slider {
    id: slider
    width: parent.width
    from: root.min
    to: root.max
    stepSize: root.step

    Binding {
      target: slider
      property: "value"
      value: root.value
      when: !slider.pressed
    }

    onMoved: {
      root.commit(slider.value);
    }

    background: Item {
      implicitHeight: 6
      y: (parent.height - height) / 2

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Color.mSurfaceContainerHighest.r, Color.mSurfaceContainerHighest.g, Color.mSurfaceContainerHighest.b, Style.childBgAlpha)
        radius: 3
        opacity: 0.8
      }

      Rectangle {
        width: Math.max(0, Math.min(1.0, slider.visualPosition)) * parent.width
        height: parent.height
        color: Color.mPrimary
        radius: 3

        gradient: Gradient {
          GradientStop {
            position: 0.0
            color: Qt.lighter(Color.mPrimary, 1.2)
          }
          GradientStop {
            position: 1.0
            color: Color.mPrimary
          }
        }
      }
    }

    handle: Item {
      x: parent.leftPadding + slider.visualPosition * (parent.availableWidth - width)
      y: parent.topPadding + parent.availableHeight / 2 - height / 2
      implicitWidth: 18
      implicitHeight: 18

      Rectangle {
        anchors.centerIn: parent
        width: slider.pressed ? 22 : 16
        height: slider.pressed ? 22 : 16
        radius: height / 2
        color: Color.mPrimary
        opacity: slider.pressed ? 0.22 : (slider.hovered ? 0.12 : 0.0)

        Behavior on width {
          NumberAnimation {
            duration: Style.animFast
            easing.type: Easing.OutCubic
          }
        }
        Behavior on height {
          NumberAnimation {
            duration: Style.animFast
            easing.type: Easing.OutCubic
          }
        }
        Behavior on opacity {
          NumberAnimation {
            duration: Style.animFast
          }
        }
      }

      Rectangle {
        anchors.centerIn: parent
        width: 12
        height: 12
        radius: 6
        color: slider.pressed ? Qt.lighter(Color.mPrimary, 1.15) : Color.mPrimary
        border.width: 2
        border.color: Color.mSurface

        Rectangle {
          anchors.fill: parent
          anchors.verticalCenterOffset: 1
          radius: parent.radius
          color: Color.mShadow
          opacity: 0.2
          z: -1
        }

        Behavior on color {
          ColorAnimation {
            duration: Style.animFast
          }
        }
      }
    }
  }
}
