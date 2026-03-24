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
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: root
      property var modelData
      screen: modelData

      // Debug mode: set to true for verbose logging
      readonly property bool debugMode: false

      visible: true
      color: "transparent"

      // Fullscreen size
      implicitWidth: screen.width
      implicitHeight: screen.height

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      WlrLayershell.exclusiveZone: -1  // Cover entire screen, ignore waybar's reserved zone

      // Data
      property var wallpaperList: []
      property var wallpaperListLower: []
      property var wallpaperFilenames: []
      property var filteredWallpaperList: []
      property var filteredFilenames: []
      property string searchText: ""

      // Cache Manager
      readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/wallpaper_thumbs"
      property bool hasFfmpeg: false

      // Scroll & Virtualization
      property real scrollIndex: 0
      property real _cachedScrollIndex: 0  // Cached for delegate binding stability
      property real scrollVelocity: 0
      property real lastScrollIndex: 0
      property int scrollTimestamp: 0
      property real targetScrollIndex: 0  // Target for smooth scrolling
      readonly property int count: filteredWallpaperList.length
      readonly property int visibleRange: 4
      readonly property int preloadRange: 2

      // Smooth scrolling with Behavior
      Behavior on targetScrollIndex {
        NumberAnimation {
          duration: 350
          easing.type: Easing.OutCubic
        }
      }

      onTargetScrollIndexChanged: {
        scrollIndex = targetScrollIndex;
      }

      Component.onCompleted: {
        targetScrollIndex = 0;
        cacheManager.initialize();
      }

      // Debounce for background changes (prevent flicker during fast scroll)
      Timer {
        id: bgChangeDebounce
        interval: 5
        onTriggered: {
          const c = centerIndex;
          if (c !== bgCurrent && c >= 0 && c < root.filteredWallpaperList.length) {
            bgPrevious = bgCurrent;
            bgCurrent = c;
            // Reset and trigger slide animation
            bgSlideProgress = 0;
            bgSlideAnim.restart();
            // Extract dominant color for new wallpaper
            extractDominantColor(root.filteredWallpaperList[c]);
          }
        }
      }

      // Background slide animation (drives progress only)
      PropertyAnimation {
        id: bgSlideAnim
        target: root
        properties: "bgSlideProgress"
        from: 0
        to: 1.0
        duration: 250
        easing.type: Easing.OutCubic
      }

      // Background Crossfade
      property int bgCurrent: -1
      property int bgPrevious: -1
      property real bgSlideProgress: 0.0  // 0 = start, 1 = complete
      property string _bgSourceA: ""
      property string _bgSourceB: ""

      onBgCurrentChanged: {
        // Update background source immediately
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

      // Handle scroll changes
      onScrollIndexChanged: {
        // Sync cached value for stable delegate bindings
        _cachedScrollIndex = scrollIndex;

        // Calculate velocity for inertia
        const now = Date.now();
        const dt = now - scrollTimestamp;
        if (dt > 0 && dt < 200) {
          scrollVelocity = (scrollIndex - lastScrollIndex) / dt * 1000;
        }
        lastScrollIndex = scrollIndex;
        scrollTimestamp = now;

        // Restart debounce timer instead of immediate background change
        bgChangeDebounce.restart();

        // Queue thumbnails for visible range
        for (let i = baseIndex; i <= maxIndex && i < root.filteredWallpaperList.length; i++) {
          const path = root.filteredWallpaperList[i];
          cacheManager.queueThumbnail(path, FileTypes.isVideoFile(path), FileTypes.isGifFile(path));
        }
      }

      property string dominantColor: "#6a9eff"
      property bool hasImagemagick: false

      // Cache Manager Instance
      CacheManager {
        id: cacheManager
        cacheDir: root.cacheDir
        hasFfmpeg: root.hasFfmpeg
        debugMode: root.debugMode

        onCacheScanned: {
          listProcess.exec({});
        }

        onCacheRefreshed: {
          console.log("[npaper] Cache refresh completed");
        }

        onThumbnailGenerated: {}
      }

      // Init Processes
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
        id: listProcess
        command: [Qt.resolvedUrl("./wallpaper.sh"), "--list"]
        stdout: StdioCollector {
          onStreamFinished: {
            const wallList = text.trim().split('\n').filter(path => path.length > 0);
            root.wallpaperList = wallList;
            root.wallpaperListLower = wallList.map(p => p.toLowerCase());
            root.wallpaperFilenames = wallList.map(p => p.split('/').pop());
            root.filteredWallpaperList = wallList;
            root.filteredFilenames = root.wallpaperFilenames;
            root.scrollIndex = 0;
            root.bgCurrent = 0;
            root.bgSlideProgress = 1.0;  // Set to 1 for initial image (no animation)
            if (wallList.length > 0) {
              extractDominantColor(wallList[0]);
            }
          }
        }
        onExited: function (exitCode, exitStatus) {
          if (exitCode !== 0 && root.debugMode)
            console.log("[npaper] Wallpaper list failed, exitCode:", exitCode);
        }
      }

      // Cache Refresh via cacheManager
      function refreshCache() {
        console.log("[npaper] Refreshing...");
        cacheManager.refreshCache(root.wallpaperList);
      }

      // Scroll Helper
      function setScrollIndex(v) {
        if (root.count === 0)
          return;
        const clamped = Math.max(0, Math.min(v, root.count - 1));
        if (clamped !== root.targetScrollIndex) {
          if (root.debugMode)
            console.log("[npaper] setScrollIndex:", root.scrollIndex, "->", clamped);
          root.targetScrollIndex = clamped;
        }
      }

      // Smooth background crossfade (for initial load)
      PropertyAnimation {
        id: bgFadeIn
        target: root
        properties: "bgOpacity"
        from: 0
        to: 1.0
        duration: 400
        easing.type: Easing.InOutCubic
      }

      // Background parallax offset (separate from slide)
      readonly property real bgBaseParallaxX: (scrollIndex - centerIndex) * 40

      // Search
      property var _searchResults: []
      property var _searchNames: []

      Timer {
        id: searchDebounce
        interval: 150
        onTriggered: {
          const text = root.searchText;
          if (root.debugMode)
          console.log("[npaper] performSearch:", text ? '"' + text + '"' : "(empty)");
          if (!text) {
            root.filteredWallpaperList = root.wallpaperList;
            root.filteredFilenames = root.wallpaperFilenames;
            // Smooth scroll to start after clearing search
            targetScrollIndex = 0;
            bgCurrent = 0;
            bgSlideProgress = 1.0;
            if (root.filteredWallpaperList.length > 0) {
              extractDominantColor(root.filteredWallpaperList[0]);
            }
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

            // Reset scroll and background to first search result (instant, no animation on filter change)
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

      // Dominant Color Extraction
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
        extractColorTimeout.start();
        extractColorProcess.command = ["magick", sourcePath, "-resize", "1x1!", "-modulate", "100,180", "txt:"];
        extractColorProcess.exec({});
      }

      function randomWallpaper() {
        if (root.count > 0) {
          targetScrollIndex = Math.floor(Math.random() * root.count);
        }
      }

      // UI
      // Background Crossfade (dual buffer with slide effect)
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
        sourceSize: Qt.size(1920, 1080)
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
        sourceSize: Qt.size(Math.min(1920, screen.width), Math.min(1080, screen.height))
        cache: true
      }

      // Dark overlay to dim background
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
        z: 0              // Ensure UI is above background

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

          Repeater {
            id: imageRepeater
            model: root.loadedCount

            delegate: Item {
              id: delegateItem
              required property int index
              // Fix: use baseIndex for virtualization
              property int realIndex: root.baseIndex + index
              property string wallpaperPath: realIndex < root.filteredWallpaperList.length ? root.filteredWallpaperList[realIndex] : ""
              property string filename: realIndex < root.filteredFilenames.length ? root.filteredFilenames[realIndex] : ""
              property bool isVideo: FileTypes.isVideoFile(wallpaperPath)
              property bool isGif: FileTypes.isGifFile(wallpaperPath)

              // Precompute all metrics in one JS block (reduces binding churn)
              readonly property var metrics: {
                const raw = realIndex - root._cachedScrollIndex;
                const abs = Math.abs(raw);
                const cos = Math.cos(Math.min(abs, 3) * 0.523599);  // PI/6 ≈ 0.523599
                const perspectiveScale = 1.0 / (1.0 + abs * 0.3);
                return {
                  raw,
                  abs,
                  cos,
                  perspectiveScale
                };
              }

              // Unified visual properties (computed once, used everywhere)
              readonly property var visual: {
                const abs = metrics.abs;
                const isCenter = abs < 0.5;
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

              // Center card shadow (float effect)
              Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                anchors.topMargin: 12
                radius: 12
                color: "#000000"
                opacity: visual.shadowOpacity
                z: -1
              }

              // Fire border effect (behind the card, slightly larger)
              ShaderEffect {
                id: borderGlow
                anchors.fill: parent
                z: 4
                visible: Math.abs(metrics.raw) < 0.5 && useShaderBorder

                property real time: 0
                // Use ShaderEffect's actual width and height
                property real innerWidth: width
                property real innerHeight: height
                property real innerRadius: 12  // Match outer transparent Rectangle's radius
                property bool useShaderBorder: true

                NumberAnimation on time {
                  from: 0
                  to: 1000
                  duration: 30000
                  loops: Animation.Infinite
                  running: visible
                }

                fragmentShader: Qt.resolvedUrl("shaders/borderGlow.frag.qsb")
              }

              Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                color: "transparent"
                radius: 12
                // Center card glow effect - show QML border when shader border is disabled
                border.color: (Math.abs(metrics.raw) < 0.5 && !borderGlow.useShaderBorder) ? "#6a9eff" : "transparent"
                border.width: 2

                Rectangle {
                  id: imageFrame
                  anchors.fill: parent
                  anchors.margins: 3
                  radius: 8
                  color: "#111111aa"
                  clip: true
                  // Cache as texture for GPU-efficient transform
                  layer.enabled: true
                  layer.smooth: true
                  layer.mipmap: true

                  Item {
                    anchors.fill: parent
                    anchors.margins: Math.abs(metrics.raw) < 0.5 ? Math.ceil(imageFrame.radius * 0.3) : 0

                    // Fallback background for when no media is loaded
                    Rectangle {
                      anchors.fill: parent
                      color: "#1a1a1a"
                      visible: !delegateItem.isVideo && !delegateItem.isGif && imageItem.status !== Image.Ready
                    }

                    // AnimatedImage for center card only (uses optimized 30fps preview for GIF and video)
                    AnimatedImage {
                      id: animatedGif
                      anchors.fill: parent
                      // Only exact center card for GIF/video (single active decoder)
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
                      sourceSize: Qt.size(450, 320)
                    }

                    Image {
                      id: imageItem
                      anchors.fill: parent
                      property string currentThumb: CacheUtils.getCachedThumb(cacheManager.thumbHashToPath, delegateItem.wallpaperPath)
                      source: {
                        const path = delegateItem.wallpaperPath;
                        if (!path || path.length === 0 || path.endsWith('/'))
                        return "";
                        // GIF/video: hide static image when animated version is ready and visible
                        if ((delegateItem.isGif || delegateItem.isVideo) && realIndex === root.centerIndex && animatedGif.status === AnimatedImage.Ready && animatedGif.visible)
                        return "";
                        // Use cached thumbnail if available
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
                      sourceSize: Qt.size(450, 320)
                      scale: 1.0

                      Component.onCompleted: {
                        if (delegateItem.wallpaperPath && !delegateItem.isVideo && !currentThumb) {
                          cacheManager.queueThumbnail(delegateItem.wallpaperPath, false, false);
                        }
                      }
                    }

                    // Show default icon for video/GIF when no thumbnail/animation cached
                    Text {
                      anchors.centerIn: parent
                      text: "🎬"
                      font.pixelSize: 48
                      // Hide when animated preview is ready and visible, or when static thumbnail is ready
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
                    // Fade filename based on distance
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

          // NixOS Logo Watermark - SVG with dynamic color + glow
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
            }
          }

          // Keyboard shortcuts hint
          Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 25
            text: "←/→ Navigate  |  Enter Apply  |  R Random  |  F5 Refresh  |  Shift+←/→ Fast Scroll  |  Type to Search  |  Esc Quit"
            color: "#888888"
            font.pixelSize: 11
            style: Text.Outline
            styleColor: "#000000"
          }

          Text {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.bottomMargin: 20
            text: root.count + " wallpapers | cache: " + cacheManager.cachedFileCount
            color: "#666666"
            font.pixelSize: 11
          }

          Keys.onPressed: event => {
            // 1. Backspace (search)
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
            // 2. Exit keys
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Escape) {
              if (root.debugMode)
              console.log("[npaper] Exit triggered");
              Qt.quit();
              event.accepted = true;
              return;
            }
            // 3. Apply wallpaper
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
            // 4. Random wallpaper
            if (event.key === Qt.Key_R && !event.modifiers) {
              randomWallpaper();
              event.accepted = true;
              return;
            }
            // 5. Refresh cache
            if (event.key === Qt.Key_F5) {
              refreshCache();
              event.accepted = true;
              return;
            }
            // 6. Navigation
            if (event.key === Qt.Key_Left) {
              const step = (event.modifiers & Qt.ShiftModifier) ? 5 : 1;
              if (root.debugMode)
              console.log("[npaper] Left arrow - step", step);
              targetScrollIndex = Math.max(0, targetScrollIndex - step);
              event.accepted = true;
              return;
            }
            if (event.key === Qt.Key_Right) {
              const step = (event.modifiers & Qt.ShiftModifier) ? 5 : 1;
              if (root.debugMode)
              console.log("[npaper] Right arrow - step", step);
              // Use filtered list count for navigation
              const maxIdx = root.filteredWallpaperList.length > 0 ? root.filteredWallpaperList.length - 1 : 0;
              targetScrollIndex = Math.min(maxIdx, targetScrollIndex + step);
              event.accepted = true;
              return;
            }
            // 7. Search input
            if (event.text && event.text.length === 1 && !event.modifiers) {
              root.searchText += event.text;
              if (root.debugMode)
              console.log("[npaper] Search input:", root.searchText);
              searchDebounce.restart();
              event.accepted = true;
            }
          }
        }
      }

      function applyWallpaper(path) {
        if (root.debugMode)
          console.log("[npaper] applyWallpaper:", path);
        Quickshell.execDetached(["bash", Qt.resolvedUrl("./wallpaper.sh").toString().slice(7), "--apply", path]);
        Qt.quit();
      }
    }
  }
}
