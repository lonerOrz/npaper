import QtQuick
import qs.services

Item {
  id: root
  anchors.fill: parent

  required property string wallpaperPath
  property int itemIndex: -1

  readonly property var adapter: ServiceLocator.adapter
  readonly property var folders: adapter ? adapter.folders : []
  readonly property string currentFolder: adapter ? adapter.currentFolder : ""

  property bool confirmDelete: false
  property bool showFolderList: false

  onVisibleChanged: {
    if (!visible) {
      confirmDelete = false;
      showFolderList = false;
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: root.parent ? (root.parent.radius || 0) : 0
    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.20) }
      GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.70) }
    }
  }

  Row {
    anchors.centerIn: parent
    spacing: Style.spaceM
    visible: !root.showFolderList

    Rectangle {
      id: btnMove
      width: 96
      height: 32
      radius: height / 2
      color: moveMouse.containsMouse ? Color.mPrimary : Qt.rgba(Color.mSurfaceContainerLowest.r, Color.mSurfaceContainerLowest.g, Color.mSurfaceContainerLowest.b, 0.6)
      border.width: moveMouse.containsMouse ? 0 : 1
      border.color: moveMouse.containsMouse ? "transparent" : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.3)
      scale: moveMouse.containsMouse ? 1.05 : 1.0

      Behavior on scale { NumberAnimation { duration: 100 } }
      Behavior on color { ColorAnimation { duration: 100 } }

      Text {
        anchors.centerIn: parent
        text: "\uf07b  Move"
        font.pixelSize: Style.fontXS
        font.family: "Symbols Nerd Font"
        font.weight: Font.Bold
        color: moveMouse.containsMouse ? Color.mSurfaceContainerLowest : Color.mOnSurface
      }

      MouseArea {
        id: moveMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.showFolderList = true
      }
    }

    Rectangle {
      id: btnDelete
      width: 96
      height: 32
      radius: height / 2
      color: {
        if (root.confirmDelete) return "#ef4444"
        if (deleteMouse.containsMouse) return "#ef4444"
        return Qt.rgba(Color.mSurfaceContainerLowest.r, Color.mSurfaceContainerLowest.g, Color.mSurfaceContainerLowest.b, 0.6)
      }
      border.width: (root.confirmDelete || deleteMouse.containsMouse) ? 0 : 1
      border.color: (root.confirmDelete || deleteMouse.containsMouse) ? "transparent" : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.3)
      scale: deleteMouse.containsMouse ? 1.05 : 1.0

      Behavior on scale { NumberAnimation { duration: 100 } }
      Behavior on color { ColorAnimation { duration: 100 } }

      Text {
        anchors.centerIn: parent
        text: root.confirmDelete ? "\uf014  Confirm?" : "\uf014  Delete"
        font.pixelSize: Style.fontXS
        font.family: "Symbols Nerd Font"
        font.weight: Font.Bold
        color: (root.confirmDelete || deleteMouse.containsMouse) ? Color.mSurfaceContainerLowest : Color.mOnSurface
      }

      MouseArea {
        id: deleteMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.confirmDelete) {
            if (root.adapter && root.wallpaperPath) {
              root.adapter.deleteWallpaper(root.wallpaperPath, root.itemIndex);
            }
          } else {
            root.confirmDelete = true;
          }
        }
      }
    }
  }

  Column {
    anchors.fill: parent
    anchors.margins: Style.spaceM
    spacing: Style.spaceS
    visible: root.showFolderList

    Row {
      width: parent.width
      spacing: Style.spaceS

      MouseArea {
        width: 24
        height: 20
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.showFolderList = false

        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: parent.containsMouse ? Qt.rgba(Color.mSurfaceContainerHigh.r, Color.mSurfaceContainerHigh.g, Color.mSurfaceContainerHigh.b, Style.childHoverAlpha) : "transparent"
        }
        Text {
          anchors.centerIn: parent
          text: "←"
          color: Color.mPrimary
          font.pixelSize: Style.fontS
          font.weight: Font.Bold
        }
      }

      Text {
        text: "Select Destination Folder"
        color: Color.mOnSurface
        font.pixelSize: Style.fontXS
        font.weight: Font.Bold
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Item {
      width: 1
      height: Style.spaceS
    }

    Flow {
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width - Style.spaceM * 2
      spacing: Style.spaceS
      layoutDirection: Qt.LeftToRight

      Repeater {
        model: root.folders

        delegate: MouseArea {
          required property string modelData
          visible: modelData !== root.currentFolder
          width: visible ? (folderText.implicitWidth + Style.spaceXL * 2) : 0
          height: Style.barSearchHeight
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: parent.containsMouse ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.25) : Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, Style.childBgAlpha)
            border.width: 1
            border.color: parent.containsMouse ? Color.mPrimary : Qt.rgba(Color.mOutlineVariant.r, Color.mOutlineVariant.g, Color.mOutlineVariant.b, Style.childBgAlpha)
            Behavior on color { ColorAnimation { duration: 100 } }
          }

          Text {
            id: folderText
            anchors.centerIn: parent
            text: modelData
            color: parent.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
            font.pixelSize: Style.fontXS
            font.weight: Font.Bold
          }

          onClicked: {
            if (root.adapter && root.wallpaperPath) {
              root.adapter.moveWallpaper(root.wallpaperPath, modelData, root.itemIndex);
            }
          }
        }
      }
    }
  }
}
