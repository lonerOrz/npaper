pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Config — persistent user configuration (nested, no flattening).
 *
 * Uses JsonAdapter + FileView — same pattern as Noctalia Settings.
 * JSON keys automatically map to adapter properties. No manual merge.
 *
 * Singleton: automatically available when imported.
 * Do NOT instantiate in shell.qml.
 *
 * Usage:
 *   Config.data.carousel.itemWidth    → read
 *   Config.data.appearance.showShadow = false  → write (auto-saves)
 *   Config.get("carousel.itemWidth", 400)       → safe read with fallback
 */
Singleton {
  id: root

  readonly property string configPath: Quickshell.env("HOME") + "/.config/npaper/config.json"
  property bool isLoaded: false
  property bool _isSaving: false

  signal dataLoaded
  signal dataUpdated

  // ── Boot ─────────────────────────────────────────────────
  Component.onCompleted: {
    Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.config/npaper"]);
  }

  // Debounced save timer
  property Timer _saveTimer: Timer {
    interval: 500
    repeat: false
    onTriggered: _doSave()
  }

  // ── The JsonAdapter: full schema with nested defaults ──
  JsonAdapter {
    id: adapter

    property JsonObject carousel: JsonObject {
      property int itemWidth: 400
      property int itemHeight: 280
      property int spacing: 20
      property int rotation: 40
      property real perspective: 0.3
    }

    property JsonObject animation: JsonObject {
      property int scrollDuration: 280
      property int scrollContinueInterval: 230
      property int bgSlideDuration: 250
      property int bgParallaxFactor: 40
    }

    property JsonObject appearance: JsonObject {
      property bool showBorderGlow: true
      property bool showShadow: true
      property bool showBgPreview: true
      property real bgOverlayOpacity: 0.4
    }

    // Flat top-level keys
    property list<string> wallpaperDirs: ["$HOME/Pictures/wallpapers"]
    property string cacheDir: "$HOME/.cache/wallpaper_thumbs"
    property bool debugMode: false
    property string previewStyle: "carousel"
  }

  // Public read-only alias
  readonly property alias data: adapter

  // ── Public API ───────────────────────────────────────────

  // Safe read with dot-path and fallback: Config.get("carousel.itemWidth", 400)
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

  // FileView: reads config.json → populates adapter automatically
  FileView {
    id: _fileView
    path: root.configPath
    adapter: adapter
    printErrors: false
    watchChanges: true

    onAdapterUpdated: {
      if (!root._isSaving) {
        _saveTimer.restart();
      }
      // Notify consumers so SettingsBridge can sync viewModel
      root.dataUpdated();
    }

    onFileChanged: {
      if (root._isSaving) return;
      reload();
    }

    onLoaded: {
      // Resolve $HOME in path properties after adapter is populated
      var resolvedDirs = [];
      for (var i = 0; i < adapter.wallpaperDirs.length; i++) {
        var p = adapter.wallpaperDirs[i];
        resolvedDirs.push(p.indexOf("$HOME") === 0 ? Quickshell.env("HOME") + p.slice(5) : p);
      }
      adapter.wallpaperDirs = resolvedDirs;
      var cd = adapter.cacheDir;
      adapter.cacheDir = cd.indexOf("$HOME") === 0 ? Quickshell.env("HOME") + cd.slice(5) : cd;

      root.isLoaded = true;
      root.dataLoaded();
    }

    onLoadFailed: function (error) {
      // File doesn't exist — create with defaults
      if (error === 2) { // ENOENT
        root._isSaving = true;
        _fileView.writeAdapter();
        root._isSaving = false;
      }
      root.isLoaded = true;
      root.dataLoaded();
    }
  }

  // ── Save ─────────────────────────────────────────────────
  function _doSave() {
    root._isSaving = true;
    _fileView.writeAdapter();
    root._isSaving = false;
  }
}
