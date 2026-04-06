import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string configDir: Quickshell.env("HOME") + "/.config/npaper"
  readonly property string configPath: configDir + "/config.json"
  readonly property string defaultConfigPath: Qt.resolvedUrl("../assets/default.json").toString().slice(7)

  property var defaultConfig: ({})
  property var userConfig: ({})
  property bool ready: false
  property bool isSaving: false

  function _get(key) {
    if (userConfig[key] !== undefined) return userConfig[key];
    if (defaultConfig[key] !== undefined) return defaultConfig[key];
    return undefined;
  }

  function getWallpaperDirs() {
    const val = _get("wallpaperDirs");
    return Array.isArray(val) ? _resolvePaths(val) : [];
  }
  function getCacheDir() {
    const val = _get("cacheDir");
    return val ? _resolvePath(val) : "";
  }
  function getShowBgPreview() {
    const val = _get("showBgPreview");
    return val !== undefined ? val : true;
  }
  function getPreviewStyle() {
    const val = _get("previewStyle");
    return val || "carousel";
  }
  function getDebugMode() {
    const val = _get("debugMode");
    return val === true;
  }

  function _resolvePath(pathStr) {
    if (!pathStr) return "";
    if (pathStr.indexOf("$HOME") === 0)
      return Quickshell.env("HOME") + pathStr.slice(5);
    return pathStr;
  }

  function _resolvePaths(dirs) {
    if (!Array.isArray(dirs)) return [];
    var result = [];
    for (var i = 0; i < dirs.length; i++) {
      var p = _resolvePath(dirs[i]);
      if (p) result.push(p);
    }
    return result;
  }

  Process {
    id: checkProcess
    onExited: function (code, status) {
      var hasConfig = (code === 0 && stdout && stdout.trim() === "exists");
      if (hasConfig) {
        userConfigView.path = root.configPath;
      } else {
        defaultConfigView.reload();
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
        root.userConfig = JSON.parse(text());
        root.ready = true;
      } catch (e) {
        console.error("[npaper] Config: parse error, using defaults:", e);
      }
    }

    onLoadFailed: function () {
      defaultConfigView.reload();
    }
  }

  FileView {
    id: defaultConfigView
    path: root.defaultConfigPath
    printErrors: true

    onLoaded: {
      try {
        root.defaultConfig = JSON.parse(text());
        root.ready = true;
      } catch (e) {
        console.error("[npaper] Config: default parse error:", e);
      }
    }

    onLoadFailed: function (error) {
      console.error("[npaper] Config: cannot load defaults:", error);
    }
  }

  Process {
    id: saveProcess
    onExited: function (code, status) {
      if (code === 0) {
        root.isSaving = false;
      } else {
        console.error("[npaper] Config: save failed, code:", code);
      }
    }
  }

  Timer {
    id: saveTimer
    interval: 500
    repeat: false
    onTriggered: {
      var configStr = JSON.stringify(root.userConfig, null, 2);
      saveProcess.command = ["sh", "-c",
        'mkdir -p "$1" && printf "%s" "$2" > "$1/config.json"',
        "npaper-save", root.configDir, configStr];
      saveProcess.exec({});
      root.isSaving = true;
    }
  }

  function saveConfig() {
    saveTimer.restart();
  }

  function set(key, value) {
    var updated = JSON.parse(JSON.stringify(root.userConfig));
    updated[key] = value;
    root.userConfig = updated;
    saveConfig();
  }

  Component.onCompleted: {
    checkProcess.command = ["sh", "-c",
      '[ -f "$HOME/.config/npaper/config.json" ] && echo exists || echo missing'];
    checkProcess.running = true;
  }
}
