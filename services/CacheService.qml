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

  property int bgWidth: Style.cacheBgWidth
  property int bgHeight: Style.cacheBgHeight
  property int animWidth: Style.cacheAnimWidth
  property int animHeight: Style.cacheAnimHeight

  property var thumbHashToPath: ({})
  property int cachedFileCount: 0
  property int thumbCacheVersion: 0

  property var thumbnailQueue: []
  property var queuedSet: ({})
  property int queueLength: 0
  property int thumbnailJobRunning: 0

  readonly property int thumbnailQueueMax: 50
  readonly property int thumbnailConcurrency: 4
  readonly property int thumbWidth: Style.gridCellWidth
  readonly property int thumbHeight: Style.gridCellHeight
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
    command: ["sh", "-c", `find "${root.cacheDir}" -mindepth 2 -maxdepth 2 \\( \\( -name '*.png' ! -name '*_bg.png' ! -name '*_thumb.png' \\) -o -name '*_bg.png' -o -name '*_thumb.png' -o -name '*_bg.jpg' -o -name '*_thumb.jpg' -o -name '*_anim.gif' \\) -printf '%P\\n' 2>/dev/null`]
    stdout: StdioCollector {
      onStreamFinished: {
        const files = text.trim().split('\n').filter(f => f.length > 0 && f.indexOf('/') > 0);
        var newMap = {};
        files.forEach(f => {
                        newMap[f] = root.cacheDir + '/' + f;
                      });
        root.thumbHashToPath = newMap;
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
    onExited: function (exitCode) {
      if (root.debugMode)
        Logger.d("Cleanup:", exitCode === 0 ? "OK" : "Failed");
      root.cacheRefreshed();
    }
  }

  Component {
    id: thumbWorkerComponent
    Process {
      property int _workerId: 0
      property string _path: ""
      property string _bgPath: ""
      property string _thumbPath: ""
      property string _animPath: ""
      property string _folder: ""
      property var _ssArgs: []
      property int _step: 0
      property bool busy: false

      function _buildCommand(step) {
        const bw = root.bgWidth;
        const bh = root.bgHeight;
        const tw = root.thumbWidth;
        const th = root.thumbHeight;
        const target = _path;
        const outDir = _bgPath.substring(0, _bgPath.lastIndexOf('/'));

        if (!_path)
          return [];

        if (step === 0) {
          return ["mkdir", "-p", outDir];
        }

        if (step === 1) {
          return ["ffmpeg", "-y", ..._ssArgs, "-i", target, "-filter_complex", `[0:v]scale=${bw}:${bh}:force_original_aspect_ratio=increase,crop=${bw}:${bh}[bg]; [0:v]scale=${tw}:${th}:force_original_aspect_ratio=increase,crop=${tw}:${th}[thumb]`, "-map", "[bg]", "-vframes", "1", "-q:v", "2", _bgPath, "-map", "[thumb]", "-vframes", "1", "-q:v", "4",
                  _thumbPath];
        }

        if (step === 2 && _needAnim()) {
          return ["ffmpeg", "-y", ..._ssArgs, "-i", target, "-r", "30", "-vf", `scale=${root.animWidth}:${root.animHeight}:force_original_aspect_ratio=increase,crop=${root.animWidth}:${root.animHeight}`, "-t", "10", _animPath];
        }

        return [];
      }

      function _needAnim() {
        return _animPath !== "";
      }

      function _totalSteps() {
        return _needAnim() ? 3 : 2;
      }

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
          runNext();
        }
      }

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

      function _finish() {
        var updated = Object.assign({}, root.thumbHashToPath);
        const folderKey = _folder + '/';
        var bgKey = _bgPath.substring(_bgPath.indexOf(folderKey));
        updated[bgKey] = _bgPath;
        var thumbKey = _thumbPath.substring(_thumbPath.indexOf(folderKey));
        updated[thumbKey] = _thumbPath;
        if (_animPath && _needAnim()) {
          var animKey = _animPath.substring(_animPath.indexOf(folderKey));
          updated[animKey] = _animPath;
        }
        root.thumbHashToPath = updated;
        root.cachedFileCount = Object.keys(updated).length;
        root.thumbCacheVersion++;

        root.thumbnailGenerated(_path, _thumbPath, _bgPath, _needAnim() ? _animPath : "");
        _reset();
        root.processQueue();
      }

      function _reset() {
        root.thumbnailJobRunning = Math.max(0, root.thumbnailJobRunning - 1);
        busy = false;
        delete root.queuedSet[_path];
        _path = "";
        _bgPath = "";
        _thumbPath = "";
        _animPath = "";
        _folder = "";
        _ssArgs = [];
        _step = 0;
      }

      function setup(item) {
        _path = item.path;
        _bgPath = item.bgPath;
        _thumbPath = item.thumbPath;
        _animPath = item.animPath;
        _folder = item.folder;
        _ssArgs = item.isVideo ? ["-ss", "00:00:01"] : [];
        _step = 0;
        busy = true;
        root.thumbnailJobRunning++;
      }
    }
  }

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
                            validKeys[folder + '/' + hash + '_bg.jpg'] = true;
                            validKeys[folder + '/' + hash + '_thumb.jpg'] = true;
                            validKeys[folder + '/' + hash + '_bg.png'] = true;
                            validKeys[folder + '/' + hash + '_thumb.png'] = true;
                            validKeys[folder + '/' + hash + '_anim.gif'] = true;
                          });

    var newMap = Object.assign({}, root.thumbHashToPath);
    const invalidFiles = [];
    Object.keys(newMap).forEach(key => {
                                  if (key.startsWith(folder + '/') && !validKeys[key]) {
                                    invalidFiles.push(newMap[key]);
                                    delete newMap[key];
                                  }
                                });
    root.thumbHashToPath = newMap;

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
      const hash = HashUtils.getThumbnailHash(item.path);
      const bgPath = root.cacheDir + '/' + folder + '/' + hash + '_bg.jpg';
      const thumbPath = root.cacheDir + '/' + folder + '/' + hash + '_thumb.jpg';
      const animPath = root.cacheDir + '/' + folder + '/' + hash + '_anim.gif';

      for (let i = 0; i < root.thumbnailWorkers.length; i++) {
        const worker = root.thumbnailWorkers[i];
        if (worker && !worker.busy) {
          worker.setup({
                         path: item.path,
                         bgPath: bgPath,
                         thumbPath: thumbPath,
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
