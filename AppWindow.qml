import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "utils/CacheUtils.js" as CacheUtils
import "utils/FileTypes.js" as FileTypes
import "components"

PanelWindow {
  id: root

  property var modelData
  property var userConfigService
  property var checkService
  property var cacheService
  property var wallpaperModel
  property var wallpaperApplier

  screen: modelData

  readonly property bool debugMode: userConfigService ? userConfigService.debugMode : false

  visible: true
  color: "transparent"

  implicitWidth: screen.width
  implicitHeight: screen.height

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.exclusiveZone: -1

  property string searchText: ""
  property real scrollIndex: 0
  property real _cachedScrollIndex: 0
  property real scrollVelocity: 0
  property real lastScrollIndex: 0
  property int scrollTimestamp: 0
  property real scrollTarget: 0
  property int keyScrollDirection: 0
  property int keyScrollStep: 1
  property bool isKeyScrolling: false

  readonly property int count: wallpaperModel ? wallpaperModel.count : 0
  readonly property int visibleRange: 4
  readonly property int preloadRange: 2
  readonly property int centerIndex: Math.round(scrollIndex)
  readonly property int baseIndex: Math.max(0, centerIndex - visibleRange - preloadRange)
  readonly property int maxIndex: Math.min(count - 1, centerIndex + visibleRange + preloadRange)
  readonly property int loadedCount: count > 0 ? Math.max(0, maxIndex - baseIndex + 1) : 0

  Behavior on scrollTarget {
    NumberAnimation {
      duration: 280
      easing.type: Easing.OutCubic
    }
  }

  onScrollTargetChanged: {
    scrollIndex = scrollTarget;
  }

  Timer {
    id: scrollContinueTimer
    interval: 230
    repeat: false
    onTriggered: {
      if (isKeyScrolling && keyScrollDirection !== 0 && root.count > 0) {
        const step = (keyScrollStep || 1);
        const maxIdx = root.count - 1;
        const currentIdx = Math.round(scrollTarget);
        let nextIdx = currentIdx;
        if (keyScrollDirection === -1) {
          nextIdx = Math.max(0, currentIdx - step);
        } else {
          nextIdx = Math.min(maxIdx, currentIdx + step);
        }
        if (nextIdx !== currentIdx) {
          scrollTarget = nextIdx;
        } else {
          isKeyScrolling = false;
        }
      } else {
        isKeyScrolling = false;
      }
    }
  }

  Component.onCompleted: {
    scrollTarget = 0;
    if (wallpaperModel) {
      wallpaperModel.dataLoaded.connect(applyFolderSelection);
    }
  }

  // Background
  property int bgCurrent: -1
  property int bgPrevious: -1
  property real bgSlideProgress: 0.0
  property string _bgSourceA: ""
  property string _bgSourceB: ""

  onBgCurrentChanged: {
    if (!cacheService || !wallpaperModel) return;
    if (bgCurrent >= 0 && bgCurrent < wallpaperModel.list.length) {
      const path = wallpaperModel.list[bgCurrent];
      const bgPreview = CacheUtils.getCachedBgPreview(cacheService.thumbHashToPath, path);
      _bgSourceA = bgPreview ? ("file://" + bgPreview) : ("file://" + path);
    }
  }

  onBgPreviousChanged: {
    if (!cacheService || !wallpaperModel) return;
    if (bgPrevious >= 0 && bgPrevious < wallpaperModel.list.length) {
      const path = wallpaperModel.list[bgPrevious];
      const bgPreview = CacheUtils.getCachedBgPreview(cacheService.thumbHashToPath, path);
      _bgSourceB = bgPreview ? ("file://" + bgPreview) : ("file://" + path);
    }
  }

  PropertyAnimation {
    id: bgSlideAnim
    target: root
    properties: "bgSlideProgress"
    from: 0
    to: 1.0
    duration: 250
    easing.type: Easing.OutQuad
  }

  readonly property real bgBaseParallaxX: (scrollIndex - centerIndex) * 40

  onScrollIndexChanged: {
    if (!cacheService || !wallpaperModel) return;
    _cachedScrollIndex = scrollIndex;

    const now = Date.now();
    const dt = now - scrollTimestamp;
    if (dt > 0 && dt < 200) {
      scrollVelocity = (scrollIndex - lastScrollIndex) / dt * 1000;
    }
    lastScrollIndex = scrollIndex;
    scrollTimestamp = now;

    const c = centerIndex;
    if (c !== bgCurrent && c >= 0 && c < wallpaperModel.list.length) {
      bgPrevious = bgCurrent;
      bgCurrent = c;
      bgSlideProgress = 0;
      bgSlideAnim.restart();
      extractDominantColor(wallpaperModel.list[c]);
    }

    let queueCount = 0;
    for (let i = baseIndex; i <= maxIndex && i < wallpaperModel.list.length; i++) {
      const path = wallpaperModel.list[i];
      cacheService.queueThumbnail(path, FileTypes.isVideoFile(path), FileTypes.isGifFile(path));
      queueCount++;
    }
    if (root.debugMode)
      console.log("[npaper] scrollTick:", "idx=" + Math.round(scrollIndex), "queue=" + queueCount);
  }

  property string dominantColor: "#6a9eff"

  Timer {
    id: extractColorTimeout
    interval: 5000
    onTriggered: {
      root.dominantColor = "#6a9eff";
    }
  }

  Process {
    id: extractColorProcess
    stdout: StdioCollector {
      onStreamFinished: {
        extractColorTimeout.stop();
        const output = text.trim();
        const match = output.match(/#([0-9A-F]{6})/i);
        if (match) {
          root.dominantColor = "#" + match[1].toUpperCase();
        } else {
          root.dominantColor = "#6a9eff";
        }
      }
    }
    onExited: function (exitCode, exitStatus) {
      extractColorTimeout.stop();
      if (exitCode !== 0) {
        root.dominantColor = "#6a9eff";
      }
    }
  }

  function extractDominantColor(wallpaperPath) {
    if (!checkService || !checkService.hasImagemagick || !wallpaperPath || wallpaperPath.length === 0) {
      root.dominantColor = "#6a9eff";
      return;
    }
    if (!cacheService) return;
    const cachedThumb = CacheUtils.getCachedThumb(cacheService.thumbHashToPath, wallpaperPath);
    if (cachedThumb) {
      runColorExtract(cachedThumb);
      return;
    }
    if (FileTypes.isVideoFile(wallpaperPath)) {
      root.dominantColor = "#6a9eff";
      return;
    }
    const path = wallpaperPath.toLowerCase().endsWith('.gif') ? wallpaperPath + '[0]' : wallpaperPath;
    runColorExtract(path);
  }

  function runColorExtract(sourcePath) {
    if (extractColorProcess.running) {
      extractColorProcess.running = false;
    }
    extractColorTimeout.start();
    extractColorProcess.command = ["magick", sourcePath, "-resize", "1x1!", "-modulate", "100,180", "txt:"];
    extractColorProcess.exec({});
  }

  function randomWallpaper() {
    if (root.count > 0) {
      scrollTarget = Math.floor(Math.random() * root.count);
    }
  }

  function applyFolderSelection() {
    scrollTarget = 0;
    scrollIndex = 0;
    _cachedScrollIndex = 0;
    bgPrevious = -1;
    bgCurrent = -1;
    bgSlideProgress = 1.0;
    if (wallpaperModel.list.length > 0) {
      bgCurrent = 0;
      extractDominantColor(wallpaperModel.list[0]);
    }
  }

  function switchFolder(folder) {
    wallpaperModel.switchFolder(folder);
    applyFolderSelection();
  }

  function refreshCache() {
    console.log("[npaper] Refreshing...");
    const folder = wallpaperModel.currentFolder;
    const paths = wallpaperModel.wallpaperMap[folder] || [];
    if (paths.length === 0) return;
    cacheService.refreshAndQueue(paths, folder);
  }

  function setScrollIndex(v) {
    if (root.count === 0) return;
    const clamped = Math.max(0, Math.min(v, root.count - 1));
    if (clamped !== scrollTarget) {
      scrollTarget = clamped;
    }
  }

  function applyWallpaper(path) {
    wallpaperApplier.apply(path);
    Qt.quit();
  }

  Timer {
    id: searchDebounce
    interval: 150
    onTriggered: {
      wallpaperModel.setSearch(root.searchText);
      if (root.searchText) {
        scrollTarget = 0;
        scrollIndex = 0;
        _cachedScrollIndex = 0;
        bgCurrent = 0;
        bgSlideProgress = 1.0;
        if (wallpaperModel.list.length > 0) {
          extractDominantColor(wallpaperModel.list[0]);
        }
      } else {
        wallpaperModel.resetSearch();
      }
    }
  }

  // ===== UI =====

  Image {
    id: bgImageA
    anchors.fill: parent
    x: root.bgBaseParallaxX + (root.bgSlideProgress * root.width)
    z: -2
    visible: userConfigService.showBgPreview && root.bgCurrent >= 0 && root.bgCurrent < wallpaperModel.list.length
    opacity: visible ? root.bgSlideProgress : 0
    source: _bgSourceA
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
    mipmap: true
    sourceSize: Qt.size(1920 * screen.devicePixelRatio, 1080 * screen.devicePixelRatio)
    cache: true
  }

  Image {
    id: bgImageB
    anchors.fill: parent
    x: root.bgBaseParallaxX + ((root.bgSlideProgress - 1) * root.width)
    z: -2
    visible: userConfigService.showBgPreview && root.bgPrevious >= 0 && root.bgPrevious < wallpaperModel.list.length
    opacity: visible ? (1.0 - root.bgSlideProgress) : 0
    source: _bgSourceB
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
    mipmap: true
    sourceSize: Qt.size(Math.min(1920, screen.width) * screen.devicePixelRatio, Math.min(1080, screen.height) * screen.devicePixelRatio)
    cache: true
  }

  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: 0.4
    z: -1
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 12
    z: 0

    Item {
      id: pathViewContainer
      Layout.fillWidth: true
      Layout.fillHeight: true
      focus: true
      clip: true

      property int itemWidth: 450
      property int itemHeight: 320
      property real spacing: 25
      property real centerX: width / 2
      property real centerY: height / 2

      Rectangle {
        anchors.fill: parent
        color: "#0d0d0dcc"
      }

      FolderTabs {
        id: folderTabs
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 16
        model: wallpaperModel.folders
        activeFolder: wallpaperModel.currentFolder
        onFolderClicked: switchFolder(folder)
      }

      Repeater {
        model: root.loadedCount

        delegate: WallpaperCard {
          required property int index
          property int realIndex: root.baseIndex + index
          wallpaperPath: realIndex < wallpaperModel.list.length ? wallpaperModel.list[realIndex] : ""
          filename: realIndex < wallpaperModel.filenames.length ? wallpaperModel.filenames[realIndex] : ""
          isVideo: FileTypes.isVideoFile(wallpaperPath)
          isGif: FileTypes.isGifFile(wallpaperPath)
          thumbHashToPath: cacheService.thumbHashToPath
          isCenter: realIndex === root.centerIndex

          readonly property var metrics: {
            const raw = realIndex - root._cachedScrollIndex;
            const abs = Math.abs(raw);
            const cos = Math.cos(Math.min(abs, 3) * 0.523599);
            const perspectiveScale = 1.0 / (1.0 + abs * 0.3);
            return { raw, abs, cos, perspectiveScale };
          }

          readonly property var visual: {
            const abs = metrics.abs;
            return {
              scale: metrics.perspectiveScale * (0.85 + metrics.cos * 0.15) + (isCenter ? 0.06 : 0),
              opacity: abs > 6 ? 0 : Math.pow(Math.max(0, 1 - abs * 0.12), 2.5),
              rotationY: metrics.raw * -40,
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

          onClicked: function(path) {
            setScrollIndex(realIndex);
            Qt.callLater(() => applyWallpaper(path));
          }
        }
      }

      Text {
        id: searchHint
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 150
        text: root.searchText ? "search: " + root.searchText : ""
        color: "#4a9eff"
        font.pixelSize: 18
        font.bold: true
        style: Text.Outline
        styleColor: "black"
      }

      Image {
        id: nixosLogo
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: searchHint.top
        anchors.bottomMargin: 15
        width: 160
        height: 160
        source: Qt.resolvedUrl("assets/nixos-logo.svg")
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: root.count > 0
        z: 10

        layer.enabled: true
        layer.effect: MultiEffect {
          colorization: 1.0
          colorizationColor: Qt.color(root.dominantColor)
          blurEnabled: true
          blur: 0.12
          brightness: 1.3
          Behavior on colorizationColor {
            ColorAnimation {
              duration: 200
            }
          }
        }
      }

      Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 25
        text: "←/→ Navigate  |  Tab/[ ] Switch Folder  |  Enter Apply  |  R Random  |  F5 Refresh  |  Shift+←/→ Fast Scroll  |  Type to Search  |  Esc Quit"
        color: "#888888"
        font.pixelSize: 11
        style: Text.Outline
        styleColor: "#000000"
      }

      StatusBar {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 20
        wallpaperCount: root.count
        cachedCount: cacheService.cachedFileCount
        queueCount: cacheService.queueLength + cacheService.thumbnailJobRunning
        activeFolder: wallpaperModel.currentFolder
      }

      Keys.onPressed: event => {
        if (event.key === Qt.Key_Backspace) {
          if (root.searchText) {
            root.searchText = root.searchText.slice(0, -1);
            searchDebounce.restart();
          }
          event.accepted = true;
          return;
        }

        if (event.key === Qt.Key_Escape) {
          Qt.quit();
          event.accepted = true;
          return;
        }

        if (event.key === Qt.Key_Tab) {
          const idx = wallpaperModel.folders.indexOf(wallpaperModel.currentFolder);
          if (wallpaperModel.folders.length > 0) {
            switchFolder(wallpaperModel.folders[idx < wallpaperModel.folders.length - 1 ? idx + 1 : 0]);
          }
          event.accepted = true;
          return;
        }

        if (event.key === Qt.Key_Backtab) {
          const idx = wallpaperModel.folders.indexOf(wallpaperModel.currentFolder);
          if (wallpaperModel.folders.length > 0) {
            switchFolder(wallpaperModel.folders[idx > 0 ? idx - 1 : wallpaperModel.folders.length - 1]);
          }
          event.accepted = true;
          return;
        }

        if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BraceLeft) {
          const idx = wallpaperModel.folders.indexOf(wallpaperModel.currentFolder);
          if (idx > 0) {
            switchFolder(wallpaperModel.folders[idx - 1]);
          } else if (wallpaperModel.folders.length > 0) {
            switchFolder(wallpaperModel.folders[wallpaperModel.folders.length - 1]);
          }
          event.accepted = true;
          return;
        }

        if (event.key === Qt.Key_BracketRight || event.key === Qt.Key_BraceRight) {
          const idx = wallpaperModel.folders.indexOf(wallpaperModel.currentFolder);
          if (idx >= 0 && idx < wallpaperModel.folders.length - 1) {
            switchFolder(wallpaperModel.folders[idx + 1]);
          } else if (wallpaperModel.folders.length > 0) {
            switchFolder(wallpaperModel.folders[0]);
          }
          event.accepted = true;
          return;
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          if (root.count > 0) {
            const idx = Math.round(root.scrollIndex);
            const path = wallpaperModel.list[((idx % root.count) + root.count) % root.count];
            applyWallpaper(path);
          }
          event.accepted = true;
          return;
        }

        if (event.key === Qt.Key_R && !event.modifiers) {
          randomWallpaper();
          event.accepted = true;
          return;
        }

        if (event.key === Qt.Key_F5) {
          refreshCache();
          event.accepted = true;
          return;
        }

        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
          const step = (event.modifiers & Qt.ShiftModifier) ? 5 : 1;
          const direction = (event.key === Qt.Key_Left) ? -1 : 1;
          if (keyScrollDirection !== direction) {
            keyScrollDirection = direction;
            keyScrollStep = step;
            isKeyScrolling = true;
            scrollContinueTimer.stop();
            const maxIdx = root.count - 1;
            if (direction === -1) {
              scrollTarget = Math.max(0, scrollTarget - step);
            } else {
              scrollTarget = Math.min(maxIdx, scrollTarget + step);
            }
          } else if (step !== keyScrollStep) {
            keyScrollStep = step;
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
          const direction = (event.key === Qt.Key_Left) ? -1 : 1;
          if (keyScrollDirection === direction) {
            keyScrollDirection = 0;
            isKeyScrolling = false;
            scrollContinueTimer.stop();
          }
          event.accepted = true;
        }
      }
    }
  }
}
