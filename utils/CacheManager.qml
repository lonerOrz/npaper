pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "HashUtils.js" as HashUtils
import "CacheUtils.js" as CacheHelpers

Item {
    id: root

    property string cacheDir: ""
    property bool hasFfmpeg: false

    property var thumbHashToPath: ({})
    property int cachedFileCount: 0
    property int thumbCacheVersion: 0

    signal cacheScanned()
    signal cacheRefreshed()
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

    Process {
        id: scanCacheProcess
        command: ["sh", "-c", `find "${root.cacheDir}" -maxdepth 1 \\( -name '*.png' -o -name '*_anim.gif' \\) -printf '%f\\n' 2>/dev/null`]
        stdout: StdioCollector {
            onStreamFinished: {
                const files = text.trim().split('\n').filter(f => f.length > 0 && (f.endsWith('.png') || f.endsWith('_anim.gif')));
                files.forEach(f => {
                    if (f.endsWith('_anim.gif')) {
                        const hash = f.replace('_anim.gif', '');
                        root.thumbHashToPath[hash + '_anim.gif'] = root.cacheDir + '/' + f;
                    } else if (f.endsWith('_bg.png')) {
                        const hash = f.replace('_bg.png', '');
                        root.thumbHashToPath[hash + '_bg.png'] = root.cacheDir + '/' + f;
                    } else {
                        const hash = f.replace('.png', '');
                        root.thumbHashToPath[hash] = root.cacheDir + '/' + f;
                    }
                });
                root.cachedFileCount = files.length;
                root.thumbCacheVersion++;
                console.log("[npaper] Cache scanned:", files.length, "files");
                root.cacheScanned();
            }
        }
    }

    Process {
        id: cleanupCacheProcess
        command: ["rm", "-f"]
        onExited: function (exitCode, exitStatus) {
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
            property var _ssArgs: []
            property int _step: 0
            property bool _needAnim: false
            property bool busy: false

            function runNext() {
                if (_step === 0) {
                    if (_needAnim) {
                        command = [
                            "ffmpeg", "-y",
                            ..._ssArgs,
                            "-i", _targetPath,
                            "-vframes", "1",
                            "-vf", "scale=450:320:force_original_aspect_ratio=increase,crop=450:320",
                            "-q:v", "5",
                            _thumbPath
                        ];
                    } else {
                        command = [
                            "ffmpeg", "-y",
                            "-i", _targetPath,
                            "-vframes", "1",
                            "-filter_complex", "[0:v]split=2[a][b];[a]scale=450:320:force_original_aspect_ratio=increase,crop=450:320[thumb];[b]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080[bg]",
                            "-map", "[thumb]", "-q:v", "5", "-update", "1", _thumbPath,
                            "-map", "[bg]", "-q:v", "2", _bgPath
                        ];
                    }
                } else if (_step === 1 && _needAnim) {
                    command = [
                        "ffmpeg", "-y",
                        ..._ssArgs,
                        "-i", _targetPath,
                        "-r", "30",
                        "-vf", "scale=450:320:force_original_aspect_ratio=increase,crop=450:320",
                        "-t", "10",
                        _animPath
                    ];
                }
                if (command.length > 0) {
                    exec({});
                }
            }

            onExited: function (exitCode, exitStatus) {
                root.thumbnailJobRunning = Math.max(0, root.thumbnailJobRunning - 1);

                if (exitCode !== 0) {
                    console.log("[npaper] Failed:", _targetPath, "exitCode:", exitCode, "worker:", _workerId);
                    busy = false;
                    const failedPath = _targetPath;
                    _targetPath = "";
                    _thumbPath = "";
                    _bgPath = "";
                    _animPath = "";
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
                    command = [
                        "ffmpeg", "-y",
                        ..._ssArgs,
                        "-i", _targetPath,
                        "-vframes", "1",
                        "-vf", "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080",
                        "-q:v", "2",
                        _bgPath
                    ];
                    exec({});
                    return;
                }

                if (_step === 2 && _needAnim) {
                    busy = true;
                    root.thumbnailJobRunning++;
                    command = [
                        "ffmpeg", "-y",
                        ..._ssArgs,
                        "-i", _targetPath,
                        "-r", "30",
                        "-vf", "scale=450:320:force_original_aspect_ratio=increase,crop=450:320",
                        "-t", "10",
                        _animPath
                    ];
                    exec({});
                    return;
                }

                root.thumbnailGenerated(_targetPath, _thumbPath, _bgPath, _animPath);

                if (_animPath) {
                    root.thumbHashToPath[hash + '_anim.gif'] = _animPath;
                    console.log("[npaper] Generated animated GIF:", _animPath);
                }
                if (_thumbPath) {
                    root.thumbHashToPath[hash] = _thumbPath;
                    console.log("[npaper] Generated thumbnail:", _thumbPath);
                }
                if (_bgPath) {
                    root.thumbHashToPath[hash + '_bg.png'] = _bgPath;
                    console.log("[npaper] Generated background:", _bgPath);
                }
                root.thumbCacheVersion++;
                root.cachedFileCount++;

                busy = false;
                const completedPath = _targetPath;
                _targetPath = "";
                _thumbPath = "";
                _bgPath = "";
                _animPath = "";
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
            workers.push(thumbWorkerComponent.createObject(root, { _workerId: i }));
        }
        root.thumbnailWorkers = workers;
        console.log("[npaper] Initialized", workers.length, "workers");
    }

    function scanCache() {
        scanCacheProcess.exec({});
    }

    function refreshCache(wallpaperList) {
        console.log("[npaper] Refreshing cache for", wallpaperList.length, "wallpapers");

        const validHashes = {};
        wallpaperList.forEach(path => {
            validHashes[HashUtils.getThumbnailHash(path)] = true;
        });

        const invalidFiles = [];
        Object.keys(root.thumbHashToPath).forEach(key => {
            let hash;
            if (key.endsWith('_anim.gif')) hash = key.replace('_anim.gif', '');
            else if (key.endsWith('_bg.png')) hash = key.replace('_bg.png', '');
            else hash = key.replace('.png', '');

            if (!validHashes[hash]) {
                invalidFiles.push(root.thumbHashToPath[key].replace(/^file:\/\//, ''));
            }
        });

        if (invalidFiles.length > 0) {
            console.log("[npaper] Removing", invalidFiles.length, "invalid files");
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
            cleanupCacheProcess.command = ["rm", "-f", ...invalidFiles];
            cleanupCacheProcess.exec({});
        } else {
            console.log("[npaper] All cached files are valid");
            root.cacheRefreshed();
        }
    }

    function queueThumbnail(wallpaperPath, isVideo, isGif) {
        if (!wallpaperPath || wallpaperPath.length === 0 || wallpaperPath.endsWith('/'))
            return;

        const isAnim = isVideo || isGif;
        if (isAnim) {
            const cached = CacheHelpers.getCachedAnimatedGif(root.thumbHashToPath, wallpaperPath);
            if (cached) return;
            if (root.queuedSet[wallpaperPath]) return;
        } else {
            const cached = CacheHelpers.getCachedThumb(root.thumbHashToPath, wallpaperPath);
            if (cached) return;
            if (root.queuedSet[wallpaperPath]) return;
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

        processQueue();
    }

    function processQueue() {
        if (!root.hasFfmpeg) {
            root.thumbnailQueue = [];
            return;
        }

        while (root.thumbnailJobRunning < root.thumbnailConcurrency && root.thumbnailQueue.length > 0) {
            const item = root.thumbnailQueue.shift();
            const thumbPath = CacheHelpers.getThumbnailPath(root.cacheDir, item.path);
            const hash = HashUtils.getThumbnailHash(item.path);
            const bgPath = root.cacheDir + '/' + hash + '_bg.png';
            const animPath = root.cacheDir + '/' + hash + '_anim.gif';

            for (let i = 0; i < root.thumbnailWorkers.length; i++) {
                const worker = root.thumbnailWorkers[i];
                if (worker && !worker.busy) {
                    worker.busy = true;
                    worker._targetPath = item.path;
                    worker._thumbPath = thumbPath;
                    worker._bgPath = bgPath;
                    worker._animPath = animPath;
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
