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

  property int carouselSpacing: Config.data.carousel ? Config.data.carousel.spacing : Style.defaultCarouselSpacing
  property int carouselRotation: Config.data.carousel ? Config.data.carousel.rotation : Style.defaultCarouselRotation
  property real carouselPerspective: Config.data.carousel ? Config.data.carousel.perspective : Style.defaultCarouselPerspective

  property int scrollDuration: Config.data.animation ? Config.data.animation.scrollDuration : Style.defaultScrollDuration
  property int scrollContinueInterval: Config.data.animation ? Config.data.animation.scrollContinueInterval : Style.defaultScrollContinueInterval
  property int bgSlideDuration: Config.data.animation ? Config.data.animation.bgSlideDuration : Style.defaultBgSlideDuration
  property int bgParallaxFactor: Config.data.animation ? Config.data.animation.bgParallaxFactor : Style.defaultBgParallaxFactor

  property string searchText: ""

  property int bgCurrent: -1
  property int bgPrevious: -1
  property real bgSlideProgress: 0.0
  property string _bgSourceA: ""
  property string _bgSourceB: ""

  // ========== Logic ==========

  Component.onCompleted: {
    Style.uiScaleRatio = screen.height / 1080;
    // Quickshell 的 property var 绑定不可靠，必须显式赋值
    displayManager.cacheService = cacheService;
    displayManager.adapter = wallpaperAdapter;
    if (adapter) {
      adapter.dataLoaded.connect(applyFolderSelection);
      adapter.wallpaperApplied.connect(function (path) {
        if (wallpaperApplier)
          wallpaperApplier.apply(path);
        Qt.quit();
      });
      adapter.load();
    }
  }

  Connections {
    target: displayManager
    function onCurrentIndexChanged() {
      updateBackground(displayManager.currentIndex);
    }
  }

  onBgCurrentChanged: {
    updateSourceA();
  }
  onBgPreviousChanged: {
    updateSourceB();
  }

  function updateSourceA() {
    if (bgCurrent >= 0 && bgCurrent < (adapter ? adapter.items.length : 0)) {
      const item = adapter.items[bgCurrent];
      if (!item)
        return;
      if (item.type === "local") {
        const p = CacheUtils.getCachedBgPreview(cacheService.thumbHashToPath, item.path);
        if (p) {
          _bgSourceA = "file://" + p;
        } else if (!item.isVideo && !item.isGif) {
          _bgSourceA = "file://" + item.path;
        } else {
          _bgSourceA = "";
        }
      } else if (item.type === "remote" && item.thumb) {
        _bgSourceA = item.thumb;
      }
    }
  }

  function updateSourceB() {
    if (bgPrevious >= 0 && bgPrevious < (adapter ? adapter.items.length : 0)) {
      const item = adapter.items[bgPrevious];
      if (!item)
        return;
      if (item.type === "local") {
        const p = CacheUtils.getCachedBgPreview(cacheService.thumbHashToPath, item.path);
        if (p) {
          _bgSourceB = "file://" + p;
        } else if (!item.isVideo && !item.isGif) {
          _bgSourceB = "file://" + item.path;
        } else {
          _bgSourceB = "";
        }
      } else if (item.type === "remote" && item.thumb) {
        _bgSourceB = item.thumb;
      }
    }
  }

  // Refresh background sources when cache is updated (new _bg.png generated)
  Connections {
    target: cacheService
    function onThumbCacheVersionChanged() {
      if (bgCurrent >= 0)
        updateSourceA();
      if (bgPrevious >= 0)
        updateSourceB();
    }
  }

  function updateBackground(index) {
    if (index !== bgCurrent && index >= 0 && index < (adapter ? adapter.items.length : 0)) {
      bgPrevious = bgCurrent;
      bgCurrent = index;
      bgSlideProgress = 0;
      bgSlideAnim.restart();
      const item = adapter.items[index];
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
      bgCurrent = 0;
      bgSlideProgress = 1.0;
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
      displayManager._queueVisibleThumbnails();
    });
    bgPrevious = -1;
    bgCurrent = -1;
    bgSlideProgress = 1.0;
    if (adapter && adapter.items.length > 0) {
      bgCurrent = 0;
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
    carouselSpacing: root.carouselSpacing
    carouselRotation: root.carouselRotation
    carouselPerspective: root.carouselPerspective
    scrollDuration: root.scrollDuration
    scrollContinueInterval: root.scrollContinueInterval
    parallaxFactor: root.bgParallaxFactor

    adapter: wallpaperAdapter
    cacheService: cacheService

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

  PropertyAnimation {
    id: bgSlideAnim
    target: root
    properties: "bgSlideProgress"
    from: 0
    to: 1.0
    duration: root.bgSlideDuration
    easing.type: Style.easingOutQuad
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

  // ========== UI ==========

  BackgroundManager {
    anchors.fill: parent
    sourceA: _bgSourceA
    sourceB: _bgSourceB
    crossfadeProgress: bgSlideProgress
    parallaxX: displayManager.contentOffset * bgParallaxFactor
    dominantColor: root.dominantColor
    overlayOpacity: root.bgOverlayOpacity
    showPreview: root.showBgPreview
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

  // Wallhaven Filter Panel (Separate from StatusBar)
  property var _whResultsConn: null

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
      if (whService) {
        root._whResultsConn = {
          target: whService,
          callback: () => displayManager.scrollTo(0)
        };
        whService.resultsUpdated.connect(root._whResultsConn.callback);
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
    wallpaperDirs: Config.data.wallpaperDirs
    cacheDir: Config.data.cacheDir
    wallhavenApiKey: Config.data.wallhaven.apiKey || ""
    wallhavenCategories: Config.data.wallhaven.categories || "111"
    wallhavenPurity: Config.data.wallhaven.purity || "100"

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
