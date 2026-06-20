import QtQuick
import qs.services

/*
* WallpaperAdapter — unified interface for local and remote wallpaper sources.
*
* UI layer reads:
*   adapter.items          → current source's filtered items (ListModel)
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

  property string currentSource: "local" // "local" | "remote"
  property string searchText: ""
  property var wallpaperDirs: []
  property string scriptPath: ""
  property var configViewModel: null
  property bool debugMode: configViewModel ? configViewModel.debugMode : false
  property string cacheDir: ""
  property var cacheService: null

  readonly property var items: currentSource === "local" ? localSource.items : remoteItems
  readonly property var folders: localSource.folders
  readonly property string currentFolder: localSource.currentFolder
  readonly property int count: items ? (items.count !== undefined ? items.count : (items.length !== undefined ? items.length : 0)) : 0
  readonly property var remoteSource: remoteSource
  readonly property var whService: wallhavenService

  ListModel {
    id: remoteItems
  }

  property bool _whLoadingMore: false

  Connections {
    target: wallhavenService
    enabled: root.currentSource === "remote"

    function onResultsUpdated() {
      if (!wallhavenService || !wallhavenService.results)
        return;
      var total = wallhavenService.results.length;
      var isNewSearch = (total < remoteItems.count) || (wallhavenService.currentPage === 1);
      if (isNewSearch) {
        remoteItems.clear();
        for (var i = 0; i < total; i++) {
          remoteItems.append(wallhavenService.results[i]);
        }
      } else {
        var toAdd = total - remoteItems.count;
        if (toAdd > 0) {
          var startIdx = remoteItems.count;
          for (var j = startIdx; j < total; j++) {
            remoteItems.append(wallhavenService.results[j]);
          }
        }
      }
      root._whLoadingMore = false;
    }
  }

  Connections {
    target: root
    function onCurrentSourceChanged() {
      if (root.currentSource === "remote") {
        remoteItems.clear();
        if (wallhavenService && wallhavenService.results && wallhavenService.results.length > 0) {
          for (var i = 0; i < wallhavenService.results.length; i++) {
            remoteItems.append(wallhavenService.results[i]);
          }
        }
      } else {
        remoteItems.clear();
      }
    }
  }

  function _initRemoteItems() {
    if (root.currentSource === "remote" && wallhavenService && wallhavenService.results) {
      var total = wallhavenService.results.length;
      if (total > 0) {
        for (var i = 0; i < total; i++) {
          remoteItems.append(wallhavenService.results[i]);
        }
      }
    }
  }

  signal dataLoaded

  LocalSource {
    id: localSource
    dirs: root.wallpaperDirs
    scriptPath: root.scriptPath
    debugMode: root.debugMode
    thumbHashToPath: root.cacheService ? root.cacheService.thumbHashToPath : {}
    cacheService: root.cacheService
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
    apiKey: root.configViewModel ? root.configViewModel.wallhaven.apiKey : ""
    categories: root.configViewModel ? root.configViewModel.wallhaven.categories : "111"
    purity: root.configViewModel ? root.configViewModel.wallhaven.purity : "100"
  }

  readonly property string _whDownloadDir: root.configViewModel ? root.configViewModel.wallhaven.downloadDir : ""

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

  function deleteWallpaper(path, idx) {
    localSource.deleteWallpaper(path, idx);
  }

  function moveWallpaper(path, targetFolder, idx) {
    localSource.moveWallpaper(path, targetFolder, idx);
  }

  function getItem(index) {
    var src = items;
    if (!src)
      return null;
    if (src.get !== undefined)
      return src.get(index);
    if (index >= 0 && index < src.length)
      return src[index];
    return null;
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
    _initRemoteItems();
  }
}
