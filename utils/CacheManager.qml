pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "CacheUtils.js" as CacheHelpers
import "FileTypes.js" as FileTypes
import "HashUtils.js" as HashUtils

Item {
  id: root

  property string cacheDir: ""
  property bool hasFfmpeg: false
  property bool debugMode: false

  property var thumbHashToPath: ({})
  property int cachedFileCount: 0
  property int thumbCacheVersion: 0
  property int queueLength: 0

  signal cacheScanned
  signal cacheRefreshed
  signal thumbnailGenerated(string path, string thumbPath, string bgPath, string animPath)

  property var thumbnailQueue: []
  property var queuedSet: ({})
  property int thumbnailJobRunning: 0

  readonly property int thumbnailQueueMax: 50
  readonly property int thumbnailConcurrency: 2
  property var thumbnailWorkers: []

  Process {
    id: createCacheDirProcess
    command: ["mkdir", "-p", root.cacheDir]
  }

  // Recursively scan subdirectories for cached files
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
        console.log("[npaper] Cache scanned:", files.length, "files");
        root.cacheScanned();
      }
    }
  }

  Process {
    id: cleanupCacheProcess
    command: ["rm", "-f"]
    onExited: function (exitCode, exitStatus) {
      if (root.debugMode)
        console.log("[npaper] Cleanup:", exitCode === 0 ? "OK" : "Failed");
      root.cacheRefreshed();
    }
  }

  Component {
    id: thumbWorkerComponent
    Process {
      property int _workerId: 0
      property string _targetPath: ""
      property string _thumbPath: ""
      property string _bgPath: ""
      property string _animPath: ""
      property string _folder: ""
      property var _ssArgs: []
      property int _step: 0
      property bool _needAnim: false
      property bool busy: false

      function runNext() {
        const hash = HashUtils.getThumbnailHash(_targetPath);
        if (_step === 0) {
          if (_needAnim) {
            command = ["ffmpeg", "-y", ..._ssArgs, "-i", _targetPath, "-vframes", "1", "-vf", "scale=450:320:force_original_aspect_ratio=increase,crop=450:320", "-q:v", "5", _thumbPath];
          } else {
            command = ["ffmpeg", "-y", "-i", _targetPath, "-vframes", "1", "-filter_complex", "[0:v]split=2[a][b];[a]scale=450:320:force_original_aspect_ratio=increase,crop=450:320[thumb];[b]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080[bg]", "-map", "[thumb]", "-q:v", "5", "-update", "1", _thumbPath, "-map", "[bg]", "-q:v", "2",
                       _bgPath];
          }
        } else if (_step === 1 && _needAnim) {
          command = ["ffmpeg", "-y", ..._ssArgs, "-i", _targetPath, "-r", "30", "-vf", "scale=450:320:force_original_aspect_ratio=increase,crop=450:320", "-t", "10", _animPath];
        }
        if (command.length > 0) {
          exec({});
        }
      }

      onExited: function (exitCode, exitStatus) {
        root.thumbnailJobRunning = Math.max(0, root.thumbnailJobRunning - 1);

        if (exitCode !== 0) {
          if (root.debugMode)
            console.log("[npaper] Failed:", _targetPath, "exitCode:", exitCode, "worker:", _workerId);
          busy = false;
          const failedPath = _targetPath;
          _targetPath = "";
          _thumbPath = "";
          _bgPath = "";
          _animPath = "";
          _folder = "";
          _ssArgs = [];
          _step = 0;
          _needAnim = false;
          delete root.queuedSet[failedPath];
          root.processQueue();
          return;
        }

        const hash = HashUtils.getThumbnailHash(_targetPath);
        _step++;

        if (_step === 1 && _needAnim) {
          busy = true;
          root.thumbnailJobRunning++;
          command = ["ffmpeg", "-y", ..._ssArgs, "-i", _targetPath, "-vframes", "1", "-vf", "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080", "-q:v", "2", _bgPath];
          exec({});
          return;
        }

        if (_step === 2 && _needAnim) {
          busy = true;
          root.thumbnailJobRunning++;
          command = ["ffmpeg", "-y", ..._ssArgs, "-i", _targetPath, "-r", "30", "-vf", "scale=450:320:force_original_aspect_ratio=increase,crop=450:320", "-t", "10", _animPath];
          exec({});
          return;
        }

        root.thumbnailGenerated(_targetPath, _thumbPath, _bgPath, _animPath);

        // Store with folder-prefixed keys matching scan format
        if (_thumbPath) {
          root.thumbHashToPath[_folder + '/' + hash + '.png'] = _thumbPath;
          if (root.debugMode)
            console.log("[npaper] Generated thumbnail:", _thumbPath);
        }
        if (_bgPath) {
          root.thumbHashToPath[_folder + '/' + hash + '_bg.png'] = _bgPath;
          if (root.debugMode)
            console.log("[npaper] Generated background:", _bgPath);
        }
        if (_animPath) {
          root.thumbHashToPath[_folder + '/' + hash + '_anim.gif'] = _animPath;
          if (root.debugMode)
            console.log("[npaper] Generated animated GIF:", _animPath);
        }
        root.thumbCacheVersion++;
        root.cachedFileCount++;

        busy = false;
        const completedPath = _targetPath;
        _targetPath = "";
        _thumbPath = "";
        _bgPath = "";
        _animPath = "";
        _folder = "";
        _ssArgs = [];
        _step = 0;
        _needAnim = false;
        delete root.queuedSet[completedPath];
        root.processQueue();
      }
    }
  }

  function initialize() {
    if (root.thumbnailWorkers && root.thumbnailWorkers.length > 0) {
      console.log("[npaper] CacheManager already initialized");
      return;
    }
    createCacheDirProcess.exec({});
    initWorkers();
  }

  function initWorkers() {
    var workers = [];
    for (let i = 0; i < root.thumbnailConcurrency; i++) {
      workers.push(thumbWorkerComponent.createObject(root, {
                                                       _workerId: i
                                                     }));
    }
    root.thumbnailWorkers = workers;
    if (root.debugMode)
      console.log("[npaper] Initialized", workers.length, "workers");
  }

  function scanCache() {
    scanCacheProcess.exec({});
  }

  function refreshCache(wallpaperList) {
    if (root.debugMode)
      console.log("[npaper] Refreshing cache for", wallpaperList.length, "wallpapers");

    // Build valid key set matching scan format (with suffix)
    const validKeys = {};
    wallpaperList.forEach(path => {
                            const folder = CacheHelpers.getFolderName(path);
                            const hash = HashUtils.getThumbnailHash(path);
                            validKeys[folder + '/' + hash + '.png'] = true;
                            validKeys[folder + '/' + hash + '_bg.png'] = true;
                            validKeys[folder + '/' + hash + '_anim.gif'] = true;
                          });

    const invalidFiles = [];
    Object.keys(root.thumbHashToPath).forEach(key => {
                                                if (!validKeys[key]) {
                                                  invalidFiles.push(root.thumbHashToPath[key]);
                                                }
                                              });

    if (invalidFiles.length > 0) {
      if (root.debugMode)
        console.log("[npaper] Removing", invalidFiles.length, "invalid files");
      invalidFiles.forEach(f => {
                             // Remove from map by relative key
                             const prefix = root.cacheDir + '/';
                             const relKey = f.startsWith(prefix) ? f.slice(prefix.length) : f;
                             delete root.thumbHashToPath[relKey];
                           });
      root.cachedFileCount = Math.max(0, root.cachedFileCount - invalidFiles.length);
      root.thumbCacheVersion++;
      cleanupCacheProcess.command = ["rm", "-f", ...invalidFiles];
      cleanupCacheProcess.exec({});
    } else {
      if (root.debugMode)
        console.log("[npaper] All cached files are valid");
      root.cacheRefreshed();
    }
  }

  // Refresh cache for a specific folder + queue missing thumbnails
  function refreshAndQueue(wallpaperList, folder) {
    if (root.debugMode)
      console.log("[npaper] Refreshing folder:", folder, "count:", wallpaperList.length);

    // Build valid key set
    const validKeys = {};
    wallpaperList.forEach(path => {
                            const hash = HashUtils.getThumbnailHash(path);
                            validKeys[folder + '/' + hash + '.png'] = true;
                            validKeys[folder + '/' + hash + '_bg.png'] = true;
                            validKeys[folder + '/' + hash + '_anim.gif'] = true;
                          });

    // Delete invalid cache files in this folder only
    const invalidFiles = [];
    Object.keys(root.thumbHashToPath).forEach(key => {
                                                if (key.startsWith(folder + '/')) {
                                                  if (!validKeys[key]) {
                                                    invalidFiles.push(root.thumbHashToPath[key]);
                                                    delete root.thumbHashToPath[key];
                                                  }
                                                }
                                              });

    if (invalidFiles.length > 0) {
      root.cachedFileCount = Math.max(0, root.cachedFileCount - invalidFiles.length);
      root.thumbCacheVersion++;
      cleanupCacheProcess.command = ["rm", "-f", ...invalidFiles];
      cleanupCacheProcess.exec({});
      if (root.debugMode)
        console.log("[npaper] Removed", invalidFiles.length, "invalid files from", folder);
    } else {
      root.cacheRefreshed();
    }

    // Queue only missing thumbnails (pre-check, avoid 50 calls for 5 cached)
    wallpaperList.forEach(path => {
                            const isVideo = FileTypes.isVideoFile(path);
                            const isGif = FileTypes.isGifFile(path);
                            const cached = isVideo || isGif ? CacheHelpers.getCachedAnimatedGif(root.thumbHashToPath, path) : CacheHelpers.getCachedThumb(root.thumbHashToPath, path);
                            if (!cached && !root.queuedSet[path]) {
                              queueThumbnail(path, isVideo, isGif);
                            }
                          });
    if (root.debugMode)
      console.log("[npaper] Queue length:", root.queueLength);
  }

  function queueThumbnail(wallpaperPath, isVideo, isGif) {
    if (!wallpaperPath || wallpaperPath.length === 0 || wallpaperPath.endsWith('/'))
      return;

    const isAnim = isVideo || isGif;
    if (isAnim) {
      const cached = CacheHelpers.getCachedAnimatedGif(root.thumbHashToPath, wallpaperPath);
      if (cached)
        return;
      if (root.queuedSet[wallpaperPath])
        return;
    } else {
      const cached = CacheHelpers.getCachedThumb(root.thumbHashToPath, wallpaperPath);
      if (cached)
        return;
      if (root.queuedSet[wallpaperPath])
        return;
    }

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
          worker.busy = true;
          worker._targetPath = item.path;
          worker._thumbPath = thumbPath;
          worker._bgPath = bgPath;
          worker._animPath = animPath;
          worker._folder = folder;
          worker._ssArgs = item.isVideo ? ["-ss", "00:00:01"] : [];
          worker._needAnim = item.isVideo || item.isGif;
          worker._step = 0;
          root.thumbnailJobRunning++;
          worker.runNext();
          break;
        }
      }
    }
  }

  function hasCachedThumb(wallpaperPath) {
    return CacheHelpers.getCachedThumb(root.thumbHashToPath, wallpaperPath) !== "";
  }

  function hasCachedAnim(wallpaperPath) {
    return CacheHelpers.getCachedAnimatedGif(root.thumbHashToPath, wallpaperPath) !== "";
  }

  function hasCachedBgPreview(wallpaperPath) {
    return CacheHelpers.getCachedBgPreview(root.thumbHashToPath, wallpaperPath) !== "";
  }
}
