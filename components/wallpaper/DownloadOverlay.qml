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

  // ── Required inputs ──
  required property string whId
  required property string downloadPath
  required property var whService
  required property var downloadStatus
  required property var downloadProgress
  required property var downloadPaths

  // ── Optional: local apply callback ──
  signal applyLocal(string localPath)

  // ── Internal state ──
  readonly property string dlStatus: root.downloadStatus[root.whId] || ""
  readonly property real dlProgress: root.downloadProgress[root.whId] || 0
  readonly property bool isDownloading: dlStatus === "downloading"
  readonly property string localPath: {
    var p = root.downloadPaths || {};
    return p[root.whId] || "";
  }

  // Dark overlay
  Rectangle {
    anchors.fill: parent
    radius: root.parent ? (root.parent.radius || 0) : 0
    color: Qt.rgba(0, 0, 0, 0.50)
  }

  // ── Buttons row (hidden while downloading) ──
  Row {
    anchors.centerIn: parent
    spacing: Style.spaceXS
    visible: !root.isDownloading

    // Download button
    Rectangle {
      id: btnDl
      width: Math.max(85, btnDlText.implicitWidth + Style.spaceL)
      height: Style.spaceXL * 2 - Style.spaceS
      radius: height / 2
      color: Color.mPrimary
      visible: root.dlStatus !== "done"

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
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.whService && root.downloadPath)
            root.whService.downloadWallpaper(root.whId, root.downloadPath);
        }
      }
    }

    // Apply button
    Rectangle {
      id: btnApply
      width: Math.max(85, btnApplyText.implicitWidth + Style.spaceL)
      height: Style.spaceXL * 2 - Style.spaceS
      radius: height / 2
      color: Color.mPrimary

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
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (!root.whService)
            return;
          if (root.dlStatus === "done") {
            if (root.localPath)
              root.applyLocal(root.localPath);
          } else {
            root.whService.downloadAndApply(root.whId, root.downloadPath);
          }
        }
      }
    }
  }

  // ── Downloading state ──
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
