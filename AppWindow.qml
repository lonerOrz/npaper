import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "utils/CacheUtils.js" as CacheUtils
import "utils/FileTypes.js" as FileTypes
import qs.components.bar
import qs.components.common
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
  readonly property int centerIndex: scrollController.currentIndex
  property string dominantColor: Color.mPrimary

  property real carouselItemWidth: Style.carouselItemWidth
  property real carouselItemHeight: Style.carouselItemHeight
  property real carouselSpacing: Style.carouselSpacing
  property real carouselRotation: Style.carouselRotation
  property real carouselPerspective: Style.carouselPerspective
  property real bgOverlayOpacity: Style.bgOverlayOpacity
  property bool showBgPreview: Style.showBgPreview
  property bool showBorderGlow: Style.showBorderGlow
  property bool showShadow: Style.showShadow

  property int scrollDuration: Style.scrollDuration
  property int scrollContinueInterval: Style.scrollContinueInterval
  property int bgSlideDuration: Style.bgSlideDuration
  property int bgParallaxFactor: Style.bgParallaxFactor

  property string searchText: ""

  property int bgCurrent: -1
  property int bgPrevious: -1
  property real bgSlideProgress: 0.0
  property string _bgSourceA: ""
  property string _bgSourceB: ""

  // ========== Logic ==========

  Component.onCompleted: {
    Style.uiScaleRatio = screen.height / 1080;
    if (adapter) {
      adapter.dataLoaded.connect(applyFolderSelection);
      adapter.wallpaperApplied.connect(function(path) {
        if (wallpaperApplier)
          wallpaperApplier.apply(path);
        Qt.quit();
      });
      adapter.load();
    }
  }

  Connections {
    target: scrollController
    function onCurrentIndexChanged() {
      updateBackground(scrollController.currentIndex);
      if (adapter && adapter.currentSource === "local")
        queueThumbnails(scrollController.baseIndex, scrollController.maxIndex);
    }
  }

  onBgCurrentChanged: { updateSourceA(); }
  onBgPreviousChanged: { updateSourceB(); }

  function updateSourceA() {
    if (bgCurrent >= 0 && bgCurrent < (adapter ? adapter.items.length : 0)) {
      const item = adapter.items[bgCurrent];
      if (!item) return;
      if (item.type === "local") {
        const p = CacheUtils.getCachedBgPreview(cacheService.thumbHashToPath, item.path);
        _bgSourceA = p ? ("file://" + p) : ("file://" + item.path);
      } else if (item.type === "remote" && item.thumb) {
        // Use remote thumbnail for background preview
        _bgSourceA = item.thumb;
      }
    }
  }

  function updateSourceB() {
    if (bgPrevious >= 0 && bgPrevious < (adapter ? adapter.items.length : 0)) {
      const item = adapter.items[bgPrevious];
      if (!item) return;
      if (item.type === "local") {
        const p = CacheUtils.getCachedBgPreview(cacheService.thumbHashToPath, item.path);
        _bgSourceB = p ? ("file://" + p) : ("file://" + item.path);
      } else if (item.type === "remote" && item.thumb) {
        _bgSourceB = item.thumb;
      }
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

  function queueThumbnails(base, max) {
    if (!adapter) return;
    for (let i = base; i <= max && i < adapter.items.length; i++) {
      const item = adapter.items[i];
      if (item && item.type === "local")
        cacheService.queueThumbnail(item.path, item.isVideo, item.isGif);
    }
  }

  function applyFolderSelection() {
    scrollController.reset();
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

  function refreshCache() {
    if (adapter)
      adapter.refresh();
  }

  // ========== Components ==========

  ScrollController {
    id: scrollController
    count: root.count
    visibleRange: Style.visibleRange
    preloadRange: Style.preloadRange
    animationDuration: viewModel ? viewModel.timing.scrollDuration : 280
    scrollContinueInterval: viewModel ? viewModel.timing.scrollContinueInterval : 230
    parallaxFactor: viewModel ? viewModel.timing.bgParallaxFactor : 40
  }

  PropertyAnimation {
    id: bgSlideAnim
    target: root
    properties: "bgSlideProgress"
    from: 0
    to: 1.0
    duration: viewModel ? viewModel.timing.bgSlideDuration : 250
    easing.type: Style.easingOutQuad
  }

  QtObject {
    id: colorExtractor
    property string dominantColor: Color.mPrimary

    function run(wp) {
      if (!checkService || !checkService.hasImagemagick || !wp || wp.length === 0) {
        root.dominantColor = Color.mPrimary;
        return;
      }
      const bg = CacheUtils.getCachedBgPreview(cacheService.thumbHashToPath, wp);
      if (bg) {
        _runColorExtract(bg);
        return;
      }
      if (FileTypes.isVideoFile(wp)) {
        root.dominantColor = Color.mPrimary;
        return;
      }
      _runColorExtract(wp.toLowerCase().endsWith('.gif') ? wp + '[0]' : wp);
    }

    function _runColorExtract(src) {
      if (extractColorProcess.running)
        extractColorProcess.running = false;
      extractColorTimeout.start();
      extractColorProcess.command = ["magick", src, "-resize", "1x1!", "-modulate", "100,180", "txt:"];
      extractColorProcess.exec({});
    }
  }

  Timer {
    id: extractColorTimeout
    interval: 5000
    onTriggered: root.dominantColor = Color.mPrimary
  }

  Process {
    id: extractColorProcess
    stdout: StdioCollector {
      onStreamFinished: {
        extractColorTimeout.stop();
        const m = text.trim().match(/#([0-9A-F]{6})/i);
        root.dominantColor = m ? "#" + m[1].toUpperCase() : Color.mPrimary;
      }
    }
    onExited: function (exitCode, exitStatus) {
      extractColorTimeout.stop();
      if (exitCode !== 0)
        root.dominantColor = Color.mPrimary;
    }
  }

  Timer {
    id: searchDebounce
    interval: Style.searchDebounceMs
    onTriggered: {
      if (adapter)
        adapter.setSearch(root.searchText);
      if (root.searchText) {
        scrollController.scrollTo(0);
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
  }

  // ========== UI ==========

  BackgroundManager {
    anchors.fill: parent
    sourceA: _bgSourceA
    sourceB: _bgSourceB
    crossfadeProgress: bgSlideProgress
    parallaxX: (scrollController.scrollTarget - scrollController.currentIndex) * scrollController.parallaxFactor
    dominantColor: root.dominantColor
    overlayOpacity: root.bgOverlayOpacity
    showPreview: root.showBgPreview
  }

  ColumnLayout {
    id: carouselLayout
    anchors.fill: parent
    anchors.margins: Style.carouselSideMargin
    anchors.topMargin: Style.carouselTopMargin
    z: 0

    Item {
      id: pathViewContainer
      Layout.fillWidth: true
      Layout.fillHeight: true
      focus: true
      clip: true

      property int itemWidth: root.carouselItemWidth
      property int itemHeight: root.carouselItemHeight
      property real spacing: root.carouselSpacing
      property real centerX: width / 2
      property real centerY: height / 2

      Repeater {
        model: scrollController.loadedCount
        delegate: WallpaperCard {
          required property int index
          property int realIndex: scrollController.baseIndex + index

          readonly property var _item: realIndex < adapter.items.length ? adapter.items[realIndex] : null
          wallpaperPath: _item ? (_item.type === "remote" ? _item.thumb : _item.path) : ""
          filename: _item ? _item.filename : ""
          isVideo: _item ? _item.isVideo : false
          isGif: _item ? _item.isGif : false
          isRemote: _item ? _item.type === "remote" : false
          remoteId: _item && _item.type === "remote" ? _item.id : ""
          remoteThumb: _item && _item.type === "remote" ? _item.thumb : ""
          thumbHashToPath: _item && _item.type === "local" ? (cacheService ? cacheService.thumbHashToPath : {}) : {}
          isCenter: realIndex === root.centerIndex
          showBorderGlow: root.showBorderGlow
          showShadow: root.showShadow

          readonly property var metrics: {
            const raw = realIndex - scrollController.scrollTarget;
            const abs = Math.abs(raw);
            return {
              raw,
              abs,
              cos: Math.cos(Math.min(abs, 3) * 0.523599),
              perspectiveScale: 1.0 / (1.0 + abs * root.carouselPerspective)
            };
          }
          readonly property var visual: {
            const abs = metrics.abs;
            return {
              scale: metrics.perspectiveScale * (0.85 + metrics.cos * 0.15) + (isCenter ? 0.06 : 0),
              opacity: abs > 6 ? 0 : Math.pow(Math.max(0, 1 - abs * 0.12), 2.5),
              rotationY: metrics.raw * -root.carouselRotation,
              z: 100 - abs * 50,
              spacingFactor: 0.85 - metrics.abs * 0.06,
              yOffset: abs * 8,
              shadowOpacity: abs < 0.6 ? 0.25 : 0
            };
          }
          visualScale: visual.scale
          visualOpacity: visual.opacity
          visualRotationY: visual.rotationY
          visualZ: visual.z
          visualYOffset: visual.yOffset
          visualShadowOpacity: visual.shadowOpacity
          x: pathViewContainer.centerX - width / 2 + metrics.raw * (width + pathViewContainer.spacing) * visual.spacingFactor
          y: pathViewContainer.centerY - height / 2 + visual.yOffset
          onClicked: function (path) {
            scrollController.scrollTo(realIndex);
            if (_item)
              adapter.apply(_item);
          }
        }
      }

      Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Style.keyboardHintBottomMargin
        text: "/ Search  |  ←/→ Navigate  |  Tab/[] Folder  |  Enter Apply  |  R Random  |  F5 Refresh  |  S Settings  |  W Wallhaven  |  Esc Quit"
        color: Color.mOutline
        font.pixelSize: Style.keyboardHintFontSize
        style: Text.Outline
        styleColor: Color.mScrim
      }

      Keys.onPressed: function(event) {
        // ===== Escape: context-sensitive =====
        if (event.key === Qt.Key_Escape) {
          if (root.settingsOpen) {
            root.settingsOpen = false;
            event.accepted = true;
            return;
          }
          Qt.quit();
          event.accepted = true;
          return;
        }

        // ===== Settings toggle (S) =====
        if (event.key === Qt.Key_S && !event.modifiers) {
          root.settingsOpen = !root.settingsOpen;
          if (root.settingsOpen) {
            settingsPanel.forceActiveFocus();
          } else {
            pathViewContainer.forceActiveFocus();
          }
          event.accepted = true;
          return;
        }

        // ===== Wallhaven toggle (W) =====
        if (event.key === Qt.Key_W && !event.modifiers) {
          // Toggle filter panel
          wallhavenFilter.filterVisible = !wallhavenFilter.filterVisible;
          // If opening, ensure we are in remote mode to search
          if (wallhavenFilter.filterVisible && adapter)
            adapter.switchSource("remote");
          // If closing, revert to local mode
          if (!wallhavenFilter.filterVisible && adapter)
            adapter.switchSource("local");
          pathViewContainer.forceActiveFocus();
          event.accepted = true;
          return;
        }

        // ===== Folder switching (Tab/Shift+Tab or [ / ]) =====
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
          if (adapter.currentSource === "local") {
            const fs = adapter.folders;
            if (fs.length > 0) {
              const idx = fs.indexOf(adapter.currentFolder);
              const nextIdx = event.key === Qt.Key_Tab
                ? (idx < fs.length - 1 ? idx + 1 : 0)
                : (idx > 0 ? idx - 1 : fs.length - 1);
              switchFolder(fs[nextIdx]);
            }
          }
          event.accepted = true;
          return;
        }

        // ===== Search (/, Ctrl+F) =====
        if (event.key === Qt.Key_Slash || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))) {
          statusBar.focusSearch();
          event.accepted = true;
          return;
        }

        if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BraceLeft) {
          if (adapter.currentSource === "local") {
            const fs = adapter.folders;
            if (fs.length > 0) {
              const idx = fs.indexOf(adapter.currentFolder);
              switchFolder(idx > 0 ? fs[idx - 1] : fs[fs.length - 1]);
            }
          }
          event.accepted = true;
          return;
        }
        if (event.key === Qt.Key_BracketRight || event.key === Qt.Key_BraceRight) {
          if (adapter.currentSource === "local") {
            const fs = adapter.folders;
            if (fs.length > 0) {
              const idx = fs.indexOf(adapter.currentFolder);
              switchFolder(idx >= 0 && idx < fs.length - 1 ? fs[idx + 1] : fs[0]);
            }
          }
          event.accepted = true;
          return;
        }

        // ===== Apply wallpaper (Enter) =====
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          if (root.count > 0) {
            const idx = scrollController.currentIndex;
            if (idx < adapter.items.length)
              adapter.apply(adapter.items[idx]);
          }
          event.accepted = true;
          return;
        }

        // ===== Navigation (Left/Right) =====
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
          const dir = (event.key === Qt.Key_Left) ? -1 : 1;
          if (event.modifiers & Qt.ShiftModifier) {
            dir === -1 ? scrollController.fastScrollLeft() : scrollController.fastScrollRight();
          } else {
            dir === -1 ? scrollController.scrollLeft() : scrollController.scrollRight();
          }
          event.accepted = true;
          return;
        }

        // ===== Random (R) =====
        if (event.key === Qt.Key_R && !event.modifiers) {
          scrollController.random();
          event.accepted = true;
          return;
        }

        // ===== Refresh (F5) =====
        if (event.key === Qt.Key_F5) {
          refreshCache();
          event.accepted = true;
          return;
        }
      }
      Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
          const dir = (event.key === Qt.Key_Left) ? -1 : 1;
          scrollController.handleKeyRelease(dir);
          event.accepted = true;
        }
      }
    }
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
        pathViewContainer.forceActiveFocus();
    }
    onWallhavenToggled: {
      wallhavenFilter.filterVisible = !wallhavenFilter.filterVisible;
    }
    searchText: root.searchText
    onSearchInputChanged: function (text) {
      root.searchText = text;
      searchDebounce.restart();
    }
    onSearchCleared: {
      root.searchText = "";
      if (adapter)
        adapter.resetSearch();
      pathViewContainer.forceActiveFocus();
    }
    onSearchSubmitted: {
      if (adapter)
        adapter.setSearch(root.searchText);
      if (root.searchText) {
        scrollController.scrollTo(0);
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
      searchDebounce.stop();
      pathViewContainer.forceActiveFocus();
    }
  }

  // Wallhaven Filter Panel (Separate from StatusBar)
  WallhavenFilter {
    id: wallhavenFilter
    anchors.bottom: statusBar.top
    anchors.bottomMargin: Style.spaceM
    anchors.horizontalCenter: statusBar.horizontalCenter
    z: 998
    adapter: root.adapter
    whService: adapter ? adapter.whService : null
    onWhServiceChanged: {
      if (whService)
        whService.resultsUpdated.connect(() => scrollController.scrollTo(0));
    }
  }

  SettingsPanel {
    id: settingsPanel
    anchors.bottom: statusBar.top
    anchors.bottomMargin: Style.spaceM
    anchors.horizontalCenter: statusBar.horizontalCenter
    z: 999
    settingsOpen: root.settingsOpen
    carouselItemWidth: root.carouselItemWidth
    carouselItemHeight: root.carouselItemHeight
    carouselSpacing: root.carouselSpacing
    carouselRotation: root.carouselRotation
    carouselPerspective: root.carouselPerspective
    showBorderGlow: root.showBorderGlow
    showShadow: root.showShadow
    showBgPreview: root.showBgPreview
    scrollDuration: root.scrollDuration
    scrollContinueInterval: root.scrollContinueInterval
    bgSlideDuration: root.bgSlideDuration
    bgParallaxFactor: root.bgParallaxFactor

    onSettingChanged: function (key, val) {
      Logger.i("AppWindow", "Setting changed:", key, "=", val);
      var propMap = {
        "carousel.itemWidth": "carouselItemWidth",
        "carousel.itemHeight": "carouselItemHeight",
        "carousel.spacing": "carouselSpacing",
        "carousel.rotation": "carouselRotation",
        "carousel.perspective": "carouselPerspective",
        "animation.scrollDuration": "scrollDuration",
        "animation.scrollContinueInterval": "scrollContinueInterval",
        "animation.bgSlideDuration": "bgSlideDuration",
        "animation.bgParallaxFactor": "bgParallaxFactor",
        "appearance.showBorderGlow": "showBorderGlow",
        "appearance.showShadow": "showShadow",
        "appearance.showBgPreview": "showBgPreview",
        "appearance.bgOverlayOpacity": "bgOverlayOpacity"
      };
      var prop = propMap[key] || key;
      root[prop] = val;
      var vm = viewModel;
      if (vm)
        vm.set(key, val);
    }

    onCloseRequested: {
      root.settingsOpen = false;
      pathViewContainer.forceActiveFocus();
    }

    onSwitchToNextFolder: {
      if (adapter) {
        const fs = adapter.folders;
        if (fs.length > 0) {
          const idx = fs.indexOf(adapter.currentFolder);
          switchFolder(idx >= 0 && idx < fs.length - 1 ? fs[idx + 1] : fs[0]);
        }
      }
    }

    onSwitchToPrevFolder: {
      if (adapter) {
        const fs = adapter.folders;
        if (fs.length > 0) {
          const idx = fs.indexOf(adapter.currentFolder);
          switchFolder(idx > 0 ? fs[idx - 1] : fs[fs.length - 1]);
        }
      }
    }

    onToggleSettings: {
      root.settingsOpen = !root.settingsOpen;
      if (root.settingsOpen) {
        settingsPanel.forceActiveFocus();
      } else {
        pathViewContainer.forceActiveFocus();
      }
    }
  }
}
