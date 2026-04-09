import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import qs.services

Popup {
  id: root

  property string title: "Select Folder"
  property string initialPath: Quickshell.env("HOME") || "/home"
  property string selectedPath: ""

  signal accepted(string path)
  signal cancelled

  width: Math.round(560 * Style.uiScaleRatio)
  height: Math.round(420 * Style.uiScaleRatio)
  modal: true
  closePolicy: Popup.CloseOnEscape
  anchors.centerIn: parent

  background: Rectangle {
    color: Color.mSurface
    radius: Style.radiusL
    border.color: Color.mOutline
    border.width: Style.borderS
  }

  function openPicker(startPath) {
    if (startPath) {
      root.selectedPath = startPath;
      folderModel.folder = "file://" + startPath;
      currentPath = startPath;
    } else {
      root.selectedPath = root.initialPath;
      folderModel.folder = "file://" + root.initialPath;
      currentPath = root.initialPath;
    }
    open();
  }

  property string currentPath: initialPath

  FolderListModel {
    id: folderModel
    folder: "file://" + root.currentPath
    showDirs: true
    showFiles: false
    showHidden: false
    showDotAndDotDot: false
    sortField: FolderListModel.Name

    onFolderChanged: {
      root.currentPath = folder.toString().replace("file://", "");
    }
  }

  Column {
    anchors.fill: parent
    anchors.margins: Style.spaceL
    spacing: Style.spaceM

    // ── Header ──
    Row {
      width: parent.width
      spacing: Style.spaceM

      Text {
        text: root.title
        font.pixelSize: Style.fontL
        font.weight: Font.Bold
        color: Color.mOnSurface
        width: parent.width * 0.3
        elide: Text.ElideRight
      }

      Text {
        id: pathText
        text: root.currentPath
        font.pixelSize: Style.fontXS
        color: Color.mOnSurfaceVariant
        elide: Text.ElideMiddle
        width: parent.width * 0.7
      }
    }

    // ── Navigation toolbar ──
    Row {
      width: parent.width
      spacing: Style.spaceS

      // Up button
      MouseArea {
        width: 32; height: 32
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusS
          color: parent.containsMouse ? Qt.alpha(Color.mPrimary, 0.12) : Color.mSurfaceContainerHigh
          border.color: Color.mOutline
          border.width: Style.borderS
          Behavior on color { ColorAnimation { duration: Style.animVeryFast } }
        }

        Text {
          anchors.centerIn: parent
          text: "\uf062"
          font.pixelSize: Style.fontM
          font.family: "Symbols Nerd Font"
          color: parent.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
        }

        onClicked: {
          folderModel.folder = "file://" + folderModel.parentFolder.toString().replace("file://", "");
        }
      }

      // Home button
      MouseArea {
        width: 32; height: 32
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusS
          color: parent.containsMouse ? Qt.alpha(Color.mPrimary, 0.12) : Color.mSurfaceContainerHigh
          border.color: Color.mOutline
          border.width: Style.borderS
          Behavior on color { ColorAnimation { duration: Style.animVeryFast } }
        }

        Text {
          anchors.centerIn: parent
          text: "\uf015"
          font.pixelSize: Style.fontM
          font.family: "Symbols Nerd Font"
          color: parent.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
        }

        onClicked: {
          var home = Quickshell.env("HOME");
          folderModel.folder = "file://" + home;
          root.currentPath = home;
        }
      }

      // Path input
      TextField {
        width: parent.width - 100
        height: 32
        text: root.currentPath
        font.pixelSize: Style.fontS
        color: Color.mOnSurface
        placeholderText: "/path/to/folder"
        placeholderTextColor: Color.mOnSurfaceVariant
        background: Rectangle {
          radius: Style.radiusS
          color: Color.mSurfaceContainer
          border.color: parent.parent.activeFocus ? Color.mPrimary : Color.mOutline
          border.width: Style.borderS
        }
        onAccepted: {
          folderModel.folder = "file://" + text;
          root.currentPath = text;
        }
      }
    }

    // ── Folder list ──
    Rectangle {
      width: parent.width
      height: parent.height - 180
      color: Color.mSurfaceContainer
      radius: Style.radiusM
      border.color: Color.mOutlineVariant
      border.width: Style.borderS

      ListView {
        id: folderListView
        anchors.fill: parent
        anchors.margins: Style.spaceXS
        model: folderModel
        clip: true

        delegate: MouseArea {
          width: folderListView.width - Style.spaceS
          height: Style.spaceXL * 2
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          Rectangle {
            anchors.fill: parent
            anchors.margins: Style.spaceXXS
            radius: Style.radiusS
            color: {
              if (root.selectedPath === model.filePath)
                return Qt.tint(Color.mPrimary, Qt.rgba(1, 1, 1, 0.08));
              if (parent.containsMouse)
                return Color.mSurfaceContainerHighest;
              return "transparent";
            }
            border.color: root.selectedPath === model.filePath ? Color.mPrimary : "transparent"
            border.width: Style.borderS
            Behavior on color { ColorAnimation { duration: Style.animVeryFast } }
          }

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.spaceM
            anchors.rightMargin: Style.spaceM
            spacing: Style.spaceM

            Text {
              text: "\uf07b"
              font.family: "Symbols Nerd Font"
              font.pixelSize: Style.fontL
              color: root.selectedPath === model.filePath ? Color.mPrimary : Color.mOnSurfaceVariant
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: model.fileName
              font.pixelSize: Style.fontM
              font.weight: root.selectedPath === model.filePath ? Font.Bold : Font.Normal
              color: root.selectedPath === model.filePath ? Color.mPrimary : Color.mOnSurface
              elide: Text.ElideMiddle
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - 40
            }
          }

          onClicked: root.selectedPath = model.filePath

          onDoubleClicked: {
            folderModel.folder = "file://" + model.filePath;
            root.currentPath = model.filePath;
            root.selectedPath = model.filePath;
          }
        }
      }
    }

    // ── Footer buttons ──
    Row {
      width: parent.width
      spacing: Style.spaceM

      Item { width: parent.width - 180; height: 1 }

      // Cancel
      MouseArea {
        id: cancelBtn
        width: 80; height: 32
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: { root.cancelled(); root.close(); }

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusS
          color: cancelBtn.containsMouse ? Color.mSurfaceContainerHighest : "transparent"
          border.color: Color.mOutline
          border.width: Style.borderS
          Behavior on color { ColorAnimation { duration: Style.animVeryFast } }
        }

        Text {
          anchors.centerIn: parent
          text: "Cancel"
          font.pixelSize: Style.fontM
          color: Color.mOnSurface
        }
      }

      // Select
      MouseArea {
        id: selectBtn
        width: 80; height: 32
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        enabled: root.selectedPath !== ""
        onClicked: { root.accepted(root.selectedPath); root.close(); }

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusS
          color: selectBtn.enabled
            ? (selectBtn.containsMouse ? Color.mPrimaryContainer : Color.mPrimary)
            : Color.mSurfaceContainerLow
          Behavior on color { ColorAnimation { duration: Style.animVeryFast } }
        }

        Text {
          anchors.centerIn: parent
          text: "Select"
          font.pixelSize: Style.fontM
          font.weight: Font.Bold
          color: selectBtn.enabled ? Color.mOnPrimary : Color.mOnSurfaceVariant
        }
      }
    }
  }
}
