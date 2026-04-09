import QtQuick
import Quickshell
import Quickshell.Io

/*
* WallhavenService - Wallhaven.cc API integration
*
* Features:
*   - Search wallpapers via Wallhaven API
*   - Download wallpapers to local directory
*   - Track download progress and status
*   - Scan local wallhaven wallpapers
*/
QtObject {
  id: root

  required property string wallpaperDir

  // Search parameters
  property string query: ""
  property string categories: "111"     // general=1, anime=1, people=1
  property string purity: "100"          // 100=safe, 100w=sketchy, 100s=nsfw
  property string sorting: "toplist"    // toplist, date_added, views, random
  property string order: "desc"
  property string topRange: "1M"         // 1M, 3M, 6M, 1Y
  property string atleast: ""            // minimum resolution (e.g., 1920x1080)
  property string ratios: ""            // aspect ratios (e.g., 16:9, 21:9)
  property string apiKey: ""

  // Pagination
  property int currentPage: 1
  property int lastPage: 1
  property bool hasMore: currentPage < lastPage

  // Data
  property var results: []
  property bool loading: false
  property string errorText: ""

  // Download tracking
  property var downloadStatus: ({})      // wallhavenId -> "downloading" | "done" | "error"
  property var downloadProgress: ({})    // wallhavenId -> 0-100
  property var downloadPaths: ({})       // wallhavenId -> local file path (after download)
  property var localWallhavenIds: ({})   // wallhavenId -> true (if downloaded locally)

  signal resultsUpdated
  signal downloadFinished(string wallhavenId, string localPath)

  // ===== Local file scanning =====
  function scanLocalFiles() {
    _localScanOutput = "";
    _localScanProc.running = true;
  }

  property string _localScanOutput: ""
  property var _localScanProc: Process {
    command: ["find", root.wallpaperDir, "-maxdepth", "1", "-name", "wallhaven-*", "-printf", "%f\n"]
    stdout: SplitParser {
      onRead: data => {
                root._localScanOutput += data + "\n";
              }
    }
    onExited: function (exitCode, exitStatus) {
      var ids = {};
      var lines = root._localScanOutput.split("\n");
      for (var i = 0; i < lines.length; i++) {
        var fname = lines[i].trim();
        if (!fname)
          continue;
        var m = fname.match(/^wallhaven-([a-zA-Z0-9]+)/);
        if (m)
          ids[m[1]] = true;
      }
      root.localWallhavenIds = ids;
    }
  }

  // ===== Search API =====
  function search(page) {
    if (loading)
      return;
    currentPage = page || 1;
    results = [];
    loading = true;
    errorText = "";
    _searchProcess.running = true;
  }

  function loadMore() {
    if (loading || !hasMore)
      return;
    search(currentPage + 1);
  }

  function clearCache() {
    results = [];
    currentPage = 1;
    lastPage = 1;
    errorText = "";
    // Clear download state when search results are cleared
    downloadStatus = {};
    downloadProgress = {};
    downloadPaths = {};
    _pendingApplyId = "";
  }

  // ===== Build API URL =====
  function _buildUrl() {
    var url = "https://wallhaven.cc/api/v1/search?";
    var params = [];

    if (query)
      params.push("q=" + encodeURIComponent(query));
    params.push("categories=" + categories);
    params.push("purity=" + purity);
    params.push("sorting=" + sorting);
    params.push("order=" + order);

    if (sorting === "toplist" && topRange)
      params.push("topRange=" + topRange);
    if (atleast)
      params.push("atleast=" + atleast);
    if (ratios)
      params.push("ratios=" + ratios);

    params.push("page=" + currentPage);
    if (apiKey)
      params.push("apikey=" + apiKey);

    return url + params.join("&");
  }

  property string _searchOutput: ""

  property var _searchProcess: Process {
    command: ["curl", "-fsSL", root._buildUrl()]
    stdout: SplitParser {
      splitMarker: ""
      onRead: data => {
                root._searchOutput += data;
              }
    }
    onRunningChanged: {
      if (running)
        root._searchOutput = "";
    }
    onExited: function (exitCode, exitStatus) {
      root.loading = false;
      if (exitCode !== 0) {
        root.errorText = "Network error (curl exit " + exitCode + ")";
        root.resultsUpdated();
        return;
      }
      try {
        var json = JSON.parse(root._searchOutput);
        if (json.error) {
          root.errorText = json.error;
        } else {
          var newItems = (json.data || []).map(function (item) {
            return {
              id: item.id,
              url: item.url,
              path: item.path,
              resolution: item.resolution,
              fileSize: item.file_size,
              purity: item.purity,
              category: item.category,
              thumbLarge: item.thumbs ? item.thumbs.large : "",
              thumbSmall: item.thumbs ? item.thumbs.small : "",
              colors: item.colors || []
            };
          });
          root.results = root.results.concat(newItems);
          root.lastPage = (json.meta && json.meta.last_page) ? json.meta.last_page : 1;
          root.currentPage = (json.meta && json.meta.current_page) ? json.meta.current_page : 1;
          root.errorText = "";
        }
      } catch (e) {
        root.errorText = "Parse error: " + e.message;
      }
      root.resultsUpdated();
      root.scanLocalFiles();
    }
  }

  // ===== Download =====
  readonly property var _allowedExts: ({
                                         "jpg": true,
                                         "jpeg": true,
                                         "png": true,
                                         "webp": true,
                                         "gif": true,
                                         "bmp": true
                                       })
  readonly property var _allowedHosts: ["w.wallhaven.cc"]

  // Parse URL without relying on URL constructor (V4 compatibility)
  function _parseUrl(url) {
    if (!url || typeof url !== "string")
      return null;
    var protocol = "";
    var rest = url;
    var protoIdx = url.indexOf("://");
    if (protoIdx > 0) {
      protocol = url.substring(0, protoIdx + 1); // e.g. "https:"
      rest = url.substring(protoIdx + 3);
    }
    var slashIdx = rest.indexOf("/");
    var host = slashIdx >= 0 ? rest.substring(0, slashIdx) : rest;
    var hostname = host.split(":")[0]; // strip port if present
    return {
      protocol: protocol,
      hostname: hostname,
      host: host
    };
  }

  // Download and mark for auto-apply when done
  function downloadAndApply(wallhavenId, fullUrl) {
    _pendingApplyId = wallhavenId;
    downloadWallpaper(wallhavenId, fullUrl);
  }

  function downloadWallpaper(wallhavenId, fullUrl) {
    if (_activeDownloads[wallhavenId])
      return;

    var urlParts = root._parseUrl(fullUrl);
    if (!urlParts)
      return;
    if (urlParts.protocol !== "https:")
      return;

    var hostOk = _allowedHosts.some(function (h) {
      return urlParts.hostname === h;
    });
    if (!hostOk)
      return;

    var ext = fullUrl.split(".").pop().split("?")[0].toLowerCase();
    if (!_allowedExts[ext])
      ext = "jpg";

    var safeId = wallhavenId.replace(/[^a-zA-Z0-9]/g, "");
    if (!safeId)
      return;

    var dest = wallpaperDir + "/wallhaven-" + safeId + "." + ext;
    var status = Object.assign({}, downloadStatus);
    status[wallhavenId] = "downloading";
    downloadStatus = status;

    _activeDownloads[wallhavenId] = {
      dest: dest
    };
    _downloadQueue.push({
                          id: wallhavenId,
                          url: fullUrl,
                          dest: dest
                        });
    _drainDownloadQueue();
  }

  property var _activeDownloads: ({})
  property var _downloadQueue: []
  property int _runningDownloads: 0
  readonly property int _maxConcurrent: 3

  // Track pending apply (download then auto-apply)
  property string _pendingApplyId: ""
  signal downloadApplied(string localPath)

  function _drainDownloadQueue() {
    while (_runningDownloads < _maxConcurrent && _downloadQueue.length > 0) {
      var job = _downloadQueue.shift();
      _runningDownloads++;
      _spawnDownload(job.id, job.url, job.dest);
    }
  }

  function _spawnDownload(whId, url, dest) {
    var safeUrl = url.replace(/'/g, "");
    var safeDest = dest.replace(/'/g, "");
    if (!safeUrl || !safeDest) {
      _runningDownloads--;
      return;
    }

    var comp = Qt.createComponent("WallhavenDownloadProc.qml");
    if (comp.status !== Component.Ready) {
      console.error("Failed to create download component:", comp.errorString());
      _runningDownloads--;
      return;
    }

    var proc = comp.createObject(root, {
                                   whId: whId,
                                   dest: safeDest
                                 });
    if (!proc) {
      _runningDownloads--;
      return;
    }

    proc.command = ["curl", "-#", "-fsSL", "-o", safeDest, safeUrl];
    proc.onProgressUpdate.connect(function (id, pct) {
      var p = Object.assign({}, downloadProgress);
      p[id] = pct;
      downloadProgress = p;
    });
    proc.onDone.connect(function (id, success) {
      _runningDownloads--;
      // Clean up active downloads entry
      delete _activeDownloads[id];
      var s = Object.assign({}, downloadStatus);
      if (success) {
        s[whId] = "done";
        downloadStatus = s;
        var prog = Object.assign({}, downloadProgress);
        prog[whId] = 1.0;
        downloadProgress = prog;
        var localPath = dest;
        var paths = Object.assign({}, downloadPaths);
        paths[whId] = localPath;
        downloadPaths = paths;
        downloadFinished(whId, localPath);
        if (_pendingApplyId === whId) {
          _pendingApplyId = "";
          downloadApplied(localPath);
        }
      } else {
        s[whId] = "error";
        downloadStatus = s;
        var prog = Object.assign({}, downloadProgress);
        prog[whId] = 0;
        downloadProgress = prog;
        // Clean up downloadPaths on error
        if (downloadPaths[whId] !== undefined) {
          var paths2 = Object.assign({}, downloadPaths);
          delete paths2[whId];
          downloadPaths = paths2;
        }
      }
      proc.destroy();
      _drainDownloadQueue();
    });
    proc.running = true;
  }

  // Initialize
  Component.onCompleted: {
    scanLocalFiles();
  }
}
