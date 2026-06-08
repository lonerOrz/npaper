import QtQuick
import QtQuick.Controls
import qs.services

/*
* SettingsCombo — labeled dropdown selector.
* Uses Popup + ListView for reliable dropdown behavior with scroll support.
*
* Usage:
*   SettingsCombo {
*     width: parent.width
*     label: "Sorting"
*     value: root.currentValue
*     items: ["toplist", "date_added", "views", "random"]
*     onSelect: function (v) { root._emit("sorting", v) }
*   }
*/
Column {
  id: root
  width: parent ? parent.width : 300
  spacing: Style.spaceM

  property string label: ""
  property string value: ""
  property var items: []
  signal select(string val)

  Text {
    width: parent.width
    text: root.label
    color: Color.mOnSurfaceVariant
    font.pixelSize: Style.fontXS
    font.weight: Font.Medium
  }

  Rectangle {
    id: displayRect
    width: parent.width
    height: Style.barSearchHeight + 6
    radius: Style.barRadius + 2
    color: Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, Style.childBgAlpha)
    border.width: 1
    border.color: Qt.rgba(Color.mOutlineVariant.r, Color.mOutlineVariant.g, Color.mOutlineVariant.b, Style.childBgAlpha)

    // Hover effect
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: Color.mPrimary
      opacity: comboHover.containsMouse ? 0.06 : 0
      Behavior on opacity {
        NumberAnimation {
          duration: Style.animFast
        }
      }
    }

    Text {
      anchors.fill: parent
      anchors.leftMargin: Style.spaceL
      anchors.rightMargin: Style.spaceXL
      verticalAlignment: Text.AlignVCenter
      horizontalAlignment: Text.AlignRight
      color: Color.mPrimary
      font.pixelSize: Style.barSearchInputFontSize
      font.family: "monospace"
      font.weight: Font.Normal
      text: root.value
      elide: Text.ElideRight
    }

    // Dropdown icon
    Rectangle {
      anchors.right: parent.right
      anchors.rightMargin: Style.spaceL
      anchors.verticalCenter: parent.verticalCenter
      width: 12
      height: 12
      radius: 2
      rotation: comboPopup.opened ? 180 : 0
      color: "transparent"

      Canvas {
        anchors.fill: parent
        onPaint: {
          var ctx = getContext("2d");
          ctx.reset();
          ctx.beginPath();
          ctx.moveTo(2, 4);
          ctx.lineTo(6, 8);
          ctx.lineTo(10, 4);
          ctx.strokeStyle = Color.mOutlineVariant;
          ctx.lineWidth = 1.5;
          ctx.stroke();
        }
      }

      Behavior on rotation {
        NumberAnimation {
          duration: Style.animFast
          easing.type: Easing.OutCubic
        }
      }
    }

    MouseArea {
      id: comboHover
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: comboPopup.open()
    }
  }

  Popup {
    id: comboPopup
    x: 0
    y: displayRect.height
    width: parent.width
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: displayRect

    // Height bound: scale with items but cap at 280px
    readonly property real _itemH: 36
    readonly property real _pad: 12
    height: Math.min(root.items.length * _itemH + _pad, 280)

    background: Rectangle {
      radius: Style.radiusM
      color: Color.mSurfaceContainer
      border.color: Color.mOutlineVariant
      border.width: 1

      Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Color.mShadow
        opacity: 0.2
        anchors.margins: -4
        z: -1
      }
    }

    contentItem: ListView {
      id: _listView
      model: root.items
      clip: true
      interactive: contentHeight > height

      delegate: ItemDelegate {
        width: ListView.view.width
        height: 36
        text: modelData

        background: Rectangle {
          color: hovered ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.1) : "transparent"
        }

        contentItem: Text {
          text: parent.text
          color: Color.mOnSurface
          font.pixelSize: Style.fontS
          font.family: "monospace"
          verticalAlignment: Text.AlignVCenter
          leftPadding: Style.spaceM
        }

        onClicked: {
          root.select(modelData);
          comboPopup.close();
        }
      }
    }
  }
}
