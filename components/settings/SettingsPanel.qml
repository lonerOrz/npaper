import QtQuick
import QtQuick.Controls
import qs.components.common
import qs.components.settings
import qs.services

Item {
  id: root

  property bool settingsOpen: false
  property string activeTab: "paths"

  property var wallpaperDirs: []
  property string cacheDir: ""
  property bool showShadow: true
  property bool showBgPreview: true
  property real bgOverlayOpacity: 0.4
  property string videoBackend: "mpvpaper"
  property string wallhavenApiKey: ""
  property string wallhavenDownloadDir: ""
  property string wallhavenCategories: "111"
  property string wallhavenPurity: "100"

  signal closeRequested
  signal switchToNextFolder
  signal switchToPrevFolder
  signal toggleSettings
  signal settingChanged(string key, var value)

  readonly property var _tabItems: [
    {
      key: "paths",
      label: "Paths"
    },
    {
      key: "wallhaven",
      label: "Wallhaven"
    },
    {
      key: "video",
      label: "Video"
    },
    {
      key: "appearance",
      label: "Appearance"
    }
  ]

  z: 999
  width: Style.settingsWidth
  clip: true

  property real _animTarget: 0.0
  property real _animProgress: 0.0
  height: Style.settingsMaxHeight * _animProgress
  opacity: _animProgress

  onSettingsOpenChanged: {
    _animTarget = settingsOpen ? 1.0 : 0.0;
    _anim.restart();
  }

  NumberAnimation {
    id: _anim
    target: root
    properties: "_animProgress"
    from: _animProgress
    to: _animTarget
    duration: settingsOpen ? Style.animNormal : Style.animFast
    easing.type: Style.easingOutCubic
    onFinished: root.visible = _animProgress > 0.01
  }

  Keys.onEscapePressed: closeRequested()

  Keys.onPressed: function (event) {
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      event.key === Qt.Key_Tab ? switchToNextFolder() : switchToPrevFolder();
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_S && !event.modifiers) {
      toggleSettings();
      event.accepted = true;
      return;
    }
  }

  focus: settingsOpen

  Rectangle {
    anchors.fill: parent
    radius: Style.settingsRadius
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: Qt.rgba(Qt.lighter(Color.mSurfaceContainerLow, 1.05).r, Qt.lighter(Color.mSurfaceContainerLow, 1.05).g, Qt.lighter(Color.mSurfaceContainerLow, 1.05).b, Style.settingsBlurAlpha)
      }
      GradientStop {
        position: 1.0
        color: Qt.rgba(Color.mSurfaceContainerLow.r, Color.mSurfaceContainerLow.g, Color.mSurfaceContainerLow.b, Style.settingsBlurAlpha)
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: Style.settingsRadius
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(Color.mOutlineVariant.r, Color.mOutlineVariant.g, Color.mOutlineVariant.b, Style.settingsBlurAlpha * 0.5)
    }
  }

  Item {
    id: tabBar
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.settingsTabHeight + Style.settingsTabPadding * 2
    anchors.margins: Style.settingsPadding

    property real _pillX: 0
    property real _pillW: 0

    Connections {
      target: root
      function onActiveTabChanged() {
        tabBar._updatePill();
      }
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      height: Style.settingsTabHeight
      radius: height / 2
      gradient: Gradient {
        GradientStop {
          position: 0.0
          color: Qt.lighter(Color.mPrimary, 1.1)
        }
        GradientStop {
          position: 1.0
          color: Color.mPrimary
        }
      }

      x: tabBar._pillX
      width: tabBar._pillW

      Rectangle {
        anchors.fill: parent
        anchors.verticalCenterOffset: 2
        radius: parent.radius
        color: Color.mShadow
        opacity: 0.15
        z: -1
      }

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
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.settingsTabSpacing

      Repeater {
        model: root._tabItems
        delegate: MouseArea {
          required property var modelData
          property bool isActive: root.activeTab === modelData.key
          width: _label.implicitWidth + Style.settingsTabSidePadding * 2
          height: Style.settingsTabHeight
          cursorShape: Qt.PointingHandCursor

          Text {
            id: _label
            anchors.centerIn: parent
            text: modelData.label
            color: parent.isActive ? Color.mSurfaceContainerLowest : Color.mOutlineVariant
            font.pixelSize: Style.settingsTabFontSize + 1
            font.weight: parent.isActive ? Font.Bold : Font.Medium
            font.letterSpacing: 0.5
            Behavior on color {
              ColorAnimation {
                duration: Style.animFast
              }
            }
          }

          onClicked: root.activeTab = modelData.key

          Component.onCompleted: {
            if (isActive)
              Qt.callLater(tabBar._updatePill);
          }
        }
      }
      Component.onCompleted: Qt.callLater(tabBar._updatePill)
    }

    function _updatePill() {
      for (let i = 0; i < tabsRow.children.length; i++) {
        const item = tabsRow.children[i];
        if (item && item.isActive) {
          _pillX = item.x;
          _pillW = item.width;
          break;
        }
      }
    }
  }

  readonly property var _currentTabItem: {
    switch (root.activeTab) {
    case "paths":
      return pathsTab;
    case "wallhaven":
      return wallhavenTab;
    case "video":
      return videoTab;
    case "appearance":
      return appearanceTab;
    default:
      return pathsTab;
    }
  }

  Flickable {
    id: contentFlickable
    anchors.top: tabBar.bottom
    anchors.topMargin: Style.settingsInnerSpacing + 2
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: Style.settingsPadding
    clip: true

    property bool scrollActive: false

    contentWidth: width
    contentHeight: (_currentTabItem ? _currentTabItem.implicitHeight : 200) + Style.settingsPadding * 2
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    WheelHandler {
      onWheel: function (event) {
        const maxScroll = Math.max(0, contentFlickable.contentHeight - contentFlickable.height);
        const step = event.angleDelta.y > 0 ? -45 : 45;
        contentFlickable.contentY = Math.max(0, Math.min(contentFlickable.contentY + step, maxScroll));
        contentFlickable.scrollActive = true;
        scrollFadeTimer.restart();
      }
    }

    Timer {
      id: scrollFadeTimer
      interval: 800
      repeat: false
      onTriggered: contentFlickable.scrollActive = false
    }

    Rectangle {
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.rightMargin: 2
      width: 4
      radius: 2
      color: Color.mOutlineVariant
      opacity: (contentFlickable.scrollActive && contentFlickable.visibleArea.heightRatio < 1.0) ? 0.6 : 0.0

      property real scrollProgress: contentFlickable.visibleArea.heightRatio < 1.0 ? contentFlickable.visibleArea.yPosition / (1.0 - contentFlickable.visibleArea.heightRatio) : 0
      property real scrollHeight: contentFlickable.visibleArea.heightRatio < 1.0 ? contentFlickable.visibleArea.heightRatio * (parent.height - 4) + 20 : 20

      y: scrollProgress * (parent.height - scrollHeight)
      height: scrollHeight

      Behavior on opacity {
        NumberAnimation {
          duration: contentFlickable.scrollActive ? Style.animVeryFast : Style.animSlow
        }
      }
    }

    Connections {
      target: root
      function onActiveTabChanged() {
        contentFlickable.contentY = 0;
      }
    }

    PathsTab {
      id: pathsTab
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: Style.settingsPadding
      visible: root.activeTab === "paths"
      wallpaperDirs: root.wallpaperDirs
      cacheDir: root.cacheDir
      onSettingChanged: (key, val) => root.settingChanged(key, val)
    }

    WallhavenTab {
      id: wallhavenTab
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: Style.settingsPadding
      visible: root.activeTab === "wallhaven"
      wallhavenApiKey: root.wallhavenApiKey
      wallhavenDownloadDir: root.wallhavenDownloadDir
      wallhavenCategories: root.wallhavenCategories
      wallhavenPurity: root.wallhavenPurity
      onSettingChanged: (key, val) => root.settingChanged(key, val)
    }

    VideoTab {
      id: videoTab
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: Style.settingsPadding
      visible: root.activeTab === "video"
      videoBackend: root.videoBackend
      onSettingChanged: (key, val) => root.settingChanged(key, val)
    }

    AppearanceTab {
      id: appearanceTab
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: Style.settingsPadding
      visible: root.activeTab === "appearance"
      showShadow: root.showShadow
      showBgPreview: root.showBgPreview
      bgOverlayOpacity: root.bgOverlayOpacity
      onSettingChanged: (key, val) => root.settingChanged(key, val)
    }
  }
}
