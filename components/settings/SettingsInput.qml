import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services

Item {
  id: root
  height: 36
  width: parent ? parent.width : 300

  property alias text: label.text
  property alias label: label.text
  property real value: 0
  property real min: 0
  property real max: 100
  property real step: 1

  signal commit(real val)

  property bool _updating: false

  Component.onCompleted: {
    var fmt = step < 1 ? 2 : 0;
    input.text = value.toFixed(fmt);
  }

  onValueChanged: {
    if (_updating) return;
    _updating = true;
    var fmt = step < 1 ? 2 : 0;
    input.text = value.toFixed(fmt);
    _updating = false;
  }

  RowLayout {
    anchors.fill: parent
    spacing: 10

    Text {
      id: label
      Layout.fillWidth: true
      color: Color.mOnSurface
      font.pixelSize: 12
    }

    TextInput {
      id: input
      Layout.preferredWidth: 72
      Layout.alignment: Qt.AlignRight
      color: Color.mPrimary
      font.pixelSize: 12
      font.family: "monospace"
      horizontalAlignment: Text.AlignRight
      text: root.value.toFixed(root.step < 1 ? 2 : 0)

      onEditingFinished: {
        var val = parseFloat(text);
        if (!isNaN(val)) {
          val = Math.max(root.min, Math.min(root.max, val));
          root.commit(val);
        }
        text = root.value.toFixed(root.step < 1 ? 2 : 0);
      }
    }

    Slider {
      Layout.fillWidth: true
      from: root.min
      to: root.max
      stepSize: root.step
      value: root.value
      onMoved: {
        if (_updating) return;
        input.text = value.toFixed(root.step < 1 ? 2 : 0);
        root.commit(value);
      }

      background: Rectangle {
        implicitHeight: 3
        color: Color.mSurfaceContainer
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
}
