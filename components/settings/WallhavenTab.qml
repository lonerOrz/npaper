import QtQuick
import QtQuick.Controls
import qs.components.common
import qs.components.settings
import qs.services

Column {
  id: root

  property string wallhavenApiKey: ""
  property string wallhavenDownloadDir: ""
  property string wallhavenCategories: "111"
  property string wallhavenPurity: "100"

  signal settingChanged(string key, variant value)

  anchors.top: parent.top
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.margins: Style.settingsPadding
  spacing: Style.settingsContentSpacing + 2

  // API section header
  Row {
    width: parent.width
    spacing: Style.spaceM

    Text {
      id: _apiHeader
      text: "API"
      color: Color.mOutline
      font.pixelSize: Style.fontXS + 1
      font.weight: Font.Bold
      font.letterSpacing: 2
    }

    Rectangle {
      width: parent.width - _apiHeader.implicitWidth - Style.spaceM
      height: 1
      anchors.verticalCenter: _apiHeader.verticalCenter
      color: Color.mOutlineVariant
      opacity: 0.3
    }
  }

  SettingsTextInput {
    width: parent.width
    label: "API Key"
    value: root.wallhavenApiKey
    placeholder: "your-wallhaven-api-key"
    onCommit: function (v) {
      root.settingChanged("wallhaven.apiKey", v.trim());
    }
  }

  // Divider
  Rectangle {
    width: parent.width
    height: 1
    color: Color.mOutlineVariant
    opacity: 0.2
  }

  // Download Folder
  Row {
    width: parent.width
    spacing: Style.spaceM

    Column {
      width: parent.width - 40
      spacing: Style.spaceXS

      Text {
        text: "Download Folder"
        color: Color.mOnSurfaceVariant
        font.pixelSize: Style.fontXS
        font.weight: Font.Medium
      }

      Text {
        text: root.wallhavenDownloadDir || "Default (Wallpaper Dir)"
        color: root.wallhavenDownloadDir ? Color.mOnSurface : Color.mOnSurfaceVariant
        font.pixelSize: Style.fontXS
        font.family: "monospace"
        elide: Text.ElideMiddle
      }
    }

    MouseArea {
      width: 24
      height: 24
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true

      Rectangle {
        anchors.fill: parent
        radius: Style.radiusS
        color: parent.containsMouse ? Qt.alpha(Color.mPrimary, 0.12) : Color.mSurfaceContainerHigh
        border.color: Color.mOutline
        border.width: Style.borderS
      }

      Text {
        anchors.centerIn: parent
        text: "\uf07c"
        font.family: "Symbols Nerd Font"
        font.pixelSize: Style.fontS
        color: parent.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
      }

      onClicked: whDownloadPicker.openPicker(root.wallhavenDownloadDir)
    }
  }

  FolderPicker {
    id: whDownloadPicker
    title: "Select Download Folder"
    onAccepted: function (path) {
      root.settingChanged("wallhaven.downloadDir", path);
    }
  }

  // Filters section header
  Row {
    width: parent.width
    spacing: Style.spaceM

    Text {
      id: _filtersHeader
      text: "FILTERS"
      color: Color.mOutline
      font.pixelSize: Style.fontXS + 1
      font.weight: Font.Bold
      font.letterSpacing: 2
    }

    Rectangle {
      width: parent.width - _filtersHeader.implicitWidth - Style.spaceM
      height: 1
      anchors.verticalCenter: _filtersHeader.verticalCenter
      color: Color.mOutlineVariant
      opacity: 0.3
    }
  }

  // Category toggles
  Column {
    width: parent.width
    spacing: Style.spaceS

    SettingsToggle {
      width: parent.width
      text: "General"
      checked: root.wallhavenCategories[0] === "1"
      onToggled: function (val) {
        var c = root.wallhavenCategories.split("");
        c[0] = val ? "1" : "0";
        root.settingChanged("wallhaven.categories", c.join(""));
      }
    }
    SettingsToggle {
      width: parent.width
      text: "Anime"
      checked: root.wallhavenCategories[1] === "1"
      onToggled: function (val) {
        var c = root.wallhavenCategories.split("");
        c[1] = val ? "1" : "0";
        root.settingChanged("wallhaven.categories", c.join(""));
      }
    }
    SettingsToggle {
      width: parent.width
      text: "People"
      checked: root.wallhavenCategories[2] === "1"
      onToggled: function (val) {
        var c = root.wallhavenCategories.split("");
        c[2] = val ? "1" : "0";
        root.settingChanged("wallhaven.categories", c.join(""));
      }
    }
  }

  // Divider
  Rectangle {
    width: parent.width
    height: 1
    color: Color.mOutlineVariant
    opacity: 0.2
  }

  // Purity toggles
  Column {
    width: parent.width
    spacing: Style.spaceS

    SettingsToggle {
      width: parent.width
      text: "Safe"
      checked: root.wallhavenPurity[0] === "1"
      onToggled: function (val) {
        var p = root.wallhavenPurity.split("");
        p[0] = val ? "1" : "0";
        root.settingChanged("wallhaven.purity", p.join(""));
      }
    }
    SettingsToggle {
      width: parent.width
      text: "Sketchy"
      checked: root.wallhavenPurity[1] === "1"
      onToggled: function (val) {
        var p = root.wallhavenPurity.split("");
        p[1] = val ? "1" : "0";
        root.settingChanged("wallhaven.purity", p.join(""));
      }
    }
    SettingsToggle {
      width: parent.width
      text: "NSFW"
      checked: root.wallhavenPurity[2] === "1"
      onToggled: function (val) {
        var p = root.wallhavenPurity.split("");
        p[2] = val ? "1" : "0";
        root.settingChanged("wallhaven.purity", p.join(""));
      }
    }
  }
}
