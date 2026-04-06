import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/CacheUtils.js" as CacheHelpers
import "../utils/FileTypes.js" as FileTypes
import "../utils/HashUtils.js" as HashUtils
import qs.utils

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

  Process {
    id: createCacheDirProcess
    command: ["mkdir", "-p", root.cacheDir]
  }

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

  Process {
    id: cleanupCacheProcess
    command: ["rm", "-f"]
    onExited: function (exitCode, exitStatus) {
      if (root.debugMode)
        Logger.d("Cleanup:", exitCode === 0 ? "OK" : "Failed");
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
        const tw = root.thumbWidth;
        const th = root.thumbHeight;
        const bw = root.bgWidth;
        const bh = root.bgHeight;
        if (_step === 0) {
          if (_needAnim) {
            command = ["ffmpeg", "-y", ..._ssArgs, "-i", _targetPath, "-vframes", "1", "-vf", `scale=${tw}:${th}:force_original_aspect_ratio=increase,crop=${tw}:${th}`, "-q:v", "5", _thumbPath];
          } else {
            command = ["ffmpeg", "-y", "-i", _targetPath, "-vframes", "1", "-filter_complex", `[0:v]split=2[a][b];[a]scale=${tw}:${th}:force_original_aspect_ratio=increase,crop=${tw}:${th}[thumb];[b]scale=${bw}:${bh}:force_original_aspect_ratio=increase,crop=${bw}:${bh}[bg]`, "-map", "[thumb]", "-q:v", "5", "-update", "1", _thumbPath, "-map", "[bg]", "-q:v", "2",
                       _bgPath];
          }
        } else if (_step === 1 && _needAnim) {
          command = ["ffmpeg", "-y", ..._ssArgs, "-i", _targetPath, "-r", "30", "-vf", `scale=${tw}:${th}:force_original_aspect_ratio=increase,crop=${tw}:${th}`, "-t", "10", _animPath];
        }
        if (command.length > 0) {
          exec({});
        }
      }

      onExited: function (exitCode, exitStatus) {
        root.thumbnailJobRunning = Math.max(0, root.thumbnailJobRunning - 1);

        if (exitCode !== 0) {
          if (root.debugMode)
            Logger.d("Failed:", _targetPath, "exitCode:", exitCode);
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

        _step++;

        if (_step === 1 && _needAnim) {
          busy = true;
          root.thumbnailJobRunning++;
          const bw = root.bgWidth;
          const bh = root.bgHeight;
          command = ["ffmpeg", "-y", ..._ssArgs, "-i", _targetPath, "-vframes", "1", "-vf", `scale=${bw}:${bh}:force_original_aspect_ratio=increase,crop=${bw}:${bh}`, "-q:v", "2", _bgPath];
          exec({});
          return;
        }

        if (_step === 2 && _needAnim) {
          busy = true;
          root.thumbnailJobRunning++;
          const tw = root.thumbWidth;
          const th = root.thumbHeight;
          command = ["ffmpeg", "-y", ..._ssArgs, "-i", _targetPath, "-r", "30", "-vf", `scale=${tw}:${th}:force_original_aspect_ratio=increase,crop=${tw}:${th}`, "-t", "10", _animPath];
          exec({});
          return;
        }

        root.thumbnailGenerated(_targetPath, _thumbPath, _bgPath, _animPath);

        if (_thumbPath) {
          root.thumbHashToPath[_folder + '/' + HashUtils.getThumbnailHash(_targetPath) + '.png'] = _thumbPath;
        }
        if (_bgPath) {
          root.thumbHashToPath[_folder + '/' + HashUtils.getThumbnailHash(_targetPath) + '_bg.png'] = _bgPath;
        }
        if (_animPath) {
          root.thumbHashToPath[_folder + '/' + HashUtils.getThumbnailHash(_targetPath) + '_anim.gif'] = _animPath;
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
      Logger.d("CacheService already initialized");
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
}
