import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
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

  width: contentRow.implicitWidth + Style.space2L
  height: Style.barHeight

  // Background Pill
  Rectangle {
    anchors.fill: parent
    radius: Style.radiusXL
    color: Color.mSurfaceContainerLowest
  }

  // Content Row
  RowLayout {
    id: contentRow
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: Style.barSidePadding
    anchors.right: parent.right
    anchors.rightMargin: Style.barSidePadding
    spacing: Style.barInnerSpacing

    // Search Input
    Rectangle {
      Layout.alignment: Qt.AlignVCenter
      Layout.minimumWidth: Style.barSearchMinWidth
      Layout.preferredWidth: Math.max(Style.barSearchMinWidth, searchInput.baseWidth + Style.space2M)
      Layout.preferredHeight: Style.barSearchHeight
      radius: Style.radiusXL
      color: Color.mSurfaceContainer

      TextInput {
        id: searchInput
        anchors.fill: parent
        anchors.leftMargin: Style.spaceL
        anchors.rightMargin: Style.spaceL
        anchors.verticalCenter: parent.verticalCenter
        text: root.searchText
        onTextChanged: root.searchInputChanged(text)
        color: Color.mOnSurface
        font.pixelSize: Style.barSearchInputFontSize
        cursorVisible: activeFocus
        selectByMouse: true

        property real baseWidth: Style.barSearchWidthBase

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
        font.pixelSize: Style.barSearchPlaceholderFontSize
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
      Layout.preferredWidth: Style.borderS
      Layout.preferredHeight: Style.barDividerHeight
      color: Color.mOutlineVariant
      opacity: Style.opacityDivider
    }

    // Folder Tabs
    Repeater {
      model: root.folders
      delegate: MouseArea {
        required property string modelData
        property bool isActive: root.activeFolder === modelData
        width: tabLabel.implicitWidth + Style.space2L
        height: Style.barTabHeight

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusXL
          color: parent.isActive ? Color.mPrimary : "transparent"
          opacity: parent.isActive ? Style.opacityLight : Style.opacityFull
          Behavior on color { ColorAnimation { duration: Style.animFast } }
          Behavior on opacity { NumberAnimation { duration: Style.animFast } }
        }

        Text {
          id: tabLabel
          anchors.centerIn: parent
          text: modelData
          color: parent.isActive ? Color.mOnPrimaryContainer : Color.mOutlineVariant
          font.pixelSize: Style.barTabFontSize
          font.weight: parent.isActive ? Font.Bold : Font.Normal
          Behavior on color { ColorAnimation { duration: Style.animFast } }
        }
        onClicked: root.folderClicked(modelData)
      }
    }

    // Divider
    Rectangle {
      Layout.preferredWidth: Style.borderS
      Layout.preferredHeight: Style.barDividerHeight
      color: Color.mOutlineVariant
      opacity: Style.opacityDivider
      visible: root.folders.length > 0
    }

    // Info Text
    Text {
      Layout.alignment: Qt.AlignVCenter
      text: root.wallpaperCount + " / " + root.cachedCount
      color: Color.mOutlineVariant
      font.pixelSize: Style.barInfoFontSize
    }

    // Settings Button
    MouseArea {
      Layout.preferredWidth: Style.barSettingsBtnWidth
      Layout.preferredHeight: Style.barSettingsBtnHeight
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: root.settingsToggled()

      property bool hover: containsMouse

      Rectangle {
        anchors.fill: parent
        radius: Style.radiusXS
        color: parent.hover ? Color.mSurfaceContainerHigh : "transparent"
        Behavior on color { ColorAnimation { duration: Style.animFast } }
      }

      Image {
        id: settingsIcon
        anchors.centerIn: parent
        width: Style.barSettingsIconSize
        height: Style.barSettingsIconSize
        source: Qt.resolvedUrl("../assets/nixos-logo.svg")
        sourceSize.width: Style.barSettingsIconSize
        sourceSize.height: Style.barSettingsIconSize
        fillMode: Image.PreserveAspectFit
        mipmap: true
        layer.enabled: true
        layer.effect: MultiEffect {
          colorization: 1.0
          colorizationColor: root.settingsOpen ? Color.mPrimary : Color.mOutlineVariant
          Behavior on colorizationColor {
            ColorAnimation {
              duration: Style.animFast
            }
          }
        }
      }
    }
  }
}
