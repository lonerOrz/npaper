import QtQuick
import QtQuick.Controls
import qs.services

/*
* SettingsCombo — labeled dropdown selector.
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
  spacing: Style.spaceS

  property string label: ""
  property string value: ""
  property var items: []
  signal select(string val)

  Text {
    width: parent.width
    text: root.label
    color: Color.mOutline
    font.pixelSize: Style.fontXS
    font.weight: Font.Medium
    font.letterSpacing: 1
  }

  Rectangle {
    width: parent.width
    height: Style.barSearchHeight
    radius: Style.barRadius
    color: Color.mSurfaceContainer

    Text {
      anchors.fill: parent
      anchors.leftMargin: Style.spaceL
      anchors.rightMargin: Style.spaceXL
      verticalAlignment: Text.AlignVCenter
      horizontalAlignment: Text.AlignRight
      color: Color.mPrimary
      font.pixelSize: Style.barSearchInputFontSize
      font.family: "monospace"
      text: root.value
      elide: Text.ElideRight
    }

    Text {
      anchors.right: parent.right
      anchors.rightMargin: Style.spaceM
      anchors.verticalCenter: parent.verticalCenter
      text: "▼"
      font.pixelSize: 8
      color: Color.mOutlineVariant
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: comboPopup.open(comboPopup.parent, 0, height)
    }
  }

  Menu {
    id: comboPopup
    modal: true
    dim: false

    onAboutToShow: {
      comboPopup.clear();
      for (var i = 0; i < root.items.length; i++) {
        var action = comboPopup.addAction(root.items[i]);
        action.triggered.connect(function () {
          root.select(root.items[i]);
        });
      }
    }
  }
}
