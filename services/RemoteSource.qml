import QtQuick
import qs.services

Item {
  id: root

  required property var whService
  property string wallpaperDir: ""

  property var items: []
  property string _pendingApplyId: ""

  signal applyLocal(string path)

  Connections {
    target: root.whService || null
    enabled: root.whService !== null

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

    const rawList = root.whService.results;
    const total = rawList.length;
    const output = [];

    for (let i = 0; i < total; i++) {
      output.push(_makeItem(rawList[i]));
    }
    return output;
  }

  function _makeItem(r) {
    const rawId = r.id ? String(r.id) : "unknown";
    const safeId = rawId.replace(/^wallhaven-/, "").replace(/[^a-zA-Z0-9]/g, "");

    return {
      id: "wallhaven-" + safeId,
      type: "remote",
      path: r.path || "",
      thumb: r.thumbLarge || r.thumbSmall || "",
      thumbLarge: r.thumbLarge || "",
      thumbSmall: r.thumbSmall || "",
      filename: "wallhaven-" + safeId + (r.resolution ? " (" + r.resolution + ")" : ""),
      resolution: r.resolution || "",
      fileSize: r.fileSize || r.filesize || 0,
      purity: r.purity || "",
      category: r.category || "",
      isVideo: false,
      isGif: false
    };
  }

  function search(query) {
    if (!root.whService)
      return;
    if (!query || query.trim().length === 0) {
      Logger.w("RemoteSource: Empty search query ignored");
      return;
    }
    root.whService.query = query.trim();
    root.whService.search(1);
  }

  function clearResults() {
    if (!root.whService)
      return;
    root.whService.results = [];
    root.items = [];
  }

  function apply(item) {
    if (!root.whService || !item || item.type !== "remote")
      return;

    const rawId = String(item.id || "");
    const cleanId = rawId.replace(/^wallhaven-/, "").replace(/[^a-zA-Z0-9]/g, "");
    if (!cleanId)
      return;

    root._pendingApplyId = cleanId;
    root.whService.downloadWallpaper(cleanId, item.path);
  }

  function _applyLocal(path) {
    root.applyLocal(path);
  }
}
