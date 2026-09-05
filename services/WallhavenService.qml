import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root

  required property string wallpaperDir

  property string query: ""
  property string categories: "111"
  property string purity: "100"
  property string sorting: "toplist"
  property string order: "desc"
  property string topRange: "1M"
  property string atleast: ""
  property string ratios: ""
  property string apiKey: ""

  property int currentPage: 1
  property int lastPage: 1
  property int _searchPageBeforeRequest: 1
  property bool hasMore: currentPage < lastPage

  property var results: []
  property bool loading: false
  property string errorText: ""

  property var downloadStatus: ({})
  property var downloadProgress: ({})
  property var downloadPaths: ({})
  property var localWallhavenIds: ({})
  property var localWallhavenPaths: ({})

  signal resultsUpdated
  signal downloadFinished(string wallhavenId, string localPath)
  signal downloadApplied(string localPath)

  readonly property Component _downloadProcComp: Qt.createComponent("WallhavenDownloadProc.qml")

  function scanLocalFiles() {
    if (!root.wallpaperDir || root.wallpaperDir.length === 0)
      return;
    _localScanOutput = "";
    _localScanProc.command = ["find", root.wallpaperDir, "-maxdepth", "1", "-name", "wallhaven-*"];
    _localScanProc.running = true;
  }

  property string _localScanOutput: ""
  property var _localScanProc: Process {
    stdout: SplitParser {
      onRead: data => {
        root._localScanOutput += data + "\n";
      }
    }
    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0)
        return;
      const ids = {};
      const paths = {};
      const lines = root._localScanOutput.split("\n");
      const total = lines.length;

      for (let i = 0; i < total; i++) {
        const p = lines[i].trim();
        if (!p)
          continue;

        const lastSlash = p.lastIndexOf('/');
        const fname = (lastSlash >= 0) ? p.substring(lastSlash + 1) : p;
        if (!fname)
          continue;

        const m = fname.match(/^wallhaven-([a-zA-Z0-9]+)\.([a-zA-Z0-9]+)$/i);
        if (m) {
          ids[m[1]] = true;
          paths[m[1]] = p;
        }
      }
      root.localWallhavenIds = ids;
      root.localWallhavenPaths = paths;
    }
  }

  function search(page) {
    if (loading)
      return;
    _searchPageBeforeRequest = currentPage;
    currentPage = page || 1;
    if (currentPage === 1)
      results = [];
    loading = true;
    errorText = "";

    _searchProcess.command = ["curl", "-fsSL", root._buildUrl()];
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
    downloadStatus = {};
    downloadProgress = {};
    downloadPaths = {};
    _pendingApplyId = "";
  }

  function _buildUrl() {
    var url = "https://wallhaven.cc/api/v1/search?";
    var params = [];

    if (query && query.trim().length > 0)
      params.push("q=" + encodeURIComponent(query.trim()));
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
    if (apiKey && apiKey.trim().length > 0)
      params.push("apikey=" + apiKey.trim());

    return url + params.join("&");
  }

  property string _searchOutput: ""

  property var _searchProcess: Process {
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
        if (root._searchPageBeforeRequest !== undefined)
          root.currentPage = root._searchPageBeforeRequest;
        root.resultsUpdated();
        return;
      }
      try {
        const json = JSON.parse(root._searchOutput);
        if (json.error) {
          root.errorText = json.error;
        } else {
          const rawItems = json.data || [];
          const newItems = [];
          for (let i = 0; i < rawItems.length; i++) {
            const item = rawItems[i];
            newItems.push({
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
                          });
          }
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

  readonly property var _allowedExts: ({
                                         "jpg": true,
                                         "jpeg": true,
                                         "png": true,
                                         "webp": true,
                                         "gif": true,
                                         "bmp": true
                                       })
  readonly property var _allowedHosts: ["w.wallhaven.cc"]

  function _parseUrl(url) {
    if (!url || typeof url !== "string")
      return null;
    let protocol = "";
    let rest = url;
    const protoIdx = url.indexOf("://");
    if (protoIdx > 0) {
      protocol = url.substring(0, protoIdx + 1);
      rest = url.substring(protoIdx + 3);
    }
    const slashIdx = rest.indexOf("/");
    const host = slashIdx >= 0 ? rest.substring(0, slashIdx) : rest;
    const hostname = host.split(":")[0];
    return {
      protocol: protocol,
      hostname: hostname,
      host: host
    };
  }

  function downloadAndApply(wallhavenId, fullUrl) {
    _pendingApplyId = wallhavenId;
    downloadWallpaper(wallhavenId, fullUrl);
  }

  function setPendingApply(itemId) {
    _pendingApplyId = itemId;
  }

  function downloadWallpaper(wallhavenId, fullUrl) {
    if (_activeDownloads[wallhavenId])
      return;

    const urlParts = root._parseUrl(fullUrl);
    if (!urlParts || urlParts.protocol !== "https:")
      return;

    const hostOk = _allowedHosts.some(h => urlParts.hostname === h);
    if (!hostOk)
      return;

    let ext = fullUrl.split(".").pop().split("?")[0].toLowerCase();
    if (!_allowedExts[ext])
      ext = "jpg";

    const safeId = wallhavenId.replace(/[^a-zA-Z0-9]/g, "");
    if (!safeId)
      return;

    const dest = root.wallpaperDir + "/wallhaven-" + safeId + "." + ext;
    const status = Object.assign({}, downloadStatus);
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
  property string _pendingApplyId: ""

  function _drainDownloadQueue() {
    while (_runningDownloads < _maxConcurrent && _downloadQueue.length > 0) {
      const job = _downloadQueue.shift();
      _runningDownloads++;
      _spawnDownload(job.id, job.url, job.dest);
    }
  }

  function _spawnDownload(whId, url, dest) {
    const safeUrl = url.replace(/'/g, "");
    const safeDest = dest.replace(/'/g, "");
    if (!safeUrl || !safeDest) {
      _runningDownloads--;
      return;
    }

    if (root._downloadProcComp.status !== Component.Ready) {
      console.error("WallhavenService: Download component not ready:", root._downloadProcComp.errorString());
      _runningDownloads--;
      return;
    }

    const proc = root._downloadProcComp.createObject(root, {
                                                       whId: whId,
                                                       dest: safeDest
                                                     });
    if (!proc) {
      _runningDownloads--;
      return;
    }

    proc.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && curl -# -fsSL -o \"$1\" \"$2\"", "npaper-dl", safeDest, safeUrl];

    let lastReportedPct = 0.0;
    proc.onProgressUpdate.connect(function (id, pct) {
      if (Math.abs(pct - lastReportedPct) >= 0.02 || pct >= 0.99) {
        lastReportedPct = pct;
        const p = Object.assign({}, downloadProgress);
        p[id] = pct;
        downloadProgress = p;
      }
    });

    proc.onDone.connect(function (id, success) {
      _runningDownloads--;
      delete _activeDownloads[id];
      const s = Object.assign({}, downloadStatus);

      if (success) {
        s[whId] = "done";
        downloadStatus = s;

        const prog = Object.assign({}, downloadProgress);
        prog[whId] = 1.0;
        downloadProgress = prog;

        const localPath = dest;
        const paths = Object.assign({}, downloadPaths);
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

        const prog = Object.assign({}, downloadProgress);
        prog[whId] = 0.0;
        downloadProgress = prog;

        if (downloadPaths[whId] !== undefined) {
          const paths2 = Object.assign({}, downloadPaths);
          delete paths2[whId];
          downloadPaths = paths2;
        }
      }

      proc.destroy();
      _drainDownloadQueue();
    });

    proc.running = true;
  }

  Component.onCompleted: {
    scanLocalFiles();
  }
}
