import QtQuick
import QtQuick.Layouts
import qs.services

Item {
  id: root

  property var model: []
  property int activeIndex: 0
  property color activeColor: Color.mPrimary
  property bool hasBg: true

  signal selected(int index, string label)

  property real _pillX: 0
  property real _pillW: 0

  implicitWidth: _row.implicitWidth + Style.spaceM * 2
  implicitHeight: Style.barTabHeight
  Layout.preferredWidth: implicitWidth
  Layout.preferredHeight: implicitHeight
  Layout.alignment: Qt.AlignVCenter

  Rectangle {
    anchors.fill: parent
    radius: Style.barTabHeight / 2
    color: Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, Style.childBgAlpha)
    visible: root.hasBg && (root.model && root.model.length > 0)
  }

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    height: Style.barTabHeight - Style.space2XS
    radius: height / 2
    color: root.activeColor
    opacity: Style.opacityLight
    x: root._pillX
    width: root._pillW
    visible: root._pillW > 0 && (root.model && root.model.length > 0)

    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: "transparent"
      border.width: 1
      border.color: root.activeColor
      opacity: 0.3
    }

    Behavior on x {
      NumberAnimation {
        duration: Style.animEnter
        easing.type: Easing.OutBack
        easing.overshoot: 1.15
      }
    }
    Behavior on width {
      NumberAnimation {
        duration: Style.animEnter
        easing.type: Easing.OutBack
        easing.overshoot: 1.15
      }
    }
  }

  Row {
    id: _row
    anchors.centerIn: parent
    spacing: Style.spaceXS

    Repeater {
      model: root.model
      delegate: MouseArea {
        required property string modelData
        required property int index
        readonly property bool _isActive: index === root.activeIndex

        implicitWidth: _pillLabel.implicitWidth + Style.spaceXXL
        width: implicitWidth
        height: Style.barTabHeight
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        Text {
          id: _pillLabel
          anchors.centerIn: parent
          text: modelData
          color: parent._isActive ? root.activeColor : (parent.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant)
          font.pixelSize: Style.barTabFontSize
          font.weight: parent._isActive ? Font.Bold : Font.Medium
          Behavior on color {
            ColorAnimation {
              duration: Style.animFast
            }
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: parent.height / 2
          color: Color.mOutline
          opacity: parent.containsMouse && !parent._isActive ? 0.12 : 0.0
          Behavior on opacity {
            NumberAnimation {
              duration: Style.animFast
            }
          }
        }

        onClicked: root.selected(index, modelData)

        Component.onCompleted: {
          if (_isActive)
            Qt.callLater(root._updatePill);
        }
      }
    }

    onWidthChanged: Qt.callLater(root._updatePill)
    Component.onCompleted: Qt.callLater(root._updatePill)
  }

  function _updatePill() {
    if (!root.model || root.model.length === 0) {
      _pillX = 0;
      _pillW = 0;
      return;
    }

    var found = false;
    for (let i = 0; i < _row.children.length; i++) {
      const item = _row.children[i];
      if (item && item.visible && typeof item._isActive !== "undefined" && item._isActive) {
        const mapped = item.mapToItem(root, 0, 0);
        _pillX = mapped.x;
        _pillW = item.width;
        found = true;
        break;
      }
    }

    if (!found) {
      _pillX = 0;
      _pillW = 0;
    }
  }

  onModelChanged: Qt.callLater(root._updatePill)
  onActiveIndexChanged: Qt.callLater(root._updatePill)
}
