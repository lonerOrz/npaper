import QtQuick
import qs.services

/*
 * SettingsTextInput — labeled text input with placeholder and focus border.
 * Enhanced with better visual hierarchy and focus states.
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
    width: parent.width
    height: Style.barSearchHeight + 6
    radius: Style.barRadius + 2
    color: Color.mSurfaceContainer
    border.width: inputField.activeFocus ? 2 : 1
    border.color: inputField.activeFocus ? Color.mPrimary : Qt.tint(Color.mOutlineVariant, Color.mSurfaceContainer)
    
    Behavior on border.color {
      ColorAnimation { duration: Style.animFast }
    }
    Behavior on border.width {
      NumberAnimation { duration: Style.animFast }
    }

    // Focus glow effect
    Rectangle {
      anchors.fill: parent
      anchors.margins: -3
      radius: parent.radius + 3
      color: Color.mPrimary
      opacity: inputField.activeFocus ? 0.08 : 0
      Behavior on opacity {
        NumberAnimation { duration: Style.animFast }
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
      font.weight: Font.Normal
      color: Color.mPrimary
      clip: true
      selectByMouse: true
      text: root.value

      // Placeholder
      Text {
        anchors.fill: parent
        verticalAlignment: Text.AlignVCenter
        font: inputField.font
        color: Color.mOutlineVariant
        opacity: 0.35
        text: root.placeholder
        visible: !inputField.text && !inputField.activeFocus
      }

      onEditingFinished: root.commit(text)
    }
  }
}
