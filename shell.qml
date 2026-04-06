pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "utils/CacheUtils.js" as CacheUtils
import "utils/FileTypes.js" as FileTypes
import "utils/HashUtils.js" as HashUtils
import "utils"

ShellRoot {
  ConfigManager {
    id: appConfig
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: root
      property var modelData
      screen: modelData

      readonly property bool debugMode: appConfig.debugMode

      visible: true
      color: "transparent"

      implicitWidth: screen.width
      implicitHeight: screen.height

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      WlrLayershell.exclusiveZone: -1

      property var wallpaperList: []
      property var wallpaperListLower: []
      property var wallpaperFilenames: []
      property var filteredWallpaperList: []
      property var filteredFilenames: []
      property string searchText: ""

      property var folderList: []
      property var folderWallpaperMap: ({})
      property string activeFolder: ""

      readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/wallpaper_thumbs"
      property bool hasFfmpeg: false

      property real scrollIndex: 0
      property real _cachedScrollIndex: 0
      property real scrollVelocity: 0
      property real lastScrollIndex: 0
      property int scrollTimestamp: 0
      property real targetScrollIndex: 0
      readonly property int count: filteredWallpaperList.length
      readonly property int visibleRange: appConfig.visibleRange
      readonly property int preloadRange: appConfig.preloadRange

      property real keyScrollVelocity: 0
      property int keyScrollDirection: 0
      property int keyScrollStep: 1
      property bool isKeyScrolling: false
      property real scrollTarget: 0

      Behavior on scrollTarget {
        NumberAnimation {
          id: scrollAnim
          duration: appConfig.scrollAnimDuration
          easing.type: Easing.OutCubic
        }
      }

      onScrollTargetChanged: {
        scrollIndex = scrollTarget;
      }

      Timer {
        id: scrollContinueTimer
        interval: appConfig.scrollContinueInterval
        repeat: false
        onTriggered: {
          if (isKeyScrolling && keyScrollDirection !== 0 && root.count > 0) {
            const step = (keyScrollStep || 1);
            const maxIdx = root.filteredWallpaperList.length - 1;
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
        targetScrollIndex = 0;
        cacheManager.initialize();
      }

      PropertyAnimation {
        id: bgSlideAnim
        target: root
        properties: "bgSlideProgress"
        from: 0
        to: 1.0
        duration: appConfig.bgSlideDuration
        easing.type: Easing.OutQuad
      }

      property int bgCurrent: -1
      property int bgPrevious: -1
      property real bgSlideProgress: 0.0
      property string _bgSourceA: ""
      property string _bgSourceB: ""

      onBgCurrentChanged: {
        if (bgCurrent >= 0 && bgCurrent < root.filteredWallpaperList.length) {
          const path = root.filteredWallpaperList[bgCurrent];
          const bgPreview = CacheUtils.getCachedBgPreview(cacheManager.thumbHashToPath, path);
          _bgSourceA = bgPreview ? ("file://" + bgPreview) : ("file://" + path);
        }
      }

      onBgPreviousChanged: {
        if (bgPrevious >= 0 && bgPrevious < root.filteredWallpaperList.length) {
          const path = root.filteredWallpaperList[bgPrevious];
          const bgPreview = CacheUtils.getCachedBgPreview(cacheManager.thumbHashToPath, path);
          _bgSourceB = bgPreview ? ("file://" + bgPreview) : ("file://" + path);
        }
      }

      readonly property int centerIndex: Math.round(scrollIndex)
      readonly property int baseIndex: Math.max(0, centerIndex - visibleRange - preloadRange)
      readonly property int maxIndex: Math.min(count - 1, centerIndex + visibleRange + preloadRange)
      readonly property int loadedCount: count > 0 ? Math.max(0, maxIndex - baseIndex + 1) : 0

      onScrollIndexChanged: {
        _cachedScrollIndex = scrollIndex;

        const now = Date.now();
        const dt = now - scrollTimestamp;
        if (dt > 0 && dt < 200) {
          scrollVelocity = (scrollIndex - lastScrollIndex) / dt * 1000;
        }
        lastScrollIndex = scrollIndex;
        scrollTimestamp = now;

        const c = centerIndex;
        if (c !== bgCurrent && c >= 0 && c < root.filteredWallpaperList.length) {
          bgPrevious = bgCurrent;
          bgCurrent = c;
          bgSlideProgress = 0;
          bgSlideAnim.restart();
          extractDominantColor(root.filteredWallpaperList[c]);
        }

        let queueCount = 0;
        for (let i = baseIndex; i <= maxIndex && i < root.filteredWallpaperList.length; i++) {
          const path = root.filteredWallpaperList[i];
          cacheManager.queueThumbnail(path, FileTypes.isVideoFile(path), FileTypes.isGifFile(path));
          queueCount++;
        }
        if (root.debugMode)
        console.log("[npaper] scrollTick:", "idx=" + Math.round(scrollIndex), "queue=" + queueCount);
      }

      property string dominantColor: "#6a9eff"
      property bool hasImagemagick: false

      // Cache Manager Instance
      CacheManager {
        id: cacheManager
        cacheDir: root.cacheDir
        hasFfmpeg: root.hasFfmpeg
        debugMode: root.debugMode
        thumbWidth: appConfig.carouselItemWidth
        thumbHeight: appConfig.carouselItemHeight

        onCacheScanned: {
          listProcess.exec({});
        }

        onCacheRefreshed: {
          console.log("[npaper] Cache refresh completed");
        }

        onThumbnailGenerated: {}
      }
      Process {
        id: checkImagemagick
        command: ["sh", "-c", "command -v magick >/dev/null 2>&1 && echo OK"]
        stdout: StdioCollector {
          onStreamFinished: {
            root.hasImagemagick = text.trim() === "OK";
          }
        }
        running: true
      }

      Process {
        id: checkFfmpeg
        command: ["sh", "-c", "command -v ffmpeg >/dev/null 2>&1 && echo OK"]
        stdout: StdioCollector {
          onStreamFinished: {
            root.hasFfmpeg = text.trim() === "OK";
            cacheManager.scanCache();
          }
        }
        running: true
      }

      Process {
        id: folderListProcess
        command: [Qt.resolvedUrl("./wallpaper.sh"), "--list-folders"]
        stdout: StdioCollector {
          onStreamFinished: {
            const folders = text.trim().split('\n').filter(f => f.length > 0);
            root.folderList = folders;
            if (folders.length > 0) {
              root.activeFolder = folders[0];
            }
            if (root.debugMode)
            console.log("[npaper] Folders:", folders);
            if (folders.length > 0) {
              const cacheDirs = folders.map(f => root.cacheDir + "/" + f);
              ensureCacheDirsProcess.command = ["mkdir", "-p", ...cacheDirs];
              ensureCacheDirsProcess.exec({});
            } else {
              listProcess.exec({});
            }
          }
        }
        onExited: function (exitCode, exitStatus) {
          if (exitCode !== 0) {
            if (root.debugMode)
              console.log("[npaper] folderListProcess failed, falling back");
            root.folderList = ["wallpapers"];
            root.activeFolder = "wallpapers";
            listProcess.exec({});
          }
        }
        running: true
      }

      Process {
        id: ensureCacheDirsProcess
        onExited: function () {
          listProcess.exec({});
        }
      }

      Process {
        id: listProcess
        command: [Qt.resolvedUrl("./wallpaper.sh"), "--list-with-folders"]
        stdout: StdioCollector {
          onStreamFinished: {
            const lines = text.trim().split('\n').filter(line => line.length > 0);
            const folderMap = {};
            lines.forEach(line => {
                            const sepIdx = line.indexOf('|');
                            if (sepIdx > 0) {
                              const folder = line.substring(0, sepIdx);
                              const path = line.substring(sepIdx + 1);
                              if (!folderMap[folder])
                              folderMap[folder] = [];
                              folderMap[folder].push(path);
                            }
                          });
            root.folderWallpaperMap = folderMap;
            applyFolderSelection();
          }
        }
        onExited: function (exitCode, exitStatus) {
          if (exitCode !== 0 && root.debugMode)
            console.log("[npaper] Wallpaper list failed, exitCode:", exitCode);
        }
      }

      function applyFolderSelection() {
        const folder = root.activeFolder;
        const paths = root.folderWallpaperMap[folder] || [];
        root.wallpaperList = paths;
        root.wallpaperListLower = paths.map(p => p.toLowerCase());
        root.wallpaperFilenames = paths.map(p => p.split('/').pop());
        root.filteredWallpaperList = paths;
        root.filteredFilenames = root.wallpaperFilenames;
        root.searchText = "";
        root.scrollTarget = 0;
        root.scrollIndex = 0;
        root._cachedScrollIndex = 0;
        root.bgPrevious = -1;
        root.bgCurrent = -1;
        root.bgSlideProgress = 1.0;
        if (paths.length > 0) {
          root.bgCurrent = 0;
          extractDominantColor(paths[0]);
        }
        if (root.debugMode)
          console.log("[npaper] Switched to folder:", folder, "count:", paths.length);
      }

      function switchFolder(folder) {
        if (root.debugMode)
          console.log("[npaper] Switching to folder:", folder);
        root.activeFolder = folder;
        applyFolderSelection();
      }

      function refreshCache() {
        console.log("[npaper] Refreshing...");
        const folder = root.activeFolder;
        const paths = root.folderWallpaperMap[folder] || [];
        if (paths.length === 0)
          return;
        cacheManager.refreshAndQueue(paths, folder);
      }

      function setScrollIndex(v) {
        if (root.count === 0)
          return;
        const clamped = Math.max(0, Math.min(v, root.count - 1));
        if (clamped !== root.targetScrollIndex) {
          if (root.debugMode)
            console.log("[npaper] setScrollIndex:", root.scrollIndex, "->", clamped);
          root.scrollTarget = clamped;
          root.targetScrollIndex = clamped;
        }
      }

      PropertyAnimation {
        id: bgFadeIn
        target: root
        properties: "bgOpacity"
        from: 0
        to: 1.0
        duration: appConfig.bgFadeDuration
        easing.type: Easing.InOutCubic
      }

      readonly property real bgBaseParallaxX: (scrollIndex - centerIndex) * appConfig.bgParallaxFactor

      property var _searchResults: []
      property var _searchNames: []

      Timer {
        id: searchDebounce
        interval: appConfig.searchDebounceMs
        onTriggered: {
          const text = root.searchText;
          if (root.debugMode)
          console.log("[npaper] performSearch:", text ? '"' + text + '"' : "(empty)");
          if (!text) {
            applyFolderSelection();
          } else {
            const lower = text.toLowerCase();
            root._searchResults = [];
            root._searchNames = [];
            for (let i = 0; i < root.wallpaperList.length; i++) {
              if (root.wallpaperListLower[i].includes(lower)) {
                root._searchResults.push(root.wallpaperList[i]);
                root._searchNames.push(root.wallpaperFilenames[i]);
              }
            }
            root.filteredWallpaperList = root._searchResults;
            root.filteredFilenames = root._searchNames;
            if (root.debugMode)
            console.log("[npaper] Search results:", root._searchResults.length, "matches");

            scrollTarget = 0;
            scrollIndex = 0;
            _cachedScrollIndex = 0;
            bgCurrent = 0;
            bgSlideProgress = 1.0;
            if (root.filteredWallpaperList.length > 0) {
              extractDominantColor(root.filteredWallpaperList[0]);
            }
          }
        }
      }

      Timer {
        id: extractColorTimeout
        interval: 5000
        onTriggered: {
          if (root.debugMode)
          console.log("[npaper] Color extraction timeout");
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
              if (root.debugMode)
              console.log("[npaper] Dominant color extracted:", root.dominantColor);
            } else {
              if (root.debugMode) {
                console.log("[npaper] Color extraction failed, got:", output);
              }
              root.dominantColor = "#6a9eff";
            }
          }
        }
        onExited: function (exitCode, exitStatus) {
          extractColorTimeout.stop();
          if (exitCode !== 0) {
            if (root.debugMode)
              console.log("[npaper] Color extraction process failed, exitCode:", exitCode);
            root.dominantColor = "#6a9eff";
          }
        }
      }

      function extractDominantColor(wallpaperPath) {
        if (!root.hasImagemagick || !wallpaperPath || wallpaperPath.length === 0) {
          root.dominantColor = "#6a9eff";
          if (root.debugMode)
            console.log("[npaper] Using default color (no imagemagick or invalid path)");
          return;
        }
        const cachedThumb = CacheUtils.getCachedThumb(cacheManager.thumbHashToPath, wallpaperPath);
        if (cachedThumb) {
          runColorExtract(cachedThumb);
          return;
        }
        if (FileTypes.isVideoFile(wallpaperPath)) {
          root.dominantColor = "#6a9eff";
          if (root.debugMode)
            console.log("[npaper] Skipping video (no thumbnail cached)");
          return;
        }
        const path = wallpaperPath.toLowerCase().endsWith('.gif') ? wallpaperPath + '[0]' : wallpaperPath;
        runColorExtract(path);
      }

      function runColorExtract(sourcePath) {
        if (root.debugMode)
          console.log("[npaper] Extracting color from:", sourcePath);

        if (extractColorProcess.running) {
          extractColorProcess.running = false;
        }

        extractColorTimeout.start();
        extractColorProcess.command = ["magick", sourcePath, "-resize", "1x1!", "-modulate", "100,180", "txt:"];
        extractColorProcess.exec({});
      }

      function randomWallpaper() {
        if (root.count > 0) {
          const randomIdx = Math.floor(Math.random() * root.count);
          scrollTarget = randomIdx;
          targetScrollIndex = randomIdx;
        }
      }

      Image {
        id: bgImageA
        anchors.fill: parent
        x: root.bgBaseParallaxX + (root.bgSlideProgress * root.width)
        z: -2
        visible: root.bgCurrent >= 0 && root.bgCurrent < root.filteredWallpaperList.length
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
        visible: root.bgPrevious >= 0 && root.bgPrevious < root.filteredWallpaperList.length
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
        opacity: appConfig.bgOverlayOpacity
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

          property int itemWidth: appConfig.carouselItemWidth
          property int itemHeight: appConfig.carouselItemHeight
          property real spacing: appConfig.carouselSpacing
          property real centerX: width / 2
          property real centerY: height / 2

          Rectangle {
            anchors.fill: parent
            color: "#0d0d0dcc"
          }

          Row {
            id: folderTabBar
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 16
            spacing: 4
            z: 20

            Repeater {
              model: root.folderList

              delegate: Item {
                required property string modelData
                property bool active: root.activeFolder === modelData
                property real tabWidth: folderTabText.implicitWidth + (active ? 24 : 12)

                width: tabWidth
                height: 32

                Rectangle {
                  anchors.fill: parent
                  radius: 6
                  color: active ? "#ffffff" : "transparent"
                  visible: active
                }

                Text {
                  id: folderTabText
                  anchors.centerIn: parent
                  text: modelData
                  color: active ? "#000000" : "#aaaaaa"
                  font.pixelSize: 13
                  font.weight: active ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: switchFolder(modelData)
                }
              }
            }
          }

          Repeater {
            id: imageRepeater
            model: root.loadedCount

            delegate: Item {
              id: delegateItem
              required property int index
              property int realIndex: root.baseIndex + index
              property string wallpaperPath: realIndex < root.filteredWallpaperList.length ? root.filteredWallpaperList[realIndex] : ""
              property string filename: realIndex < root.filteredFilenames.length ? root.filteredFilenames[realIndex] : ""
              property bool isVideo: FileTypes.isVideoFile(wallpaperPath)
              property bool isGif: FileTypes.isGifFile(wallpaperPath)

              readonly property var metrics: {
                const raw = realIndex - root._cachedScrollIndex;
                const abs = Math.abs(raw);
                const cos = Math.cos(Math.min(abs, 3) * 0.523599);
                const perspectiveScale = 1.0 / (1.0 + abs * appConfig.carouselPerspective);
                return {
                  raw,
                  abs,
                  cos,
                  perspectiveScale
                };
              }

              readonly property var visual: {
                const abs = metrics.abs;
                const isCenter = abs < 0.5;
                return {
                  scale: metrics.perspectiveScale * (0.85 + metrics.cos * 0.15) + (isCenter ? 0.06 : 0),
                  opacity: abs > 6 ? 0 : Math.pow(Math.max(0, 1 - abs * 0.12), 2.5),
                  rotationY: metrics.raw * -appConfig.carouselRotation,
                  z: 100 - abs * 50,
                  spacingFactor: 0.45 + metrics.cos * 0.35,
                  yOffset: abs * 8,
                  shadowOpacity: abs < 0.6 ? 0.25 : 0
                };
              }

              width: pathViewContainer.itemWidth
              height: pathViewContainer.itemHeight
              x: pathViewContainer.centerX - width / 2 + metrics.raw * (width + pathViewContainer.spacing) * visual.spacingFactor
              y: pathViewContainer.centerY - height / 2 + visual.yOffset
              scale: visual.scale
              opacity: visual.opacity
              z: visual.z
              transformOrigin: Item.Center

              transform: [
                Rotation {
                  axis {
                    x: 0
                    y: 1
                    z: 0
                  }
                  angle: visual.rotationY
                  origin.x: width / 2
                  origin.y: height / 2
                }
              ]

              Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                anchors.topMargin: 12
                radius: 12
                color: "#000000"
                opacity: visual.shadowOpacity && appConfig.showShadow ? visual.shadowOpacity : 0
                z: -1
              }

              ShaderEffect {
                id: borderGlow
                anchors.fill: parent
                z: 4
                property bool useShaderBorder: appConfig.showBorderGlow
                visible: Math.abs(metrics.raw) < 0.5 && useShaderBorder

                property real time: 0
                property real innerWidth: width
                property real innerHeight: height
                property real innerRadius: 12

                NumberAnimation on time {
                  from: 0
                  to: 1000
                  duration: 30000
                  loops: Animation.Infinite
                  running: Math.abs(metrics.raw) < 0.1 && borderGlow.useShaderBorder
                }

                fragmentShader: Qt.resolvedUrl("shaders/borderGlow.frag.qsb")
              }

              Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                color: "transparent"
                radius: 12
                border.color: (Math.abs(metrics.raw) < 0.5 && !borderGlow.useShaderBorder) ? "#6a9eff" : "transparent"
                border.width: 2

                Rectangle {
                  id: imageFrame
                  anchors.fill: parent
                  anchors.margins: 3
                  radius: 8
                  color: "#111111aa"
                  clip: true
                  layer.enabled: true
                  layer.smooth: true
                  layer.mipmap: true

                  Item {
                    anchors.fill: parent
                    anchors.margins: Math.abs(metrics.raw) < 0.5 ? Math.ceil(imageFrame.radius * 0.3) : 0

                    Rectangle {
                      anchors.fill: parent
                      color: "#1a1a1a"
                      visible: !delegateItem.isVideo && !delegateItem.isGif && imageItem.status !== Image.Ready
                    }

                    AnimatedImage {
                      id: animatedGif
                      anchors.fill: parent
                      visible: (delegateItem.isGif || delegateItem.isVideo) && realIndex === root.centerIndex
                      source: {
                        if (!delegateItem.isGif && !delegateItem.isVideo)
                        return "";
                        const path = delegateItem.wallpaperPath;
                        if (!path || path.length === 0 || path.endsWith('/'))
                        return "";
                        const cachedAnim = CacheUtils.getCachedAnimatedGif(cacheManager.thumbHashToPath, path);
                        if (cachedAnim)
                        return "file://" + cachedAnim;
                        return "";
                      }
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                      smooth: true
                      mipmap: true
                      scale: 1.0
                      playing: visible
                      sourceSize: Qt.size(appConfig.carouselItemWidth * screen.devicePixelRatio, appConfig.carouselItemHeight * screen.devicePixelRatio)
                    }

                    Image {
                      id: imageItem
                      anchors.fill: parent
                      property var _cacheVer: cacheManager.thumbCacheVersion
                      property string currentThumb: {
                        const _v = _cacheVer;
                        return CacheUtils.getCachedThumb(cacheManager.thumbHashToPath, delegateItem.wallpaperPath);
                      }
                      source: {
                        const path = delegateItem.wallpaperPath;
                        if (!path || path.length === 0 || path.endsWith('/'))
                        return "";
                        if ((delegateItem.isGif || delegateItem.isVideo) && realIndex === root.centerIndex && animatedGif.status === AnimatedImage.Ready && animatedGif.visible)
                        return "";
                        if (currentThumb)
                        return "file://" + currentThumb;
                        if (delegateItem.isVideo)
                        return "";
                        return "file://" + path;
                      }
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                      smooth: realIndex === root.centerIndex
                      mipmap: true
                      opacity: status === Image.Ready ? 1 : 0
                      sourceSize: Qt.size(appConfig.carouselItemWidth * screen.devicePixelRatio, appConfig.carouselItemHeight * screen.devicePixelRatio)
                      scale: 1.0

                      Component.onCompleted: {
                        if (delegateItem.wallpaperPath && !currentThumb) {
                          cacheManager.queueThumbnail(delegateItem.wallpaperPath, delegateItem.isVideo, delegateItem.isGif);
                        }
                      }
                    }

                    Text {
                      anchors.centerIn: parent
                      text: "🎬"
                      font.pixelSize: 48
                      visible: (delegateItem.isVideo || delegateItem.isGif) && realIndex !== root.centerIndex && imageItem.status !== Image.Ready
                    }

                    MouseArea {
                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: {
                        if (root.debugMode)
                        console.log("[npaper] Mouse click on index", realIndex, ":", delegateItem.wallpaperPath);
                        setScrollIndex(realIndex);
                        Qt.callLater(() => applyWallpaper(delegateItem.wallpaperPath));
                      }
                    }
                  }

                  Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 8
                    height: 24
                    color: "#00000055"
                    radius: 6
                    opacity: Math.max(0, 1 - metrics.abs)
                    visible: opacity > 0.1
                    Text {
                      anchors.centerIn: parent
                      text: delegateItem.filename
                      color: "white"
                      font.pixelSize: 12
                      elide: Text.ElideMiddle
                      style: Text.Outline
                      styleColor: "black"
                    }
                  }
                }
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

          Text {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.bottomMargin: 20
            text: (root.activeFolder ? root.activeFolder + " · " : "") + root.count + " wallpapers | cache: " + cacheManager.cachedFileCount + " | queue: " + (cacheManager.queueLength + cacheManager.thumbnailJobRunning)
            color: "#666666"
            font.pixelSize: 11
          }

          Keys.onPressed: event => {
            if (event.key === Qt.Key_Backspace) {
              if (root.searchText) {
                root.searchText = root.searchText.slice(0, -1);
                if (root.debugMode)
                console.log("[npaper] Search:", root.searchText);
                searchDebounce.restart();
              }
              event.accepted = true;
              return;
            }

            if (event.key === Qt.Key_Escape) {
              if (root.debugMode)
              console.log("[npaper] Exit triggered");
              Qt.quit();
              event.accepted = true;
              return;
            }

            if (event.key === Qt.Key_Tab) {
              const idx = root.folderList.indexOf(root.activeFolder);
              if (root.folderList.length > 0) {
                const next = idx < root.folderList.length - 1 ? idx + 1 : 0;
                switchFolder(root.folderList[next]);
              }
              event.accepted = true;
              return;
            }
            if (event.key === Qt.Key_Backtab) {
              const idx = root.folderList.indexOf(root.activeFolder);
              if (root.folderList.length > 0) {
                const next = idx > 0 ? idx - 1 : root.folderList.length - 1;
                switchFolder(root.folderList[next]);
              }
              event.accepted = true;
              return;
            }

            if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BraceLeft) {
              const idx = root.folderList.indexOf(root.activeFolder);
              if (idx > 0) {
                switchFolder(root.folderList[idx - 1]);
              } else if (root.folderList.length > 0) {
                switchFolder(root.folderList[root.folderList.length - 1]);
              }
              event.accepted = true;
              return;
            }
            if (event.key === Qt.Key_BracketRight || event.key === Qt.Key_BraceRight) {
              const idx = root.folderList.indexOf(root.activeFolder);
              if (idx >= 0 && idx < root.folderList.length - 1) {
                switchFolder(root.folderList[idx + 1]);
              } else if (root.folderList.length > 0) {
                switchFolder(root.folderList[0]);
              }
              event.accepted = true;
              return;
            }

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              if (root.count > 0) {
                const idx = Math.round(root.scrollIndex);
                const path = root.filteredWallpaperList[((idx % root.count) + root.count) % root.count];
                if (root.debugMode)
                console.log("[npaper] Enter pressed - applying wallpaper at index", idx);
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

              if (root.debugMode)
              console.log("[npaper] Navigation - direction:", direction, "step:", step);

              if (keyScrollDirection !== direction) {
                keyScrollDirection = direction;
                keyScrollStep = step;
                isKeyScrolling = true;
                scrollContinueTimer.stop();
                const maxIdx = root.filteredWallpaperList.length - 1;
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
              if (root.debugMode)
              console.log("[npaper] Search input:", root.searchText);
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

      function applyWallpaper(path) {
        if (root.debugMode)
          console.log("[npaper] applyWallpaper:", path);
        const scriptPath = Qt.resolvedUrl("./wallpaper.sh").toString().slice(7);
        const cmd = [
          "bash", "-c",
          '"$1" --apply "$2" || notify-send -u critical "npaper" "Failed to apply wallpaper: $2"',
          "npaper-apply",
          scriptPath,
          path
        ];
        Quickshell.execDetached(cmd);
        Qt.quit();
      }
    }
  }
}
