import QtQuick
import qs.services

Column {
  id: root
  width: parent ? parent.width : 300
  spacing: Style.spaceM

  property string label: ""
  property string value: ""
  property string placeholder: ""
  signal commit(string val)

  Text {
    width: parent.width
    text: root.label
    color: Color.mOutline
    font.pixelSize: Style.fontXS + 1
    font.weight: Font.Medium
    font.letterSpacing: 1.2
  }

  Rectangle {
    id: borderRect
    width: parent.width
    height: Style.barSearchHeight + 6
    radius: Style.barRadius + 2
    color: Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, Style.childBgAlpha)
    border.width: inputField.activeFocus ? 2 : 1
    border.color: inputField.activeFocus ? Color.mPrimary : Qt.rgba(Color.mOutlineVariant.r, Color.mOutlineVariant.g, Color.mOutlineVariant.b, Style.childBgAlpha)

    Behavior on border.color {
      ColorAnimation {
        duration: Style.animFast
      }
    }
    Behavior on border.width {
      NumberAnimation {
        duration: Style.animFast
      }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: -3
      radius: parent.radius + 3
      color: Color.mPrimary
      opacity: inputField.activeFocus ? 0.08 : 0
      Behavior on opacity {
        NumberAnimation {
          duration: Style.animFast
        }
      }
    }

    TextInput {
      id: inputField
      anchors.left: parent.left
      anchors.right: clearBtn.visible ? clearBtn.left : parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.leftMargin: Style.spaceL
      anchors.rightMargin: Style.spaceS
      verticalAlignment: TextInput.AlignVCenter
      font.pixelSize: Style.barSearchInputFontSize
      font.family: "monospace"
      font.weight: Font.Normal
      color: Color.mPrimary
      clip: true
      selectByMouse: true

      Binding {
        target: inputField
        property: "text"
        value: root.value
        when: !inputField.activeFocus
      }

      Text {
        anchors.fill: parent
        verticalAlignment: Text.AlignVCenter
        font: inputField.font
        color: Color.mOutlineVariant
        opacity: 0.38
        text: root.placeholder
        visible: !inputField.text && !inputField.activeFocus
      }

      Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.commit(inputField.text);
          inputField.focus = false;
          event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
          inputField.text = root.value;
          inputField.focus = false;
          event.accepted = true;
        }
      }

      onEditingFinished: {
        root.commit(text);
      }
    }

    MouseArea {
      id: clearBtn
      width: 24
      height: 24
      anchors.right: parent.right
      anchors.rightMargin: Style.spaceM
      anchors.verticalCenter: parent.verticalCenter
      visible: inputField.text.length > 0 && inputField.activeFocus
      cursorShape: Qt.PointingHandCursor

      Text {
        anchors.centerIn: parent
        text: "\uf00d"
        font.family: "Symbols Nerd Font"
        font.pixelSize: Style.fontXS
        color: clearBtn.containsMouse ? Color.mPrimary : Color.mOutline
      }

      onClicked: {
        inputField.text = "";
        inputField.forceActiveFocus();
      }
    }

    MouseArea {
      anchors.fill: parent
      z: -1
      cursorShape: Qt.IBeamCursor
      onClicked: inputField.forceActiveFocus()
    }
  }
}
