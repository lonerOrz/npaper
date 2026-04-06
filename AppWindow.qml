import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.utils
import "utils/CacheUtils.js" as CacheUtils
import "utils/FileTypes.js" as FileTypes

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

  Style {
    id: styleConstants
  }

  // ViewModel Bindings (No direct Model access)
  property real carouselItemWidth: viewModel ? viewModel.get("carouselItemWidth", 450) : 450
  property real carouselItemHeight: viewModel ? viewModel.get("carouselItemHeight", 320) : 320
  property real carouselSpacing: viewModel ? viewModel.get("carouselSpacing", 25) : 25
  property real carouselRotation: viewModel ? viewModel.get("carouselRotation", 40) : 40
  property real carouselPerspective: viewModel ? viewModel.get("carouselPerspective", 0.3) : 0.3
  readonly property bool debugMode: viewModel ? viewModel.get("debugMode", false) : false

  visible: true
  color: "transparent"
  implicitWidth: screen.width
  implicitHeight: screen.height

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.exclusiveZone: -1

  property string searchText: ""

  readonly property int count: wallpaperModel ? wallpaperModel.count : 0
  readonly property int centerIndex: scrollController.currentIndex

  Component.onCompleted: {
    Logger.init(root.debugMode);
    if (wallpaperModel)
      wallpaperModel.dataLoaded.connect(applyFolderSelection);
  }

  // React to scroll position changes (background update & thumbnail queue)
  Connections {
    target: scrollController
    function onCurrentIndexChanged() {
      const c = scrollController.currentIndex;
      if (c !== bgCurrent && c >= 0 && c < (wallpaperModel ? wallpaperModel.list.length : 0)) {
        bgPrevious = bgCurrent;
        bgCurrent = c;
        bgSlideProgress = 0;
        bgSlideAnim.restart();
        extractDominantColor(wallpaperModel.list[c]);
      }

      // Queue thumbnails for visible range
      let queueCount = 0;
      if (wallpaperModel) {
        const base = scrollController.baseIndex;
        const max = scrollController.maxIndex;
        for (let i = base; i <= max && i < wallpaperModel.list.length; i++) {
          cacheService.queueThumbnail(wallpaperModel.list[i], FileTypes.isVideoFile(wallpaperModel.list[i]), FileTypes.isGifFile(wallpaperModel.list[i]));
          queueCount++;
        }
      }
      Logger.d("scrollTick: idx=" + c + " queue=" + queueCount);
    }
  }

  // Background logic
  property int bgCurrent: -1
  property int bgPrevious: -1
  property real bgSlideProgress: 0.0
  property string _bgSourceA: ""
  property string _bgSourceB: ""

  onBgCurrentChanged: {
    if (!cacheService || !wallpaperModel)
      return;
    if (bgCurrent >= 0 && bgCurrent < wallpaperModel.list.length) {
      const path = wallpaperModel.list[bgCurrent];
      const p = CacheUtils.getCachedBgPreview(cacheService.thumbHashToPath, path);
      _bgSourceA = p ? ("file://" + p) : ("file://" + path);
    }
  }
  onBgPreviousChanged: {
    if (!cacheService || !wallpaperModel)
      return;
    if (bgPrevious >= 0 && bgPrevious < wallpaperModel.list.length) {
      const path = wallpaperModel.list[bgPrevious];
      const p = CacheUtils.getCachedBgPreview(cacheService.thumbHashToPath, path);
      _bgSourceB = p ? ("file://" + p) : ("file://" + path);
    }
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

  property string dominantColor: "#6a9eff"

  function extractDominantColor(wp) {
    if (!checkService || !checkService.hasImagemagick || !wp || wp.length === 0) {
      root.dominantColor = "#6a9eff";
      return;
    }
    const t = CacheUtils.getCachedThumb(cacheService.thumbHashToPath, wp);
    if (t) {
      runColorExtract(t);
      return;
    }
    if (FileTypes.isVideoFile(wp)) {
      root.dominantColor = "#6a9eff";
      return;
    }
    runColorExtract(wp.toLowerCase().endsWith('.gif') ? wp + '[0]' : wp);
  }
  function runColorExtract(src) {
    if (extractColorProcess.running)
      extractColorProcess.running = false;
    extractColorTimeout.start();
    extractColorProcess.command = ["magick", src, "-resize", "1x1!", "-modulate", "100,180", "txt:"];
    extractColorProcess.exec({});
  }
  function randomWallpaper() {
    scrollController.random();
  }
  function applyFolderSelection() {
    scrollController.reset();
    bgPrevious = -1;
    bgCurrent = -1;
    bgSlideProgress = 1.0;
    if (wallpaperModel.list.length > 0) {
      bgCurrent = 0;
      extractDominantColor(wallpaperModel.list[0]);
    }
  }
  function switchFolder(f) {
    wallpaperModel.switchFolder(f);
    applyFolderSelection();
  }
  function refreshCache() {
    const f = wallpaperModel.currentFolder;
    const ps = wallpaperModel.wallpaperMap[f] || [];
    if (ps.length === 0)
      return;
    cacheService.refreshAndQueue(ps, f);
  }
  function applyWallpaper(path) {
    if (wallpaperApplier)
      wallpaperApplier.apply(path);
    Qt.quit();
  }

  Timer {
    id: extractColorTimeout
    interval: 5000
    onTriggered: root.dominantColor = "#6a9eff"
  }
  Process {
    id: extractColorProcess
    stdout: StdioCollector {
      onStreamFinished: {
        extractColorTimeout.stop();
        const m = text.trim().match(/#([0-9A-F]{6})/i);
        root.dominantColor = m ? "#" + m[1].toUpperCase() : "#6a9eff";
      }
    }
    onExited: function (exitCode, exitStatus) {
      extractColorTimeout.stop();
      if (exitCode !== 0)
        root.dominantColor = "#6a9eff";
    }
  }
  Timer {
    id: searchDebounce
    interval: styleConstants.searchDebounceMs
    onTriggered: {
      wallpaperModel.setSearch(root.searchText);
      if (root.searchText) {
        scrollController.scrollTo(0);
        bgCurrent = 0;
        bgSlideProgress = 1.0;
        if (wallpaperModel.list.length > 0)
          extractDominantColor(wallpaperModel.list[0]);
      } else
        wallpaperModel.resetSearch();
    }
  }

  // ===== UI =====

  // Scroll Controller (New Component)
  ScrollController {
    id: scrollController
    count: root.count
    visibleRange: styleConstants.visibleRange
    preloadRange: styleConstants.preloadRange
    animationDuration: viewModel ? viewModel.get("scrollDuration", 280) : 280
    scrollContinueInterval: viewModel ? viewModel.get("scrollContinueInterval", 230) : 230
    parallaxFactor: viewModel ? viewModel.get("bgParallaxFactor", 40) : 40
  }

  // Background Manager
  BackgroundManager {
    anchors.fill: parent
    sourceA: _bgSourceA
    sourceB: _bgSourceB
    crossfadeProgress: bgSlideProgress
    parallaxX: (scrollController.scrollTarget - scrollController.currentIndex) * scrollController.parallaxFactor
    dominantColor: root.dominantColor
    overlayOpacity: viewModel ? viewModel.get("bgOverlayOpacity", 0.4) : 0.4
    showPreview: viewModel ? viewModel.get("showBgPreview", true) : true
  }

  // Main Content Layout
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 12
    anchors.topMargin: 80 // Space for StatusBar (y=16 + h=44 + padding)
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

      Rectangle {
        anchors.fill: parent
        color: "#0d0d0dcc"
      }

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
          showBorderGlow: viewModel ? viewModel.get("showBorderGlow", true) : true
          showShadow: viewModel ? viewModel.get("showShadow", true) : true

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
        text: "←/→ Navigate  |  Tab/[ ] Switch Folder  |  Enter Apply  |  R Random  |  F5 Refresh  |  S Settings  |  Esc Quit"
        color: "#888888"
        font.pixelSize: 11
        style: Text.Outline
        styleColor: "#000000"
      }

      Keys.onPressed: event => {
                        if (event.key === Qt.Key_S && !event.modifiers) {
                          root.settingsOpen = true;
                          event.accepted = true;
                          return;
                        }
                        if (event.key === Qt.Key_Backspace) {
                          if (root.searchText) {
                            root.searchText = root.searchText.slice(0, -1);
                            searchDebounce.restart();
                          }
                          event.accepted = true;
                          return;
                        }
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
                        if (event.key === Qt.Key_Tab) {
                          const fs = wallpaperModel ? wallpaperModel.folders : [];
                          if (fs.length > 0) {
                            const idx = fs.indexOf(wallpaperModel ? wallpaperModel.currentFolder : "");
                            switchFolder(fs[idx < fs.length - 1 ? idx + 1 : 0]);
                          }
                          event.accepted = true;
                          return;
                        }
                        if (event.key === Qt.Key_Backtab) {
                          const fs = wallpaperModel ? wallpaperModel.folders : [];
                          if (fs.length > 0) {
                            const idx = fs.indexOf(wallpaperModel ? wallpaperModel.currentFolder : "");
                            switchFolder(fs[idx > 0 ? idx - 1 : fs.length - 1]);
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
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                          if (root.count > 0) {
                            const idx = scrollController.currentIndex;
                            applyWallpaper(wallpaperModel.list[idx]);
                          }
                          event.accepted = true;
                          return;
                        }
                        if (event.key === Qt.Key_R && !event.modifiers) {
                          scrollController.random();
                          event.accepted = true;
                          return;
                        }
                        if (event.key === Qt.Key_F5) {
                          refreshCache();
                          event.accepted = true;
                          return;
                        }
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
                        if (event.text && event.text.length === 1 && !event.modifiers) {
                          root.searchText += event.text;
                          searchDebounce.restart();
                          event.accepted = true;
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

  // Top Status Bar (Floating, above layout)
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
    onSettingsToggled: root.settingsOpen = !root.settingsOpen
  }

  // Settings Panel (Anchored to StatusBar)
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
      // Return focus to main view
      pathViewContainer.forceActiveFocus();
    }
  }
}
