pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.models
import qs.services
import qs.utils

ShellRoot {
  SettingsService {
    id: settings
    onDataLoaded: Logger.applyDebug(settings.config.debugMode)
  }

  SettingsBridge {
    id: bridge
    settings: settings
  }

  CheckService {
    id: checkService
    Component.onCompleted: run()
    onAllChecked: {
      cacheService.hasFfmpeg = hasFfmpeg;
      if (hasFfmpeg && bridge.viewModel) {
        cacheService.initialize();
        cacheService.scanCache();
      }
    }
  }

  CacheService {
    id: cacheService
    cacheDir: bridge.viewModel ? bridge.viewModel.system.cacheDir : ""
    debugMode: bridge.viewModel ? bridge.viewModel.system.debugMode : false
    onCacheScanned: {
      wallpaperModel.load()
    }
  }

  WallpaperModel {
    id: wallpaperModel
    dirs: bridge.viewModel ? bridge.viewModel.system.wallpaperDirs : []
    scriptPath: Qt.resolvedUrl("./scripts/wallpaper.sh").toString().slice(7)
    debugMode: bridge.viewModel ? bridge.viewModel.system.debugMode : false
  }

  WallpaperApplier {
    id: wallpaperApplier
    dirs: bridge.viewModel ? bridge.viewModel.system.wallpaperDirs : []
    scriptPath: Qt.resolvedUrl("./scripts/wallpaper.sh").toString().slice(7)
  }

  Variants {
    model: Quickshell.screens
    delegate: AppWindow {
      screen: modelData
      viewModel: bridge.viewModel
      bridge: bridge
      wallpaperModel: wallpaperModel
      cacheService: cacheService
      wallpaperApplier: wallpaperApplier
      checkService: checkService
    }
  }
}
