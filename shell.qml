pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "services"
import "models"
import "viewmodels"
import "components"

ShellRoot {
    // 1. Model (State)
    ConfigModel { id: configModel }

    // 2. Service (IO)
    ConfigService {
        id: configService
        model: configModel
        Component.onCompleted: load()
        onLoaded: function(configData) {
            // Update model with loaded config data
            model.data = configData
            model.ready = true
        }
        onError: function(message) {
            console.error("[npaper] ConfigService error:", message)
            // Still set model with defaults on error
            model.data = JSON.parse(JSON.stringify(configService._defaults))
            model.ready = true
        }
    }

    // 3. ViewModel (Logic)
    SettingsViewModel {
        id: settingsVM
        model: configModel
        configService: configService
    }

    // 4. Business Services
    CacheService {
        id: cacheService
        cacheDir: configService.get("cacheDir")
        debugMode: configService.get("debugMode")
        onCacheScanned: { wallpaperModel.load(); }
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

    // 5. Kick off checks when config is ready
    Connections {
        target: configModel
        function onReadyChanged() {
            console.log("[npaper] ConfigModel ready changed:", configModel.ready);
            if (configModel.ready) {
                console.log("[npaper] Triggering checkService.run()");
                checkService.run()
            }
        }
    }

    // 6. UI
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
