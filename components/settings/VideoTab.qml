import QtQuick
import QtQuick.Controls
import qs.components.common
import qs.components.settings
import qs.services

Column {
  id: root

  property string videoBackend: "mpvpaper"

  signal settingChanged(string key, variant value)

  anchors.top: parent.top
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.margins: Style.settingsPadding
  spacing: Style.settingsContentSpacing + 2

  // Engine section header
  Row {
    width: parent.width
    spacing: Style.spaceM

    Text {
      id: _engineHeader
      text: "ENGINE"
      color: Color.mOutline
      font.pixelSize: Style.fontXS + 1
      font.weight: Font.Bold
      font.letterSpacing: 2
    }

    Rectangle {
      width: parent.width - _engineHeader.implicitWidth - Style.spaceM
      height: 1
      anchors.verticalCenter: _engineHeader.verticalCenter
      color: Color.mOutlineVariant
      opacity: 0.3
    }
  }

  SettingsCombo {
    width: parent.width
    label: "Video Backend"
    value: root.videoBackend
    items: ["mpvpaper", "phonto"]
    onSelect: function (v) {
      root.settingChanged("videoBackend", v);
    }
  }
}
