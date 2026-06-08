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
  property var viewModel
  property var adapter
  property var cacheService
  property var wallpaperApplier
  property var checkService

  property bool settingsOpen: false
  screen: modelData

  visible: true
  color: "transparent"
  implicitWidth: screen.width
  implicitHeight: screen.height

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.exclusiveZone: -1

  readonly property int count: adapter ? adapter.count : 0
  property string dominantColor: Color.mPrimary

  property bool showBgPreview: Config.data.appearance ? Config.data.appearance.showBgPreview : true
  property bool showShadow: Config.data.appearance ? Config.data.appearance.showShadow : true
  property bool showBorderGlow: Config.data.appearance ? Config.data.appearance.showBorderGlow : true
  property real bgOverlayOpacity: Config.data.appearance ? Config.data.appearance.bgOverlayOpacity : 0.4
  property string videoBackend: Config.data.videoBackend || "mpvpaper"

  property int bgSlideDuration: Config.data.animation ? Config.data.animation.bgSlideDuration : Style.defaultBgSlideDuration
  property int bgParallaxFactor: Config.data.animation ? Config.data.animation.bgParallaxFactor : Style.defaultBgParallaxFactor

  property string searchText: ""
  property bool _toggleViewLock: false

  property var _blurRoot: null

  property int bgCurrent: -1

  // ========== Logic ==========

  Component.onCompleted: {
    Style.uiScaleRatio = screen.height / 1080;
    if (adapter) {
      adapter.dataLoaded.connect(applyFolderSelection);
      adapter.wallpaperApplied.connect(function (path) {
        if (wallpaperApplier)
          wallpaperApplier.apply(path);
        Qt.quit();
      });
      adapter.load();
    }

    // ── Status Bar Blur ──
    if (BlurService.available) {
      Qt.callLater(_initAllBlur);
    }
  }

  function _initAllBlur() {
    if (!BlurService.available)
      return;
    try {
      // Build a single Region tree with all panels as children
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

  Connections {
    target: displayManager
    function onCurrentIndexChanged() {
      bgUpdateDebounce.restart();
    }
  }

  onBgCurrentChanged: {
    if (bgCurrent >= 0 && adapter && bgCurrent < adapter.items.length) {
      const item = adapter.items[bgCurrent];
      if (item && item.type === "local")
        colorExtractor.run(item.path);
      else
        root.dominantColor = Color.mPrimary;
    }
  }

  function _doSearch() {
    if (adapter)
      adapter.setSearch(root.searchText);
    if (root.searchText) {
      displayManager.scrollTo(0);
      bgCurrent = -1; // 强制变动重置
      bgCurrent = 0;
      if (adapter.items.length > 0) {
        const item = adapter.items[0];
        if (item.type === "local")
          colorExtractor.run(item.path);
      }
    } else {
      adapter.resetSearch();
    }
  }

  function refreshCache() {
    if (adapter)
      adapter.refresh();
  }

  function applyFolderSelection() {
    displayManager.reset();
    Qt.callLater(function () {
      displayManager.queueVisibleThumbnails();
    });
    bgCurrent = -1;
    bgCurrent = 0;
    if (adapter && adapter.items.length > 0) {
      const item = adapter.items[0];
      if (item.type === "local")
        colorExtractor.run(item.path);
    }
  }

  function switchFolder(folder) {
    if (adapter) {
      adapter.switchFolder(folder);
      // Qt.callLater ensures adapter.items has fully updated before reset
      Qt.callLater(applyFolderSelection);
    }
  }

  function nextFolder() {
    if (!adapter || adapter.currentSource !== "local")
      return;
    const fs = adapter.folders;
    if (fs.length === 0)
      return;
    const idx = fs.indexOf(adapter.currentFolder);
    const nextIdx = idx >= 0 && idx < fs.length - 1 ? idx + 1 : 0;
    switchFolder(fs[nextIdx]);
  }

  function prevFolder() {
    if (!adapter || adapter.currentSource !== "local")
      return;
    const fs = adapter.folders;
    if (fs.length === 0)
      return;
    const idx = fs.indexOf(adapter.currentFolder);
    const prevIdx = idx > 0 ? idx - 1 : fs.length - 1;
    switchFolder(fs[prevIdx]);
  }

  // ========== Components ==========

  DisplayManager {
    id: displayManager
    anchors.fill: parent
    anchors.margins: Style.carouselSideMargin
    anchors.topMargin: Style.carouselTopMargin
    z: 1

    displayMode: Config.previewStyle

    onRequestQuit: {
      if (root.settingsOpen) {
        root.settingsOpen = false;
        displayManager.focusView();
      } else {
        Qt.quit();
      }
    }
    onRequestSettings: {
      root.settingsOpen = !root.settingsOpen;
      root.settingsOpen ? settingsPanel.forceActiveFocus() : displayManager.focusView();
    }
    onRequestToggleViewMode: {
      if (_toggleViewLock)
        return;
      _toggleViewLock = true;
      Qt.callLater(function () {
        var next = Config.previewStyle === "grid" ? "carousel" : "grid";
        Config.update("previewStyle", next);
        _toggleViewLock = false;
      });
    }
    onRequestPrevFolder: prevFolder()
    onRequestNextFolder: nextFolder()
    onRequestFocusSearch: statusBar.focusSearch()
    onRequestApplyItem: function (item) {
      wallpaperApplier.apply(item.path);
      Qt.quit();
    }
    onRequestRandom: {}
    onRequestToggleWallhaven: {
      wallhavenFilter.filterVisible = !wallhavenFilter.filterVisible;
      if (wallhavenFilter.filterVisible && adapter)
        adapter.switchSource("remote");
      if (!wallhavenFilter.filterVisible && adapter)
        adapter.switchSource("local");
      displayManager.focusView();
    }
    onRequestRefresh: refreshCache()
  }

  ColorExtractor {
    id: colorExtractor
    thumbHashToPath: cacheService ? cacheService.thumbHashToPath : ({})
    hasImageMagick: checkService ? checkService.hasImagemagick : false
    onColorChanged: root.dominantColor = color
  }

  Timer {
    id: searchDebounce
    interval: Style.searchDebounceMs
    onTriggered: _doSearch()
  }

  Timer {
    id: bgUpdateDebounce
    interval: 150
    repeat: false
    onTriggered: {
      if (displayManager.currentIndex >= 0 && displayManager.currentIndex < (adapter ? adapter.items.length : 0)) {
        root.bgCurrent = displayManager.currentIndex;
      }
    }
  }

  // ========== UI ==========

  BackgroundManager {
    anchors.fill: parent
    currentWallpaperItem: (root.bgCurrent >= 0 && adapter && root.bgCurrent < adapter.items.length) ? adapter.items[root.bgCurrent] : null
    parallaxX: displayManager.contentOffset * bgParallaxFactor
    dominantColor: root.dominantColor
    overlayOpacity: root.bgOverlayOpacity
    showPreview: root.showBgPreview
    slideDuration: root.bgSlideDuration
  }

  // ========== StatusBar ==========
  StatusBar {
    id: statusBar
    anchors.top: parent.top
    anchors.topMargin: Style.barTopMargin
    anchors.horizontalCenter: parent.horizontalCenter
    z: 100

    folders: adapter && adapter.currentSource === "local" ? adapter.folders : []
    activeFolder: adapter && adapter.currentSource === "local" ? adapter.currentFolder : ""
    onFolderClicked: function (folder) {
      switchFolder(folder);
    }
    wallpaperCount: root.count
    cachedCount: cacheService ? cacheService.cachedFileCount : 0
    queueCount: cacheService ? cacheService.queueLength + cacheService.thumbnailJobRunning : 0
    dominantColor: root.dominantColor
    settingsOpen: root.settingsOpen
    isWallhaven: wallhavenFilter.filterVisible || (adapter && adapter.currentSource === "remote")
    onSettingsToggled: {
      root.settingsOpen = !root.settingsOpen;
      if (!root.settingsOpen)
        displayManager.focusView();
    }
    onWallhavenToggled: wallhavenFilter.filterVisible = !wallhavenFilter.filterVisible

    searchText: root.searchText
    onSearchInputChanged: function (text) {
      root.searchText = text;
      searchDebounce.restart();
    }
    onSearchCleared: {
      root.searchText = "";
      if (adapter)
        adapter.resetSearch();
      displayManager.focusView();
    }
    onSearchSubmitted: {
      _doSearch();
      searchDebounce.stop();
      displayManager.focusView();
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

  // Wallhaven Filter Panel (Separate from StatusBar)
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
    settingsOpen: root.settingsOpen
    showBorderGlow: root.showBorderGlow
    showShadow: root.showShadow
    showBgPreview: root.showBgPreview
    bgOverlayOpacity: root.bgOverlayOpacity
    videoBackend: root.videoBackend
    wallpaperDirs: Config.data.wallpaperDirs
    cacheDir: Config.data.cacheDir
    wallhavenApiKey: Config.data.wallhaven.apiKey
    wallhavenDownloadDir: Config.data.wallhaven.downloadDir
    wallhavenCategories: Config.data.wallhaven.categories
    wallhavenPurity: Config.data.wallhaven.purity

    onSettingChanged: function (key, val) {
      var vm = viewModel;
      if (vm)
        vm.set(key, val);
    }

    onCloseRequested: {
      root.settingsOpen = false;
      displayManager.focusView();
    }

    onSwitchToNextFolder: nextFolder()
    onSwitchToPrevFolder: prevFolder()
    onToggleSettings: {
      root.settingsOpen = !root.settingsOpen;
      root.settingsOpen ? settingsPanel.forceActiveFocus() : displayManager.focusView();
    }
  }
}
