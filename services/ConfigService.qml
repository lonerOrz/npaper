import QtQuick
import Quickshell
import Quickshell.Io
import "../models"

Item {
  id: root

  required property ConfigModel model

  // Signals to communicate with ViewModel
  signal loaded(var configData)
  signal saveCompleted(bool success)
  signal error(string message)

  readonly property string configDir: Quickshell.env("HOME") + "/.config/npaper"
  readonly property string stylePath: configDir + "/style.json"

  // Defaults are defined here so ConfigService controls them
  readonly property var _defaults: ({
                                      "wallpaperDirs": ["$HOME/Pictures/wallpapers"],
                                      "cacheDir": "$HOME/.cache/wallpaper_thumbs",
                                      "debugMode": false,
                                      "carouselItemWidth": 450,
                                      "carouselItemHeight": 320,
                                      "carouselSpacing": 25,
                                      "carouselRotation": 40,
                                      "carouselPerspective": 0.3,
                                      "scrollDuration": 280,
                                      "scrollContinueInterval": 230,
                                      "bgSlideDuration": 250,
                                      "bgParallaxFactor": 40,
                                      "showBgPreview": true,
                                      "showBorderGlow": true,
                                      "showShadow": true,
                                      "bgOverlayOpacity": 0.4
                                    })

  property bool isSaving: false

  // Public API
  function get(key) {
    var val = (model && model.data && model.data[key] !== undefined) ? model.data[key] : _defaults[key];

    // Resolve $HOME for specific keys
    if (val !== undefined) {
      if (key === "wallpaperDirs" && Array.isArray(val)) {
        return val.map(p => _resolvePath(p));
      }
      if (key === "cacheDir" && typeof val === "string") {
        return _resolvePath(val);
      }
    }
    return val;
  }

  function _resolvePath(p) {
    if (p && p.indexOf("$HOME") === 0) {
      return Quickshell.env("HOME") + p.slice(5);
    }
    return p;
  }

  function save(data) {
    var jsonStr = JSON.stringify(data, null, 2);
    saveProcess.command = ["sh", "-c", 'mkdir -p "$1" && printf "%s" > "$1/style.json"', "npaper-save", root.configDir, jsonStr];
    saveProcess.exec({});
    root.isSaving = true;
  }

  function load() {
    // 1. Load defaults synchronously
    var defaults = JSON.parse(JSON.stringify(_defaults));

    // 2. Load user config asynchronously
    checkUserConfig.running = true;

    // 3. When user config loads, merge and emit loaded signal
    // (Actual merging happens in userView.onLoaded)
  }

  // IO: Check file
  Process {
    id: checkUserConfig
    command: ["sh", "-c", '[ -f "$HOME/.config/npaper/style.json" ] && echo exists || echo missing']
    onExited: function (code, status) {
      if (code === 0 && stdout && stdout.trim() === "exists") {
        userView.path = root.stylePath;
      } else {
        // No user config file - use defaults and emit loaded signal
        root.loaded(JSON.parse(JSON.stringify(_defaults)));
      }
    }
  }

  // IO: Read user config
  FileView {
    id: userView
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
        // Merge user config into current model data
        var updated = JSON.parse(JSON.stringify(model.data)); // Clone
        for (var k in userCfg) {
          updated[k] = userCfg[k];
        }
        // Emit loaded signal with merged config - ViewModel will handle updating model
        root.loaded(updated);
      } catch (e) {
        root.error("Config error: " + e);
      }
    }
  }

  Process {
    id: saveProcess
    onExited: function (code, status) {
      if (code === 0)
        root.isSaving = false;
    }
  }
}
