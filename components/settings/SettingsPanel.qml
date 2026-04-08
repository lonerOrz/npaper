import QtQuick
import qs.components.settings
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

  // ── Background ───────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    radius: Style.settingsRadius
    color: Color.mSurfaceContainerLow
    opacity: root._animProgress
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
      color: Color.mPrimary

      x: tabBar._pillX
      width: tabBar._pillW

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
            font.pixelSize: Style.settingsTabFontSize
            font.weight: parent.isActive ? Font.Bold : Font.Normal
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

  // ── Content area ─────────────────────────────────────────
  Item {
    anchors.top: tabBar.bottom
    anchors.topMargin: Style.settingsInnerSpacing
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: Style.settingsPadding
    clip: true

    // ── Paths tab ─────────────────────────────────────────
    Column {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.settingsContentSpacing
      visible: root.activeTab === "paths"

      Text {
        width: parent.width
        text: "STORAGE"
        color: Color.mOutline
        font.pixelSize: Style.fontXS
        font.weight: Font.Bold
        font.letterSpacing: 1.5
      }

      SettingsTextInput {
        width: parent.width
        label: "Wallpaper Directories"
        value: root.wallpaperDirs.join(";")
        placeholder: "/path/to/wallpapers;/path/to/more"
        onCommit: function (v) {
          var dirs = v.split(";").map(s => s.trim()).filter(s => s.length > 0);
          root._emit("wallpaperDirs", dirs);
        }
      }

      SettingsTextInput {
        width: parent.width
        label: "Cache Directory"
        value: root.cacheDir
        placeholder: "/path/to/cache"
        onCommit: function (v) {
          root._emit("cacheDir", v.trim());
        }
      }
    }

    // ── Wallhaven tab ────────────────────────────────────
    Column {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.settingsContentSpacing
      visible: root.activeTab === "wallhaven"

      Text {
        width: parent.width
        text: "API"
        color: Color.mOutline
        font.pixelSize: Style.fontXS
        font.weight: Font.Bold
        font.letterSpacing: 1.5
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

      Rectangle {
        width: parent.width
        height: 1
        color: Color.mOutlineVariant
        opacity: Style.opacityDivider
      }

      Text {
        width: parent.width
        text: "FILTERS"
        color: Color.mOutline
        font.pixelSize: Style.fontXS
        font.weight: Font.Bold
        font.letterSpacing: 1.5
      }

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

      Rectangle {
        width: parent.width
        height: 1
        color: Color.mOutlineVariant
        opacity: Style.opacityDivider
      }

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

    // ── Appearance tab ──────────────────────────────────
    Column {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.settingsContentSpacing
      visible: root.activeTab === "appearance"

      Text {
        width: parent.width
        text: "OVERLAY"
        color: Color.mOutline
        font.pixelSize: Style.fontXS
        font.weight: Font.Bold
        font.letterSpacing: 1.5
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

      Rectangle {
        width: parent.width
        height: 1
        color: Color.mOutlineVariant
        opacity: Style.opacityDivider
      }

      Text {
        width: parent.width
        text: "EFFECTS"
        color: Color.mOutline
        font.pixelSize: Style.fontXS
        font.weight: Font.Bold
        font.letterSpacing: 1.5
      }

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
  }
}
