import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.components.common
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

  property bool isWallhaven: false
  signal wallhavenToggled

  property string searchText: ""
  signal searchInputChanged(string text)
  signal searchCleared
  signal searchSubmitted

  function focusSearch() {
    searchInput.forceActiveFocus();
  }

  // Fixed height, single row
  height: Style.barHeight
  width: contentRow.implicitWidth + Style.space2L

  // ── Background Pill ──────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    radius: Style.barRadius
    color: Qt.rgba(Color.mSurfaceContainerLowest.r, Color.mSurfaceContainerLowest.g, Color.mSurfaceContainerLowest.b, Style.barBlurAlpha)
  }

  // ── Content Row ──────────────────────────────────────────
  RowLayout {
    id: contentRow
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Style.barSidePadding
    spacing: Style.barInnerSpacing

    // NixOS Logo
    Image {
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
        colorizationColor: Qt.lighter(root.dominantColor, 3.0)
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
      color: Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, Style.childBgAlpha)

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
        verticalAlignment: TextInput.AlignVCenter
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
        text: root.isWallhaven ? "Search Wallhaven..." : "Type to search..."
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

    // View Mode Pill
    SelectorPill {
      model: ["Carousel", "Grid"]
      activeIndex: Config.previewStyle === "grid" ? 1 : 0
      onSelected: function (index, label) {
        Config.update("previewStyle", label.toLowerCase());
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
    SelectorPill {
      model: root.folders
      activeIndex: root.folders.indexOf(root.activeFolder)
      activeColor: Color.mPrimary
      visible: !root.isWallhaven
      onSelected: function (index, label) {
        root.folderClicked(label);
      }
    }

    // Wallhaven Button
    MouseArea {
      Layout.preferredWidth: Style.barSettingsBtnWidth
      Layout.preferredHeight: Style.barSettingsBtnHeight
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: root.wallhavenToggled()

      property bool hover: containsMouse

      Rectangle {
        anchors.fill: parent
        radius: Style.barSettingsBtnHeight / 2
        color: parent.hover ? Qt.rgba(Color.mSurfaceContainerHigh.r, Color.mSurfaceContainerHigh.g, Color.mSurfaceContainerHigh.b, Style.childHoverAlpha) : "transparent"
        Behavior on color {
          ColorAnimation {
            duration: Style.animFast
          }
        }
      }

      Text {
        anchors.centerIn: parent
        // fa-globe when on Wallhaven, fa-picture when local
        text: root.isWallhaven ? "\uf0ac" : "\uf03e"
        font.pixelSize: Style.barSettingsIconSize
        font.family: "Symbols Nerd Font"
        color: root.isWallhaven ? Color.mPrimary : Color.mOnSurface
      }
    }

    // Info Text
    Text {
      Layout.alignment: Qt.AlignVCenter
      text: root.wallpaperCount + " / " + root.cachedCount
      color: Color.mOnSurface
      font.pixelSize: Style.barInfoFontSize
    }

    // Queue Count
    Text {
      Layout.alignment: Qt.AlignVCenter
      text: root.queueCount > 0 ? "\uf251 " + root.queueCount : ""
      color: Color.mPrimary
      font.pixelSize: Style.barInfoFontSize
      font.family: "Symbols Nerd Font"
      visible: root.queueCount > 0
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
        color: parent.hover ? Qt.rgba(Color.mSurfaceContainerHigh.r, Color.mSurfaceContainerHigh.g, Color.mSurfaceContainerHigh.b, Style.childHoverAlpha) : "transparent"
        Behavior on color {
          ColorAnimation {
            duration: Style.animFast
          }
        }
      }

      Text {
        anchors.centerIn: parent
        text: "\uf013"
        font.pixelSize: Style.barSettingsIconSize
        font.family: "Symbols Nerd Font"
        color: root.settingsOpen ? Color.mPrimary : Color.mOnSurface
        Behavior on color {
          ColorAnimation {
            duration: Style.animFast
          }
        }
      }
    }
  }
}
