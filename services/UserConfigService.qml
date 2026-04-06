import QtQuick
import Quickshell
import Quickshell.Io

ConfigService {
  id: root

  readonly property string configDir: Quickshell.env("HOME") + "/.config/npaper"
  readonly property string configPath: configDir + "/config.json"
  required property var defaultConfig

  // ========== Reactive config properties ==========
  property var wallpaperDirs: []
  property string cacheDir: ""
  property bool showBgPreview: true
  property string previewStyle: "carousel"
  property bool debugMode: false

  property bool isSaving: false

  function _resolvePath(pathStr) {
    if (!pathStr) return "";
    if (pathStr.indexOf("$HOME") === 0)
      return Quickshell.env("HOME") + pathStr.slice(5);
    return pathStr;
  }

  function _resolvePaths(dirs) {
    if (!Array.isArray(dirs)) return [];
    var result = [];
    for (var i = 0; i < dirs.length; i++)
      result.push(_resolvePath(dirs[i]));
    return result;
  }

  function _mergeAndApply(src) {
    if (!src) return;
    if (src.wallpaperDirs !== undefined) root.wallpaperDirs = _resolvePaths(src.wallpaperDirs);
    if (src.cacheDir !== undefined) root.cacheDir = _resolvePath(src.cacheDir);
    if (src.showBgPreview !== undefined) root.showBgPreview = src.showBgPreview;
    if (src.previewStyle !== undefined) root.previewStyle = src.previewStyle;
    if (src.debugMode !== undefined) root.debugMode = src.debugMode;
  }

  Process {
    id: checkProcess
    stdout: StdioCollector {
      onStreamFinished: {
        var hasConfig = (text.trim() === "exists");
        if (hasConfig) {
          fileView.path = root.configPath;
        } else {
          _mergeAndApply(root.defaultConfig.config);
          root.ready = true;
        }
      }
    }
    onExited: function (code, status) {
      if (code !== 0) {
        _mergeAndApply(root.defaultConfig.config);
        root.ready = true;
      }
    }
  }

  FileView {
    id: fileView
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
        var userCfg = JSON.parse(text());
        // Merge: defaults ← user config
        _mergeAndApply(root.defaultConfig.config);
        _mergeAndApply(userCfg);
        root.ready = true;
      } catch (e) {
        console.error("[npaper] UserConfig: parse error, using defaults:", e);
        _mergeAndApply(root.defaultConfig.config);
        root.ready = true;
      }
    }

    onLoadFailed: function () {
      _mergeAndApply(root.defaultConfig.config);
      root.ready = true;
    }
  }

  Process {
    id: saveProcess
    onExited: function (code, status) {
      if (code === 0) {
        root.isSaving = false;
      } else {
        console.error("[npaper] UserConfig: save failed, code:", code);
      }
    }
  }

  Timer {
    id: saveTimer
    interval: 500
    repeat: false
    onTriggered: {
      var cfg = {};
      cfg.wallpaperDirs = root.wallpaperDirs;
      cfg.cacheDir = root.cacheDir;
      cfg.showBgPreview = root.showBgPreview;
      cfg.previewStyle = root.previewStyle;
      cfg.debugMode = root.debugMode;
      var configStr = JSON.stringify(cfg, null, 2);
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
    var cfg = {};
    cfg[key] = value;
    root._mergeAndApply(cfg);
    saveConfig();
  }

  function startCheck() {
    if (!defaultConfig.ready) {
      return;
    }
    checkProcess.command = ["sh", "-c",
      '[ -f "$HOME/.config/npaper/config.json" ] && echo exists || echo missing'];
    checkProcess.running = true;
  }

  Connections {
    target: defaultConfig
    function onReadyChanged() {
      if (defaultConfig.ready) {
        root.startCheck();
      }
    }
  }

  Component.onCompleted: {
    if (defaultConfig.ready) {
      root.startCheck();
    }
  }
}
