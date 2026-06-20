import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "utils/CacheUtils.js" as CacheUtils
import "utils/FileTypes.js" as FileTypes
import qs.components.bar
import qs.components.common
import qs.components.manager
import qs.components.settings
import qs.components.wallpaper
import qs.services

PanelWindow {
  id: root

  property var modelData
  property var configViewModel
  property var appViewModel
  property var adapter
  property var cacheService
  property var wallpaperApplier
  property var checkService

  screen: modelData

  visible: true
  color: "transparent"
  implicitWidth: screen.width
  implicitHeight: screen.height

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.exclusiveZone: -1

  Component.onCompleted: {
    Style.uiScaleRatio = screen.height / 1080;

    if (appViewModel) {
      appViewModel.bindDisplayManager(displayManager);
      appViewModel.bindColorExtractor(colorExtractor);
      appViewModel.bindStatusBar(statusBar);
      appViewModel.init();
    }

    if (BlurService.available) {
      Qt.callLater(_initAllBlur);
    }
  }

  function _initAllBlur() {
    if (!BlurService.available)
      return;
    try {
      const qml = `
        import Quickshell
        Region {
          Region { item: statusBar; radius: ${Style.barRadius} }
          Region { item: settingsPanel; radius: ${Style.settingsRadius} }
          Region { item: wallhavenFilter; radius: ${Style.barRadius} }
        }
      `;

      _blurRoot = Qt.createQmlObject(qml, root, "BlurRoot");
      root.BackgroundEffect.blurRegion = _blurRoot;
    } catch (e) {
      console.warn("AppWindow: Failed to create blur regions:", e);
    }
  }

  property var _blurRoot: null

  DisplayManager {
    id: displayManager
    anchors.fill: parent
    anchors.margins: Style.carouselSideMargin
    anchors.topMargin: Style.carouselTopMargin
    z: 1

    displayMode: Config.previewStyle

    configViewModel: root.configViewModel
    appViewModel: root.appViewModel
    wallhavenFilter: wallhavenFilter
    adapter: root.adapter
    cacheService: root.cacheService
    wallpaperApplier: root.wallpaperApplier
    checkService: root.checkService
  }

  ColorExtractor {
    id: colorExtractor
    thumbHashToPath: cacheService ? cacheService.thumbHashToPath : ({})
    hasImageMagick: checkService ? checkService.hasImagemagick : false
  }

  Connections {
    target: colorExtractor
    function onColorChanged(color) {
      if (appViewModel && color)
        appViewModel.dominantColor = color;
    }
  }

  BackgroundManager {
    anchors.fill: parent
    currentWallpaperItem: (appViewModel && appViewModel.bgCurrent >= 0 && adapter && appViewModel.bgCurrent < adapter.items.length) ? adapter.items[appViewModel.bgCurrent] : null
    parallaxX: displayManager ? displayManager.contentOffset * (appViewModel ? appViewModel.bgParallaxFactor : Style.defaultBgParallaxFactor) : 0
    dominantColor: appViewModel ? appViewModel.dominantColor : Color.mPrimary
    overlayOpacity: appViewModel ? appViewModel.bgOverlayOpacity : 0.4
    showPreview: appViewModel ? appViewModel.showBgPreview : true
    slideDuration: appViewModel ? appViewModel.bgSlideDuration : Style.defaultBgSlideDuration
  }

  StatusBar {
    id: statusBar
    anchors.top: parent.top
    anchors.topMargin: Style.barTopMargin
    anchors.horizontalCenter: parent.horizontalCenter
    z: 100

    folders: adapter && adapter.currentSource === "local" ? adapter.folders : []
    activeFolder: adapter && adapter.currentSource === "local" ? adapter.currentFolder : ""
    onFolderClicked: function (folder) {
      if (appViewModel)
        appViewModel.switchFolder(folder);
    }
    wallpaperCount: appViewModel ? appViewModel.count : 0
    cachedCount: cacheService ? cacheService.cachedFileCount : 0
    queueCount: cacheService ? cacheService.queueLength + cacheService.thumbnailJobRunning : 0
    dominantColor: appViewModel ? appViewModel.dominantColor : Color.mPrimary
    settingsOpen: appViewModel ? appViewModel.settingsOpen : false
    isWallhaven: wallhavenFilter.filterVisible || (adapter && adapter.currentSource === "remote")
    onSettingsToggled: appViewModel ? appViewModel.toggleSettings() : null
    onWallhavenToggled: wallhavenFilter.filterVisible = !wallhavenFilter.filterVisible

    searchText: appViewModel ? appViewModel.searchText : ""
    onSearchInputChanged: function (text) {
      if (appViewModel)
        appViewModel.handleSearchInput(text);
    }
    onSearchCleared: {
      if (appViewModel) {
        appViewModel.handleSearchClear();
        displayManager.focusView();
      }
    }
    onSearchSubmitted: {
      if (appViewModel) {
        appViewModel.handleSearchSubmit();
        displayManager.focusView();
      }
    }
  }

  Component.onDestruction: {
    if (_blurRoot) {
      try {
        root.BackgroundEffect.blurRegion = null;
      } catch (e) {}
      _blurRoot.destroy();
    }
  }

  property var _whResultsConn: null
  property var _whDlAppliedConn: null

  WallhavenFilter {
    id: wallhavenFilter
    anchors.bottom: statusBar.top
    anchors.bottomMargin: Style.spaceM
    anchors.horizontalCenter: statusBar.horizontalCenter
    z: 998
    adapter: root.adapter
    whService: adapter ? adapter.whService : null
    onWhServiceChanged: {
      if (root._whResultsConn && root._whResultsConn.target)
        root._whResultsConn.target.resultsUpdated.disconnect(root._whResultsConn.callback);
      if (root._whDlAppliedConn && root._whDlAppliedConn.target)
        root._whDlAppliedConn.target.downloadApplied.disconnect(root._whDlAppliedConn.callback);
      if (whService) {
        root._whResultsConn = {
          target: whService,
          callback: function () {
            if (whService.currentPage === 1)
              displayManager.scrollTo(0);
          }
        };
        whService.resultsUpdated.connect(root._whResultsConn.callback);
        root._whDlAppliedConn = {
          target: whService,
          callback: function (localPath) {
            if (wallpaperApplier)
              wallpaperApplier.apply(localPath);
            Qt.callLater(Qt.quit);
          }
        };
        whService.downloadApplied.connect(root._whDlAppliedConn.callback);
      }
    }
  }

  SettingsPanel {
    id: settingsPanel
    anchors.bottom: statusBar.top
    anchors.bottomMargin: Style.spaceM
    anchors.horizontalCenter: statusBar.horizontalCenter
    z: 999
    settingsOpen: appViewModel ? appViewModel.settingsOpen : false
    showBorderGlow: appViewModel ? appViewModel.showBorderGlow : true
    showShadow: appViewModel ? appViewModel.showShadow : true
    showBgPreview: appViewModel ? appViewModel.showBgPreview : true
    bgOverlayOpacity: appViewModel ? appViewModel.bgOverlayOpacity : 0.4
    videoBackend: appViewModel ? appViewModel.videoBackend : "mpvpaper"
    wallpaperDirs: configViewModel ? configViewModel.paths.wallpaperDirs : []
    cacheDir: configViewModel ? configViewModel.paths.cacheDir : ""
    wallhavenApiKey: configViewModel ? configViewModel.wallhaven.apiKey : ""
    wallhavenDownloadDir: configViewModel ? configViewModel.wallhaven.downloadDir : ""
    wallhavenCategories: configViewModel ? configViewModel.wallhaven.categories : "111"
    wallhavenPurity: configViewModel ? configViewModel.wallhaven.purity : "100"

    onSettingChanged: function (key, val) {
      if (configViewModel)
        configViewModel.set(key, val);
    }

    onCloseRequested: {
      if (appViewModel) {
        appViewModel.settingsOpen = false;
        displayManager.focusView();
      }
    }

    onSwitchToNextFolder: appViewModel ? appViewModel.nextFolder() : null
    onSwitchToPrevFolder: appViewModel ? appViewModel.prevFolder() : null
    onToggleSettings: appViewModel ? appViewModel.toggleSettings() : null
  }
}
