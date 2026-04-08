import QtQuick
import QtQuick.Controls
import qs.services

/*
* SettingsSlider — labeled slider with value display.
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
  spacing: Style.spaceS

  property string label: ""
  property real value: 0
  property real min: 0.0
  property real max: 1.0
  property real step: 0.05
  signal commit(real val)

  Row {
    width: parent.width
    spacing: Style.spaceM

    Text {
      width: parent.width - 48
      text: root.label
      color: Color.mOutline
      font.pixelSize: Style.fontXS
      font.weight: Font.Medium
      font.letterSpacing: 1
    }

    Text {
      width: 40
      color: Color.mPrimary
      font.pixelSize: Style.barSearchInputFontSize
      font.family: "monospace"
      horizontalAlignment: Text.AlignRight
      text: root.value.toFixed(root.step < 1 ? 2 : 0)
    }
  }

  Slider {
    id: slider
    width: parent.width
    from: root.min
    to: root.max
    stepSize: root.step
    value: root.value
    onPressedChanged: if (!pressed) root.commit(value)

    background: Rectangle {
      implicitHeight: 3
      color: Color.mSurfaceContainerHighest
      radius: 2
      Rectangle {
        width: parent.visualPosition * parent.width
        height: parent.height
        color: Color.mPrimary
        radius: 2
      }
    }
    handle: Rectangle {
      x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
      y: parent.topPadding + parent.availableHeight / 2 - height / 2
      implicitWidth: 12
      implicitHeight: 12
      radius: 6
      color: Color.mPrimary
    }
  }
}
