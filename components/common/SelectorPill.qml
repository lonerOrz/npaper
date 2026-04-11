import QtQuick
import QtQuick.Layouts
import qs.services

/*
* SelectorPill — reusable sliding pill indicator for tab/mode selection.
*
* Usage:
*   SelectorPill {
*     model: ["Carousel", "Grid"]
*     activeIndex: Config.previewStyle === "grid" ? 1 : 0
*     onSelected: Config.update("previewStyle", index === 0 ? "carousel" : "grid")
*   }
*/
Item {
  id: root

  Layout.preferredWidth: _row.implicitWidth + Style.spaceM
  Layout.preferredHeight: Style.barTabHeight
  Layout.alignment: Qt.AlignVCenter

  property var model: []
  property int activeIndex: 0
  property color activeColor: Color.mPrimary
  property bool hasBg: true

  signal selected(int index, string label)

  property real _pillX: 0
  property real _pillW: 0

  function _updatePill() {
    var found = false;
    for (let i = 0; i < _row.children.length; i++) {
      const item = _row.children[i];
      if (item && typeof item._isActive !== "undefined" && item._isActive) {
        // Map item's top-left to root's coordinate space
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

  // Background (optional)
  Rectangle {
    anchors.fill: parent
    radius: Style.barTabHeight / 2
    color: Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, Style.childBgAlpha)
    visible: root.hasBg
  }

  // Sliding active indicator
  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    height: Style.barTabHeight - Style.space2XS
    radius: height / 2
    color: root.activeColor
    opacity: Style.opacityLight
    x: root._pillX
    width: root._pillW
    Behavior on x {
      NumberAnimation {
        duration: Style.animEnter
        easing.type: Easing.OutBack
        easing.overshoot: 1.2
      }
    }
    Behavior on width {
      NumberAnimation {
        duration: Style.animEnter
        easing.type: Easing.OutBack
        easing.overshoot: 1.2
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
        property bool _isActive: index === root.activeIndex

        width: _pillLabel.implicitWidth + Style.spaceXXL
        height: Style.barTabHeight
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        Text {
          id: _pillLabel
          anchors.centerIn: parent
          text: modelData
          color: parent._isActive ? root.activeColor : Color.mOnSurface
          font.pixelSize: Style.barTabFontSize
          font.weight: parent._isActive ? Font.Bold : Font.Normal
          Behavior on color {
            ColorAnimation {
              duration: Style.animFast
            }
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: parent.height / 2
          color: parent.containsMouse ? Color.mOutline : "transparent"
          opacity: parent.containsMouse ? 0.15 : 0
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
    Component.onCompleted: Qt.callLater(root._updatePill)
  }

  onActiveIndexChanged: Qt.callLater(root._updatePill)
}
