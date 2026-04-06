import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.utils

Item {
  id: root

  required property var folders
  required property string activeFolder
  signal folderClicked(string folder)

  required property int wallpaperCount
  required property int cachedCount
  required property int queueCount

  property bool settingsOpen: false
  signal settingsToggled

  property string searchText: ""
  signal searchInputChanged(string text)
  signal searchCleared

  // Width is determined by content + margins
  // This prevents the bar from being too wide and having empty background space
  width: contentRow.implicitWidth + 24
  height: 44

  // Background Pill
  Rectangle {
    anchors.fill: parent
    radius: 22
    color: Color.mSurfaceContainerLowest
    border.color: Color.mOutlineVariant
    border.width: 1

    // Inner highlight
    Rectangle {
      anchors.fill: parent
      radius: 22
      color: "transparent"
      border.color: Color.mInverseSurface
      border.width: 1
      opacity: 0.05
    }
  }

  // Content Row
  RowLayout {
    id: contentRow
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: 12
    spacing: 8

    // Search Input
    Rectangle {
      Layout.alignment: Qt.AlignVCenter
      Layout.minimumWidth: 140
      Layout.preferredWidth: Math.max(140, searchInput.baseWidth + 16)
      Layout.preferredHeight: 28
      radius: 14
      color: Color.mSurfaceContainerHigh
      border.color: searchInput.activeFocus ? Color.mPrimaryContainer : Color.mOutlineVariant
      border.width: 1

      TextInput {
        id: searchInput
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.searchText
        onTextChanged: root.searchInputChanged(text)
        color: Color.mOnSurface
        font.pixelSize: 12
        cursorVisible: activeFocus
        selectByMouse: true

        property real baseWidth: 120

        Keys.onPressed: event => {
                          if (event.key === Qt.Key_Escape) {
                            root.searchCleared();
                            event.accepted = true;
                          }
                        }
      }

      Text {
        anchors.centerIn: parent
        text: "Type to search..."
        color: Color.mOutline
        font.pixelSize: 12
        visible: !searchInput.text && !searchInput.activeFocus
      }

      TapHandler {
        onTapped: searchInput.forceActiveFocus()
      }
    }

    // Divider
    Rectangle {
      Layout.preferredWidth: 1
      Layout.preferredHeight: 20
      color: Color.mOutlineVariant
    }

    // Folder Tabs
    Repeater {
      model: root.folders
      delegate: MouseArea {
        required property string modelData
        property bool isActive: root.activeFolder === modelData
        width: tabLabel.implicitWidth + 16
        height: 28

        Rectangle {
          anchors.fill: parent
          radius: 14
          color: isActive ? Color.mPrimaryContainer : "transparent"
          opacity: isActive ? 0.2 : 1.0
        }

        Text {
          id: tabLabel
          anchors.centerIn: parent
          text: modelData
          color: isActive ? Color.mOnPrimaryContainer : Color.mOutlineVariant
          font.pixelSize: 12
          font.weight: isActive ? Font.Bold : Font.Medium
        }
        onClicked: root.folderClicked(modelData)
      }
    }

    // Divider
    Rectangle {
      Layout.preferredWidth: 1
      Layout.preferredHeight: 20
      color: Color.mOutlineVariant
      visible: root.folders.length > 0
    }

    // Info Text (Follows Divider immediately)
    Text {
      Layout.alignment: Qt.AlignVCenter
      text: "Wallpapers: " + root.wallpaperCount + "  |  Cache: " + root.cachedCount
      color: Color.mOutlineVariant
      font.pixelSize: 11
      // font.family: "monospace"
    }

    // Settings Button
    MouseArea {
      Layout.preferredWidth: 32
      Layout.preferredHeight: 32
      cursorShape: Qt.PointingHandCursor
      onClicked: root.settingsToggled()

      Rectangle {
        anchors.centerIn: parent
        width: 32
        height: 32
        radius: 16
        color: settingsHover.containsMouse ? Color.mSurfaceContainerHigh : "transparent"
        MouseArea {
          id: settingsHover
          anchors.fill: parent
          hoverEnabled: true
        }
        Behavior on color {
          ColorAnimation {
            duration: 150
          }
        }
      }

      Text {
        anchors.centerIn: parent
        text: "⚙"
        font.pixelSize: 15
        color: root.settingsOpen ? Color.mPrimaryContainer : Color.mOutlineVariant
      }
    }
  }
}
