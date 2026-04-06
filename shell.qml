pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "models"
import "components"

ShellRoot {
  ConfigService {
    id: defaultConfigService
    Component.onCompleted: defaultConfigService.loadPath(Qt.resolvedUrl("assets/default.json").toString().slice(7))
  }

  UserConfigService {
    id: userConfigService
    defaultConfig: defaultConfigService
  }

  CacheService {
    id: cacheService
    cacheDir: userConfigService.cacheDir
    debugMode: userConfigService.debugMode
    onCacheScanned: {
      wallpaperModel.load();
    }
  }

  WallpaperModel {
    id: wallpaperModel
    dirs: userConfigService.wallpaperDirs
    scriptPath: Qt.resolvedUrl("./scripts/wallpaper.sh").toString().slice(7)
    debugMode: userConfigService.debugMode
  }

  WallpaperApplier {
    id: wallpaperApplier
    dirs: userConfigService.wallpaperDirs
    scriptPath: Qt.resolvedUrl("./scripts/wallpaper.sh").toString().slice(7)
  }

  CheckService {
    id: checkService
    onAllChecked: {
      cacheService.hasFfmpeg = hasFfmpeg;
      if (hasFfmpeg) {
        cacheService.initialize();
        cacheService.scanCache();
      }
    }
  }

  Variants {
    model: Quickshell.screens

    AppWindow {
      screen: modelData
      userConfigService: userConfigService
      checkService: checkService
      cacheService: cacheService
      wallpaperModel: wallpaperModel
      wallpaperApplier: wallpaperApplier
    }
  }

  Connections {
    target: userConfigService
    function onReadyChanged() {
      if (userConfigService.ready) {
        checkService.run();
      }
    }
  }
}
