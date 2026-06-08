import QtQuick
import qs.services

/*
* WallpaperAdapter — unified interface for local and remote wallpaper sources.
*
* UI layer reads:
*   adapter.items          → current source's filtered items
*   adapter.currentSource  → "local" or "remote"
*   adapter.folders        → local folders (empty for remote)
*   adapter.currentFolder  → current local folder
*
* UI layer writes:
*   adapter.switchSource("local"|"remote")
*   adapter.searchText = "query"
*   adapter.apply(item)  → applies wallpaper (local or downloads remote first)
*/

Item {
  id: root

  property string currentSource: "local"  // "local" | "remote"
  property string searchText: ""
  property var wallpaperDirs: []
  property string scriptPath: ""
  property bool debugMode: false
  property string cacheDir: ""
  property var cacheService: null

  readonly property var items: currentSource === "local" ? localSource.items : remoteSource.items
  readonly property var folders: localSource.folders
  readonly property string currentFolder: localSource.currentFolder
  readonly property int count: items.length
  readonly property var remoteSource: remoteSource
  readonly property var whService: wallhavenService

  signal dataLoaded

  LocalSource {
    id: localSource
    dirs: root.wallpaperDirs
    scriptPath: root.scriptPath
    debugMode: root.debugMode
    thumbHashToPath: root.cacheService ? root.cacheService.thumbHashToPath : {}
    onDataLoaded: root.dataLoaded()
  }

  RemoteSource {
    id: remoteSource
    whService: wallhavenService
    wallpaperDir: root.wallpaperDirs && root.wallpaperDirs.length > 0 ? root.wallpaperDirs[0] : ""
    onApplyLocal: function (path) {
      root._onApplyLocal(path);
    }
  }

  WallhavenService {
    id: wallhavenService
    wallpaperDir: _whDownloadDir || (root.wallpaperDirs && root.wallpaperDirs.length > 0 ? root.wallpaperDirs[0] : "")
    apiKey: Config.data.wallhaven.apiKey
    categories: Config.data.wallhaven.categories
    purity: Config.data.wallhaven.purity
  }

  readonly property string _whDownloadDir: (Config.data.wallhaven && Config.data.wallhaven.downloadDir) ? Config.data.wallhaven.downloadDir : ""

  function switchSource(source) {
    root.currentSource = source;
  }

  function switchFolder(folder) {
    localSource.switchFolder(folder);
  }

  function setSearch(text) {
    root.searchText = text;
    if (root.currentSource === "local")
      localSource.setSearch(text);
    else
      remoteSource.search(text);
  }

  function resetSearch() {
    root.searchText = "";
    localSource.resetSearch();
    if (root.currentSource === "remote" && root.whService) {
      root.whService.query = "";
      root.whService.search(1);
    }
  }

  function refresh() {
    localSource.refresh(root.cacheService);
  }

  function apply(item) {
    if (!item)
      return;
    if (item.type === "local")
      root._onApplyLocal(item.path);
    else
      remoteSource.apply(item);
  }

  function smartApply(item) {
    if (!item)
      return;
    if (item.type === "local") {
      root._onApplyLocal(item.path);
    } else {
      var ws = root.whService;
      var safeId = item.id ? String(item.id).replace("wallhaven-", "") : "";
      var status = ws ? (ws.downloadStatus[safeId] || "") : "";
      if (status === "done") {
        var localPath = ws ? (ws.downloadPaths[safeId] || "") : "";
        if (localPath)
          root._onApplyLocal(localPath);
        else if (ws)
          ws.downloadAndApply(safeId, item.path);
      } else if (status === "downloading") {
        if (ws)
          ws._pendingApplyId = safeId;
      } else if (ws) {
        ws.downloadAndApply(safeId, item.path);
      }
    }
  }

  function _onApplyLocal(path) {
    root.wallpaperApplied(path);
  }

  signal wallpaperApplied(string path)

  function load() {
    localSource.load();
  }
}
