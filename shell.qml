pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components.settings
import qs.components.wallpaper
import qs.services

ShellRoot {
  id: shellRoot

  Connections {
    target: Config
    function onDataLoaded() {
      Logger.applyDebug(Config.data.debugMode);
    }
  }

  Scope {
    id: shellScope

    SettingsBridge {
      id: bridge
    }

    CheckService {
      id: checkService
      onAllChecked: {
        cacheService.hasFfmpeg = hasFfmpeg;
      }
    }

    CacheService {
      id: cacheService
      property bool _initialized: false
      cacheDir: bridge.viewModel ? bridge.viewModel.paths.cacheDir : ""
      debugMode: bridge.viewModel ? bridge.viewModel.debugMode : false
    }

    WallpaperApplier {
      id: wallpaperApplier
      dirs: bridge.viewModel ? bridge.viewModel.paths.wallpaperDirs : []
      scriptPath: Qt.resolvedUrl("./scripts/wallpaper.sh").toString().replace("file://", "")
      videoBackend: bridge.viewModel ? bridge.viewModel.videoBackend : "mpvpaper"
    }

    readonly property var _effectiveWallpaperDirs: {
      var dirs = bridge.viewModel ? bridge.viewModel.paths.wallpaperDirs : [];
      var whDir = bridge.viewModel ? bridge.viewModel.wallhaven.downloadDir : "";
      if (whDir && whDir.length > 0 && dirs.indexOf(whDir) === -1)
        dirs = dirs.concat([whDir]);
      return dirs;
    }

    WallpaperAdapter {
      id: wallpaperAdapter
      configViewModel: bridge.viewModel
      wallpaperDirs: shellScope._effectiveWallpaperDirs
      scriptPath: Qt.resolvedUrl("./scripts/wallpaper.sh").toString().replace("file://", "")
      cacheService: cacheService
    }

    ViewModel {
      id: appViewModel
      configViewModel: bridge.viewModel
      adapter: wallpaperAdapter
      cacheService: cacheService
      wallpaperApplier: wallpaperApplier
    }

    function _initCache() {
      if (cacheService._initialized)
        return;
      cacheService._initialized = true;
      cacheService.hasFfmpeg = checkService.hasFfmpeg;
      cacheService.initialize();
      cacheService.scanCache();
    }

    Component.onCompleted: {
      ServiceLocator.register({
                                adapter: wallpaperAdapter,
                                cacheService: cacheService,
                                applier: wallpaperApplier,
                                checks: checkService
                              });

      _initCache();
    }

    Variants {
      model: Quickshell.screens
      delegate: AppWindow {
        screen: modelData
        configViewModel: bridge.viewModel
        appViewModel: appViewModel
        adapter: wallpaperAdapter
        cacheService: cacheService
        wallpaperApplier: wallpaperApplier
        checkService: checkService
      }
    }
  }
}
