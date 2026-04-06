import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string userConfigDir: Quickshell.env("HOME") + "/.config/npaper"
  readonly property string userConfigPath: userConfigDir + "/config.json"
  readonly property string defaultConfigPath: Qt.resolvedUrl("../assets/default.json").toString().slice(7)

  property var config: ({})
  property bool ready: false
  property bool isSaving: false
  property bool useUserConfig: false

  readonly property string previewStyle: _get("previewStyle", "carousel")

  readonly property real carouselItemWidth: _getNested("carousel", "itemWidth", 450)
  readonly property real carouselItemHeight: _getNested("carousel", "itemHeight", 320)
  readonly property real carouselSpacing: _getNested("carousel", "spacing", 25)
  readonly property real carouselRotation: _getNested("carousel", "rotation", 40)
  readonly property real carouselPerspective: _getNested("carousel", "perspective", 0.3)

  readonly property int gridColumns: _getNested("grid", "columns", 4)
  readonly property real gridItemWidth: _getNested("grid", "itemWidth", 320)
  readonly property real gridItemHeight: _getNested("grid", "itemHeight", 220)
  readonly property real gridSpacing: _getNested("grid", "spacing", 12)

  readonly property int scrollAnimDuration: _getNested("animation", "scrollDuration", 280)
  readonly property int scrollContinueInterval: _getNested("animation", "scrollContinueInterval", 230)
  readonly property int bgSlideDuration: _getNested("animation", "bgSlideDuration", 250)
  readonly property int bgFadeDuration: _getNested("animation", "bgFadeDuration", 400)
  readonly property real bgParallaxFactor: _getNested("animation", "bgParallaxFactor", 40)

  readonly property bool showBorderGlow: _getNested("appearance", "showBorderGlow", true)
  readonly property bool showShadow: _getNested("appearance", "showShadow", true)
  readonly property real bgOverlayOpacity: _getNested("appearance", "bgOverlayOpacity", 0.4)

  readonly property int visibleRange: _getNested("performance", "visibleRange", 4)
  readonly property int preloadRange: _getNested("performance", "preloadRange", 2)

  readonly property int searchDebounceMs: _getNested("search", "debounceMs", 150)

  readonly property bool debugMode: _get("debugMode", false)

  function _get(key, defaultVal) {
    if (!root.config) return defaultVal;
    return (root.config[key] !== undefined) ? root.config[key] : defaultVal;
  }

  function _getNested(section, key, defaultVal) {
    if (!root.config) return defaultVal;
    const sec = root.config[section];
    if (!sec || typeof sec !== "object") return defaultVal;
    return (sec[key] !== undefined) ? sec[key] : defaultVal;
  }

  Process {
    id: checkUserConfigProcess
    onExited: function (code, status) {
      if (code === 0) {
        var result = stdout ? stdout.trim() : "";
        if (result === "exists") {
          root.useUserConfig = true;
        } else {
          root.useUserConfig = false;
        }
        loadConfig();
      } else {
        console.error("[npaper] Config: Check failed, using defaults");
        root.useUserConfig = false;
        loadConfig();
      }
    }
  }

  FileView {
    id: userConfigView
    path: ""
    printErrors: true
    watchChanges: true

    onFileChanged: {
      if (root.isSaving) {
        root.isSaving = false;
        return;
      }
      reload();
    }

    onLoaded: {
      try {
        root.config = JSON.parse(text());
        root.ready = true;
        console.log("[npaper] Config: Loaded from user config");
      } catch (e) {
        console.error("[npaper] Config: Failed to parse user config:", e);
        loadDefaultConfig();
      }
    }

    onLoadFailed: function (error) {
      loadDefaultConfig();
    }
  }

  FileView {
    id: defaultConfigView
    path: root.defaultConfigPath
    printErrors: true

    onLoaded: {
      try {
        root.config = JSON.parse(text());
        root.ready = true;
        console.log("[npaper] Config: Loaded from default.json");
      } catch (e) {
        console.error("[npaper] Config: Failed to parse default.json:", e);
        root.config = {};
        root.ready = true;
      }
    }

    onLoadFailed: function (error) {
      console.error("[npaper] Config: Failed to load default.json:", error);
      root.config = {};
      root.ready = true;
    }
  }

  function loadConfig() {
    if (root.useUserConfig) {
      userConfigView.path = root.userConfigPath;
    } else {
      loadDefaultConfig();
    }
  }

  function loadDefaultConfig() {
    root.useUserConfig = false;
    defaultConfigView.reload();
  }

  Process {
    id: saveConfigProcess
    onExited: function (code, status) {
      if (code === 0) {
        root.isSaving = false;
        console.log("[npaper] Config: Saved");
      } else {
        console.error("[npaper] Config: Save failed with code", code);
      }
    }
  }

  Timer {
    id: saveTimer
    interval: 500
    repeat: false
    onTriggered: {
      root.saveConfig();
    }
  }

  function saveConfig() {
    var configStr = JSON.stringify(root.config, null, 2);
    saveConfigProcess.command = ["sh", "-c", `
      mkdir -p "$HOME/.config/npaper" &&
      printf "%s" "$1" > "$HOME/.config/npaper/config.json"
    `, "npaper-save", configStr];
    saveConfigProcess.exec({});
    root.isSaving = true;
  }

  function scheduleSave() {
    saveTimer.restart();
  }

  function setNested(section, key, value) {
    if (!root.config[section] || typeof root.config[section] !== "object") {
      var newConfig = JSON.parse(JSON.stringify(root.config));
      newConfig[section] = {};
      newConfig[section][key] = value;
      root.config = newConfig;
    } else {
      var updated = JSON.parse(JSON.stringify(root.config));
      updated[section][key] = value;
      root.config = updated;
    }
    scheduleSave();
  }

  function set(key, value) {
    var updated = JSON.parse(JSON.stringify(root.config));
    updated[key] = value;
    root.config = updated;
    scheduleSave();
  }

  Component.onCompleted: {
    checkUserConfigProcess.command = ["sh", "-c", `
      CONFIG_FILE="$HOME/.config/npaper/config.json"
      if [ -f "$CONFIG_FILE" ]; then
        if command -v jq &> /dev/null; then
          if jq empty "$CONFIG_FILE" 2>/dev/null; then
            echo "exists"
          else
            echo "missing"
          fi
        else
          if grep -q '"previewStyle"' "$CONFIG_FILE" 2>/dev/null; then
            echo "exists"
          else
            echo "missing"
          fi
        fi
      else
        echo "missing"
      fi
    `];
    checkUserConfigProcess.running = true;
  }
}
