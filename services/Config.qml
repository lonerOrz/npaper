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
 *   3. UI reads:  Config.data.carousel.itemWidth
 *   4. UI writes: Config.update("carousel.itemWidth", 450) → modifies data → debounced save
 *   5. Hot-reload: FileView watches config.json → re-read → merge → dataUpdated
 */
Singleton {
  id: root

  readonly property string configPath: Quickshell.env("HOME") + "/.config/npaper/config.json"
  property bool isLoaded: false
  property bool _isSaving: false

  signal dataLoaded
  signal dataUpdated

  // ── Hardcoded defaults ──────────────────────────────────
  readonly property var _defaults: ({
    "wallpaperDirs": ["$HOME/Pictures/wallpapers"],
    "cacheDir": "$HOME/.cache/wallpaper_thumbs",
    "debugMode": false,
    "previewStyle": "carousel",
    "carousel": {
      "itemWidth": 400,
      "itemHeight": 280,
      "spacing": 20,
      "rotation": 40,
      "perspective": 0.3
    },
    "animation": {
      "scrollDuration": 280,
      "scrollContinueInterval": 230,
      "bgSlideDuration": 250,
      "bgParallaxFactor": 40
    },
    "appearance": {
      "showBorderGlow": true,
      "showShadow": true,
      "showBgPreview": true,
      "bgOverlayOpacity": 0.4
    }
  })

  // ── Merged data (pure JS object) ────────────────────────
  property var data: ({})

  property Timer _saveTimer: Timer {
    interval: 500
    repeat: false
    onTriggered: {
      console.log("[npaper][I] Config _saveTimer FIRED — calling _doSave");
      _doSave();
    }
  }

  // ── Boot ─────────────────────────────────────────────────
  Component.onCompleted: {
    // Initialize data to defaults first
    root.data = _deepClone(_defaults);
    console.log("[npaper][I] Config: initialized with defaults, itemWidth =", root.data.carousel.itemWidth);
    Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.config/npaper"]);
    _readConfig();
  }

  // Read config.json via Process
  function _readConfig() {
    _readProc.command = ["cat", root.configPath];
    _readProc.exec({});
  }

  Process {
    id: _readProc
    stdout: StdioCollector { id: _readStdout }
    stderr: StdioCollector { id: _readStderr }
    onExited: function (code) {
      console.log("[npaper][I] Config _readProc exited, code =", code);
      var raw = _readStdout.text;
      if (code !== 0 || !raw || String(raw).trim().length === 0) {
        // No file — use defaults (already set)
        console.log("[npaper][I] Config _readProc: no data, using defaults");
        root.isLoaded = true;
        root.dataLoaded();
        return;
      }
      try {
        var user = JSON.parse(String(raw).trim());
        console.log("[npaper][I] Config _readProc: parsed user config");
        root.data = _deepMerge(_deepClone(_defaults), user);
        root.data = _resolvePaths(root.data);
        console.log("[npaper][I] Config _readProc: merged data, itemWidth =", root.data.carousel.itemWidth);
        root.isLoaded = true;
        root.dataLoaded();
      } catch (e) {
        console.error("Config: parse error", e);
        root.data = _deepClone(_defaults);
        root.isLoaded = true;
        root.dataLoaded();
      }
    }
  }

  // FileView for hot-reload only
  FileView {
    id: _fileView
    path: root.configPath
    printErrors: false
    watchChanges: true

    onFileChanged: {
      if (root._isSaving) return;
      _readConfig();
    }
  }

  // ── Public API ───────────────────────────────────────────

  // Safe read: Config.get("carousel.itemWidth", 400)
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

  // Write: Config.update("carousel.itemWidth", 450)
  function update(path, value) {
    console.log("[npaper][I] Config.update called:", path, "=", value);
    var parts = path.split(".");
    var obj = root.data;
    for (var i = 0; i < parts.length - 1; i++) {
      if (obj[parts[i]] === undefined || typeof obj[parts[i]] !== "object")
        obj[parts[i]] = {};
      obj = obj[parts[i]];
    }
    console.log("[npaper][I] Config.update setting", parts[parts.length - 1], "=", value);
    obj[parts[parts.length - 1]] = value;
    console.log("[npaper][I] Config.update: data =", JSON.stringify(root.data).substring(0, 100));
    if (_saveTimer.running) {
      _saveTimer.restart();
      console.log("[npaper][I] Config.update: restarting save timer");
    } else {
      _saveTimer.start();
      console.log("[npaper][I] Config.update: starting save timer");
    }
  }

  // ── Save ─────────────────────────────────────────────────
  function _doSave() {
    root._isSaving = true;
    var ordered = {
      "wallpaperDirs": root.data.wallpaperDirs,
      "cacheDir": root.data.cacheDir,
      "debugMode": root.data.debugMode,
      "previewStyle": root.data.previewStyle,
      "carousel": _pick(root.data.carousel, ["itemWidth","itemHeight","spacing","rotation","perspective"]),
      "animation": _pick(root.data.animation, ["scrollDuration","scrollContinueInterval","bgSlideDuration","bgParallaxFactor"]),
      "appearance": _pick(root.data.appearance, ["showBorderGlow","showShadow","showBgPreview","bgOverlayOpacity"])
    };
    var jsonStr = JSON.stringify(ordered, null, 2);
    _writeProc.command = ["python3", "-c",
      "import sys, json; json.dump(json.loads(sys.argv[1]), open(sys.argv[2], 'w'), indent=2)",
      jsonStr, root.configPath];
    _writeProc.exec({});
  }

  Process {
    id: _writeProc
    onExited: function (code) {
      root._isSaving = false;
      if (code !== 0)
        console.error("Config: write failed, exit code =", code);
    }
  }

  // ── Helpers ──────────────────────────────────────────────

  function _deepMerge(base, user) {
    var result = _deepClone(base);
    for (var k in user) {
      if (user[k] && typeof user[k] === "object" && !Array.isArray(user[k])
          && result[k] && typeof result[k] === "object") {
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
