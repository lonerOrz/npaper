import QtQuick
import QtQuick.Controls
import qs.components.settings
import qs.components.common
import qs.services

/*
* SettingsPanel — core configuration only.
*
* Tabs:
*   - Paths: wallpaper directories, cache directory
*   - Wallhaven: API key, categories, purity, sorting
*/
Item {
  id: root

  property bool settingsOpen: false
  property string activeTab: "paths"

  // Mirrored from AppWindow
  property var wallpaperDirs: []
  property string cacheDir: ""
  property bool showBorderGlow: true
  property bool showShadow: true
  property bool showBgPreview: true
  property real bgOverlayOpacity: 0.4
  property string wallhavenApiKey: ""
  property string wallhavenDownloadDir: ""
  property string wallhavenCategories: "111"
  property string wallhavenPurity: "100"

  signal closeRequested
  signal switchToNextFolder
  signal switchToPrevFolder
  signal toggleSettings
  signal settingChanged(string key, variant value)

  function _emit(key, val) {
    root.settingChanged(key, val);
  }

  // ── Animated height ──────────────────────────────────────
  z: 999
  width: Style.settingsWidth
  clip: true

  property real _animTarget: 0.0
  property real _animProgress: 0.0
  height: Style.settingsMaxHeight * _animProgress

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

  // ── Background with subtle gradient ──────────────────────
  Rectangle {
    anchors.fill: parent
    radius: Style.settingsRadius
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: Qt.lighter(Color.mSurfaceContainerLow, 1.05)
      }
      GradientStop {
        position: 1.0
        color: Color.mSurfaceContainerLow
      }
    }
    opacity: root._animProgress

    // Subtle border for depth
    Rectangle {
      anchors.fill: parent
      radius: Style.settingsRadius
      color: "transparent"
      border.width: 1
      border.color: Qt.tint(Color.mOutlineVariant, Color.mSurfaceContainerLow)
      opacity: 0.5
    }
  }

  // ── Tab bar with sliding capsule ─────────────────────────
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

      // Soft shadow for depth
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
        model: [
          {
            key: "paths",
            label: "Paths"
          },
          {
            key: "wallhaven",
            label: "Wallhaven"
          },
          {
            key: "appearance",
            label: "Appearance"
          }
        ]
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
              tabBar._updatePill();
          }
        }
      }

      Component.onCompleted: tabBar._updatePill()
    }

    function _updatePill() {
      for (let i = 0; i < tabsRow.children.length; i++) {
        const item = tabsRow.children[i];
        if (item && item.isActive) {
          _pillX = item.x;
          _pillW = item.width;
        }
      }
    }
  }

  // ── Content area with scroll support ─────────────────────
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
    contentHeight: Math.max(pathsColumn.implicitHeight, wallhavenColumn.implicitHeight, appearanceColumn.implicitHeight) + Style.settingsPadding * 2
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    // Enable mouse wheel scrolling
    WheelHandler {
      onWheel: function (event) {
        contentFlickable.contentY += event.angleDelta.y > 0 ? -40 : 40;
        contentFlickable.scrollActive = true;
        scrollFadeTimer.restart();
      }
    }

    Timer {
      id: scrollFadeTimer
      interval: 800
      onTriggered: contentFlickable.scrollActive = false
    }

    // Custom scrollbar (hidden by default, shows on interaction)
    Rectangle {
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.rightMargin: 2
      width: 4
      radius: 2
      color: Color.mOutlineVariant
      opacity: contentFlickable.scrollActive ? 0.6 : 0

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

    // Reset scroll position when switching tabs
    Connections {
      target: root
      function onActiveTabChanged() {
        contentFlickable.contentY = 0;
      }
    }

    // ── Paths tab ─────────────────────────────────────────
    Column {
      id: pathsColumn
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: Style.settingsPadding
      spacing: Style.settingsContentSpacing + 2
      visible: root.activeTab === "paths"

      // Section header with underline
      Row {
        width: parent.width
        spacing: Style.spaceM

        Text {
          text: "STORAGE"
          color: Color.mOutline
          font.pixelSize: Style.fontXS + 1
          font.weight: Font.Bold
          font.letterSpacing: 2
        }

        Rectangle {
          width: parent.width - _sectionText.implicitWidth - Style.spaceM
          height: 1
          anchors.verticalCenter: _sectionText.verticalCenter
          color: Color.mOutlineVariant
          opacity: 0.3
        }

        Text {
          id: _sectionText
          visible: false
        }
      }

      // ── Wallpaper Directories ──
      Column {
        width: parent.width
        spacing: Style.spaceS

        Text {
          text: "Wallpaper Directories"
          color: Color.mOnSurfaceVariant
          font.pixelSize: Style.fontXS
          font.weight: Font.Medium
        }

        // Directory list
        Column {
          width: parent.width
          spacing: Style.spaceXS

          Repeater {
            model: root.wallpaperDirs

            Row {
              width: parent.width
              spacing: Style.spaceS

              Text {
                width: parent.width - 32
                text: modelData
                color: Color.mOnSurface
                font.pixelSize: Style.fontXS
                font.family: "monospace"
                elide: Text.ElideMiddle
              }

              // Remove button
              MouseArea {
                width: 20; height: 20
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                Rectangle {
                  anchors.fill: parent
                  radius: Style.radiusXS
                  color: parent.containsMouse ? Qt.alpha("#ff5555", 0.12) : "transparent"
                  Behavior on color { ColorAnimation { duration: Style.animVeryFast } }
                }

                Text {
                  anchors.centerIn: parent
                  text: "\uf014"
                  font.family: "Symbols Nerd Font"
                  font.pixelSize: Style.fontXS
                  color: parent.containsMouse ? "#ff5555" : Color.mOnSurfaceVariant
                }

                onClicked: {
                  var dirs = root.wallpaperDirs.slice();
                  dirs.splice(index, 1);
                  root._emit("wallpaperDirs", dirs);
                }
              }
            }
          }
        }

        // Add button
        MouseArea {
          width: parent.width
          height: 26
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          Rectangle {
            anchors.fill: parent
            radius: Style.radiusS
            color: parent.containsMouse ? Qt.alpha(Color.mPrimary, 0.08) : "transparent"
            border.color: Color.mOutline
            border.width: Style.borderS
            Behavior on color { ColorAnimation { duration: Style.animVeryFast } }
          }

          Text {
            anchors.centerIn: parent
            text: "\uf07b  Add Directory"
            font.family: "Symbols Nerd Font"
            font.pixelSize: Style.fontS
            color: parent.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
          }

          onClicked: folderPicker.openPicker("")
        }
      }

      FolderPicker {
        id: folderPicker
        title: "Select Wallpaper Folder"
        onAccepted: function (path) {
          var dirs = root.wallpaperDirs.slice();
          if (dirs.indexOf(path) === -1) {
            dirs.push(path);
            root._emit("wallpaperDirs", dirs);
          }
        }
      }

      // ── Cache Directory ──
      Row {
        width: parent.width
        spacing: Style.spaceM

        Column {
          width: parent.width - 40
          spacing: Style.spaceXS

          Text {
            text: "Cache Directory"
            color: Color.mOnSurfaceVariant
            font.pixelSize: Style.fontXS
            font.weight: Font.Medium
          }

          Text {
            text: root.cacheDir || "Not configured"
            color: root.cacheDir ? Color.mOnSurface : Color.mOnSurfaceVariant
            font.pixelSize: Style.fontXS
            font.family: "monospace"
            elide: Text.ElideMiddle
          }
        }

        MouseArea {
          width: 24; height: 24
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          Rectangle {
            anchors.fill: parent
            radius: Style.radiusS
            color: parent.containsMouse ? Qt.alpha(Color.mPrimary, 0.12) : Color.mSurfaceContainerHigh
            border.color: Color.mOutline
            border.width: Style.borderS
          }

          Text {
            anchors.centerIn: parent
            text: "\uf07c"
            font.family: "Symbols Nerd Font"
            font.pixelSize: Style.fontS
            color: parent.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
          }

          onClicked: cachePicker.openPicker(root.cacheDir)
        }
      }

      FolderPicker {
        id: cachePicker
        title: "Select Cache Folder"
        onAccepted: function (path) {
          root._emit("cacheDir", path);
        }
      }
    }

    // ── Wallhaven tab ────────────────────────────────────
    Column {
      id: wallhavenColumn
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: Style.settingsPadding
      spacing: Style.settingsContentSpacing + 2
      visible: root.activeTab === "wallhaven"

      // API section header
      Row {
        width: parent.width
        spacing: Style.spaceM

        Text {
          id: _apiHeader
          text: "API"
          color: Color.mOutline
          font.pixelSize: Style.fontXS + 1
          font.weight: Font.Bold
          font.letterSpacing: 2
        }

        Rectangle {
          width: parent.width - _apiHeader.implicitWidth - Style.spaceM
          height: 1
          anchors.verticalCenter: _apiHeader.verticalCenter
          color: Color.mOutlineVariant
          opacity: 0.3
        }
      }

      SettingsTextInput {
        width: parent.width
        label: "API Key"
        value: root.wallhavenApiKey
        placeholder: "your-wallhaven-api-key"
        onCommit: function (v) {
          root._emit("wallhaven.apiKey", v.trim());
        }
      }

      // Divider
      Rectangle {
        width: parent.width
        height: 1
        color: Color.mOutlineVariant
        opacity: 0.2
      }

      // Download Folder
      Row {
        width: parent.width
        spacing: Style.spaceM

        Column {
          width: parent.width - 40
          spacing: Style.spaceXS

          Text {
            text: "Download Folder"
            color: Color.mOnSurfaceVariant
            font.pixelSize: Style.fontXS
            font.weight: Font.Medium
          }

          Text {
            text: root.wallhavenDownloadDir || "Default (Wallpaper Dir)"
            color: root.wallhavenDownloadDir ? Color.mOnSurface : Color.mOnSurfaceVariant
            font.pixelSize: Style.fontXS
            font.family: "monospace"
            elide: Text.ElideMiddle
          }
        }

        MouseArea {
          width: 24; height: 24
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          Rectangle {
            anchors.fill: parent
            radius: Style.radiusS
            color: parent.containsMouse ? Qt.alpha(Color.mPrimary, 0.12) : Color.mSurfaceContainerHigh
            border.color: Color.mOutline
            border.width: Style.borderS
          }

          Text {
            anchors.centerIn: parent
            text: "\uf07c"
            font.family: "Symbols Nerd Font"
            font.pixelSize: Style.fontS
            color: parent.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
          }

          onClicked: whDownloadPicker.openPicker(root.wallhavenDownloadDir)
        }
      }

      FolderPicker {
        id: whDownloadPicker
        title: "Select Download Folder"
        onAccepted: function (path) {
          root._emit("wallhaven.downloadDir", path);
        }
      }

      // Filters section header
      Row {
        width: parent.width
        spacing: Style.spaceM

        Text {
          id: _filtersHeader
          text: "FILTERS"
          color: Color.mOutline
          font.pixelSize: Style.fontXS + 1
          font.weight: Font.Bold
          font.letterSpacing: 2
        }

        Rectangle {
          width: parent.width - _filtersHeader.implicitWidth - Style.spaceM
          height: 1
          anchors.verticalCenter: _filtersHeader.verticalCenter
          color: Color.mOutlineVariant
          opacity: 0.3
        }
      }

      // Category toggles with better grouping
      Column {
        width: parent.width
        spacing: Style.spaceS

        SettingsToggle {
          width: parent.width
          text: "General"
          checked: root.wallhavenCategories[0] === "1"
          onToggled: function (val) {
            var c = root.wallhavenCategories.split("");
            c[0] = val ? "1" : "0";
            root._emit("wallhaven.categories", c.join(""));
          }
        }
        SettingsToggle {
          width: parent.width
          text: "Anime"
          checked: root.wallhavenCategories[1] === "1"
          onToggled: function (val) {
            var c = root.wallhavenCategories.split("");
            c[1] = val ? "1" : "0";
            root._emit("wallhaven.categories", c.join(""));
          }
        }
        SettingsToggle {
          width: parent.width
          text: "People"
          checked: root.wallhavenCategories[2] === "1"
          onToggled: function (val) {
            var c = root.wallhavenCategories.split("");
            c[2] = val ? "1" : "0";
            root._emit("wallhaven.categories", c.join(""));
          }
        }
      }

      // Divider
      Rectangle {
        width: parent.width
        height: 1
        color: Color.mOutlineVariant
        opacity: 0.2
      }

      // Purity togges with better grouping
      Column {
        width: parent.width
        spacing: Style.spaceS

        SettingsToggle {
          width: parent.width
          text: "Safe"
          checked: root.wallhavenPurity[0] === "1"
          onToggled: function (val) {
            var p = root.wallhavenPurity.split("");
            p[0] = val ? "1" : "0";
            root._emit("wallhaven.purity", p.join(""));
          }
        }
        SettingsToggle {
          width: parent.width
          text: "Sketchy"
          checked: root.wallhavenPurity[1] === "1"
          onToggled: function (val) {
            var p = root.wallhavenPurity.split("");
            p[1] = val ? "1" : "0";
            root._emit("wallhaven.purity", p.join(""));
          }
        }
        SettingsToggle {
          width: parent.width
          text: "NSFW"
          checked: root.wallhavenPurity[2] === "1"
          onToggled: function (val) {
            var p = root.wallhavenPurity.split("");
            p[2] = val ? "1" : "0";
            root._emit("wallhaven.purity", p.join(""));
          }
        }
      }
    }

    // ── Appearance tab ──────────────────────────────────
    Column {
      id: appearanceColumn
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: Style.settingsPadding
      spacing: Style.settingsContentSpacing + 2
      visible: root.activeTab === "appearance"

      // Overlay section header
      Row {
        width: parent.width
        spacing: Style.spaceM

        Text {
          id: _overlayHeader
          text: "OVERLAY"
          color: Color.mOutline
          font.pixelSize: Style.fontXS + 1
          font.weight: Font.Bold
          font.letterSpacing: 2
        }

        Rectangle {
          width: parent.width - _overlayHeader.implicitWidth - Style.spaceM
          height: 1
          anchors.verticalCenter: _overlayHeader.verticalCenter
          color: Color.mOutlineVariant
          opacity: 0.3
        }
      }

      SettingsSlider {
        width: parent.width
        label: "Opacity"
        value: root.bgOverlayOpacity
        min: 0.0
        max: 1.0
        step: 0.05
        onCommit: function (v) {
          root._emit("appearance.bgOverlayOpacity", v);
        }
      }

      // Divider
      Rectangle {
        width: parent.width
        height: 1
        color: Color.mOutlineVariant
        opacity: 0.2
      }

      // Effects section header
      Row {
        width: parent.width
        spacing: Style.spaceM

        Text {
          id: _effectsHeader
          text: "EFFECTS"
          color: Color.mOutline
          font.pixelSize: Style.fontXS + 1
          font.weight: Font.Bold
          font.letterSpacing: 2
        }

        Rectangle {
          width: parent.width - _effectsHeader.implicitWidth - Style.spaceM
          height: 1
          anchors.verticalCenter: _effectsHeader.verticalCenter
          color: Color.mOutlineVariant
          opacity: 0.3
        }
      }

      Column {
        width: parent.width
        spacing: Style.spaceS

        SettingsToggle {
          width: parent.width
          text: "Border Glow"
          checked: root.showBorderGlow
          onToggled: function (val) {
            root._emit("appearance.showBorderGlow", val);
          }
        }
        SettingsToggle {
          width: parent.width
          text: "Card Shadow"
          checked: root.showShadow
          onToggled: function (val) {
            root._emit("appearance.showShadow", val);
          }
        }
        SettingsToggle {
          width: parent.width
          text: "Background Preview"
          checked: root.showBgPreview
          onToggled: function (val) {
            root._emit("appearance.showBgPreview", val);
          }
        }
      }
    } // end appearanceColumn
  } // end Flickable
}
