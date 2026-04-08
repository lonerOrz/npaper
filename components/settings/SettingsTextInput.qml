import QtQuick
import qs.services

/*
* SettingsTextInput — labeled text input with placeholder and focus border.
*
* Usage:
*   SettingsTextInput {
*     width: parent.width
*     label: "API Key"
*     value: root.someValue
*     placeholder: "your-api-key"
*     onCommit: function (v) { root._emit("someKey", v) }
*   }
*/
Column {
  id: root
  width: parent ? parent.width : 300
  spacing: Style.spaceS

  property string label: ""
  property string value: ""
  property string placeholder: ""
  signal commit(string val)

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
    border.width: inputField.activeFocus ? 1 : 0
    border.color: inputField.activeFocus ? Color.mPrimary : "transparent"
    Behavior on border.color {
      ColorAnimation {
        duration: Style.animFast
      }
    }

    TextInput {
      id: inputField
      anchors.fill: parent
      anchors.leftMargin: Style.spaceL
      anchors.rightMargin: Style.spaceL
      verticalAlignment: TextInput.AlignVCenter
      font.pixelSize: Style.barSearchInputFontSize
      font.family: "monospace"
      color: Color.mPrimary
      clip: true
      selectByMouse: true
      text: root.value

      Text {
        anchors.fill: parent
        verticalAlignment: Text.AlignVCenter
        font: inputField.font
        color: Color.mOutlineVariant
        opacity: 0.4
        text: root.placeholder
        visible: !inputField.text && !inputField.activeFocus
      }

      onEditingFinished: root.commit(text)
    }
  }
}
