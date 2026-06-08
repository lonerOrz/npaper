import QtQuick
import qs.services

/*
* DownloadOverlay — Reusable download button overlay for wallpaper cards.
* Used by WallpaperCard.qml (CarouselView) and GridView.qml.
*
* Required inputs:
*   whId          — Wallhaven wallpaper ID (e.g., "abc123")
*   downloadPath  — Remote URL for download
*   whService     — WallhavenService instance
*   downloadStatus — Map from whService
*   downloadProgress — Map from whService
*   downloadPaths — Map from whService
*
* Signals:
*   onApplyLocal(localPath) — Emitted when Apply is clicked on a downloaded wallpaper
*/

Item {
  id: root

  anchors.fill: parent
  z: 10

  required property string whId
  required property string downloadPath
  required property var whService
  required property var downloadStatus
  required property var downloadProgress
  required property var downloadPaths

  signal applyLocal(string localPath)

  readonly property string dlStatus: root.downloadStatus[root.whId] || ""
  readonly property real dlProgress: root.downloadProgress[root.whId] || 0
  readonly property bool isDownloading: dlStatus === "downloading"

  readonly property string existingLocalPath: {
    if (root.whService && root.whService.localWallhavenPaths) {
      return root.whService.localWallhavenPaths[root.whId] || "";
    }
    return "";
  }

  readonly property string effectiveLocalPath: {
    var p = root.downloadPaths || {};
    return (p[root.whId] && p[root.whId] !== "") ? p[root.whId] : root.existingLocalPath;
  }

  readonly property bool isLocallyAvailable: dlStatus === "done" || root.effectiveLocalPath !== ""

  Rectangle {
    anchors.fill: parent
    radius: root.parent ? (root.parent.radius || 0) : 0
    color: Qt.rgba(0, 0, 0, 0.50)
  }

  Row {
    anchors.centerIn: parent
    spacing: Style.spaceXS
    visible: !root.isDownloading

    Rectangle {
      id: btnDl
      width: Math.max(85, btnDlText.implicitWidth + Style.spaceL)
      height: Style.spaceXL * 2 - Style.spaceS
      radius: height / 2
      color: dlMouse.containsMouse ? Qt.lighter(Color.mPrimary, 1.08) : Color.mPrimary
      visible: !root.isLocallyAvailable
      scale: dlMouse.containsMouse ? 1.05 : 1.0

      Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 100 } }

      Text {
        id: btnDlText
        anchors.centerIn: parent
        text: "\uf019  Download"
        font.pixelSize: Style.fontXXS
        font.family: "Symbols Nerd Font"
        font.weight: Font.Bold
        color: Color.mSurfaceContainerLowest
      }

      MouseArea {
        id: dlMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.whService && root.downloadPath)
            root.whService.downloadWallpaper(root.whId, root.downloadPath);
        }
      }
    }

    Rectangle {
      id: btnApply
      width: Math.max(85, btnApplyText.implicitWidth + Style.spaceL)
      height: Style.spaceXL * 2 - Style.spaceS
      radius: height / 2
      color: applyMouse.containsMouse ? Qt.lighter(Color.mPrimary, 1.08) : Color.mPrimary
      scale: applyMouse.containsMouse ? 1.05 : 1.0

      Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 100 } }

      Text {
        id: btnApplyText
        anchors.centerIn: parent
        text: "\uf04b  Apply"
        font.pixelSize: Style.fontXXS
        font.family: "Symbols Nerd Font"
        font.weight: Font.Bold
        color: Color.mSurfaceContainerLowest
      }

      MouseArea {
        id: applyMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (!root.whService)
            return;
          if (root.effectiveLocalPath) {
            root.applyLocal(root.effectiveLocalPath);
          } else {
            root.whService.downloadAndApply(root.whId, root.downloadPath);
          }
        }
      }
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: Style.spaceXS
    visible: root.isDownloading

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Downloading..."
      font.pixelSize: Style.fontXXS
      font.weight: Font.Medium
      color: Color.mPrimary
    }

    Rectangle {
      width: 80
      height: 3
      radius: 2
      color: Color.mSurfaceContainerHighest

      Rectangle {
        width: parent.width * root.dlProgress
        height: parent.height
        radius: parent.radius
        color: Color.mPrimary
      }
    }
  }
}
