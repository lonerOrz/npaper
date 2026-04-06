import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  required property var defaultConfig

  // ========== Paths ==========
  readonly property string configDir: Quickshell.env("HOME") + "/.config/npaper"
  readonly property string configPath: configDir + "/config.json"

  property bool isSaving: false
  property bool ready: false

  // ========== Reactive Properties ==========
  // Paths
  property var wallpaperDirs: []
  property string cacheDir: ""

  // Toggles
  property bool showBgPreview: true
  property bool debugMode: false
  property string previewStyle: "carousel"

  // Carousel
  property real carouselItemWidth: 450
  property real carouselItemHeight: 320
  property real carouselSpacing: 25
  property real carouselRotation: 40
  property real carouselPerspective: 0.3

  // Grid (Reserved for future)
  property int gridColumns: 4
  property real gridItemWidth: 320
  property real gridItemHeight: 220
  property real gridSpacing: 12

  // Animation
  property int scrollDuration: 280
  property int scrollContinueInterval: 230
  property int bgSlideDuration: 250
  property int bgFadeDuration: 400
  property real bgParallaxFactor: 40

  // Appearance
  property bool showBorderGlow: true
  property bool showShadow: true
  property real bgOverlayOpacity: 0.4

  // Performance
  property int visibleRange: 4
  property int preloadRange: 2

  // Search
  property int searchDebounceMs: 150

  // ========== Helpers ==========

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

  function _apply(obj) {
    if (!obj) return;
    // Paths
    if (obj.wallpaperDirs !== undefined) root.wallpaperDirs = _resolvePaths(obj.wallpaperDirs);
    if (obj.cacheDir !== undefined) root.cacheDir = _resolvePath(obj.cacheDir);
    if (obj.debugMode !== undefined) root.debugMode = obj.debugMode;

    // Toggles
    if (obj.showBgPreview !== undefined) root.showBgPreview = obj.showBgPreview;
    if (obj.previewStyle !== undefined) root.previewStyle = obj.previewStyle;

    // Carousel
    if (obj.carousel) {
      var c = obj.carousel;
      if (c.itemWidth !== undefined) root.carouselItemWidth = c.itemWidth;
      if (c.itemHeight !== undefined) root.carouselItemHeight = c.itemHeight;
      if (c.spacing !== undefined) root.carouselSpacing = c.spacing;
      if (c.rotation !== undefined) root.carouselRotation = c.rotation;
      if (c.perspective !== undefined) root.carouselPerspective = c.perspective;
    }

    // Animation
    if (obj.animation) {
      var a = obj.animation;
      if (a.scrollDuration !== undefined) root.scrollDuration = a.scrollDuration;
      if (a.scrollContinueInterval !== undefined) root.scrollContinueInterval = a.scrollContinueInterval;
      if (a.bgSlideDuration !== undefined) root.bgSlideDuration = a.bgSlideDuration;
      if (a.bgFadeDuration !== undefined) root.bgFadeDuration = a.bgFadeDuration;
      if (a.bgParallaxFactor !== undefined) root.bgParallaxFactor = a.bgParallaxFactor;
    }

    // Appearance
    if (obj.appearance) {
      var app = obj.appearance;
      if (app.showBorderGlow !== undefined) root.showBorderGlow = app.showBorderGlow;
      if (app.showShadow !== undefined) root.showShadow = app.showShadow;
      if (app.bgOverlayOpacity !== undefined) root.bgOverlayOpacity = app.bgOverlayOpacity;
    }

    // Performance
    if (obj.performance) {
      var p = obj.performance;
      if (p.visibleRange !== undefined) root.visibleRange = p.visibleRange;
      if (p.preloadRange !== undefined) root.preloadRange = p.preloadRange;
    }

    // Search
    if (obj.search && obj.search.debounceMs !== undefined) root.searchDebounceMs = obj.search.debounceMs;
  }

  // ========== Config Loading ==========

  function startCheck() {
    if (!defaultConfig.ready) return;
    
    // Apply defaults first
    _apply(defaultConfig.config);

    checkProcess.command = ["sh", "-c",
      '[ -f "$HOME/.config/npaper/config.json" ] && echo exists || echo missing'];
    checkProcess.running = true;
  }

  Connections {
    target: defaultConfig
    function onReadyChanged() {
      if (defaultConfig.ready) root.startCheck();
    }
  }

  Process {
    id: checkProcess
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() === "exists") {
          fileView.path = root.configPath;
        } else {
          root.ready = true;
        }
      }
    }
    onExited: function (code, status) {
      if (code !== 0) root.ready = true;
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
        _apply(userCfg); // Override defaults
        root.ready = true;
      } catch (e) {
        console.error("[npaper] UserConfig parse error:", e);
        root.ready = true;
      }
    }
  }

  // ========== Config Saving ==========

  Process {
    id: saveProcess
    onExited: function (code, status) {
      if (code === 0) root.isSaving = false;
    }
  }

  Timer {
    id: saveTimer
    interval: 500
    repeat: false
    onTriggered: {
      var json = {
        wallpaperDirs: root.wallpaperDirs,
        cacheDir: root.cacheDir,
        showBgPreview: root.showBgPreview,
        previewStyle: root.previewStyle,
        debugMode: root.debugMode,
        carousel: {
          itemWidth: root.carouselItemWidth,
          itemHeight: root.carouselItemHeight,
          spacing: root.carouselSpacing,
          rotation: root.carouselRotation,
          perspective: root.carouselPerspective
        },
        animation: {
          scrollDuration: root.scrollDuration,
          scrollContinueInterval: root.scrollContinueInterval,
          bgSlideDuration: root.bgSlideDuration,
          bgFadeDuration: root.bgFadeDuration,
          bgParallaxFactor: root.bgParallaxFactor
        },
        appearance: {
          showBorderGlow: root.showBorderGlow,
          showShadow: root.showShadow,
          bgOverlayOpacity: root.bgOverlayOpacity
        },
        performance: {
          visibleRange: root.visibleRange,
          preloadRange: root.preloadRange
        },
        search: {
          debounceMs: root.searchDebounceMs
        }
      };
      var str = JSON.stringify(json, null, 2);
      saveProcess.command = ["sh", "-c",
        'mkdir -p "$1" && printf "%s" "$2" > "$1/config.json"',
        "npaper-save", root.configDir, str];
      saveProcess.exec({});
      root.isSaving = true;
    }
  }

  function saveConfig() { saveTimer.restart(); }

  function set(key, value) {
    root[key] = value;
    saveConfig();
  }

  Component.onCompleted: {
    // Will be triggered by Connection to defaultConfig, but if default is already ready:
    if (defaultConfig.ready) root.startCheck();
  }
}
