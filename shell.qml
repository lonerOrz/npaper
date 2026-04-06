pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.models
import qs.services
import qs.utils
import qs.viewmodels

ShellRoot {
  ConfigModel {
    id: configModel
  }

  ConfigService {
    id: configService
    model: configModel
    Component.onCompleted: load()
    onLoaded: function (configData) {
      model.data = configData;
      model.ready = true;
    }
    onError: function (message) {
      Logger.e("ConfigService error:", message);
      model.data = JSON.parse(JSON.stringify(configService._defaults));
      model.ready = true;
    }
  }

  SettingsViewModel {
    id: settingsVM
    model: configModel
    configService: configService
  }

  CacheService {
    id: cacheService
    cacheDir: configService.get("cacheDir")
    debugMode: configService.get("debugMode")
    onCacheScanned: {
      wallpaperModel.load();
    }
  }

  WallpaperModel {
    id: wallpaperModel
    dirs: configService.get("wallpaperDirs")
    scriptPath: Qt.resolvedUrl("./scripts/wallpaper.sh").toString().slice(7)
    debugMode: configService.get("debugMode")
  }

  WallpaperApplier {
    id: wallpaperApplier
    dirs: configService.get("wallpaperDirs")
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

  Connections {
    target: configModel
    function onReadyChanged() {
      Logger.d("ConfigModel ready changed:", configModel.ready);
      if (configModel.ready) {
        Logger.d("Triggering checkService.run()");
        checkService.run();
      }
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: AppWindow {
      screen: modelData
      viewModel: settingsVM
      wallpaperModel: wallpaperModel
      cacheService: cacheService
      wallpaperApplier: wallpaperApplier
      checkService: checkService
    }
  }
}
