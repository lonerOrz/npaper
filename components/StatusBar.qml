import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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
  signal searchSubmitted

  function focusSearch() {
    searchInput.forceActiveFocus();
  }

  width: contentRow.implicitWidth + 24
  height: 44

  // Background Pill
  Rectangle {
    anchors.fill: parent
    radius: 22
    color: Color.mSurfaceContainerLowest
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
      color: Color.mSurfaceContainer

      TextInput {
        id: searchInput
        anchors.fill: parent
        anchors.leftMargin: 10
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
                          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.searchSubmitted();
                            searchInput.focus = false;
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

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: searchInput.forceActiveFocus()
      }
    }

    // Divider
    Rectangle {
      Layout.preferredWidth: 1
      Layout.preferredHeight: 18
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

        Text {
          id: tabLabel
          anchors.centerIn: parent
          text: modelData
          color: parent.isActive ? Color.mPrimary : Color.mOutlineVariant
          font.pixelSize: 12
          font.weight: parent.isActive ? Font.Bold : Font.Normal
          Behavior on color {
            ColorAnimation {
              duration: 150
            }
          }
        }
        onClicked: root.folderClicked(modelData)
      }
    }

    // Divider
    Rectangle {
      Layout.preferredWidth: 1
      Layout.preferredHeight: 18
      color: Color.mOutlineVariant
      visible: root.folders.length > 0
    }

    // Info Text
    Text {
      Layout.alignment: Qt.AlignVCenter
      text: root.wallpaperCount + " / " + root.cachedCount
      color: Color.mOutlineVariant
      font.pixelSize: 11
    }

    // Settings Button
    MouseArea {
      Layout.preferredWidth: 32
      Layout.preferredHeight: 28
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: root.settingsToggled()

      property bool hover: containsMouse

      Rectangle {
        anchors.fill: parent
        radius: 8
        color: parent.hover ? Color.mSurfaceContainerHigh : "transparent"
        Behavior on color {
          ColorAnimation {
            duration: 150
          }
        }
      }

      Image {
        id: settingsIcon
        anchors.centerIn: parent
        width: 16
        height: 16
        source: Qt.resolvedUrl("../assets/settings.svg")
        sourceSize.width: 16
        sourceSize.height: 16
        fillMode: Image.PreserveAspectFit
        mipmap: true
        layer.enabled: true
        layer.effect: MultiEffect {
          colorization: 1.0
          colorizationColor: root.settingsOpen ? Color.mPrimary : Color.mOutlineVariant
          Behavior on colorizationColor {
            ColorAnimation {
              duration: 150
            }
          }
        }
      }
    }
  }
}
