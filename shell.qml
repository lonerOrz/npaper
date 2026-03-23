pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: root
      property var modelData
      screen: modelData

      implicitWidth: screen.width
      implicitHeight: screen.height
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

      // ========== Data ==========
      property var wallpaperList: []
      property var wallpaperListLower: []  // Cached lowercase for search
      property var wallpaperFilenames: []  // Cached filenames
      property var filteredWallpaperList: []
      property var filteredFilenames: []
      property string searchText: ""

      // ========== Thumbnail Cache ==========
      readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/wallpaper_thumbs"
      property bool hasFfmpeg: false
      property var thumbHashToPath: ({})  // hash -> "file:///cache/path.png"
      property int thumbCacheVersion: 0
      property int cachedFileCount: 0

      property int baseIndex: 0
      property int loadedCount: 0
      readonly property int count: filteredWallpaperList.length
      property real scrollIndex: 0
      property real visualScroll: 0  // Smooth scroll visualization

      readonly property int visibleRange: 4
      readonly property int preloadRange: 2

      // Smooth scroll animation for visualScroll
      Behavior on visualScroll {
        NumberAnimation {
          duration: 200
          easing.type: Easing.OutCubic
        }
      }

      // Sync visualScroll with scrollIndex (no animation on scrollIndex itself)
      onScrollIndexChanged: {
        visualScroll = scrollIndex;
        const c = Math.round(root.scrollIndex);
        if (c !== root.centerIndex) {
          console.log("[shell.qml] Scroll index changed: center", root.centerIndex, "->", c);
          root.bgIndexB = root.bgIndexA;
          root.bgIndexA = c;
          root.bgOpacity = 0;
          bgFadeIn.restart();
          root.centerIndex = c;
          // Extract dominant color from new wallpaper
          if (c >= 0 && c < root.filteredWallpaperList.length) {
            extractDominantColor(root.filteredWallpaperList[c]);
          }
        }
        updateVisibleRange();
      }

      // Background crossfade ( dual buffer)
      property int bgIndexA: -1
      property int bgIndexB: -1
      property real bgOpacity: 1.0

      // Dominant color extraction for logo
      property string dominantColor: "#6a9eff"  // Default blue
      property bool hasImagemagick: false

      // ========== Helper Functions (must be defined before use) ==========
      Component.onCompleted: {
        console.log("[shell.qml] Component.onCompleted - Initializing wallpaper selector");
        console.log("[shell.qml] Screen:", screen.width, "x", screen.height);
        createCacheDirProcess.exec({});
        initThumbnailWorkers();
      }

      // ========== Init Processes ==========
      Process {
        id: checkImagemagick
        command: ["sh", "-c", "command -v magick >/dev/null 2>&1 && echo OK"]
        stdout: StdioCollector {
          onStreamFinished: {
            root.hasImagemagick = text.trim() === "OK";
            console.log("[shell.qml] ImageMagick check:", text.trim(), "hasImagemagick:", root.hasImagemagick);
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
            console.log("[shell.qml] ffmpeg check:", text.trim(), "hasFfmpeg:", root.hasFfmpeg);
            scanCacheProcess.exec({});
          }
        }
        running: true
      }

      Process {
        id: createCacheDirProcess
        command: ["mkdir", "-p", root.cacheDir]
      }

      Process {
        id: scanCacheProcess
        command: ["sh", "-c", `find "${root.cacheDir}" -maxdepth 1 \\( -name '*.png' -o -name '*_anim.gif' \\) -printf '%f\\n' 2>/dev/null`]
        stdout: StdioCollector {
          onStreamFinished: {
            const files = text.trim().split('\n').filter(f => f.length > 0 && (f.endsWith('.png') || f.endsWith('_anim.gif')));
            files.forEach(f => {
              if (f.endsWith('_anim.gif')) {
                const hash = f.replace('_anim.gif', '');
                root.thumbHashToPath[hash + '_anim.gif'] = "file://" + root.cacheDir + '/' + f;
              } else if (f.endsWith('_bg.png')) {
                // Background preview (1920x1080)
                const hash = f.replace('_bg.png', '');
                root.thumbHashToPath[hash + '_bg.png'] = "file://" + root.cacheDir + '/' + f;
              } else {
                const hash = f.replace('.png', '');
                root.thumbHashToPath[hash] = "file://" + root.cacheDir + '/' + f;
              }
            });
            root.cachedFileCount = files.length;
            console.log("[shell.qml] Cache scanned:", files.length, "files, hash map size:", Object.keys(root.thumbHashToPath).length);
            listProcess.exec({});
          }
        }
      }

      Process {
        id: listProcess
        command: [Qt.resolvedUrl("./wallpaper.sh"), "--list"]
        stdout: StdioCollector {
          onStreamFinished: {
            const wallList = text.trim().split('\n').filter(path => path.length > 0);
            root.wallpaperList = wallList;
            root.wallpaperListLower = wallList.map(p => p.toLowerCase());
            // Pre-compute filenames to avoid repeated split() in delegate
            root.wallpaperFilenames = wallList.map(p => p.split('/').pop());
            root.filteredWallpaperList = wallList;
            root.filteredFilenames = root.wallpaperFilenames;
            root.scrollIndex = 0;
            root.centerIndex = 0;
            root.bgIndexA = 0;
            root.bgOpacity = 1.0;
            console.log("[shell.qml] Wallpaper list loaded:", wallList.length, "wallpapers");
            // Extract color from first wallpaper
            if (wallList.length > 0) {
              extractDominantColor(wallList[0]);
            }
            updateVisibleRange();
          }
        }
      }

      // ========== Cache Refresh ==========
      Process {
        id: cleanupCacheProcess
        command: ["rm", "-f"]
        onExited: function (exitCode, exitStatus) {
          console.log("[Cache] Cleanup:", exitCode === 0 ? "OK" : "Failed");
        }
      }

      Process {
        id: refreshCacheProcess
        command: ["sh", "-c", `find "${root.cacheDir}" -maxdepth 1 \\( -name '*.png' -o -name '*_anim.gif' \\) -printf '%f\\n' 2>/dev/null`]
        stdout: StdioCollector {
          onStreamFinished: {
            const files = text.trim().split('\n').filter(f => f.length > 0 && (f.endsWith('.png') || f.endsWith('_anim.gif')));
            // Build valid hash set
            const validHashes = {};
            root.wallpaperList.forEach(path => {
              validHashes[getThumbnailHash(path)] = true;
            });
            // Find invalid cache files
            const invalidFiles = [];
            files.forEach(f => {
              let hash;
              if (f.endsWith('_anim.gif')) {
                hash = f.replace('_anim.gif', '');
              } else if (f.endsWith('_bg.png')) {
                hash = f.replace('_bg.png', '');
              } else {
                hash = f.replace('.png', '');
              }
              if (!validHashes[hash]) {
                invalidFiles.push(root.cacheDir + "/" + f);
              }
            });
            // Remove invalid cache files
            if (invalidFiles.length > 0) {
              cleanupCacheProcess.command = ["rm", "-f", ...invalidFiles];
              cleanupCacheProcess.exec({});
              console.log("[Cache] Removing", invalidFiles.length, "invalid files");
              // Remove from memory
              invalidFiles.forEach(f => {
                const fname = f.split('/').pop();
                let hash;
                if (fname.endsWith('_anim.gif')) {
                  hash = fname.replace('_anim.gif', '');
                  delete root.thumbHashToPath[hash + '_anim.gif'];
                } else if (fname.endsWith('_bg.png')) {
                  hash = fname.replace('_bg.png', '');
                  delete root.thumbHashToPath[hash + '_bg.png'];
                } else {
                  hash = fname.replace('.png', '');
                  delete root.thumbHashToPath[hash];
                }
              });
              root.cachedFileCount = Math.max(0, root.cachedFileCount - invalidFiles.length);
              root.thumbCacheVersion++;
            } else {
              console.log("[Cache] All cached files are valid");
            }
          }
        }
      }

      function refreshCache() {
        console.log("[Cache] Refreshing...");
        refreshCacheProcess.exec({});
      }

      // ========== Thumbnail Queue ==========
      property var thumbnailQueue: []
      property int thumbnailJobRunning: 0  // Count of running jobs
      readonly property int thumbnailQueueMax: 50  // Queue size limit
      readonly property int thumbnailConcurrency: 2  // Max parallel ffmpeg jobs (2 for stability)
      property var thumbnailWorkers: []  // Array of Process objects
      property var queuedSet: ({})  // Set of paths already queued or processing (O(1) lookup)

      function initThumbnailWorkers() {
        var workers = [];
        for (let i = 0; i < root.thumbnailConcurrency; i++) {
          workers.push(thumbWorkerComponent.createObject(root, {
                                                           _workerId: i
                                                         }));
        }
        root.thumbnailWorkers = workers;
      }

      // Worker component for concurrent thumbnail generation
      Component {
        id: thumbWorkerComponent
        Process {
          property int _workerId: 0
          property string _targetPath: ""
          property string _thumbPath: ""
          property string _bgPath: ""
          property string _animPath: ""
          property var _ssArgs: []
          property int _step: 0  // 0=none, 1=bg done, 2=anim done
          property bool _needBg: false
          property bool _needAnim: false
          property bool busy: false
          onExited: function (exitCode, exitStatus) {
            root.thumbnailJobRunning--;
            const path = _targetPath;
            const thumbPath = _thumbPath;
            const bgPath = _bgPath;
            const animPath = _animPath;
            const step = _step;
            
            if (exitCode === 0) {
              const hash = getThumbnailHash(path);
              
              // Step-based processing for multi-pass generation
              if (_needAnim && step === 1) {
                // Background done, now generate animated preview
                _step = 2;
                busy = true;
                root.thumbnailJobRunning++;
                command = [
                  "ffmpeg", "-y",
                  ..._ssArgs,
                  "-i", path,
                  "-r", "30",
                  "-vf", "scale=450:320:force_original_aspect_ratio=increase,crop=450:320",
                  "-t", "10",
                  animPath
                ];
                exec({});
                return;  // Don't clear state yet
              } else if (_needBg && step === 0) {
                // Thumbnail done, now generate background preview
                _step = 1;
                _needBg = false;
                busy = true;
                root.thumbnailJobRunning++;
                command = [
                  "ffmpeg", "-y",
                  "-i", path,
                  "-vframes", "1",
                  "-vf", "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080",
                  "-q:v", "2",
                  bgPath
                ];
                exec({});
                return;  // Don't clear state yet
              }
              
              // All done - store the generated files
              if (animPath) {
                root.thumbHashToPath[hash + '_anim.gif'] = "file://" + animPath;
                console.log("[shell.qml] Generated animated GIF:", animPath, "(worker", _workerId + ")");
              }
              if (thumbPath && !thumbPath.endsWith('.gif')) {
                root.thumbHashToPath[hash] = "file://" + thumbPath;
                console.log("[shell.qml] Generated thumbnail:", thumbPath, "(worker", _workerId + ")");
              }
              if (bgPath) {
                root.thumbHashToPath[hash + '_bg.png'] = "file://" + bgPath;
                console.log("[shell.qml] Generated background preview:", bgPath, "(worker", _workerId + ")");
              }
              root.thumbCacheVersion++;
              root.cachedFileCount++;
            } else {
              console.log("[shell.qml] Failed:", path, "exitCode:", exitCode, "worker:", _workerId, "step:", step);
            }
            
            // Clear state
            busy = false;
            _targetPath = "";
            _thumbPath = "";
            _bgPath = "";
            _animPath = "";
            _ssArgs = [];
            _step = 0;
            _needBg = false;
            _needAnim = false;
            delete root.queuedSet[path];
            processThumbnailQueue();
          }
        }
      }

      function getThumbnailHash(wallpaperPath) {
        // Use MD5-like hash for short, unique filenames
        // djb2 algorithm with path length
        let h = 5381;
        for (let i = 0; i < wallpaperPath.length; i++) {
          h = ((h << 5) + h + wallpaperPath.charCodeAt(i)) | 0;
        }
        return Math.abs(h).toString(36) + "_" + (wallpaperPath.length & 0xFF);
      }

      function getThumbnailPath(wallpaperPath) {
        return root.cacheDir + '/' + getThumbnailHash(wallpaperPath) + '.png';
      }

      function getBackgroundPreviewPath(wallpaperPath) {
        // Return cached background preview (1920x1080) for video/GIF
        if (!wallpaperPath || wallpaperPath.length === 0 || wallpaperPath.endsWith('/'))
          return "";
        const hash = getThumbnailHash(wallpaperPath);
        return root.thumbHashToPath[hash + '_bg.png'] || "";
      }

      function getCachedAnimatedGif(wallpaperPath) {
        // Check if animated preview exists in cache
        if (!wallpaperPath || wallpaperPath.length === 0 || wallpaperPath.endsWith('/'))
          return "";
        const hash = getThumbnailHash(wallpaperPath);
        const animFile = hash + '_anim.gif';
        // Check if we have this in our cache map
        const cached = root.thumbHashToPath[animFile];
        return cached || "";
      }

      function getCachedThumb(wallpaperPath) {
        if (!wallpaperPath || wallpaperPath.length === 0 || wallpaperPath.endsWith('/'))
          return "";
        const hash = getThumbnailHash(wallpaperPath);
        return root.thumbHashToPath[hash] || "";
      }

      function isVideoFile(path) {
        if (!path || path.length === 0 || path.endsWith('/')) return false;
        const lower = path.toLowerCase();
        return lower.endsWith('.mp4') || lower.endsWith('.mkv') || lower.endsWith('.mov') || lower.endsWith('.webm');
      }

      function isGifFile(path) {
        if (!path || path.length === 0 || path.endsWith('/')) return false;
        return path.toLowerCase().endsWith('.gif');
      }

      function queueThumbnail(wallpaperPath, isVideo) {
        if (!wallpaperPath || wallpaperPath.length === 0 || wallpaperPath.endsWith('/'))
          return;
        const isG = isGifFile(wallpaperPath);
        // For GIF files, check if animated preview exists
        if (isG) {
          const cachedAnim = getCachedAnimatedGif(wallpaperPath);
          if (cachedAnim) {
            console.log("[queueThumbnail] GIF already has anim cache:", wallpaperPath);
            return;
          }
          // Check if already queued for anim generation
          if (root.queuedSet[wallpaperPath]) {
            console.log("[queueThumbnail] GIF already queued:", wallpaperPath);
            return;
          }
        } else if (isVideo) {
          // For video files, check if animated preview exists
          const cachedAnim = getCachedAnimatedGif(wallpaperPath);
          if (cachedAnim) {
            console.log("[queueThumbnail] Video already has anim cache:", wallpaperPath);
            return;
          }
          // Check if already queued for anim generation
          if (root.queuedSet[wallpaperPath]) {
            console.log("[queueThumbnail] Video already queued:", wallpaperPath);
            return;
          }
        } else {
          // For non-GIF, non-video files, use existing static thumbnail cache logic
          const cached = getCachedThumb(wallpaperPath);
          if (cached) {
            return;
          }
          // O(1) duplicate check
          if (root.queuedSet[wallpaperPath])
            return;
        }

        // Queue full: remove oldest
        if (root.thumbnailQueue.length >= root.thumbnailQueueMax) {
          const removed = root.thumbnailQueue.shift();
          delete root.queuedSet[removed.path];
        }

        root.queuedSet[wallpaperPath] = true;
        root.thumbnailQueue.push({
                                   path: wallpaperPath,
                                   hash: getThumbnailHash(wallpaperPath),
                                   isVideo: isVideo,
                                   isGif: isG
                                 });
        processThumbnailQueue();
      }

      function processThumbnailQueue() {
        if (!root.hasFfmpeg) {
          console.log("[shell.qml] No ffmpeg, clearing queue");
          root.thumbnailQueue = [];
          return;
        }
        // Start as many concurrent jobs as allowed
        while (root.thumbnailJobRunning < root.thumbnailConcurrency && root.thumbnailQueue.length > 0) {
          const item = root.thumbnailQueue.shift();
          const thumbPath = getThumbnailPath(item.path);
          const hash = getThumbnailHash(item.path);
          const bgPath = root.cacheDir + '/' + hash + '_bg.png';  // Background preview (1920x1080)
          // Find an idle worker
          for (let i = 0; i < root.thumbnailWorkers.length; i++) {
            const worker = root.thumbnailWorkers[i];
            if (worker && !worker.busy) {
              worker.busy = true;
              worker._targetPath = item.path;
              worker._thumbPath = thumbPath;
              worker._bgPath = bgPath;
              // For GIF and video: generate animated preview (30fps, 450x320) + background preview (1920x1080)
              // For images: single frame thumbnail + background preview
              if (item.isGif || item.isVideo) {
                // Generate animated GIF preview (two passes)
                const animPath = root.cacheDir + '/' + hash + '_anim.gif';
                worker._thumbPath = animPath;  // Override output path
                worker._animPath = animPath;
                worker._ssArgs = item.isVideo ? ["-ss", "00:00:01"] : [];
                worker._step = 1;  // Start with background
                worker._needAnim = true;
                // First pass: background preview
                worker.command = [
                  "ffmpeg", "-y",
                  ...worker._ssArgs,
                  "-i", item.path,
                  "-vframes", "1",
                  "-vf", "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080",
                  "-q:v", "2",
                  bgPath
                ];
              } else {
                // Static image: generate thumbnail first, then background
                worker.command = [
                  "ffmpeg", "-y",
                  "-i", item.path,
                  "-vframes", "1",
                  "-vf", "scale=450:320:force_original_aspect_ratio=increase,crop=450:320",
                  "-q:v", "5",
                  "-update", "1",
                  thumbPath
                ];
                worker._needBg = true;  // Generate bg after thumbnail
              }
              root.thumbnailJobRunning++;
              console.log("[shell.qml] Queue:", item.path, "(worker", i + ")");
              worker.exec({});
              break;
            }
          }
        }
      }

      // ========== Virtualization ==========
      property int _lastCenter: -1

      function updateVisibleRange() {
        const center = Math.round(root.scrollIndex);
        // Only update if center changed (reduce queue checks by ~80%)
        if (center === root._lastCenter)
          return;
        root._lastCenter = center;

        const minIdx = Math.max(0, center - root.visibleRange - root.preloadRange);
        const maxIdx = Math.min(root.count - 1, center + root.visibleRange + root.preloadRange);
        root.baseIndex = minIdx;
        root.loadedCount = root.count > 0 ? Math.max(1, maxIdx - minIdx + 1) : 0;
        console.log("[shell.qml] Visible range updated: center=", center, "baseIndex=", minIdx, "loadedCount=", root.loadedCount);
        // Queue thumbnails for visible range
        for (let i = minIdx; i <= maxIdx && i < root.filteredWallpaperList.length; i++) {
          const path = root.filteredWallpaperList[i];
          queueThumbnail(path, isVideoFile(path));
        }
      }

      // ========== Scroll Helper ==========
      property int centerIndex: -1

      function setScrollIndex(v) {
        if (root.count === 0)
          return;
        const clamped = Math.max(0, Math.min(v, root.count - 1));
        if (clamped !== root.scrollIndex) {
          console.log("[shell.qml] setScrollIndex:", root.scrollIndex, "->", clamped);
          root.scrollIndex = clamped;
        }
      }

      // Smooth background crossfade animation
      PropertyAnimation {
        id: bgFadeIn
        target: root
        properties: "bgOpacity"
        from: 0
        to: 1.0
        duration: 260
        easing.type: Easing.InOutCubic
      }

      // ========== Search ==========
      property bool _searchPending: false

      function scheduleSearch() {
        if (root._searchPending)
          return;
        root._searchPending = true;
        Qt.callLater(performSearch);
      }

      function performSearch() {
        root._searchPending = false;
        const text = root.searchText;
        console.log("[shell.qml] performSearch:", text ? '"' + text + '"' : "(empty)");
        if (!text) {
          root.filteredWallpaperList = root.wallpaperList;
          root.filteredFilenames = root.wallpaperFilenames;
        } else {
          const lower = text.toLowerCase();
          // Single pass to reduce GC pressure (vs reduce + 2x map)
          const list = [];
          const names = [];
          for (let i = 0; i < root.wallpaperListLower.length; i++) {
            if (root.wallpaperListLower[i].includes(lower)) {
              list.push(root.wallpaperList[i]);
              names.push(root.wallpaperFilenames[i]);
            }
          }
          root.filteredWallpaperList = list;
          root.filteredFilenames = names;
          console.log("[shell.qml] Search results:", list.length, "matches");
        }
        root.scrollIndex = 0;
        root._lastCenter = -1;
        updateVisibleRange();
        // Extract color from first filtered result
        if (root.filteredWallpaperList.length > 0) {
          extractDominantColor(root.filteredWallpaperList[0]);
        }
      }

      Timer {
        id: searchDebounce
        interval: 150
        onTriggered: {
          scheduleSearch();
        }
      }

      // ========== Dominant Color Extraction ==========
      Process {
        id: extractColorProcess
        stdout: StdioCollector {
          onStreamFinished: {
            const output = text.trim();
            // Parse txt: output: "#F0ECE0  srgb(...)"
            const match = output.match(/#([0-9A-F]{6})/i);
            if (match) {
              root.dominantColor = "#" + match[1].toUpperCase();
              console.log("[shell.qml] Dominant color extracted:", root.dominantColor);
            } else {
              console.log("[shell.qml] Color extraction failed, got:", output);
            }
          }
        }
      }

      function extractDominantColor(wallpaperPath) {
        if (!root.hasImagemagick || !wallpaperPath || wallpaperPath.length === 0) {
          root.dominantColor = "#6a9eff";  // Default blue
          console.log("[shell.qml] Using default color (no imagemagick or invalid path)");
          return;
        }
        // Always use cached thumbnail if available (works for both images and videos)
        const cachedThumb = getCachedThumb(wallpaperPath);
        if (cachedThumb) {
          const sourcePath = cachedThumb.replace(/^file:\/\//, '');
          console.log("[shell.qml] Extracting color from thumbnail:", sourcePath);
          extractColorProcess.command = [
            "magick",
            sourcePath,
            "-resize", "1x1!",
            "-modulate", "100,180",
            "txt:"
          ];
          extractColorProcess.exec({});
          return;
        }
        // No thumbnail: skip video files (no cache yet)
        if (isVideoFile(wallpaperPath)) {
          root.dominantColor = "#6a9eff";
          console.log("[shell.qml] Skipping video (no thumbnail cached)");
          return;
        }
        // Use original image for non-video files
        console.log("[shell.qml] Extracting color from original:", wallpaperPath);
        const path = wallpaperPath.toLowerCase().endsWith('.gif') ? wallpaperPath + '[0]' : wallpaperPath;
        extractColorProcess.command = [
          "magick",
          path,
          "-resize", "1x1!",
          "-modulate", "100,180",
          "txt:"
        ];
        extractColorProcess.exec({});
      }

      // ========== UI ==========
      // Background layer (outside Layout to avoid z-order issues)
      // Dual buffer for crossfade - uses 1920x1080 preview for all types
      Image {
        id: bgImageA
        anchors.fill: parent
        z: -2
        visible: root.bgIndexA >= 0 && root.bgIndexA < root.filteredWallpaperList.length && root.bgOpacity > 0.01
        // Use 1920x1080 background preview for all types
        source: {
          if (root.bgIndexA < 0 || root.bgIndexA >= root.filteredWallpaperList.length)
            return "";
          const path = root.filteredWallpaperList[root.bgIndexA];
          const bgPreview = getBackgroundPreviewPath(path);
          if (bgPreview)
            return bgPreview;
          // Fallback: use original if no preview cached yet
          return "file://" + path;
        }
        fillMode: Image.PreserveAspectCrop
        opacity: root.bgOpacity * 0.85  // Increased for better visibility
        asynchronous: true
        smooth: true
        mipmap: true
        // Fixed source size for 1920x1080 preview
        sourceSize: Qt.size(1920, 1080)
        cache: true  // Enable caching to avoid reload
        scale: 1.0
      }

      Image {
        id: bgImageB
        anchors.fill: parent
        z: -2
        visible: root.bgIndexB >= 0 && root.bgIndexB < root.filteredWallpaperList.length && (1.0 - root.bgOpacity) > 0.01
        // Use 1920x1080 background preview for all types
        source: {
          if (root.bgIndexB < 0 || root.bgIndexB >= root.filteredWallpaperList.length)
            return "";
          const path = root.filteredWallpaperList[root.bgIndexB];
          const bgPreview = getBackgroundPreviewPath(path);
          if (bgPreview)
            return bgPreview;
          // Fallback: use original if no preview cached yet
          return "file://" + path;
        }
        fillMode: Image.PreserveAspectCrop
        opacity: (1.0 - root.bgOpacity) * 0.85  // Increased for better visibility
        asynchronous: true
        smooth: true
        mipmap: true
        sourceSize: Qt.size(Math.min(1920, screen.width), Math.min(1080, screen.height))
        cache: true  // Enable caching to avoid reload
        scale: 1.0
      }

      // Dark overlay to dim background (slightly darker for better contrast)
      Rectangle {
        anchors.fill: parent
        color: "#000000"  // Solid black background to block system desktop
        opacity: 0.55     // Balanced for visibility
        z: -1             // Behind everything
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
              property bool isVideo: isVideoFile(wallpaperPath)
              property bool isGif: isGifFile(wallpaperPath)

              property real rawDistance: realIndex - root.visualScroll
              property real absDist: Math.abs(rawDistance)
              // Opacity only (no visible property to avoid scene graph rebuild)
              property real itemOpacity: Math.max(0, 1 - absDist * 0.15)

              // Finder-style CoverFlow curves
              property real itemScale: 0.78 + Math.cos(Math.min(absDist, 3) * Math.PI / 6) * 0.22
              // Fixed z to avoid SceneGraph resorting every frame
              property real itemZ: -absDist * 30
              // Non-linear spacing: center wide, edges compressed
              property real spacingFactor: 0.45 + Math.cos(Math.min(absDist, 3) * Math.PI / 6) * 0.35
              property real xOffset: rawDistance * (width + pathViewContainer.spacing) * spacingFactor
              // Parallax Y offset
              property real yOffset: absDist * 8

              width: pathViewContainer.itemWidth
              height: pathViewContainer.itemHeight
              x: pathViewContainer.centerX - width / 2 + xOffset
              y: pathViewContainer.centerY - height / 2 + yOffset
              scale: itemScale
              opacity: itemOpacity
              z: itemZ
              transformOrigin: Item.Center

              // 3D rotation for coverflow effect (NO Behavior - follows visualScroll directly)
              property real rotationY: rawDistance * -40

              transform: Rotation {
                axis {
                  x: 0
                  y: 1
                  z: 0
                }
                angle: rotationY
                origin.x: width / 2
                origin.y: height / 2
              }

              // Center card shadow (float effect) - simulated with Rectangle
              Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                anchors.topMargin: 12
                radius: 12
                color: "#000000"
                // Use opacity instead of visible to avoid SceneGraph rebuild
                opacity: absDist < 0.6 ? 0.25 : 0
                z: -1
              }

              // Fire border effect (behind the card, slightly larger)
              ShaderEffect {
                id: borderGlow
                anchors.fill: parent
                z: 4
                visible: Math.abs(rawDistance) < 0.5 && useShaderBorder

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
                border.color: (Math.abs(rawDistance) < 0.5 && !borderGlow.useShaderBorder) ? "#6a9eff" : "transparent"
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
                    anchors.margins: Math.abs(rawDistance) < 0.5 ? Math.ceil(imageFrame.radius * 0.3) : 0

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
                      // Only show on exact center card when GIF/video and animated preview exists
                      // Fix: Only evaluate source for actual GIF/video files to avoid binding loops
                      visible: (delegateItem.isGif || delegateItem.isVideo) && absDist < 0.1
                      source: {
                        if (!delegateItem.isGif && !delegateItem.isVideo)
                          return "";  // Never load for static images
                        const path = delegateItem.wallpaperPath;
                        if (!path || path.length === 0 || path.endsWith('/'))
                          return "";
                        // Use optimized animated preview (30fps)
                        return getCachedAnimatedGif(path);
                      }
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                      smooth: true
                      mipmap: true
                      scale: 1.0
                      playing: visible  // Only play when visible
                      // Limit source size for performance
                      sourceSize: Qt.size(450, 320)
                    }

                    Image {
                      id: imageItem
                      anchors.fill: parent
                      property string currentThumb: getCachedThumb(delegateItem.wallpaperPath)
                      // Use cached thumbnail, or original for static preview
                      source: {
                        const path = delegateItem.wallpaperPath;
                        if (!path || path.length === 0 || path.endsWith('/'))
                          return "";
                        // GIF/video: hide static image when animated version is ready and visible
                        if ((delegateItem.isGif || delegateItem.isVideo) && absDist < 0.1 && animatedGif.status === AnimatedImage.Ready && animatedGif.visible)
                          return "";
                        // Use cached thumbnail if available
                        if (currentThumb)
                          return currentThumb;
                        if (delegateItem.isVideo)
                          return "";
                        return "file://" + path;
                      }
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                      // Only smooth center card (GPU optimization)
                      smooth: absDist < 1.2
                      mipmap: true
                      opacity: status === Image.Ready ? 1 : 0
                      sourceSize: Qt.size(450, 320)
                      scale: 1.0  // Disable hover scaling

                      Component.onCompleted: {
                        if (delegateItem.wallpaperPath && !delegateItem.isVideo && !currentThumb) {
                          queueThumbnail(delegateItem.wallpaperPath, false);
                        }
                      }
                    }

                    // Show default icon for video/GIF when no thumbnail/animation cached
                    Text {
                      anchors.centerIn: parent
                      text: "🎬"
                      font.pixelSize: 48
                      // Hide when animated preview is ready and visible, or when static thumbnail is ready
                      visible: (delegateItem.isVideo || delegateItem.isGif) && imageItem.status !== Image.Ready && (animatedGif.status !== AnimatedImage.Ready || !animatedGif.visible)
                    }

                    MouseArea {
                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: {
                        console.log("[shell.qml] Mouse click on index", realIndex, ":", delegateItem.wallpaperPath);
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
                    opacity: Math.max(0, 1 - absDist)
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

          // NixOS Logo Watermark - SVG alpha as mask with dynamic color + glow
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
              colorizationColor: root.dominantColor  // Dynamic color from wallpaper
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
            text: "←/→ Navigate  |  Enter Apply  |  F5 Refresh  |  Shift+←/→ Fast Scroll  |  Type to Search  |  Esc Quit"
            color: "#888888"
            font.pixelSize: 11
            style: Text.Outline
            styleColor: "#000000"
          }

          Text {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.bottomMargin: 20
            text: root.count + " wallpapers | cache: " + root.cachedFileCount
            color: "#666666"
            font.pixelSize: 11
          }

          Keys.onPressed: event => {
            // 1. Backspace (search)
            if (event.key === Qt.Key_Backspace) {
              if (root.searchText) {
                root.searchText = root.searchText.slice(0, -1);
                console.log("[shell.qml] Search:", root.searchText);
                searchDebounce.restart();
              }
              event.accepted = true;
              return;
            }
            // 2. Exit keys (must be before text input)
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Escape) {
              console.log("[shell.qml] Exit triggered");
              Qt.quit();
              event.accepted = true;
              return;
            }
            // 3. Navigation
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              if (root.count > 0) {
                const idx = Math.round(root.scrollIndex);
                const path = root.filteredWallpaperList[((idx % root.count) + root.count) % root.count];
                console.log("[shell.qml] Enter pressed - applying wallpaper at index", idx);
                applyWallpaper(path);
              }
              event.accepted = true;
              return;
            }
            // 4. Refresh cache (F5)
            if (event.key === Qt.Key_F5) {
              refreshCache();
              event.accepted = true;
              return;
            }
            if (event.key === Qt.Key_Left) {
              const step = (event.modifiers & Qt.ShiftModifier) ? 5 : 1;
              console.log("[shell.qml] Left arrow - step", step);
              setScrollIndex(Math.round(root.scrollIndex) - step);
              event.accepted = true;
              return;
            }
            if (event.key === Qt.Key_Right) {
              const step = (event.modifiers & Qt.ShiftModifier) ? 5 : 1;
              console.log("[shell.qml] Right arrow - step", step);
              setScrollIndex(Math.round(root.scrollIndex) + step);
              event.accepted = true;
              return;
            }
            // 4. Character input (for search) - must be last
            if (event.text && event.text.length === 1 && !event.modifiers) {
              root.searchText += event.text;
              console.log("[shell.qml] Search input:", root.searchText);
              searchDebounce.restart();
              event.accepted = true;
            }
          }
        }
      }

      function applyWallpaper(path) {
        console.log("[shell.qml] applyWallpaper:", path);
        Quickshell.execDetached(["bash", Qt.resolvedUrl("./wallpaper.sh").toString().slice(7), "--apply", path]);
        Qt.quit();
      }
    }
  }
}
