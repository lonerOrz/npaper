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
                                      "scrollDuration": 280,
                                      "scrollContinueInterval": 230,
                                      "bgSlideDuration": 250,
                                      "bgParallaxFactor": 40
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
    saveProcess.command = ["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" | jq "." > "$1/style.json"', "_save", root.configDir, jsonStr];
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
    command: ["test", "-f", root.stylePath]
    onExited: function (code, status) {
      if (code === 0) {
        userView.path = root.stylePath;
      } else {
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
        return;
      }
      reload();
    }

    onLoaded: {
      try {
        var textContent = text();
        if (!textContent || textContent.trim().length === 0) {
          root.loaded(JSON.parse(JSON.stringify(_defaults)));
          return;
        }
        var userCfg = JSON.parse(textContent);
        root.loaded(userCfg);
      } catch (e) {
        root.error("Config error: " + e);
      }
    }
  }

  Process {
    id: saveProcess
    onExited: function (code, status) {
      root.isSaving = false;
    }
  }
}
