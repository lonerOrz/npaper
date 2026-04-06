import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "utils/CacheUtils.js" as CacheUtils
import "utils/FileTypes.js" as FileTypes
import qs.components
import qs.utils

PanelWindow {
  id: root

  property var modelData
  property var viewModel
  property var wallpaperModel
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

  readonly property int count: wallpaperModel ? wallpaperModel.count : 0
  readonly property int centerIndex: scrollController.currentIndex
  property string dominantColor: Color.mPrimary

  property real carouselItemWidth: viewModel ? viewModel.get("carouselItemWidth", 450) : 450
  property real carouselItemHeight: viewModel ? viewModel.get("carouselItemHeight", 320) : 320
  property real carouselSpacing: viewModel ? viewModel.get("carouselSpacing", 25) : 25
  property real carouselRotation: viewModel ? viewModel.get("carouselRotation", 40) : 40
  property real carouselPerspective: viewModel ? viewModel.get("carouselPerspective", 0.3) : 0.3
  property real bgOverlayOpacity: viewModel ? viewModel.get("bgOverlayOpacity", 0.4) : 0.4
  property bool showBgPreview: viewModel ? viewModel.get("showBgPreview", true) : true
  property bool showBorderGlow: viewModel ? viewModel.get("showBorderGlow", true) : true
  property bool showShadow: viewModel ? viewModel.get("showShadow", true) : true
  readonly property bool debugMode: viewModel ? viewModel.get("debugMode", false) : false

  property string searchText: ""

  property int bgCurrent: -1
  property int bgPrevious: -1
  property real bgSlideProgress: 0.0
  property string _bgSourceA: ""
  property string _bgSourceB: ""

  // ========== Logic ==========

  Component.onCompleted: {
    Logger.init(root.debugMode);
    if (wallpaperModel)
      wallpaperModel.dataLoaded.connect(applyFolderSelection);
  }

  Connections {
    target: scrollController
    function onCurrentIndexChanged() {
      updateBackground(scrollController.currentIndex);
      if (wallpaperModel)
        queueThumbnails(scrollController.baseIndex, scrollController.maxIndex);
    }
  }

  onBgCurrentChanged: {
    updateSourceA();
  }

  onBgPreviousChanged: {
    updateSourceB();
  }

  function updateSourceA() {
    if (bgCurrent >= 0 && bgCurrent < (wallpaperModel ? wallpaperModel.list.length : 0)) {
      const path = wallpaperModel.list[bgCurrent];
      const p = CacheUtils.getCachedBgPreview(cacheService.thumbHashToPath, path);
      _bgSourceA = p ? ("file://" + p) : ("file://" + path);
    }
  }

  function updateSourceB() {
    if (bgPrevious >= 0 && bgPrevious < (wallpaperModel ? wallpaperModel.list.length : 0)) {
      const path = wallpaperModel.list[bgPrevious];
      const p = CacheUtils.getCachedBgPreview(cacheService.thumbHashToPath, path);
      _bgSourceB = p ? ("file://" + p) : ("file://" + path);
    }
  }

  function updateBackground(index) {
    if (index !== bgCurrent && index >= 0 && index < (wallpaperModel ? wallpaperModel.list.length : 0)) {
      bgPrevious = bgCurrent;
      bgCurrent = index;
      bgSlideProgress = 0;
      bgSlideAnim.restart();
      colorExtractor.run(wallpaperModel.list[index]);
    }
  }

  function queueThumbnails(base, max) {
    if (!wallpaperModel)
      return;
    for (let i = base; i <= max && i < wallpaperModel.list.length; i++) {
      cacheService.queueThumbnail(wallpaperModel.list[i], FileTypes.isVideoFile(wallpaperModel.list[i]), FileTypes.isGifFile(wallpaperModel.list[i]));
    }
  }

  function applyFolderSelection() {
    scrollController.reset();
    bgPrevious = -1;
    bgCurrent = -1;
    bgSlideProgress = 1.0;
    if (wallpaperModel.list.length > 0) {
      bgCurrent = 0;
      colorExtractor.run(wallpaperModel.list[0]);
    }
  }

  function switchFolder(folder) {
    if (wallpaperModel) {
      wallpaperModel.switchFolder(folder);
      applyFolderSelection();
    }
  }

  function refreshCache() {
    if (wallpaperModel)
      wallpaperModel.refresh(wallpaperModel.currentFolder, cacheService);
  }

  function applyWallpaper(path) {
    if (wallpaperApplier)
      wallpaperApplier.apply(path);
    Qt.quit();
  }

  // ========== Components ==========

  Style {
    id: styleConstants
  }

  ScrollController {
    id: scrollController
    count: root.count
    visibleRange: styleConstants.visibleRange
    preloadRange: styleConstants.preloadRange
    animationDuration: viewModel ? viewModel.get("scrollDuration", 280) : 280
    scrollContinueInterval: viewModel ? viewModel.get("scrollContinueInterval", 230) : 230
    parallaxFactor: viewModel ? viewModel.get("bgParallaxFactor", 40) : 40
  }

  PropertyAnimation {
    id: bgSlideAnim
    target: root
    properties: "bgSlideProgress"
    from: 0
    to: 1.0
    duration: viewModel ? viewModel.get("bgSlideDuration", 250) : 250
    easing.type: styleConstants.easingOutQuad
  }

  QtObject {
    id: colorExtractor
    property string dominantColor: Color.mPrimary

    function run(wp) {
      if (!checkService || !checkService.hasImagemagick || !wp || wp.length === 0) {
        root.dominantColor = Color.mPrimary;
        return;
      }
      const t = CacheUtils.getCachedThumb(cacheService.thumbHashToPath, wp);
      if (t) {
        _runColorExtract(t);
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
    interval: styleConstants.searchDebounceMs
    onTriggered: {
      if (wallpaperModel)
        wallpaperModel.setSearch(root.searchText);
      if (root.searchText) {
        scrollController.scrollTo(0);
        bgCurrent = 0;
        bgSlideProgress = 1.0;
        if (wallpaperModel.list.length > 0)
          colorExtractor.run(wallpaperModel.list[0]);
      } else {
        wallpaperModel.resetSearch();
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
    anchors.fill: parent
    anchors.margins: 12
    anchors.topMargin: 80
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
          wallpaperPath: realIndex < wallpaperModel.list.length ? wallpaperModel.list[realIndex] : ""
          filename: realIndex < (wallpaperModel ? wallpaperModel.filenames.length : 0) ? (wallpaperModel ? wallpaperModel.filenames[realIndex] : "") : ""
          isVideo: FileTypes.isVideoFile(wallpaperPath)
          isGif: FileTypes.isGifFile(wallpaperPath)
          thumbHashToPath: cacheService ? cacheService.thumbHashToPath : {}
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
              spacingFactor: 0.45 + metrics.cos * 0.35,
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
            Qt.callLater(() => applyWallpaper(path));
          }
        }
      }

      Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 25
        text: "/ Search  |  ←/→ Navigate  |  Tab/[] Folder  |  Enter Apply  |  R Random  |  F5 Refresh  |  S Settings  |  Esc Quit"
        color: Color.mOutline
        font.pixelSize: 11
        style: Text.Outline
        styleColor: Color.mScrim
      }

      Keys.onPressed: event => {
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

                        // ===== Settings (S) =====
                        if (event.key === Qt.Key_S && !event.modifiers) {
                          root.settingsOpen = true;
                          event.accepted = true;
                          return;
                        }

                        // ===== Search (/, Ctrl+F) =====
                        if (event.key === Qt.Key_Slash || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))) {
                          statusBar.focusSearch();
                          event.accepted = true;
                          return;
                        }

                        // ===== Folder switching (Tab/Shift+Tab or [ / ]) =====
                        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                          const fs = wallpaperModel ? wallpaperModel.folders : [];
                          if (fs.length > 0) {
                            const idx = fs.indexOf(wallpaperModel ? wallpaperModel.currentFolder : "");
                            switchFolder(event.key === Qt.Key_Tab
                              ? (idx < fs.length - 1 ? idx + 1 : 0)
                              : (idx > 0 ? idx - 1 : fs.length - 1));
                          }
                          event.accepted = true;
                          return;
                        }
                        if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BraceLeft) {
                          const fs = wallpaperModel ? wallpaperModel.folders : [];
                          if (fs.length > 0) {
                            const idx = fs.indexOf(wallpaperModel ? wallpaperModel.currentFolder : "");
                            switchFolder(idx > 0 ? fs[idx - 1] : fs[fs.length - 1]);
                          }
                          event.accepted = true;
                          return;
                        }
                        if (event.key === Qt.Key_BracketRight || event.key === Qt.Key_BraceRight) {
                          const fs = wallpaperModel ? wallpaperModel.folders : [];
                          if (fs.length > 0) {
                            const idx = fs.indexOf(wallpaperModel ? wallpaperModel.currentFolder : "");
                            switchFolder(idx >= 0 && idx < fs.length - 1 ? fs[idx + 1] : fs[0]);
                          }
                          event.accepted = true;
                          return;
                        }

                        // ===== Apply wallpaper (Enter) =====
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                          if (root.count > 0) {
                            const idx = scrollController.currentIndex;
                            applyWallpaper(wallpaperModel.list[idx]);
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
      Keys.onReleased: event => {
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
    anchors.topMargin: 16
    anchors.horizontalCenter: parent.horizontalCenter
    z: 100

    folders: wallpaperModel ? wallpaperModel.folders : []
    activeFolder: wallpaperModel ? wallpaperModel.currentFolder : ""
    onFolderClicked: function (folder) {
      switchFolder(folder);
    }
    wallpaperCount: root.count
    cachedCount: cacheService ? cacheService.cachedFileCount : 0
    queueCount: cacheService ? cacheService.queueLength + cacheService.thumbnailJobRunning : 0
    settingsOpen: root.settingsOpen
    onSettingsToggled: {
      root.settingsOpen = !root.settingsOpen;
      if (!root.settingsOpen) pathViewContainer.forceActiveFocus();
    }
    searchText: root.searchText
    onSearchInputChanged: function (text) {
      root.searchText = text;
      searchDebounce.restart();
    }
    onSearchCleared: {
      root.searchText = "";
      if (wallpaperModel)
        wallpaperModel.resetSearch();
      pathViewContainer.forceActiveFocus();
    }
    onSearchSubmitted: {
      if (wallpaperModel)
        wallpaperModel.setSearch(root.searchText);
      if (root.searchText) {
        scrollController.scrollTo(0);
        bgCurrent = 0;
        bgSlideProgress = 1.0;
        if (wallpaperModel.list.length > 0)
          colorExtractor.run(wallpaperModel.list[0]);
      } else {
        wallpaperModel.resetSearch();
      }
      searchDebounce.stop();
      pathViewContainer.forceActiveFocus();
    }
  }

  SettingsPanel {
    id: settingsPanel
    anchors.top: statusBar.bottom
    anchors.topMargin: 8
    anchors.horizontalCenter: statusBar.horizontalCenter
    z: 999
    openDownward: true
    viewModel: root.viewModel
    settingsOpen: root.settingsOpen
    onCloseRequested: {
      root.settingsOpen = false;
      pathViewContainer.forceActiveFocus();
    }
  }
}
