import QtQuick
import qs.services

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

  readonly property string dlStatus: (root.downloadStatus && root.downloadStatus[root.whId]) ? root.downloadStatus[root.whId] : ""
  readonly property real dlProgress: (root.downloadProgress && root.downloadProgress[root.whId] !== undefined) ? root.downloadProgress[root.whId] : 0.0
  readonly property bool isDownloading: dlStatus === "downloading"
  readonly property bool isError: dlStatus === "error"

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
    radius: root.parent ? (root.parent.radius || Style.radiusL) : Style.radiusL
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: Qt.rgba(0, 0, 0, 0.25)
      }
      GradientStop {
        position: 1.0
        color: Qt.rgba(0, 0, 0, 0.75)
      }
    }
  }

  Row {
    anchors.centerIn: parent
    spacing: Style.spaceM
    visible: !root.isDownloading

    Rectangle {
      id: btnDl
      width: Math.max(96, btnDlText.implicitWidth + Style.spaceL)
      height: 32
      radius: height / 2
      color: dlMouse.containsMouse ? Color.mPrimary : Qt.rgba(Color.mSurfaceContainerLowest.r, Color.mSurfaceContainerLowest.g, Color.mSurfaceContainerLowest.b, 0.65)
      border.width: dlMouse.containsMouse ? 0 : 1
      border.color: dlMouse.containsMouse ? "transparent" : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.3)
      visible: !root.isLocallyAvailable
      scale: dlMouse.containsMouse ? 1.05 : 1.0

      Behavior on scale {
        NumberAnimation {
          duration: 100
          easing.type: Easing.OutCubic
        }
      }
      Behavior on color {
        ColorAnimation {
          duration: 100
        }
      }

      Text {
        id: btnDlText
        anchors.centerIn: parent
        text: root.isError ? "\uf021  Retry" : "\uf019  Download"
        font.pixelSize: Style.fontXS
        font.family: "Symbols Nerd Font"
        font.weight: Font.Bold
        color: root.isError ? "#ff5555" : (dlMouse.containsMouse ? Color.mSurfaceContainerLowest : Color.mOnSurface)
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
      width: Math.max(96, btnApplyText.implicitWidth + Style.spaceL)
      height: 32
      radius: height / 2
      color: applyMouse.containsMouse ? Color.mPrimary : Qt.rgba(Color.mSurfaceContainerLowest.r, Color.mSurfaceContainerLowest.g, Color.mSurfaceContainerLowest.b, 0.65)
      border.width: applyMouse.containsMouse ? 0 : 1
      border.color: applyMouse.containsMouse ? "transparent" : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.3)
      scale: applyMouse.containsMouse ? 1.05 : 1.0

      Behavior on scale {
        NumberAnimation {
          duration: 100
          easing.type: Easing.OutCubic
        }
      }
      Behavior on color {
        ColorAnimation {
          duration: 100
        }
      }

      Text {
        id: btnApplyText
        anchors.centerIn: parent
        text: "\uf04b  Apply"
        font.pixelSize: Style.fontXS
        font.family: "Symbols Nerd Font"
        font.weight: Font.Bold
        color: applyMouse.containsMouse ? Color.mSurfaceContainerLowest : Color.mOnSurface
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
    spacing: Style.spaceS
    visible: root.isDownloading

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.spaceXS

      Text {
        text: "Downloading..."
        font.pixelSize: Style.fontXS
        font.weight: Font.Medium
        color: Color.mPrimary
      }

      Text {
        text: Math.round(root.dlProgress * 100) + "%"
        font.pixelSize: Style.fontXS
        font.family: "monospace"
        font.weight: Font.Bold
        color: Color.mPrimary
      }
    }

    Rectangle {
      width: 100
      height: 4
      radius: 2
      color: Qt.rgba(Color.mSurfaceContainerHighest.r, Color.mSurfaceContainerHighest.g, Color.mSurfaceContainerHighest.b, 0.6)

      Rectangle {
        width: parent.width * Math.max(0.05, Math.min(1.0, root.dlProgress))
        height: parent.height
        radius: parent.radius
        color: Color.mPrimary

        Behavior on width {
          NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }
}
