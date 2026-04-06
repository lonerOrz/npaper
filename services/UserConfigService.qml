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
  property var wallpaperDirs: []
  property string cacheDir: ""
  property bool showBgPreview: true
  property string previewStyle: "carousel"
  property bool debugMode: false

  // Carousel
  property real carouselItemWidth: 450
  property real carouselItemHeight: 320
  property real carouselSpacing: 25
  property real carouselRotation: 40
  property real carouselPerspective: 0.3

  // Animation (Tunable)
  property int scrollDuration: 280
  property int scrollContinueInterval: 230
  property int bgSlideDuration: 250
  property real bgParallaxFactor: 40

  // Appearance
  property bool showBorderGlow: true
  property bool showShadow: true
  property real bgOverlayOpacity: 0.4

  // ========== Helpers ==========

  function _resolvePath(pathStr) {
    if (!pathStr)
      return "";
    if (pathStr.indexOf("$HOME") === 0)
      return Quickshell.env("HOME") + pathStr.slice(5);
    return pathStr;
  }

  function _resolvePaths(dirs) {
    if (!Array.isArray(dirs))
      return [];
    var result = [];
    for (var i = 0; i < dirs.length; i++)
      result.push(_resolvePath(dirs[i]));
    return result;
  }

  function _apply(obj) {
    if (!obj)
      return;
    // Paths
    if (obj.wallpaperDirs !== undefined)
      root.wallpaperDirs = _resolvePaths(obj.wallpaperDirs);
    if (obj.cacheDir !== undefined)
      root.cacheDir = _resolvePath(obj.cacheDir);
    if (obj.debugMode !== undefined)
      root.debugMode = obj.debugMode;

    // Toggles
    if (obj.showBgPreview !== undefined)
      root.showBgPreview = obj.showBgPreview;
    if (obj.previewStyle !== undefined)
      root.previewStyle = obj.previewStyle;

    // Carousel
    if (obj.carousel) {
      var c = obj.carousel;
      if (c.itemWidth !== undefined)
        root.carouselItemWidth = c.itemWidth;
      if (c.itemHeight !== undefined)
        root.carouselItemHeight = c.itemHeight;
      if (c.spacing !== undefined)
        root.carouselSpacing = c.spacing;
      if (c.rotation !== undefined)
        root.carouselRotation = c.rotation;
      if (c.perspective !== undefined)
        root.carouselPerspective = c.perspective;
    }

    // Animation
    if (obj.animation) {
      var a = obj.animation;
      if (a.scrollDuration !== undefined)
        root.scrollDuration = a.scrollDuration;
      if (a.scrollContinueInterval !== undefined)
        root.scrollContinueInterval = a.scrollContinueInterval;
      if (a.bgSlideDuration !== undefined)
        root.bgSlideDuration = a.bgSlideDuration;
      if (a.bgParallaxFactor !== undefined)
        root.bgParallaxFactor = a.bgParallaxFactor;
    }

    // Appearance
    if (obj.appearance) {
      var app = obj.appearance;
      if (app.showBorderGlow !== undefined)
        root.showBorderGlow = app.showBorderGlow;
      if (app.showShadow !== undefined)
        root.showShadow = app.showShadow;
      if (app.bgOverlayOpacity !== undefined)
        root.bgOverlayOpacity = app.bgOverlayOpacity;
    }
  }

  // ========== Config Loading ==========

  function startCheck() {
    if (!defaultConfig.ready)
      return;

    // Apply defaults first
    _apply(defaultConfig.config);

    checkProcess.command = ["sh", "-c", '[ -f "$HOME/.config/npaper/config.json" ] && echo exists || echo missing'];
    checkProcess.running = true;
  }

  Connections {
    target: defaultConfig
    function onReadyChanged() {
      if (defaultConfig.ready)
        root.startCheck();
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
      if (code !== 0)
        root.ready = true;
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
      if (code === 0)
        root.isSaving = false;
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
          bgParallaxFactor: root.bgParallaxFactor
        },
        appearance: {
          showBorderGlow: root.showBorderGlow,
          showShadow: root.showShadow,
          bgOverlayOpacity: root.bgOverlayOpacity
        }
      };
      var str = JSON.stringify(json, null, 2);
      saveProcess.command = ["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$1/config.json"', "npaper-save", root.configDir, str];
      saveProcess.exec({});
      root.isSaving = true;
    }
  }

  function saveConfig() {
    saveTimer.restart();
  }

  function set(key, value) {
    root[key] = value;
    saveConfig();
  }

  Component.onCompleted: {
    if (defaultConfig.ready)
      root.startCheck();
  }
}
