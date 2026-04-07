import QtQuick
import Quickshell
import Quickshell.Io

/*
 * SettingsService — pure persistence layer.
 *
 * Structure: nested, matches config.json exactly.
 * No flattening — new sections require no code changes.
 *
 * API:
 *   get(path)           → "carousel.itemWidth" returns 400
 *   update(path, value) → "carousel.itemWidth", 450
 *   config              → full nested object (for reading at startup)
 *
 * Signals:
 *   dataLoaded  — config fully loaded/merged
 *   dataChanged — external file edit (hot-reload)
 */
Item {
  id: root

  readonly property string configPath: Quickshell.env("HOME") + "/.config/npaper/config.json"

  // ── Merged defaults + user overrides (nested tree) ──────
  property var config: ({})
  property bool ready: false
  property bool _isSaving: false

  // ── Defaults — matches config.json structure ────────────
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

  property bool _dataLoadedOnce: false

  signal dataLoaded
  signal dataChanged

  // Debounced save
  property Timer _saveTimer: Timer {
    interval: 500
    repeat: false
    onTriggered: _doSave()
  }

  // ── Public API ───────────────────────────────────────────
  // Get value by dot-path: get("carousel.itemWidth")
  function get(path, def) {
    var parts = path.split(".");
    var obj = root.config;
    for (var i = 0; i < parts.length; i++) {
      if (obj === null || obj === undefined || typeof obj !== "object")
        return def;
      if (obj[parts[i]] === undefined)
        return def;
      obj = obj[parts[i]];
    }
    return obj;
  }

  // Update value by dot-path: update("carousel.itemWidth", 450)
  function update(path, value) {
    var next = JSON.parse(JSON.stringify(root.config));
    var parts = path.split(".");
    var obj = next;
    for (var i = 0; i < parts.length - 1; i++) {
      if (obj[parts[i]] === undefined || typeof obj[parts[i]] !== "object")
        obj[parts[i]] = {};
      obj = obj[parts[i]];
    }
    obj[parts[parts.length - 1]] = value;
    root.config = next;
    if (_saveTimer.running)
      _saveTimer.restart();
    else
      _saveTimer.start();
  }

  // ── Boot ─────────────────────────────────────────────────
  Component.onCompleted: {
    _readConfig();
  }

  function _readConfig() {
    _readProc.command = ["cat", root.configPath];
    _readProc.exec({});
  }

  Process {
    id: _readProc
    stdout: StdioCollector { id: _readStdout }
    stderr: StdioCollector { id: _readStderr }
    onExited: function (code, status) {
      var raw = _readStdout.text;
      if (code !== 0 || !raw || String(raw).trim().length === 0) {
        _loadDefaults();
        return;
      }
      try {
        var user = JSON.parse(String(raw).trim());
        root.config = _deepMerge(JSON.parse(JSON.stringify(_defaults)), user);
        root.config = _resolvePaths(root.config);
        root.ready = true;
        if (root._dataLoadedOnce) { root.dataChanged(); return; }
        root._dataLoadedOnce = true;
        root.dataLoaded();
      } catch (e) {
        console.error("SettingsService: parse error", e);
        _loadDefaults();
      }
    }
  }

  // FileView only for hot-reload monitoring
  FileView {
    id: _fileView
    path: root.configPath
    printErrors: true
    watchChanges: true

    onFileChanged: {
      if (root._isSaving) return;
      _readConfig();
    }
  }

  function _loadDefaults() {
    root.config = _resolvePaths(JSON.parse(JSON.stringify(_defaults)));
    root.ready = true;
    if (root._dataLoadedOnce) { root.dataChanged(); return; }
    root._dataLoadedOnce = true;
    root.dataLoaded();
  }

  function _doSave() {
    var jsonStr = JSON.stringify(root.config, null, 2);
    _writeProc.command = ["python3", "-c",
      "import sys, json; json.dump(json.loads(sys.argv[1]), open(sys.argv[2], 'w'), indent=2)",
      jsonStr, root.configPath];
    _writeProc.exec({});
    root._isSaving = true;
  }

  Process {
    id: _writeProc
    onExited: function (code, status) {
      root._isSaving = false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────
  // Deep merge: defaults as base, user overrides on top
  function _deepMerge(base, user) {
    var result = JSON.parse(JSON.stringify(base));
    for (var k in user) {
      if (user[k] && typeof user[k] === "object" && !Array.isArray(user[k]) && result[k] && typeof result[k] === "object") {
        result[k] = _deepMerge(result[k], user[k]);
      } else {
        result[k] = user[k];
      }
    }
    return result;
  }

  function _resolvePath(p) {
    if (p && p.indexOf("$HOME") === 0)
      return Quickshell.env("HOME") + p.slice(5);
    return p;
  }

  function _resolvePaths(obj) {
    var r = JSON.parse(JSON.stringify(obj));
    if (r.wallpaperDirs) {
      var d = [];
      for (var i = 0; i < r.wallpaperDirs.length; i++)
        d.push(_resolvePath(r.wallpaperDirs[i]));
      r.wallpaperDirs = d;
    }
    if (r.cacheDir)
      r.cacheDir = _resolvePath(r.cacheDir);
    return r;
  }
}
