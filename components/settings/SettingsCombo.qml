import QtQuick
import QtQuick.Controls
import qs.services

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
    border.color: comboHover.containsMouse ? Color.mPrimary : Qt.rgba(Color.mOutlineVariant.r, Color.mOutlineVariant.g, Color.mOutlineVariant.b, Style.childBgAlpha)

    Behavior on border.color {
      ColorAnimation {
        duration: Style.animFast
      }
    }

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
      anchors.left: parent.left
      anchors.right: arrowIcon.left
      anchors.leftMargin: Style.spaceL
      anchors.rightMargin: Style.spaceM
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignRight
      color: Color.mPrimary
      font.pixelSize: Style.barSearchInputFontSize
      font.family: "monospace"
      font.weight: Font.Medium
      text: root.value
      elide: Text.ElideRight
    }

    Text {
      id: arrowIcon
      anchors.right: parent.right
      anchors.rightMargin: Style.spaceL
      anchors.verticalCenter: parent.verticalCenter
      text: "\uf078"
      font.family: "Symbols Nerd Font"
      font.pixelSize: Style.fontXS
      color: comboHover.containsMouse ? Color.mPrimary : Color.mOutlineVariant

      rotation: comboPopup.opened ? 180 : 0
      Behavior on rotation {
        NumberAnimation {
          duration: Style.animFast
          easing.type: Easing.OutCubic
        }
      }
      Behavior on color {
        ColorAnimation {
          duration: Style.animFast
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
    y: displayRect.height + 4
    width: parent.width
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: displayRect

    readonly property real _itemH: 34
    readonly property real _pad: 8
    height: Math.min((root.items ? root.items.length : 0) * _itemH + _pad, 220)

    background: Rectangle {
      radius: Style.radiusM
      color: Color.mSurfaceContainer
      border.color: Color.mOutlineVariant
      border.width: 1

      Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Color.mShadow
        opacity: 0.25
        anchors.margins: -4
        z: -1
      }
    }

    contentItem: ListView {
      id: _listView
      model: root.items || []
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      delegate: ItemDelegate {
        id: delegateItem
        width: ListView.view.width
        height: 34
        text: modelData

        readonly property bool isSelected: modelData === root.value

        background: Rectangle {
          color: {
            if (delegateItem.isSelected)
              return Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.18);
            if (delegateItem.hovered)
              return Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.08);
            return "transparent";
          }
          Behavior on color {
            ColorAnimation {
              duration: Style.animVeryFast
            }
          }
        }

        contentItem: Row {
          anchors.fill: parent
          anchors.leftMargin: Style.spaceM
          anchors.rightMargin: Style.spaceM
          spacing: Style.spaceS

          Text {
            text: delegateItem.isSelected ? "\uf00c" : ""
            font.family: "Symbols Nerd Font"
            font.pixelSize: Style.fontXS
            color: Color.mPrimary
            anchors.verticalCenter: parent.verticalCenter
            width: 14
          }

          Text {
            text: delegateItem.text
            color: delegateItem.isSelected ? Color.mPrimary : Color.mOnSurface
            font.pixelSize: Style.fontS
            font.family: "monospace"
            font.weight: delegateItem.isSelected ? Font.Bold : Font.Normal
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        onClicked: {
          root.select(modelData);
          comboPopup.close();
        }
      }
    }
  }
}
