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

  signal settingChanged(string key, var value)

  anchors.top: parent.top
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.margins: Style.settingsPadding
  spacing: Style.settingsContentSpacing + 2

  function _withAlpha(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a);
  }

  Row {
    width: parent.width
    spacing: Style.spaceM

    Text {
      id: apiHeader
      text: "API CONFIG"
      color: Color.mOutline
      font.pixelSize: Style.fontXS + 1
      font.weight: Font.Bold
      font.letterSpacing: 2
    }

    Rectangle {
      width: Math.max(10, parent.width - apiHeader.implicitWidth - Style.spaceM)
      height: 1
      anchors.verticalCenter: apiHeader.verticalCenter
      color: Color.mOutlineVariant
      opacity: 0.3
    }
  }

  SettingsTextInput {
    width: parent.width
    label: "API Key (Optional for NSFW & Rate Limits)"
    value: root.wallhavenApiKey
    placeholder: "your-wallhaven-api-key"
    onCommit: function (v) {
      root.settingChanged("wallhaven.apiKey", v.trim());
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

    Column {
      width: parent.width - 64
      spacing: Style.spaceXS

      Text {
        text: "Download Folder"
        color: Color.mOnSurfaceVariant
        font.pixelSize: Style.fontXS
        font.weight: Font.Medium
      }

      Text {
        text: root.wallhavenDownloadDir || "Default (First Wallpaper Dir)"
        color: root.wallhavenDownloadDir ? Color.mOnSurface : Color.mOnSurfaceVariant
        font.pixelSize: Style.fontXS
        font.family: "monospace"
        elide: Text.ElideMiddle
        width: parent.width
      }
    }

    MouseArea {
      width: 26
      height: 26
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      visible: !!root.wallhavenDownloadDir
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.fill: parent
        radius: Style.radiusS
        color: parent.containsMouse ? Qt.rgba(1.0, 0.33, 0.33, 0.15) : "transparent"
        Behavior on color {
          ColorAnimation {
            duration: Style.animVeryFast
          }
        }
      }

      Text {
        anchors.centerIn: parent
        text: "\uf00d"
        font.family: "Symbols Nerd Font"
        font.pixelSize: Style.fontS
        color: parent.containsMouse ? "#ff5555" : Color.mOnSurfaceVariant
      }

      onClicked: {
        root.settingChanged("wallhaven.downloadDir", "");
      }
    }

    MouseArea {
      width: 26
      height: 26
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.fill: parent
        radius: Style.radiusS
        color: parent.containsMouse ? root._withAlpha(Color.mPrimary, 0.15) : Color.mSurfaceContainerHigh
        border.color: parent.containsMouse ? Color.mPrimary : Color.mOutline
        border.width: Style.borderS
        Behavior on color {
          ColorAnimation {
            duration: Style.animVeryFast
          }
        }
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
      if (path && path.trim().length > 0)
        root.settingChanged("wallhaven.downloadDir", path.trim());
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
      id: catHeader
      text: "DEFAULT CATEGORIES"
      color: Color.mOutline
      font.pixelSize: Style.fontXS + 1
      font.weight: Font.Bold
      font.letterSpacing: 2
    }

    Rectangle {
      width: Math.max(10, parent.width - catHeader.implicitWidth - Style.spaceM)
      height: 1
      anchors.verticalCenter: catHeader.verticalCenter
      color: Color.mOutlineVariant
      opacity: 0.3
    }
  }

  function _updateBit(currentStr, bitIdx, val) {
    const arr = (currentStr || "100").split("");
    arr[bitIdx] = val ? "1" : "0";
    if (arr.join("") === "000")
      return currentStr;
    return arr.join("");
  }

  Column {
    width: parent.width
    spacing: Style.spaceS

    SettingsToggle {
      width: parent.width
      text: "General"
      checked: (root.wallhavenCategories || "111")[0] === "1"
      onToggled: function (val) {
        root.settingChanged("wallhaven.categories", root._updateBit(root.wallhavenCategories, 0, val));
      }
    }
    SettingsToggle {
      width: parent.width
      text: "Anime"
      checked: (root.wallhavenCategories || "111")[1] === "1"
      onToggled: function (val) {
        root.settingChanged("wallhaven.categories", root._updateBit(root.wallhavenCategories, 1, val));
      }
    }
    SettingsToggle {
      width: parent.width
      text: "People"
      checked: (root.wallhavenCategories || "111")[2] === "1"
      onToggled: function (val) {
        root.settingChanged("wallhaven.categories", root._updateBit(root.wallhavenCategories, 2, val));
      }
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
      id: purityHeader
      text: "DEFAULT PURITY"
      color: Color.mOutline
      font.pixelSize: Style.fontXS + 1
      font.weight: Font.Bold
      font.letterSpacing: 2
    }

    Rectangle {
      width: Math.max(10, parent.width - purityHeader.implicitWidth - Style.spaceM)
      height: 1
      anchors.verticalCenter: purityHeader.verticalCenter
      color: Color.mOutlineVariant
      opacity: 0.3
    }
  }

  Column {
    width: parent.width
    spacing: Style.spaceS

    SettingsToggle {
      width: parent.width
      text: "Safe (SFW)"
      checked: (root.wallhavenPurity || "100")[0] === "1"
      onToggled: function (val) {
        root.settingChanged("wallhaven.purity", root._updateBit(root.wallhavenPurity, 0, val));
      }
    }
    SettingsToggle {
      width: parent.width
      text: "Sketchy"
      checked: (root.wallhavenPurity || "100")[1] === "1"
      onToggled: function (val) {
        root.settingChanged("wallhaven.purity", root._updateBit(root.wallhavenPurity, 1, val));
      }
    }
    SettingsToggle {
      width: parent.width
      text: "NSFW (Requires API Key)"
      checked: (root.wallhavenPurity || "100")[2] === "1"
      onToggled: function (val) {
        root.settingChanged("wallhaven.purity", root._updateBit(root.wallhavenPurity, 2, val));
      }
    }
  }
}
