import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/FileTypes.js" as FileTypes
import "../utils/CacheUtils.js" as CacheUtils
import qs.services

/*
 * LocalSource — local wallpaper directory scanner.
 *
 * Outputs unified items:
 *   { id, type:"local", path, thumb, filename, resolution, fileSize, apply }
 */
Item {
  id: root

  property var dirs: []
  property string scriptPath: ""
  property bool debugMode: false
  property var thumbHashToPath: ({})

  property string currentFolder: ""
  property var folders: []
  property var wallpaperMap: ({})
  property string searchText: ""

  // Unified item list for current folder
  readonly property var items: _filterItems()

  signal dataLoaded

  // ========== Logic ==========

  function _filterItems() {
    const folder = root.wallpaperMap[root.currentFolder];
    if (!folder) {
      if (root.debugMode) Logger.d("LocalSource: No folder found:", root.currentFolder);
      return [];
    }
    if (!root.searchText)
      return folder.map(p => _makeItem(p));
    const lower = root.searchText.toLowerCase();
    return folder.filter(p => p.toLowerCase().includes(lower)).map(p => _makeItem(p));
  }

  function _makeItem(path) {
    const cachedBg = CacheUtils.getCachedBgPreview(root.thumbHashToPath, path);
    return {
      id: path,
      type: "local",
      path: path,
      thumb: cachedBg ? ("file://" + cachedBg) : ("file://" + path),
      filename: path.split('/').pop(),
      resolution: "",
      fileSize: 0,
      isVideo: FileTypes.isVideoFile(path),
      isGif: FileTypes.isGifFile(path)
    };
  }

  function switchFolder(folder) {
    if (root.debugMode)
      Logger.d("LocalSource: Switch folder:", folder);
    root.currentFolder = folder;
    root.searchText = "";
  }

  function setSearch(text) {
    root.searchText = text;
  }

  function resetSearch() {
    root.searchText = "";
  }

  function refresh(cacheService) {
    if (root.debugMode)
      Logger.d("LocalSource: Refresh — re-scanning all directories");
    var _cs = cacheService; // capture reference for callback
    var _onDone = function() {
      // Refresh thumbnail cache for current folder after re-scan
      if (_cs && root.currentFolder && root.wallpaperMap[root.currentFolder]) {
        _cs.refreshAndQueue(root.wallpaperMap[root.currentFolder], root.currentFolder);
      }
      root.dataLoaded.disconnect(_onDone);
    };
    root.dataLoaded.connect(_onDone);
    root.load();
  }

  function load() {
    if (root.dirs.length === 0 || !root.scriptPath) {
      if (root.debugMode)
        Logger.d("LocalSource: Skipping load due to missing dirs or scriptPath");
      return;
    }
    folderListProcess.command = ["bash", "-c", 'NPAPER_WALLPAPER_DIRS="$1" "$2" --list-folders', "npaper-fl", root.dirs.join("|"), root.scriptPath];
    listProcess.command = ["bash", "-c", 'NPAPER_WALLPAPER_DIRS="$1" "$2" --list-with-folders', "npaper-lwf", root.dirs.join("|"), root.scriptPath];
    folderListProcess.exec({});
  }

  // ========== Processes ==========

  Process {
    id: folderListProcess
    stdout: StdioCollector {
      onStreamFinished: {
        const f = text.trim().split('\n').filter(s => s.length > 0);
        root.folders = f;
        if (f.length > 0)
          root.currentFolder = f[0];
        if (root.debugMode)
          Logger.d("LocalSource: Folders:", f);
        listProcess.exec({});
      }
    }
    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0) {
        if (root.debugMode)
          Logger.d("LocalSource: folderListProcess failed, falling back");
        root.folders = ["wallpapers"];
        root.currentFolder = "wallpapers";
        listProcess.exec({});
      }
    }
  }

  Process {
    id: listProcess
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split('\n').filter(l => l.length > 0);
        const folderMap = {};
        lines.forEach(line => {
          const sepIdx = line.indexOf('|');
          if (sepIdx > 0) {
            const folder = line.substring(0, sepIdx);
            const path = line.substring(sepIdx + 1);
            if (!folderMap[folder])
              folderMap[folder] = [];
            folderMap[folder].push(path);
          }
        });
        root.wallpaperMap = folderMap;
        Logger.i("LocalSource: loaded", lines.length, "wallpapers into", Object.keys(folderMap).length, "folders");
        root.dataLoaded();
      }
    }
    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0 && root.debugMode)
        Logger.d("LocalSource: listProcess failed, exitCode:", exitCode);
    }
  }
}
