import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string configDir: Quickshell.env("HOME") + "/.config/npaper"
  readonly property string configPath: configDir + "/config.json"
  readonly property string defaultConfigPath: Qt.resolvedUrl("../assets/default.json").toString().slice(7)

  property var config: ({})
  property bool ready: false
  property bool isSaving: false

  readonly property var wallpaperDirs: _resolvePaths(config.wallpaperDirs || ["$HOME/Pictures/wallpapers"])
  readonly property string cacheDir: _resolvePath(config.cacheDir || "$HOME/.cache/wallpaper_thumbs")
  readonly property string previewStyle: config.previewStyle || "carousel"
  readonly property bool debugMode: config.debugMode || false

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
        root.config = JSON.parse(text());
        root.ready = true;
      } catch (e) {
        console.error("[npaper] Config: parse error, using defaults:", e);
        defaultConfigView.reload();
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
        root.config = JSON.parse(text());
        root.ready = true;
      } catch (e) {
        console.error("[npaper] Config: default parse error:", e);
        root.config = {};
        root.ready = true;
      }
    }

    onLoadFailed: function (error) {
      console.error("[npaper] Config: cannot load defaults:", error);
      root.config = {};
      root.ready = true;
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
      var configStr = JSON.stringify(root.config, null, 2);
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
    var updated = JSON.parse(JSON.stringify(root.config));
    updated[key] = value;
    root.config = updated;
    saveConfig();
  }

  Component.onCompleted: {
    checkProcess.command = ["sh", "-c",
      '[ -f "$HOME/.config/npaper/config.json" ] && echo exists || echo missing'];
    checkProcess.running = true;
  }
}
