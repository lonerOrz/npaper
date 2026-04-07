pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.models
import qs.services

ShellRoot {
  id: shellRoot

  property bool configLoaded: false

  // Gate: wait for Config before creating UI
  Connections {
    target: Config
    function onDataLoaded() {
      configLoaded = true;
      Logger.applyDebug(Config.data.debugMode);
    }
    function onDataUpdated() {
      // Hot-reload: SettingsBridge handles viewModel sync internally
    }
  }

  Loader {
    active: configLoaded

    sourceComponent: Item {
      SettingsBridge {
        id: bridge
      }

      function _initCache() {
        if (cacheService._initialized) return;
        if (!checkService.hasFfmpeg) return;
        if (!bridge.viewModel) return;
        cacheService._initialized = true;
        cacheService.initialize();
        cacheService.scanCache();
      }

      CheckService {
        id: checkService
        property bool _ready: false
        Component.onCompleted: { run(); }
        onAllChecked: {
          _ready = true;
          cacheService.hasFfmpeg = hasFfmpeg;
          if (bridge.viewModel) {
            _initCache();
          }
        }
      }

      Connections {
        target: bridge
        function onViewModelChanged() {
          if (bridge.viewModel && checkService._ready) {
            _initCache();
          }
        }
      }

      CacheService {
        id: cacheService
        property bool _initialized: false
        cacheDir: Config.data.cacheDir
        debugMode: Config.data.debugMode
        onCacheScanned: {
          wallpaperModel.load()
        }
      }

      WallpaperModel {
        id: wallpaperModel
        dirs: Config.data.wallpaperDirs
        scriptPath: Qt.resolvedUrl("./scripts/wallpaper.sh").toString().slice(7)
        debugMode: Config.data.debugMode
      }

      WallpaperApplier {
        id: wallpaperApplier
        dirs: Config.data.wallpaperDirs
        scriptPath: Qt.resolvedUrl("./scripts/wallpaper.sh").toString().slice(7)
      }

      Variants {
        model: Quickshell.screens
        delegate: AppWindow {
          screen: modelData
          wallpaperModel: wallpaperModel
          cacheService: cacheService
          wallpaperApplier: wallpaperApplier
          checkService: checkService
        }
      }
    }
  }
}
