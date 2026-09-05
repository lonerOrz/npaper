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

  signal settingChanged(string key, var value)

  anchors.top: parent.top
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.margins: Style.settingsPadding
  spacing: Style.settingsContentSpacing + 2

  Row {
    width: parent.width
    spacing: Style.spaceM

    Text {
      id: overlayHeader
      text: "OVERLAY & BACKGROUND"
      color: Color.mOutline
      font.pixelSize: Style.fontXS + 1
      font.weight: Font.Bold
      font.letterSpacing: 2
    }

    Rectangle {
      width: Math.max(10, parent.width - overlayHeader.implicitWidth - Style.spaceM)
      height: 1
      anchors.verticalCenter: overlayHeader.verticalCenter
      color: Color.mOutlineVariant
      opacity: 0.3
    }
  }

  SettingsSlider {
    width: parent.width
    label: "Background Dimming"
    value: root.bgOverlayOpacity
    min: 0.0
    max: 1.0
    step: 0.05
    onCommit: function (v) {
      root.settingChanged("appearance.bgOverlayOpacity", Math.round(v * 100) / 100);
    }
  }

  Rectangle {
    width: parent.width
    height: 1
    color: Color.mOutlineVariant
    opacity: 0.2
  }

  Row {
    width: parent.width
    spacing: Style.spaceM

    Text {
      id: effectsHeader
      text: "VISUAL EFFECTS"
      color: Color.mOutline
      font.pixelSize: Style.fontXS + 1
      font.weight: Font.Bold
      font.letterSpacing: 2
    }

    Rectangle {
      width: Math.max(10, parent.width - effectsHeader.implicitWidth - Style.spaceM)
      height: 1
      anchors.verticalCenter: effectsHeader.verticalCenter
      color: Color.mOutlineVariant
      opacity: 0.3
    }
  }

  Column {
    width: parent.width
    spacing: Style.spaceS

    SettingsToggle {
      width: parent.width
      text: "Card Drop Shadow"
      checked: root.showShadow
      onToggled: function (val) {
        root.settingChanged("appearance.showShadow", val);
      }
    }

    SettingsToggle {
      width: parent.width
      text: "Full Background Preview"
      checked: root.showBgPreview
      onToggled: function (val) {
        root.settingChanged("appearance.showBgPreview", val);
      }
    }
  }
}
