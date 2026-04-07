import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/CacheUtils.js" as CacheHelpers
import "../utils/FileTypes.js" as FileTypes
import "../utils/HashUtils.js" as HashUtils
import qs.services

Item {
  id: root

  property string cacheDir: ""
  property bool hasFfmpeg: false
  property bool debugMode: false

  property int thumbWidth: 450
  property int thumbHeight: 320
  property int bgWidth: 1920
  property int bgHeight: 1080

  property var thumbHashToPath: ({})
  property int cachedFileCount: 0
  property int thumbCacheVersion: 0

  property var thumbnailQueue: []
  property var queuedSet: ({})
  property int queueLength: 0
  property int thumbnailJobRunning: 0

  readonly property int thumbnailQueueMax: 50
  readonly property int thumbnailConcurrency: 2
  property var thumbnailWorkers: []

  signal cacheScanned
  signal cacheRefreshed
  signal thumbnailGenerated(string path, string thumbPath, string bgPath, string animPath)

  // ── Cache directory creation ──────────────────────────────
  Process {
    id: createCacheDirProcess
    command: ["mkdir", "-p", root.cacheDir]
  }

  // ── Cache scanning ────────────────────────────────────────
  Process {
    id: scanCacheProcess
    command: ["sh", "-c", `find "${root.cacheDir}" -mindepth 2 -maxdepth 2 \\( -name '*.png' -o -name '*_anim.gif' \\) -printf '%P\\n' 2>/dev/null`]
    stdout: StdioCollector {
      onStreamFinished: {
        const files = text.trim().split('\n').filter(f => f.length > 0 && f.indexOf('/') > 0);
        files.forEach(f => {
          root.thumbHashToPath[f] = root.cacheDir + '/' + f;
        });
        root.cachedFileCount = files.length;
        root.thumbCacheVersion++;
        if (root.debugMode)
          Logger.d("Cache scanned:", files.length, "files");
        root.cacheScanned();
      }
    }
  }

  // ── Cache cleanup ─────────────────────────────────────────
  Process {
    id: cleanupCacheProcess
    command: ["rm", "-f"]
    onExited: function (exitCode) {
      if (root.debugMode)
        Logger.d("Cleanup:", exitCode === 0 ? "OK" : "Failed");
      root.cacheRefreshed();
    }
  }

  // ── Worker component ──────────────────────────────────────
  Component {
    id: thumbWorkerComponent
    Process {
      // ── Per-worker state ──
      property int _workerId: 0
      property string _path: ""       // source wallpaper path
      property string _thumbPath: ""  // output thumbnail
      property string _bgPath: ""     // output background preview
      property string _animPath: ""   // output animated gif
      property string _folder: ""     // folder name for cache keys
      property var _ssArgs: []        // ffmpeg seek args for video
      property int _step: 0           // current step index
      property bool busy: false

      // ── Step definitions (declarative) ──
      // Each step returns a command array or null (skip)
      function _buildCommand(step) {
        const tw = root.thumbWidth;
        const th = root.thumbHeight;
        const bw = root.bgWidth;
        const bh = root.bgHeight;
        const target = _path;

        if (!_path) return [];  // idle

        if (!_needAnim()) {
          // Static image: single ffmpeg with split filter (thumb + bg)
          return step === 0 ? [
            "ffmpeg", "-y", "-i", target, "-vframes", "1",
            "-filter_complex",
            `[0:v]split=2[a][b];[a]scale=${tw}:${th}:force_original_aspect_ratio=increase,crop=${tw}:${th}[thumb];[b]scale=${bw}:${bh}:force_original_aspect_ratio=increase,crop=${bw}:${bh}[bg]`,
            "-map", "[thumb]", "-q:v", "5", "-update", "1", _thumbPath,
            "-map", "[bg]", "-q:v", "2", _bgPath
          ] : [];
        }

        // Animated: multi-step
        switch (step) {
        case 0: // thumbnail frame
          return ["ffmpeg", "-y", ..._ssArgs, "-i", target, "-vframes", "1",
                  "-vf", `scale=${tw}:${th}:force_original_aspect_ratio=increase,crop=${tw}:${th}`,
                  "-q:v", "5", _thumbPath];
        case 1: // background frame
          return ["ffmpeg", "-y", ..._ssArgs, "-i", target, "-vframes", "1",
                  "-vf", `scale=${bw}:${bh}:force_original_aspect_ratio=increase,crop=${bw}:${bh}`,
                  "-q:v", "2", _bgPath];
        case 2: // animated gif
          return ["ffmpeg", "-y", ..._ssArgs, "-i", target, "-r", "30",
                  "-vf", `scale=${tw}:${th}:force_original_aspect_ratio=increase,crop=${tw}:${th}`,
                  "-t", "10", _animPath];
        default:
          return [];
        }
      }

      function _needAnim() {
        return _animPath !== "";
      }

      function _totalSteps() {
        return _needAnim() ? 3 : 1;
      }

      // ── Run current step ──
      function runNext() {
        if (_step >= _totalSteps()) {
          _finish();
          return;
        }
        command = _buildCommand(_step);
        if (command.length > 0) {
          exec({});
        } else {
          _step++;
          runNext();  // skip empty step
        }
      }

      // ── Step completed ──
      onExited: function (exitCode, exitStatus) {
        if (exitCode !== 0) {
          if (root.debugMode)
            Logger.d("Worker", _workerId, "failed at step", _step, ":", _path, "code:", exitCode);
          _reset();
          root.processQueue();
          return;
        }

        _step++;
        if (_step >= _totalSteps()) {
          _finish();
        } else {
          runNext();
        }
      }

      // ── All steps done ──
      function _finish() {
        root.thumbnailGenerated(_path, _thumbPath, _bgPath, _animPath);

        if (_thumbPath) {
          root.thumbHashToPath[_folder + '/' + HashUtils.getThumbnailHash(_path) + '.png'] = _thumbPath;
        }
        if (_bgPath) {
          root.thumbHashToPath[_folder + '/' + HashUtils.getThumbnailHash(_path) + '_bg.png'] = _bgPath;
        }
        if (_animPath) {
          root.thumbHashToPath[_folder + '/' + HashUtils.getThumbnailHash(_path) + '_anim.gif'] = _animPath;
        }
        root.thumbCacheVersion++;
        root.cachedFileCount++;

        _reset();
        root.processQueue();
      }

      // ── Reset worker state ──
      function _reset() {
        root.thumbnailJobRunning = Math.max(0, root.thumbnailJobRunning - 1);
        busy = false;
        delete root.queuedSet[_path];
        _path = "";
        _thumbPath = "";
        _bgPath = "";
        _animPath = "";
        _folder = "";
        _ssArgs = [];
        _step = 0;
      }

      // ── Initialize with item data ──
      function setup(item) {
        _path = item.path;
        _thumbPath = item.thumbPath;
        _bgPath = item.bgPath;
        _animPath = item.animPath;
        _folder = item.folder;
        _ssArgs = item.isVideo ? ["-ss", "00:00:01"] : [];
        _step = 0;
        busy = true;
        root.thumbnailJobRunning++;
      }
    }
  }

  // ── Public API ────────────────────────────────────────────

  function initialize() {
    if (root.thumbnailWorkers.length > 0) {
      Logger.d("CacheService already initialized");
      return;
    }
    createCacheDirProcess.exec({});
    initWorkers();
  }

  function initWorkers() {
    var workers = [];
    for (let i = 0; i < root.thumbnailConcurrency; i++) {
      workers.push(thumbWorkerComponent.createObject(root, { _workerId: i }));
    }
    root.thumbnailWorkers = workers;
    if (root.debugMode)
      Logger.d("Initialized", workers.length, "workers");
  }

  function scanCache() {
    scanCacheProcess.exec({});
  }

  function refreshAndQueue(wallpaperList, folder) {
    if (root.debugMode)
      Logger.d("Refreshing folder:", folder, "count:", wallpaperList.length);

    const validKeys = {};
    wallpaperList.forEach(path => {
      const hash = HashUtils.getThumbnailHash(path);
      validKeys[folder + '/' + hash + '.png'] = true;
      validKeys[folder + '/' + hash + '_bg.png'] = true;
      validKeys[folder + '/' + hash + '_anim.gif'] = true;
    });

    const invalidFiles = [];
    Object.keys(root.thumbHashToPath).forEach(key => {
      if (key.startsWith(folder + '/') && !validKeys[key]) {
        invalidFiles.push(root.thumbHashToPath[key]);
        delete root.thumbHashToPath[key];
      }
    });

    if (invalidFiles.length > 0) {
      root.cachedFileCount = Math.max(0, root.cachedFileCount - invalidFiles.length);
      root.thumbCacheVersion++;
      cleanupCacheProcess.command = ["rm", "-f", ...invalidFiles];
      cleanupCacheProcess.exec({});
      if (root.debugMode)
        Logger.d("Removed", invalidFiles.length, "invalid files from", folder);
    } else {
      root.cacheRefreshed();
    }

    wallpaperList.forEach(path => {
      queueThumbnail(path, FileTypes.isVideoFile(path), FileTypes.isGifFile(path));
    });
    if (root.debugMode)
      Logger.d("Queue length:", root.queueLength);
  }

  function queueThumbnail(wallpaperPath, isVideo, isGif) {
    if (!wallpaperPath || wallpaperPath.length === 0 || wallpaperPath.endsWith('/'))
      return;

    const isAnim = isVideo || isGif;
    if (isAnim) {
      if (CacheHelpers.getCachedAnimatedGif(root.thumbHashToPath, wallpaperPath))
        return;
    } else {
      if (CacheHelpers.getCachedThumb(root.thumbHashToPath, wallpaperPath))
        return;
    }
    if (root.queuedSet[wallpaperPath])
      return;

    if (root.thumbnailQueue.length >= root.thumbnailQueueMax) {
      const removed = root.thumbnailQueue.shift();
      delete root.queuedSet[removed.path];
    }

    root.queuedSet[wallpaperPath] = true;
    root.thumbnailQueue.push({
      path: wallpaperPath,
      hash: HashUtils.getThumbnailHash(wallpaperPath),
      isVideo: isVideo,
      isGif: isGif
    });
    root.queueLength = root.thumbnailQueue.length;

    processQueue();
  }

  function processQueue() {
    if (!root.hasFfmpeg) {
      root.thumbnailQueue = [];
      return;
    }

    while (root.thumbnailJobRunning < root.thumbnailConcurrency && root.thumbnailQueue.length > 0) {
      const item = root.thumbnailQueue.shift();
      root.queueLength = root.thumbnailQueue.length;

      const folder = CacheHelpers.getFolderName(item.path);
      const thumbPath = CacheHelpers.getThumbnailPath(root.cacheDir, item.path);
      const hash = HashUtils.getThumbnailHash(item.path);
      const bgPath = root.cacheDir + '/' + folder + '/' + hash + '_bg.png';
      const animPath = root.cacheDir + '/' + folder + '/' + hash + '_anim.gif';

      for (let i = 0; i < root.thumbnailWorkers.length; i++) {
        const worker = root.thumbnailWorkers[i];
        if (worker && !worker.busy) {
          worker.setup({
            path: item.path,
            thumbPath: thumbPath,
            bgPath: bgPath,
            animPath: item.isVideo || item.isGif ? animPath : "",
            folder: folder,
            isVideo: item.isVideo,
            isGif: item.isGif
          });
          worker.runNext();
          break;
        }
      }
    }
  }
}
