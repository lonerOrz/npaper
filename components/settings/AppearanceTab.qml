import QtQuick
import QtQuick.Controls
import qs.components.common
import qs.components.settings
import qs.services

Column {
  id: root

  property bool showShadow: true
  property bool showBgPreview: true
  property real bgOverlayOpacity: 0.4

  signal settingChanged(string key, variant value)

  anchors.top: parent.top
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.margins: Style.settingsPadding
  spacing: Style.settingsContentSpacing + 2

  // Overlay section header
  Row {
    width: parent.width
    spacing: Style.spaceM

    Text {
      id: _overlayHeader
      text: "OVERLAY"
      color: Color.mOutline
      font.pixelSize: Style.fontXS + 1
      font.weight: Font.Bold
      font.letterSpacing: 2
    }

    Rectangle {
      width: parent.width - _overlayHeader.implicitWidth - Style.spaceM
      height: 1
      anchors.verticalCenter: _overlayHeader.verticalCenter
      color: Color.mOutlineVariant
      opacity: 0.3
    }
  }

  SettingsSlider {
    width: parent.width
    label: "Opacity"
    value: root.bgOverlayOpacity
    min: 0.0
    max: 1.0
    step: 0.05
    onCommit: function (v) {
      root.settingChanged("appearance.bgOverlayOpacity", v);
    }
  }

  // Divider
  Rectangle {
    width: parent.width
    height: 1
    color: Color.mOutlineVariant
    opacity: 0.2
  }

  // Effects section header
  Row {
    width: parent.width
    spacing: Style.spaceM

    Text {
      id: _effectsHeader
      text: "EFFECTS"
      color: Color.mOutline
      font.pixelSize: Style.fontXS + 1
      font.weight: Font.Bold
      font.letterSpacing: 2
    }

    Rectangle {
      width: parent.width - _effectsHeader.implicitWidth - Style.spaceM
      height: 1
      anchors.verticalCenter: _effectsHeader.verticalCenter
      color: Color.mOutlineVariant
      opacity: 0.3
    }
  }

  Column {
    width: parent.width
    spacing: Style.spaceS

    SettingsToggle {
      width: parent.width
      text: "Card Shadow"
      checked: root.showShadow
      onToggled: function (val) {
        root.settingChanged("appearance.showShadow", val);
      }
    }
    SettingsToggle {
      width: parent.width
      text: "Background Preview"
      checked: root.showBgPreview
      onToggled: function (val) {
        root.settingChanged("appearance.showBgPreview", val);
      }
    }
  }
}
