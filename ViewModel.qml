import QtQuick
import qs.services

QtObject {
  id: root

  property var adapter: null
  property var displayManager: null
  property var colorExtractor: null
  property var wallpaperApplier: null
  property var cacheService: null
  property var configViewModel: null
  property var statusBar: null

  property bool _initialized: false
  property var _dmConn: null

  property bool settingsOpen: false
  property string searchText: ""
  property int bgCurrent: -1
  property string dominantColor: Color.mPrimary
  property bool _toggleViewLock: false

  property bool showBgPreview: configViewModel ? configViewModel.appearance.showBgPreview : true
  property bool showShadow: configViewModel ? configViewModel.appearance.showShadow : true
  property real bgOverlayOpacity: configViewModel ? configViewModel.appearance.bgOverlayOpacity : 0.4
  property string videoBackend: configViewModel ? configViewModel.videoBackend : "mpvpaper"
  property int bgSlideDuration: configViewModel ? configViewModel.animation.bgSlideDuration : Style.defaultBgSlideDuration
  property int bgParallaxFactor: configViewModel ? configViewModel.animation.bgParallaxFactor : Style.defaultBgParallaxFactor

  readonly property int count: adapter ? adapter.count : 0

  property var _searchDebounce: Timer {
    interval: Style.searchDebounceMs
    repeat: false
    onTriggered: root._doSearch()
  }

  property var _remoteSearchDebounce: Timer {
    interval: Style.remoteSearchDebounceMs
    repeat: false
    onTriggered: root._doSearch()
  }

  property var _bgUpdateDebounce: Timer {
    interval: 120
    repeat: false
    onTriggered: {
      if (root.displayManager && root.displayManager.currentIndex >= 0 && root.adapter && root.displayManager.currentIndex < root.adapter.count) {
        root.bgCurrent = root.displayManager.currentIndex;
      }
    }
  }

  onBgCurrentChanged: {
    if (root.bgCurrent >= 0 && root.adapter && root.bgCurrent < root.adapter.count) {
      const item = root.adapter.getItem(root.bgCurrent);
      if (item && item.type === "local" && root.colorExtractor) {
        root.colorExtractor.run(item.path);
      } else {
        root.dominantColor = Color.mPrimary;
      }
    }
  }

  function init() {
    if (!adapter || root._initialized)
      return;

    root._initialized = true;

    adapter.dataLoaded.connect(function () {
      root.applyFolderSelection();
    });

    adapter.wallpaperApplied.connect(function (path) {
      if (root.wallpaperApplier)
        root.wallpaperApplier.apply(path);
      Qt.quit();
    });

    adapter.load();
  }

  function bindDisplayManager(dm) {
    if (root._dmConn && root._dmConn.target) {
      root._dmConn.target.onCurrentIndexChanged.disconnect(root._dmConn.handler);
    }
    root.displayManager = dm;
    if (dm) {
      root._dmConn = {
        target: dm,
        handler: function () {
          root._bgUpdateDebounce.restart();
        }
      };
      dm.onCurrentIndexChanged.connect(root._dmConn.handler);
    }
  }

  Component.onDestruction: {
    if (root._dmConn && root._dmConn.target) {
      root._dmConn.target.onCurrentIndexChanged.disconnect(root._dmConn.handler);
    }
  }

  function bindColorExtractor(ce) {
    root.colorExtractor = ce;
    if (ce) {
      ce.onColorChanged.connect(function (color) {
        if (color)
          root.dominantColor = color;
      });
    }
  }

  function bindStatusBar(sb) {
    root.statusBar = sb;
  }

  function focusSearch() {
    if (root.statusBar)
      root.statusBar.focusSearch();
  }

  function _doSearch() {
    if (!root.adapter)
      return;

    root.adapter.setSearch(root.searchText);

    if (root.searchText) {
      if (root.displayManager)
        root.displayManager.scrollTo(0);
      root.bgCurrent = -1;
      root.bgCurrent = 0;

      if (root.adapter.count > 0) {
        const item = root.adapter.getItem(0);
        if (item && item.type === "local" && root.colorExtractor)
          root.colorExtractor.run(item.path);
      }
    } else {
      root.adapter.resetSearch();
    }
  }

  function refreshCache() {
    if (root.adapter)
      root.adapter.refresh();
  }

  function applyFolderSelection() {
    if (root.displayManager) {
      root.displayManager.reset();
      Qt.callLater(function () {
        root.displayManager.queueVisibleThumbnails();
      });
    }

    root.bgCurrent = -1;
    root.bgCurrent = 0;

    if (root.adapter && root.adapter.count > 0) {
      const item = root.adapter.getItem(0);
      if (item && item.type === "local" && root.colorExtractor)
        root.colorExtractor.run(item.path);
    }
  }

  function switchFolder(folder) {
    if (root.adapter) {
      root.adapter.switchFolder(folder);
      Qt.callLater(root.applyFolderSelection);
    }
  }

  function nextFolder() {
    if (!root.adapter || root.adapter.currentSource !== "local")
      return;

    const fs = root.adapter.folders;
    if (!fs || fs.length === 0)
      return;

    const idx = fs.indexOf(root.adapter.currentFolder);
    const nextIdx = idx >= 0 && idx < fs.length - 1 ? idx + 1 : 0;
    root.switchFolder(fs[nextIdx]);
  }

  function prevFolder() {
    if (!root.adapter || root.adapter.currentSource !== "local")
      return;

    const fs = root.adapter.folders;
    if (!fs || fs.length === 0)
      return;

    const idx = fs.indexOf(root.adapter.currentFolder);
    const prevIdx = idx > 0 ? idx - 1 : fs.length - 1;
    root.switchFolder(fs[prevIdx]);
  }

  function handleSearchInput(text) {
    root.searchText = text;
    if (root.adapter && root.adapter.currentSource === "remote")
      root._remoteSearchDebounce.restart();
    else
      root._searchDebounce.restart();
  }

  function handleSearchClear() {
    root.searchText = "";
    if (root.adapter)
      root.adapter.resetSearch();
  }

  function handleSearchSubmit() {
    root._searchDebounce.stop();
    root._doSearch();
  }

  function toggleSettings() {
    root.settingsOpen = !root.settingsOpen;
    if (!root.settingsOpen && root.displayManager)
      root.displayManager.focusView();
  }

  function handleRequestQuit() {
    if (root.settingsOpen) {
      root.settingsOpen = false;
      if (root.displayManager)
        root.displayManager.focusView();
    } else {
      Qt.quit();
    }
  }

  function handleRequestRandom() {
    if (!root.adapter || root.adapter.count === 0)
      return;

    const randomIdx = Math.floor(Math.random() * root.adapter.count);
    if (root.displayManager) {
      root.displayManager.scrollTo(randomIdx);
    }
  }

  function handleRequestToggleViewMode() {
    if (root._toggleViewLock)
      return;

    root._toggleViewLock = true;
    Qt.callLater(function () {
      var modes = Config.previewModes;
      var currentIdx = modes.indexOf(Config.previewStyle);
      if (currentIdx === -1)
        currentIdx = 0;
      var next = modes[(currentIdx + 1) % modes.length];
      Config.update("previewStyle", next);
      root._toggleViewLock = false;
    });
  }

  function handleRequestToggleWallhaven(filter) {
    if (!filter)
      return;

    filter.filterVisible = !filter.filterVisible;
    if (filter.filterVisible && root.adapter)
      root.adapter.switchSource("remote");
    if (!filter.filterVisible && root.adapter)
      root.adapter.switchSource("local");
  }

  function applyItem(item) {
    if (!item)
      return;
    if (root.wallpaperApplier)
      root.wallpaperApplier.apply(item.path);
    Qt.quit();
  }
}
