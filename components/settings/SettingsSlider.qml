import QtQuick
import QtQuick.Controls
import qs.services

/*
* SettingsSlider — labeled slider with value display.
* Redesigned with refined aesthetics and smooth interactions.
*
* Usage:
*   SettingsSlider {
*     width: parent.width
*     label: "Opacity"
*     value: root.opacity
*     min: 0.0
*     max: 1.0
*     step: 0.05
*     onCommit: function (v) { root._emit("opacity", v) }
*   }
*/
Column {
  id: root
  width: parent ? parent.width : 300
  spacing: Style.spaceL

  property string label: ""
  property real value: 0
  property real min: 0.0
  property real max: 1.0
  property real step: 0.05
  signal commit(real val)

  // Header row with label and value
  Row {
    width: parent.width
    spacing: Style.spaceM

    Text {
      width: parent.width - 56
      text: root.label
      color: Color.mOnSurface
      font.pixelSize: Style.fontS
      font.weight: Font.Medium
      verticalAlignment: Text.AlignVCenter
    }

    // Value badge - refined pill design
    Rectangle {
      width: valueText.implicitWidth + Style.spaceXXL
      height: Style.fontS + 4
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
        text: root.value.toFixed(root.step < 1 ? 2 : 0)
      }
    }
  }

  Slider {
    id: slider
    width: parent.width
    from: root.min
    to: root.max
    stepSize: root.step
    value: root.value

    // Commit on release
    onValueChanged: {
      if (slider.pressed) {
        root.commit(value);
      }
    }

    background: Item {
      implicitHeight: 8
      y: (parent.height - height) / 2

      // Track groove
      Rectangle {
        anchors.fill: parent
        anchors.verticalCenterOffset: 0
        color: Color.mSurfaceContainerHighest
        radius: 4
        opacity: 0.8
      }

      // Track progress fill
      Rectangle {
        width: parent.visualPosition * parent.width
        height: parent.height
        color: Color.mPrimary
        radius: 4

        // Smooth gradient
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
      x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
      y: parent.topPadding + parent.availableHeight / 2 - height / 2
      implicitWidth: 20
      implicitHeight: 20

      // Outer glow ring (expands on hover)
      Rectangle {
        anchors.centerIn: parent
        width: slider.pressed ? 24 : 18
        height: slider.pressed ? 24 : 18
        radius: height / 2
        color: Color.mPrimary
        opacity: slider.pressed ? 0.2 : 0.12

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
      }

      // Main handle circle
      Rectangle {
        anchors.centerIn: parent
        width: 12
        height: 12
        radius: 6
        color: slider.pressed ? Qt.lighter(Color.mPrimary, 1.1) : Color.mPrimary
        border.width: 2
        border.color: Color.mSurface

        // Subtle shadow
        Rectangle {
          anchors.fill: parent
          anchors.verticalCenterOffset: 2
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
