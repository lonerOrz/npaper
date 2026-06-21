pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
* Config — persistent user configuration (pure JS, no JsonAdapter).
*
* Flow:
*   1. Component.onCompleted → start with _defaults
*   2. Read config.json via Process → deepMerge into data
*   3. UI reads:  Config.data.carousel.spacing
*   4. UI writes: Config.update("carousel.spacing", 25) → modifies data → debounced save
*   5. Hot-reload: FileView watches config.json → re-read → merge → QML bindings auto-update
*   */

Singleton {
  id: root

  readonly property string configPath: Quickshell.env("HOME") + "/.config/npaper/config.json"
  property bool isLoaded: false
  property bool _isSaving: false

  property string previewStyle: "carousel"
  readonly property var previewModes: ["carousel", "grid", "slanted"]

  signal dataLoaded

  readonly property var _defaults: ({
                                      "wallpaperDirs": ["$HOME/Pictures/wallpapers"],
                                      "cacheDir": "$HOME/.cache/wallpaper_thumbs",
                                      "debugMode": false,
                                      "previewStyle": "carousel",
                                      "videoBackend": "mpvpaper",
                                      "wallhaven": {
                                        "apiKey": "",
                                        "downloadDir": "",
                                        "defaultAtleast": "1920x1080",
                                        "categories": "111",
                                        "purity": "100",
                                        "sorting": "toplist"
                                      },
                                      "appearance": {
                                        "showBorderGlow": true,
                                        "showShadow": true,
                                        "showBgPreview": true,
                                        "bgOverlayOpacity": 0.4
                                      }
                                    })

  property var data: ({})

  property Timer _saveTimer: Timer {
    interval: 500
    repeat: false
    onTriggered: _doSave()
  }

  Component.onCompleted: {
    root.data = _deepClone(_defaults);
    Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.config/npaper"]);
    Qt.callLater(function () {
      if (!root.isLoaded) {
        root._parseAndApplyConfig();
      }
    });
  }

  FileView {
    id: _fileView
    path: root.configPath
    printErrors: false
    watchChanges: true
    blockLoading: true

    onFileChanged: {
      if (root._isSaving) {
        root._isSaving = false;
        return;
      }
      root._parseAndApplyConfig();
    }
  }

  function _parseAndApplyConfig() {
    var raw = _fileView.text();
    if (!raw || String(raw).trim().length === 0) {
      Logger.i("Config", "No config file or empty — creating defaults at", root.configPath);
      root.data = _resolvePaths(_deepClone(_defaults));
      root.isLoaded = true;
      root.previewStyle = root.data.previewStyle || "carousel";
      root.dataLoaded();
      _doSave();
      return;
    }
    try {
      var user = JSON.parse(String(raw).trim());
      root.data = _deepMerge(_deepClone(_defaults), user);
      root.data = _resolvePaths(root.data);
      root.previewStyle = root.data.previewStyle || "carousel";
      Logger.i("Config", "Loaded user config");
      root.isLoaded = true;
      root.dataLoaded();
    } catch (e) {
      Logger.w("Config", "Parse error, using defaults:", e);
      root.data = _deepClone(_defaults);
      root.previewStyle = root.data.previewStyle || "carousel";
      root.isLoaded = true;
      root.dataLoaded();
    }
  }

  function get(path, def) {
    var parts = path.split(".");
    var obj = root.data;
    for (var i = 0; i < parts.length; i++) {
      if (obj === null || obj === undefined || typeof obj !== "object")
        return def;
      if (obj[parts[i]] === undefined)
        return def;
      obj = obj[parts[i]];
    }
    return obj;
  }

  function update(path, value) {
    var parts = path.split(".");
    var obj = root.data;
    for (var i = 0; i < parts.length - 1; i++) {
      if (obj[parts[i]] === undefined || typeof obj[parts[i]] !== "object")
        obj[parts[i]] = {};
      obj = obj[parts[i]];
    }
    obj[parts[parts.length - 1]] = value;
    root.data = JSON.parse(JSON.stringify(root.data));
    if (path === "previewStyle")
      root.previewStyle = value;
    if (_saveTimer.running) {
      _saveTimer.restart();
    } else {
      _saveTimer.start();
    }
  }

  function _doSave() {
    root._isSaving = true;
    var resolvedData = _resolvePaths(root.data);
    var ordered = {
      "wallpaperDirs": resolvedData.wallpaperDirs,
      "cacheDir": resolvedData.cacheDir,
      "debugMode": resolvedData.debugMode,
      "previewStyle": resolvedData.previewStyle,
      "videoBackend": resolvedData.videoBackend,
      "wallhaven": _pick(resolvedData.wallhaven, ["apiKey", "downloadDir", "defaultAtleast", "categories", "purity", "sorting"]),
      "appearance": _pick(resolvedData.appearance, ["showBorderGlow", "showShadow", "showBgPreview", "bgOverlayOpacity"])
    };
    var jsonStr = JSON.stringify(ordered, null, 2);
    _fileView.setText(jsonStr);
  }

  function _deepMerge(base, user) {
    var result = _deepClone(base);
    for (var k in user) {
      if (user[k] && typeof user[k] === "object" && !Array.isArray(user[k]) && result[k] && typeof result[k] === "object") {
        result[k] = _deepMerge(result[k], user[k]);
      } else {
        result[k] = user[k];
      }
    }
    return result;
  }

  function _deepClone(obj) {
    return JSON.parse(JSON.stringify(obj));
  }

  function _pick(obj, keys) {
    var out = {};
    for (var i = 0; i < keys.length; i++) {
      if (obj[keys[i]] !== undefined)
        out[keys[i]] = obj[keys[i]];
    }
    return out;
  }

  function _resolvePath(p) {
    if (p && typeof p === "string" && p.indexOf("$HOME") === 0)
      return Quickshell.env("HOME") + p.slice(5);
    return p;
  }

  function _resolvePaths(obj) {
    var r = _deepClone(obj);
    if (r.wallpaperDirs && Array.isArray(r.wallpaperDirs)) {
      for (var i = 0; i < r.wallpaperDirs.length; i++)
        r.wallpaperDirs[i] = _resolvePath(r.wallpaperDirs[i]);
    }
    if (r.cacheDir)
      r.cacheDir = _resolvePath(r.cacheDir);
    return r;
  }
}
