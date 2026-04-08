import QtQuick
import QtQuick.Controls
import qs.services

/*
 * SettingsCombo — labeled dropdown selector.
 * Enhanced with better visual hierarchy and menu styling.
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
    color: Color.mOutline
    font.pixelSize: Style.fontXS + 1
    font.weight: Font.Medium
    font.letterSpacing: 1.2
  }

  Rectangle {
    width: parent.width
    height: Style.barSearchHeight + 6
    radius: Style.barRadius + 2
    color: Color.mSurfaceContainer
    border.width: 1
    border.color: Qt.tint(Color.mOutlineVariant, Color.mSurfaceContainer)

    // Hover effect
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: Color.mPrimary
      opacity: comboHover.containsMouse ? 0.06 : 0
      Behavior on opacity {
        NumberAnimation { duration: Style.animFast }
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
      rotation: comboPopup.visible ? 180 : 0
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

  Menu {
    id: comboPopup
    modal: true
    dim: false
    
    // Style the menu
    background: Rectangle {
      implicitWidth: root.width
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

    onAboutToShow: {
      comboPopup.clear();
      for (var i = 0; i < root.items.length; i++) {
        var action = comboPopup.addAction(root.items[i]);
        action.triggered.connect(function() {
          root.select(root.items[i]);
        });
      }
    }
  }
}
