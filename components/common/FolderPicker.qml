import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.services

Popup {
  id: root

  property string title: "Select Folder"
  property string initialPath: Quickshell.env("HOME") || "/home"
  property string selectedPath: ""

  signal accepted(string path)
  signal cancelled

  width: Math.round(480 * Style.uiScaleRatio)
  height: Math.round(360 * Style.uiScaleRatio)
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

  // Process for mkdir
  Process {
    id: mkdirProc
    running: false
    onExited: {
      folderModel.folder = "file://" + root.currentPath;
    }
  }

  // Process for rmdir
  Process {
    id: rmdirProc
    running: false
    onExited: {
      folderModel.folder = "file://" + root.currentPath;
    }
  }

  Column {
    anchors.fill: parent
    anchors.margins: Style.spaceM
    spacing: Style.spaceS

    // ── Header ──
    Row {
      width: parent.width
      spacing: Style.spaceM

      Text {
        text: root.title
        font.pixelSize: Style.fontM
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

    // ── Toolbar ──
    Row {
      width: parent.width
      spacing: Style.spaceXS

      Repeater {
        model: [
          {
            icon: "\uf062",
            label: "Up"
          },
          {
            icon: "\uf015",
            label: "Home"
          },
          {
            icon: "\uf07b",
            label: "New"
          }
        ]
        delegate: MouseArea {
          width: 28
          height: 28
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          Rectangle {
            anchors.fill: parent
            radius: Style.radiusS
            color: parent.containsMouse ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.12) : Qt.rgba(Color.mSurfaceContainerHigh.r, Color.mSurfaceContainerHigh.g, Color.mSurfaceContainerHigh.b, Style.childBgAlpha)
            border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, Style.childBgAlpha)
            border.width: Style.borderS
            Behavior on color {
              ColorAnimation {
                duration: Style.animVeryFast
              }
            }
          }

          Text {
            anchors.centerIn: parent
            text: modelData.icon
            font.pixelSize: Style.fontS
            font.family: "Symbols Nerd Font"
            color: parent.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
          }

          onClicked: {
            if (index === 0)
              folderModel.folder = "file://" + folderModel.parentFolder.toString().replace("file://", "");
            else if (index === 1) {
              folderModel.folder = "file://" + Quickshell.env("HOME");
              root.currentPath = Quickshell.env("HOME");
            } else if (index === 2)
              showNewFolder();
          }
        }
      }

      // Delete button
      MouseArea {
        width: 28
        height: 28
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        enabled: root.selectedPath !== ""

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusS
          color: {
            if (parent.containsMouse)
              return Qt.rgba(1.0, 0.33, 0.33, 0.15);
            return root.selectedPath !== "" ? Qt.rgba(Color.mSurfaceContainerHigh.r, Color.mSurfaceContainerHigh.g, Color.mSurfaceContainerHigh.b, Style.childBgAlpha) : "transparent";
          }
          border.color: root.selectedPath !== "" ? "#ff5555" : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, Style.childBgAlpha)
          border.width: Style.borderS
          Behavior on color {
            ColorAnimation {
              duration: Style.animVeryFast
            }
          }
        }

        Text {
          anchors.centerIn: parent
          text: "\uf014"
          font.pixelSize: Style.fontS
          font.family: "Symbols Nerd Font"
          color: root.selectedPath !== "" ? (parent.containsMouse ? "#ff5555" : Color.mOnSurfaceVariant) : Color.mOnSurfaceVariant
        }

        onClicked: {
          if (root.selectedPath !== "") {
            rmdirProc.command = ["rmdir", root.selectedPath];
            rmdirProc.running = true;
            root.selectedPath = "";
          }
        }
      }

      // Path input
      TextField {
        width: parent.width - 130
        height: 28
        text: root.currentPath
        font.pixelSize: Style.fontXS
        color: Color.mOnSurface
        placeholderText: "/path/to/folder"
        placeholderTextColor: Color.mOnSurfaceVariant
        background: Rectangle {
          radius: Style.radiusS
          color: Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, Style.childBgAlpha)
          border.color: parent.parent.activeFocus ? Color.mPrimary : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, Style.childBgAlpha)
          border.width: Style.borderS
        }
        onAccepted: {
          folderModel.folder = "file://" + text;
          root.currentPath = text;
        }
      }
    }

    // New folder input
    TextField {
      id: newFolderInput
      width: parent.width
      height: 28
      visible: false
      font.pixelSize: Style.fontXS
      placeholderText: "Enter folder name..."
      placeholderTextColor: Color.mOnSurfaceVariant
      background: Rectangle {
        radius: Style.radiusS
        color: Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, Style.childBgAlpha)
        border.color: parent.activeFocus ? Color.mPrimary : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, Style.childBgAlpha)
        border.width: Style.borderS
      }
      onAccepted: {
        if (text.trim().length > 0) {
          mkdirProc.command = ["mkdir", "-p", root.currentPath + "/" + text.trim()];
          mkdirProc.running = true;
        }
        visible = false;
        text = "";
      }
      Keys.onEscapePressed: {
        visible = false;
        text = "";
      }
    }

    // ── Folder list ──
    Rectangle {
      width: parent.width
      height: parent.height - 130
      color: Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, Style.childBgAlpha)
      radius: Style.radiusS
      border.color: Qt.rgba(Color.mOutlineVariant.r, Color.mOutlineVariant.g, Color.mOutlineVariant.b, Style.childBgAlpha)
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
                return Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.15);
              if (parent.containsMouse)
                return Qt.rgba(Color.mSurfaceContainerHighest.r, Color.mSurfaceContainerHighest.g, Color.mSurfaceContainerHighest.b, Style.childBgAlpha);
              return "transparent";
            }
            border.color: root.selectedPath === model.filePath ? Color.mPrimary : "transparent"
            border.width: Style.borderS
            Behavior on color {
              ColorAnimation {
                duration: Style.animVeryFast
              }
            }
          }

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.spaceS
            anchors.rightMargin: Style.spaceS
            spacing: Style.spaceS

            Text {
              text: "\uf07b"
              font.family: "Symbols Nerd Font"
              font.pixelSize: Style.fontM
              color: root.selectedPath === model.filePath ? Color.mPrimary : Color.mOnSurfaceVariant
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: model.fileName
              font.pixelSize: Style.fontS
              font.weight: root.selectedPath === model.filePath ? Font.Medium : Font.Normal
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
      spacing: Style.spaceS

      Item {
        width: parent.width - 120
        height: 1
      }

      // Cancel
      MouseArea {
        id: cancelBtn
        width: 55
        height: 28
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: {
          root.cancelled();
          root.close();
        }

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusS
          color: cancelBtn.containsMouse ? Qt.rgba(Color.mSurfaceContainerHighest.r, Color.mSurfaceContainerHighest.g, Color.mSurfaceContainerHighest.b, Style.childBgAlpha) : "transparent"
          border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, Style.childBgAlpha)
          border.width: Style.borderS
          Behavior on color {
            ColorAnimation {
              duration: Style.animVeryFast
            }
          }
        }

        Text {
          anchors.centerIn: parent
          text: "Cancel"
          font.pixelSize: Style.fontXS
          color: Color.mOnSurface
        }
      }

      // Select
      MouseArea {
        id: selectBtn
        width: 55
        height: 28
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        enabled: root.selectedPath !== ""
        onClicked: {
          root.accepted(root.selectedPath);
          root.close();
        }

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusS
          color: selectBtn.enabled ? (selectBtn.containsMouse ? Color.mPrimaryContainer : Color.mPrimary) : Qt.rgba(Color.mSurfaceContainerLow.r, Color.mSurfaceContainerLow.g, Color.mSurfaceContainerLow.b, Style.childBgAlpha)
          Behavior on color {
            ColorAnimation {
              duration: Style.animVeryFast
            }
          }
        }

        Text {
          anchors.centerIn: parent
          text: "Select"
          font.pixelSize: Style.fontXS
          font.weight: Font.Bold
          color: selectBtn.enabled ? Color.mOnPrimary : Color.mOnSurfaceVariant
        }
      }
    }
  }

  function showNewFolder() {
    newFolderInput.visible = true;
    newFolderInput.forceActiveFocus();
  }
}
