import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import qs.components.bar
import qs.components.wallpaper
import qs.services

Item {
  id: root

  required property var folders
  required property string activeFolder
  signal folderClicked(string folder)

  required property int wallpaperCount
  required property int cachedCount
  required property int queueCount

  property color dominantColor: Color.mPrimary
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
    radius: Style.barRadius
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

    // NixOS Logo
    Image {
      id: nixosLogo
      Layout.preferredWidth: Style.barLogoSize
      Layout.preferredHeight: Style.barLogoSize
      Layout.alignment: Qt.AlignVCenter
      source: Qt.resolvedUrl("../../assets/nixos-logo.svg")
      sourceSize.width: Style.barLogoSize
      sourceSize.height: Style.barLogoSize
      fillMode: Image.PreserveAspectFit
      mipmap: true
      layer.enabled: true
      layer.effect: MultiEffect {
        colorization: 1.0
        colorizationColor: root.dominantColor
        Behavior on colorizationColor {
          ColorAnimation {
            duration: Style.animFast
          }
        }
      }

      RotationAnimation on rotation {
        from: 0
        to: 360
        duration: Style.logoRotationMs
        loops: Animation.Infinite
      }
    }

    // Search Input
    Rectangle {
      Layout.alignment: Qt.AlignVCenter
      Layout.minimumWidth: Style.barSearchMinWidth
      Layout.preferredWidth: Math.max(Style.barSearchMinWidth, searchInput.baseWidth + Style.space2M)
      Layout.preferredHeight: Style.barSearchHeight
      radius: Style.barSearchHeight / 2
      color: Color.mSurfaceContainer

      TextInput {
        id: searchInput
        anchors.fill: parent
        anchors.leftMargin: Style.barTabSidePadding
        anchors.rightMargin: Style.barTabSidePadding
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

    // Folder Tabs with sliding capsule
    Item {
      id: folderTabs
      Layout.preferredWidth: tabsRow.implicitWidth + Style.spaceM
      Layout.preferredHeight: Style.barTabHeight
      Layout.alignment: Qt.AlignVCenter

      property real _pillX: 0
      property real _pillW: 0

      Connections {
        target: root
        function onActiveFolderChanged() { Qt.callLater(folderTabs._updatePill); }
      }

      // Sliding capsule indicator
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        height: Style.barTabHeight
        radius: height / 2
        color: Color.mPrimary
        opacity: Style.opacityLight

        x: folderTabs._pillX
        width: folderTabs._pillW

        Behavior on x {
          NumberAnimation {
            duration: Style.animEnter
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
          }
        }
        Behavior on width {
          NumberAnimation {
            duration: Style.animEnter
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
          }
        }
      }

      Row {
        id: tabsRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spaceS

        Repeater {
          model: root.folders
          delegate: MouseArea {
            required property string modelData
            property bool isActive: root.activeFolder === modelData
            width: tabLabel.implicitWidth + Style.barTabSidePadding * 2
            height: Style.barTabHeight
            cursorShape: Qt.PointingHandCursor

            Text {
              id: tabLabel
              text: modelData
              color: parent.isActive ? Color.mPrimary : Color.mOutlineVariant
              font.pixelSize: Style.barTabFontSize
              font.weight: parent.isActive ? Font.Bold : Font.Normal

              // Explicit centering calculation avoids anchor rounding errors
              x: (parent.width - implicitWidth) / 2
              anchors.verticalCenter: parent.verticalCenter

              Behavior on color {
                ColorAnimation {
                  duration: Style.animFast
                }
              }
            }

            onClicked: root.folderClicked(modelData)

            Component.onCompleted: {
              if (isActive) Qt.callLater(folderTabs._updatePill);
            }
          }
        }

        Component.onCompleted: Qt.callLater(folderTabs._updatePill)
      }

      function _updatePill() {
        for (let i = 0; i < tabsRow.children.length; i++) {
          const item = tabsRow.children[i];
          if (item && item.isActive) {
            _pillX = item.x;
            // Ensure capsule always has a pill shape (1.4x width:height)
            _pillW = Math.max(item.width, Style.barTabHeight * 1.4);
          }
        }
      }
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
        radius: Style.barSettingsBtnHeight / 2
        color: parent.hover ? Color.mSurfaceContainerHigh : "transparent"
        Behavior on color {
          ColorAnimation {
            duration: Style.animFast
          }
        }
      }

      Text {
        anchors.centerIn: parent
        text: "⚙"
        font.pixelSize: Style.barSettingsGearFontSize
        color: root.settingsOpen ? Color.mPrimary : Color.mOutlineVariant
        Behavior on color {
          ColorAnimation {
            duration: Style.animFast
          }
        }
      }
    }
  }
}
