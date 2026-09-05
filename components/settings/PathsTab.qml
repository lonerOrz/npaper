import QtQuick
import QtQuick.Controls
import qs.components.common
import qs.components.settings
import qs.services

Column {
  id: root

  property var wallpaperDirs: []
  property string cacheDir: ""

  signal settingChanged(string key, var value)

  anchors.top: parent.top
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.margins: Style.settingsPadding
  spacing: Style.settingsContentSpacing + 2

  function _withAlpha(colorVal, alphaVal) {
    return Qt.rgba(colorVal.r, colorVal.g, colorVal.b, alphaVal);
  }

  Row {
    width: parent.width
    spacing: Style.spaceM

    Text {
      id: sectionTitle
      text: "STORAGE"
      color: Color.mOutline
      font.pixelSize: Style.fontXS + 1
      font.weight: Font.Bold
      font.letterSpacing: 2
    }

    Rectangle {
      width: Math.max(10, parent.width - sectionTitle.implicitWidth - Style.spaceM)
      height: 1
      anchors.verticalCenter: sectionTitle.verticalCenter
      color: Color.mOutlineVariant
      opacity: 0.3
    }
  }

  Column {
    width: parent.width
    spacing: Style.spaceS

    Text {
      text: "Wallpaper Directories"
      color: Color.mOnSurfaceVariant
      font.pixelSize: Style.fontXS
      font.weight: Font.Medium
    }

    Column {
      width: parent.width
      spacing: Style.spaceXS

      Text {
        visible: !root.wallpaperDirs || root.wallpaperDirs.length === 0
        text: "No wallpaper directories configured"
        color: Color.mOutline
        font.pixelSize: Style.fontXS
        font.italic: true
      }

      Repeater {
        model: root.wallpaperDirs || []

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
            anchors.verticalCenter: parent.verticalCenter
          }

          MouseArea {
            width: 22
            height: 22
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            Rectangle {
              anchors.fill: parent
              radius: Style.radiusXS
              color: parent.containsMouse ? Qt.rgba(1.0, 0.33, 0.33, 0.15) : "transparent"
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
              const dirs = (root.wallpaperDirs || []).slice();
              dirs.splice(index, 1);
              root.settingChanged("wallpaperDirs", dirs);
            }
          }
        }
      }
    }

    MouseArea {
      width: parent.width
      height: 28
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true

      Rectangle {
        anchors.fill: parent
        radius: Style.radiusS
        color: parent.containsMouse ? root._withAlpha(Color.mPrimary, 0.12) : "transparent"
        border.color: parent.containsMouse ? Color.mPrimary : Color.mOutline
        border.width: Style.borderS
        Behavior on color {
          ColorAnimation {
            duration: Style.animVeryFast
          }
        }
        Behavior on border.color {
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
      if (!path || path.trim().length === 0)
        return;
      const dirs = (root.wallpaperDirs || []).slice();
      if (dirs.indexOf(path) === -1) {
        dirs.push(path);
        root.settingChanged("wallpaperDirs", dirs);
      }
    }
  }

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

      onClicked: cachePicker.openPicker(root.cacheDir)
    }
  }

  FolderPicker {
    id: cachePicker
    title: "Select Cache Folder"
    onAccepted: function (path) {
      if (path && path.trim().length > 0) {
        root.settingChanged("cacheDir", path.trim());
      }
    }
  }
}
