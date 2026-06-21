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

  property var items: []
  property string _pendingApplyId: ""

  signal applyLocal(string path)

  Connections {
    target: root.whService
    function onResultsUpdated() {
      root.items = root._makeItems();
    }
    function onDownloadFinished(whId, localPath) {
      if (root._pendingApplyId && root._pendingApplyId === whId) {
        root._pendingApplyId = "";
        root._applyLocal(localPath);
      }
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
      path: r.path || "",
      thumb: r.thumbLarge || "",
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

  function apply(item) {
    if (!root.whService || !item || item.type !== "remote")
      return;
    var safeId = item.id.replace(/[^a-zA-Z0-9-]/g, "");
    root._pendingApplyId = safeId;
    root.whService.downloadWallpaper(safeId, item.path);
  }

  function _applyLocal(path) {
    root.applyLocal(path);
  }
}
