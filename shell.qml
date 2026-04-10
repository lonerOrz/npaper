pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components.settings
import qs.components.wallpaper
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
  }

  Loader {
    active: configLoaded

    sourceComponent: Item {
      id: shellItem
      SettingsBridge {
        id: bridge
      }

      function _initCache() {
        if (cacheService._initialized)
          return;
        if (!checkService.hasFfmpeg)
          return;
        if (!bridge.viewModel)
          return;
        cacheService._initialized = true;
        cacheService.initialize();
        cacheService.scanCache();
      }

      CheckService {
        id: checkService
        property bool _ready: false
        Component.onCompleted: {
          run();
        }
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
          // Adapter loads its own data
        }
      }

      WallpaperApplier {
        id: wallpaperApplier
        dirs: Config.data.wallpaperDirs
        scriptPath: Qt.resolvedUrl("./scripts/wallpaper.sh").toString().slice(7)
      }

      // Computed wallpaper dirs: user dirs + wallhaven download dir (if configured)
      readonly property var _effectiveWallpaperDirs: {
        var dirs = Config.data.wallpaperDirs || [];
        var whDir = Config.data.wallhaven ? Config.data.wallhaven.downloadDir : "";
        if (whDir && whDir.length > 0 && dirs.indexOf(whDir) === -1)
        dirs = dirs.concat([whDir]);
        return dirs;
      }

      // Must be defined BEFORE Variants so it's available for injection
      WallpaperAdapter {
        id: wallpaperAdapter
        wallpaperDirs: shellItem._effectiveWallpaperDirs
        scriptPath: Qt.resolvedUrl("./scripts/wallpaper.sh").toString().slice(7)
        debugMode: Config.data.debugMode
        cacheDir: Config.data.cacheDir
        cacheService: cacheService
      }

      // Register into ServiceLocator for leaf components
      Component.onCompleted: {
        ServiceLocator.register({
                                  adapter: wallpaperAdapter,
                                  cacheService: cacheService,
                                  applier: wallpaperApplier,
                                  checks: checkService
                                });
      }

      Variants {
        model: Quickshell.screens
        delegate: AppWindow {
          screen: modelData
          viewModel: bridge.viewModel
          adapter: wallpaperAdapter
          cacheService: cacheService
          wallpaperApplier: wallpaperApplier
          checkService: checkService
        }
      }
    }
  }
}
