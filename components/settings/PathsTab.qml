import QtQuick
import QtQuick.Controls
import qs.components.common
import qs.components.settings
import qs.services

Column {
  id: root

  property var wallpaperDirs: []
  property string cacheDir: ""

  signal settingChanged(string key, variant value)

  anchors.top: parent.top
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.margins: Style.settingsPadding
  spacing: Style.settingsContentSpacing + 2

  // Section header with underline
  Row {
    width: parent.width
    spacing: Style.spaceM

    Text {
      text: "STORAGE"
      color: Color.mOutline
      font.pixelSize: Style.fontXS + 1
      font.weight: Font.Bold
      font.letterSpacing: 2
    }

    Rectangle {
      width: parent.width - _sectionText.implicitWidth - Style.spaceM
      height: 1
      anchors.verticalCenter: _sectionText.verticalCenter
      color: Color.mOutlineVariant
      opacity: 0.3
    }

    Text {
      id: _sectionText
      visible: false
    }
  }

  // ── Wallpaper Directories ──
  Column {
    width: parent.width
    spacing: Style.spaceS

    Text {
      text: "Wallpaper Directories"
      color: Color.mOnSurfaceVariant
      font.pixelSize: Style.fontXS
      font.weight: Font.Medium
    }

    // Directory list
    Column {
      width: parent.width
      spacing: Style.spaceXS

      Repeater {
        model: root.wallpaperDirs

        Row {
          width: parent.width
          spacing: Style.spaceS

          Text {
            width: parent.width - 32
            text: modelData
            color: Color.mOnSurface
            font.pixelSize: Style.fontXS
            font.family: "monospace"
            elide: Text.ElideMiddle
          }

          // Remove button
          MouseArea {
            width: 20
            height: 20
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            Rectangle {
              anchors.fill: parent
              radius: Style.radiusXS
              color: parent.containsMouse ? Qt.alpha("#ff5555", 0.12) : "transparent"
              Behavior on color {
                ColorAnimation {
                  duration: Style.animVeryFast
                }
              }
            }

            Text {
              anchors.centerIn: parent
              text: "\uf014"
              font.family: "Symbols Nerd Font"
              font.pixelSize: Style.fontXS
              color: parent.containsMouse ? "#ff5555" : Color.mOnSurfaceVariant
            }

            onClicked: {
              var dirs = root.wallpaperDirs.slice();
              dirs.splice(index, 1);
              root.settingChanged("wallpaperDirs", dirs);
            }
          }
        }
      }
    }

    // Add button
    MouseArea {
      width: parent.width
      height: 26
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true

      Rectangle {
        anchors.fill: parent
        radius: Style.radiusS
        color: parent.containsMouse ? Qt.alpha(Color.mPrimary, 0.08) : "transparent"
        border.color: Color.mOutline
        border.width: Style.borderS
        Behavior on color {
          ColorAnimation {
            duration: Style.animVeryFast
          }
        }
      }

      Text {
        anchors.centerIn: parent
        text: "\uf07b  Add Directory"
        font.family: "Symbols Nerd Font"
        font.pixelSize: Style.fontS
        color: parent.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
      }

      onClicked: folderPicker.openPicker("")
    }
  }

  FolderPicker {
    id: folderPicker
    title: "Select Wallpaper Folder"
    onAccepted: function (path) {
      var dirs = root.wallpaperDirs.slice();
      if (dirs.indexOf(path) === -1) {
        dirs.push(path);
        root.settingChanged("wallpaperDirs", dirs);
      }
    }
  }

  // ── Cache Directory ──
  Row {
    width: parent.width
    spacing: Style.spaceM

    Column {
      width: parent.width - 40
      spacing: Style.spaceXS

      Text {
        text: "Cache Directory"
        color: Color.mOnSurfaceVariant
        font.pixelSize: Style.fontXS
        font.weight: Font.Medium
      }

      Text {
        text: root.cacheDir || "Not configured"
        color: root.cacheDir ? Color.mOnSurface : Color.mOnSurfaceVariant
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

      onClicked: cachePicker.openPicker(root.cacheDir)
    }
  }

  FolderPicker {
    id: cachePicker
    title: "Select Cache Folder"
    onAccepted: function (path) {
      root.settingChanged("cacheDir", path);
    }
  }
}
