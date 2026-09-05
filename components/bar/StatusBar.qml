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

  readonly property bool searchActiveFocus: searchInput.activeFocus

  function focusSearch() {
    searchInput.forceActiveFocus();
  }

  readonly property var _previewLabels: ["Carousel", "Grid", "Slanted"]

  height: Style.barHeight
  implicitWidth: contentRow.implicitWidth + Style.space2L
  width: implicitWidth

  Rectangle {
    anchors.fill: parent
    radius: Style.barRadius
    color: Qt.rgba(Color.mSurfaceContainerLowest.r, Color.mSurfaceContainerLowest.g, Color.mSurfaceContainerLowest.b, Style.barBlurAlpha)
  }

  RowLayout {
    id: contentRow
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Style.barSidePadding
    spacing: Style.barInnerSpacing

    Item {
      Layout.preferredWidth: Style.barLogoSize
      Layout.preferredHeight: Style.barLogoSize
      Layout.alignment: Qt.AlignVCenter

      RotationAnimation on rotation {
        from: 0
        to: 360
        duration: Style.logoRotationMs
        loops: Animation.Infinite
      }

      Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../../assets/nixos-logo.svg")
        sourceSize.width: Style.barLogoSize
        sourceSize.height: Style.barLogoSize
        fillMode: Image.PreserveAspectFit
        mipmap: false

        layer.enabled: true
        layer.effect: MultiEffect {
          colorization: 1.0
          colorizationColor: Qt.lighter(root.dominantColor, 1.5)
        }
      }
    }

    Rectangle {
      Layout.alignment: Qt.AlignVCenter
      Layout.minimumWidth: Style.barSearchMinWidth
      Layout.preferredWidth: Math.max(Style.barSearchMinWidth, searchInput.baseWidth + Style.space2M)
      Layout.preferredHeight: Style.barSearchHeight
      radius: Style.barSearchHeight / 2
      color: Qt.rgba(Color.mSurfaceContainer.r, Color.mSurfaceContainer.g, Color.mSurfaceContainer.b, Style.childBgAlpha)
      border.width: searchInput.activeFocus ? 2 : 1
      border.color: searchInput.activeFocus ? Color.mPrimary : Qt.rgba(Color.mOutlineVariant.r, Color.mOutlineVariant.g, Color.mOutlineVariant.b, 0.2)

      Behavior on border.color {
        ColorAnimation {
          duration: 150
        }
      }
      Behavior on border.width {
        NumberAnimation {
          duration: 150
        }
      }

      Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: parent.radius + 2
        color: Color.mPrimary
        opacity: searchInput.activeFocus ? 0.08 : 0
        visible: opacity > 0.01
        Behavior on opacity {
          NumberAnimation {
            duration: 150
          }
        }
      }

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

    SelectorPill {
      model: root._previewLabels
      activeIndex: Math.max(0, Config.previewModes.indexOf(Config.previewStyle))
      onSelected: function (index, label) {
        Config.update("previewStyle", Config.previewModes[index]);
      }
    }

    Rectangle {
      Layout.preferredWidth: Style.borderS
      Layout.preferredHeight: Style.barDividerHeight
      color: Color.mOutlineVariant
      opacity: Style.opacityDivider
    }

    SelectorPill {
      model: root.folders
      activeIndex: Math.max(0, root.folders ? root.folders.indexOf(root.activeFolder) : 0)
      activeColor: Color.mPrimary
      visible: !root.isWallhaven && root.folders && root.folders.length > 0
      onSelected: function (index, label) {
        root.folderClicked(label);
      }
    }

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
        text: root.isWallhaven ? "\uf0ac" : "\uf03e"
        font.pixelSize: Style.barSettingsIconSize
        font.family: "Symbols Nerd Font"
        color: root.isWallhaven ? Color.mPrimary : Color.mOnSurface
      }
    }

    Text {
      Layout.alignment: Qt.AlignVCenter
      text: root.wallpaperCount + " / " + root.cachedCount
      color: Color.mOnSurface
      font.pixelSize: Style.barInfoFontSize
    }

    Text {
      Layout.alignment: Qt.AlignVCenter
      text: root.queueCount > 0 ? "\uf251 " + root.queueCount : ""
      color: Color.mPrimary
      font.pixelSize: Style.barInfoFontSize
      font.family: "Symbols Nerd Font"
      visible: root.queueCount > 0
    }

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
