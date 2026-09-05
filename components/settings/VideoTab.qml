import QtQuick
import QtQuick.Controls
import qs.components.common
import qs.components.settings
import qs.services

Column {
  id: root

  property string videoBackend: "mpvpaper"

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
      id: engineHeader
      text: "VIDEO ENGINE"
      color: Color.mOutline
      font.pixelSize: Style.fontXS + 1
      font.weight: Font.Bold
      font.letterSpacing: 2
    }

    Rectangle {
      width: Math.max(10, parent.width - engineHeader.implicitWidth - Style.spaceM)
      height: 1
      anchors.verticalCenter: engineHeader.verticalCenter
      color: Color.mOutlineVariant
      opacity: 0.3
    }
  }

  SettingsCombo {
    width: parent.width
    label: "Playback Backend"
    value: root.videoBackend
    items: ["mpvpaper", "phonto"]
    onSelect: function (v) {
      root.settingChanged("videoBackend", v);
    }
  }

  readonly property bool _isBackendInstalled: {
    const checks = ServiceLocator.checks;
    if (!checks)
      return true;
    if (root.videoBackend === "phonto")
      return checks.hasPhonto;
    return checks.hasMpvpaper;
  }

  Row {
    width: parent.width
    spacing: Style.spaceS

    Text {
      text: root._isBackendInstalled ? "\uf058" : "\uf06a"
      font.family: "Symbols Nerd Font"
      font.pixelSize: Style.fontXS
      color: root._isBackendInstalled ? "#4ade80" : "#fbbf24"
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      text: root._isBackendInstalled ? (root.videoBackend + " is ready for video wallpapers") : (root.videoBackend + " is not detected in your PATH")
      color: root._isBackendInstalled ? Color.mOnSurfaceVariant : "#fbbf24"
      font.pixelSize: Style.fontXS
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
      width: parent.width - 24
    }
  }

  Text {
    width: parent.width
    text: "Tip: mpvpaper is recommended for Wayland compositors (Hyprland, Sway, etc.). Audio is muted by default."
    color: Color.mOutline
    font.pixelSize: Style.fontXS
    wrapMode: Text.WordWrap
    opacity: 0.8
  }
}
