import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.services

Popup {
  id: pickerRoot

  property string title: "Select Folder"
  property string initialPath: Quickshell.env("HOME") || "/home"
  property string selectedPath: ""
  property string currentPath: initialPath

  signal accepted(string path)
  signal cancelled

  width: Math.round(520 * Style.uiScaleRatio)
  height: Math.round(380 * Style.uiScaleRatio)
  modal: true
  focus: true
  closePolicy: Popup.CloseOnEscape
  anchors.centerIn: parent

  background: Rectangle {
    color: Color.mSurface
    radius: Style.radiusL
    border.color: Color.mOutlineVariant
    border.width: Style.borderS

    Rectangle {
      anchors.fill: parent
      anchors.margins: -4
      radius: parent.radius + 2
      color: Color.mShadow
      opacity: 0.3
      z: -1
    }
  }

  FolderListModel {
    id: folderModel
    folder: ""
    showDirs: true
    showFiles: false
    showHidden: false
    showDotAndDotDot: false
    sortField: FolderListModel.Name

    onFolderChanged: {
      if (folder.toString().length > 0) {
        pickerRoot.currentPath = _urlToPath(folder.toString());
      }
    }
  }

  function _urlToPath(urlStr) {
    if (!urlStr)
      return "";
    var clean = urlStr.toString().replace("file://", "");
    return decodeURIComponent(clean);
  }

  function _pathToUrl(p) {
    return Qt.resolvedUrl("file://" + encodeURI(p));
  }

  function openPicker(startPath) {
    const target = (startPath && startPath.trim().length > 0) ? startPath.trim() : pickerRoot.initialPath;
    pickerRoot.selectedPath = target;
    pickerRoot.currentPath = target;
    folderModel.folder = _pathToUrl(target);
    open();
  }

  onClosed: {
    folderModel.folder = "";
  }

  Process {
    id: mkdirProc
    running: false
    onExited: function (code) {
      if (code === 0) {
        _forceRefresh();
      }
    }
  }

  Process {
    id: rmdirProc
    running: false
    onExited: function (code) {
      if (code === 0) {
        pickerRoot.selectedPath = "";
        _forceRefresh();
      }
    }
  }

  function _forceRefresh() {
    const curr = folderModel.folder;
    folderModel.folder = "";
    Qt.callLater(function () {
      folderModel.folder = curr;
    });
  }

  Column {
    anchors.fill: parent
    anchors.margins: Style.spaceM
    spacing: Style.spaceS

    Row {
      width: parent.width
      spacing: Style.spaceM

      Text {
        text: pickerRoot.title
        font.pixelSize: Style.fontM
        font.weight: Font.Bold
        color: Color.mOnSurface
        width: parent.width * 0.3
        elide: Text.ElideRight
      }

      Text {
        text: pickerRoot.currentPath
        font.pixelSize: Style.fontXS
        font.family: "monospace"
        color: Color.mOnSurfaceVariant
        elide: Text.ElideMiddle
        width: parent.width * 0.7
      }
    }

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
            if (index === 0) {
              const parentUrl = folderModel.parentFolder.toString();
              if (parentUrl.length > 0)
                folderModel.folder = parentUrl;
            } else if (index === 1) {
              const home = Quickshell.env("HOME") || "/";
              folderModel.folder = _pathToUrl(home);
            } else if (index === 2) {
              showNewFolder();
            }
          }
        }
      }

      MouseArea {
        width: 28
        height: 28
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        enabled: pickerRoot.selectedPath !== ""

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusS
          color: {
            if (parent.containsMouse)
              return Qt.rgba(1.0, 0.33, 0.33, 0.15);
            return pickerRoot.selectedPath !== "" ? Qt.rgba(Color.mSurfaceContainerHigh.r, Color.mSurfaceContainerHigh.g, Color.mSurfaceContainerHigh.b, Style.childBgAlpha) : "transparent";
          }
          border.color: pickerRoot.selectedPath !== "" ? "#ff5555" : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, Style.childBgAlpha)
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
          color: pickerRoot.selectedPath !== "" ? (parent.containsMouse ? "#ff5555" : Color.mOnSurfaceVariant) : Color.mOnSurfaceVariant
        }

        onClicked: {
          if (pickerRoot.selectedPath !== "") {
            rmdirProc.command = ["rmdir", pickerRoot.selectedPath];
            rmdirProc.exec({});
          }
        }
      }

      TextField {
        width: parent.width - 130
        height: 28
        text: pickerRoot.currentPath
        font.pixelSize: Style.fontXS
        font.family: "monospace"
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
          if (text.trim().length > 0)
            folderModel.folder = _pathToUrl(text.trim());
        }
      }
    }

    TextField {
      id: newFolderInput
      width: parent.width
      height: 28
      visible: false
      font.pixelSize: Style.fontXS
      placeholderText: "Enter new folder name..."
      placeholderTextColor: Color.mOnSurfaceVariant
      background: Rectangle {
        radius: Style.radiusS
        color: Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, Style.childBgAlpha)
        border.color: parent.activeFocus ? Color.mPrimary : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, Style.childBgAlpha)
        border.width: Style.borderS
      }
      onAccepted: {
        const name = text.trim();
        if (name.length > 0) {
          mkdirProc.command = ["mkdir", "-p", pickerRoot.currentPath + "/" + name];
          mkdirProc.exec({});
        }
        visible = false;
        text = "";
      }
      Keys.onEscapePressed: {
        visible = false;
        text = "";
      }
    }

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
              if (pickerRoot.selectedPath === model.filePath)
                return Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.15);
              if (parent.containsMouse)
                return Qt.rgba(Color.mSurfaceContainerHighest.r, Color.mSurfaceContainerHighest.g, Color.mSurfaceContainerHighest.b, Style.childBgAlpha);
              return "transparent";
            }
            border.color: pickerRoot.selectedPath === model.filePath ? Color.mPrimary : "transparent"
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
              color: pickerRoot.selectedPath === model.filePath ? Color.mPrimary : Color.mOnSurfaceVariant
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: model.fileName
              font.pixelSize: Style.fontS
              font.weight: pickerRoot.selectedPath === model.filePath ? Font.Medium : Font.Normal
              color: pickerRoot.selectedPath === model.filePath ? Color.mPrimary : Color.mOnSurface
              elide: Text.ElideMiddle
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - 40
            }
          }

          onClicked: pickerRoot.selectedPath = model.filePath

          onDoubleClicked: {
            folderModel.folder = Qt.resolvedUrl("file://" + model.filePath);
            pickerRoot.currentPath = model.filePath;
            pickerRoot.selectedPath = model.filePath;
          }
        }
      }
    }

    Row {
      width: parent.width
      spacing: Style.spaceS

      Item {
        width: parent.width - 130
        height: 1
      }

      MouseArea {
        id: cancelBtn
        width: 60
        height: 28
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: {
          pickerRoot.cancelled();
          pickerRoot.close();
        }

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusS
          color: cancelBtn.containsMouse ? Qt.rgba(Color.mSurfaceContainerHighest.r, Color.mSurfaceContainerHighest.g, Color.mSurfaceContainerHighest.b, Style.childBgAlpha) : "transparent"
          border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, Style.childBgAlpha)
          border.width: Style.borderS
        }

        Text {
          anchors.centerIn: parent
          text: "Cancel"
          font.pixelSize: Style.fontXS
          color: Color.mOnSurface
        }
      }

      MouseArea {
        id: selectBtn
        width: 60
        height: 28
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        enabled: pickerRoot.selectedPath !== ""
        onClicked: {
          pickerRoot.accepted(pickerRoot.selectedPath);
          pickerRoot.close();
        }

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusS
          color: selectBtn.enabled ? (selectBtn.containsMouse ? Color.mPrimaryContainer : Color.mPrimary) : Qt.rgba(Color.mSurfaceContainerLow.r, Color.mSurfaceContainerLow.g, Color.mSurfaceContainerLow.b, Style.childBgAlpha)
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
