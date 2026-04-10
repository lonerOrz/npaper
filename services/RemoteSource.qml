import QtQuick
import qs.services

/*
* RemoteSource — Wallhaven.cc wallpaper source.
*
* Outputs unified items:
*   { id, type:"remote", path, thumb, filename, resolution, fileSize, isVideo, isGif }
*/
Item {
  id: root

  required property var whService
  property string wallpaperDir: ""

  // Unified item list from Wallhaven results
  // Use a mutable property updated by signal to ensure reactivity
  property var items: []

  Connections {
    target: root.whService
    function onResultsUpdated() {
      root.items = root._makeItems();
    }
  }

  Component.onCompleted: {
    root.items = root._makeItems();
  }

  function _makeItems() {
    if (!root.whService || !root.whService.results)
      return [];
    return root.whService.results.map(r => _makeItem(r));
  }

  function _makeItem(r) {
    var safeId = r.id ? String(r.id).replace(/[^a-zA-Z0-9-]/g, "") : "unknown";
    return {
      id: "wallhaven-" + safeId,
      type: "remote",
      path: r.path || ""        // remote path for download
            ,
      thumb: r.thumbLarge || "" // direct URL to thumbnail
             ,
      filename: "wallhaven-" + safeId + (r.resolution ? " (" + r.resolution + ")" : ""),
      resolution: r.resolution || "",
      fileSize: r.filesize || 0,
      isVideo: false,
      isGif: false
    };
  }

  function search(query) {
    if (!root.whService)
      return;
    // Guard: prevent empty searches
    if (!query || query.trim().length === 0) {
      Logger.w("RemoteSource", "Empty search query ignored");
      return;
    }
    root.whService.query = query;
    root.whService.search(1);
  }

  function clearResults() {
    if (!root.whService)
      return;
    root.whService.results = [];
  }

  // Download and apply a remote wallpaper
  function apply(item) {
    if (!root.whService || !item || item.type !== "remote")
      return;
    var safeId = item.id.replace(/[^a-zA-Z0-9-]/g, "");
    // Extract actual extension from URL
    var ext = "jpg";
    if (item.path && item.path.indexOf(".") !== -1) {
      var parts = item.path.split(".");
      var candidate = parts[parts.length - 1].split("?")[0].toLowerCase();
      if (["jpg", "jpeg", "png", "webp", "gif"].indexOf(candidate) !== -1)
        ext = candidate;
    }
    var localPath = root.wallpaperDir + "/" + safeId + "." + ext;
    root.whService.downloadWallpaper(safeId, item.path);
    var startTime = new Date().getTime();
    var timeoutMs = 30000; // 30 seconds
    var checkDone = function () {
      var elapsed = new Date().getTime() - startTime;
      if (elapsed > timeoutMs) {
        Logger.w("RemoteSource", "Download timeout for", item.id, "after", Math.round(elapsed / 1000) + "s");
        return;
      }
      var status = root.whService.downloadStatus[safeId];
      if (status === "done") {
        Logger.i("RemoteSource", "Download complete:", localPath);
        root._applyLocal(localPath);
      } else if (status !== "downloading") {
        Logger.w("RemoteSource", "Download failed for", item.id);
      } else {
        Qt.callLater(checkDone, 500);
      }
    };
    Qt.callLater(checkDone);
  }

  function _applyLocal(path) {
    // This will be connected by the Adapter via a callback
    if (root._onApply)
      root._onApply(path);
  }

  property var _onApply: null
}
