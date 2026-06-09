import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/CacheUtils.js" as CacheUtils
import "../utils/FileTypes.js" as FileTypes
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

  property var cacheService: null

  property string currentFolder: ""
  property var folders: []
  property var wallpaperMap: ({})
  property string searchText: ""
  property bool _internalUpdate: false

  readonly property alias items: localModel

  signal dataLoaded

  onCurrentFolderChanged: _updateItems()
  onSearchTextChanged: _updateItems()
  onWallpaperMapChanged: {
    if (!_internalUpdate) {
      _updateItems();
    }
  }

  ListModel {
    id: localModel
  }

  Connections {
    target: root.cacheService || null
    function onCacheScanned() {
      root._updateItems();
    }
    function onThumbnailGenerated(path, thumbPath, bgPath, animPath) {
      let len = localModel.count;
      for (let i = 0; i < len; i++) {
        let item = localModel.get(i);
        if (item && item.path === path) {
          localModel.setProperty(i, "thumb", "file://" + thumbPath);
          break;
        }
      }
    }
  }

  function _updateItems() {
    localModel.clear();
    const folder = root.wallpaperMap[root.currentFolder];
    if (!folder) {
      if (root.debugMode)
        Logger.d("LocalSource: No folder found:", root.currentFolder);
      return;
    }

    let filtered;
    if (!root.searchText) {
      filtered = folder;
    } else {
      const lower = root.searchText.toLowerCase();
      filtered = folder.filter(p => p.toLowerCase().includes(lower));
    }

    let len = filtered.length;
    for (let i = 0; i < len; i++) {
      localModel.append(_makeItem(filtered[i]));
    }
  }

  function _makeItem(path) {
    const thumbMap = root.thumbHashToPath || {};
    const cachedThumb = CacheUtils.resolveThumb(thumbMap, path);
    const cachedBg = CacheUtils.resolveBgPreview(thumbMap, path);
    let resolvedThumb = "";

    if (cachedThumb) {
      resolvedThumb = "file://" + cachedThumb;
    } else if (cachedBg) {
      resolvedThumb = "file://" + cachedBg;
    } else if (!FileTypes.isVideoFile(path) && !FileTypes.isGifFile(path)) {
      resolvedThumb = "file://" + path;
    }

    return {
      id: path,
      type: "local",
      path: path,
      thumb: resolvedThumb,
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
    const prevFolder = root.currentFolder;
    var _cs = cacheService;
    var _onDone = function () {
      if (prevFolder && root.folders.includes(prevFolder))
        root.currentFolder = prevFolder;
      if (_cs && root.currentFolder && root.wallpaperMap[root.currentFolder]) {
        _cs.refreshAndQueue(root.wallpaperMap[root.currentFolder], root.currentFolder);
      }
      root.dataLoaded.disconnect(_onDone);
    };
    root.dataLoaded.connect(_onDone);
    root.load();
  }

  function load() {
    if (!root.dirs || root.dirs.length === 0 || !root.scriptPath) {
      if (root.debugMode)
        Logger.d("LocalSource: Skipping load due to missing dirs or scriptPath");
      return;
    }
    listProcess.command = ["bash", "-c", 'NPAPER_WALLPAPER_DIRS="$1" "$2" --list-with-folders', "npaper-lwf", (root.dirs || []).join("|"), root.scriptPath];
    listProcess.exec({});
  }

  function deleteWallpaper(path, idx) {
    if (!path)
      return;

    if (idx >= 0 && idx < localModel.count) {
      localModel.remove(idx);
    }

    let folder = root.currentFolder;
    let map = Object.assign({}, root.wallpaperMap);
    if (map[folder]) {
      map[folder] = map[folder].filter(p => p !== path);
      root._internalUpdate = true;
      root.wallpaperMap = map;
      root._internalUpdate = false;
    }

    deleteProcess.command = ["rm", "-f", path];
    deleteProcess.exec({});
  }

  function moveWallpaper(path, targetFolder, idx) {
    if (!path || !targetFolder)
      return;

    if (idx >= 0 && idx < localModel.count) {
      localModel.remove(idx);
    }

    let srcFolder = root.currentFolder;
    let map = Object.assign({}, root.wallpaperMap);
    if (map[srcFolder]) {
      map[srcFolder] = map[srcFolder].filter(p => p !== path);
    }

    let dest = _getDestinationPath(path, targetFolder);
    if (dest) {
      if (!map[targetFolder]) {
        map[targetFolder] = [];
      }
      map[targetFolder].push(dest);
      root._internalUpdate = true;
      root.wallpaperMap = map;
      root._internalUpdate = false;

      let destDir = dest.substring(0, dest.lastIndexOf('/'));
      moveProcess.command = ["sh", "-c", "mkdir -p \"$1\" && mv \"$2\" \"$3\"", "npaper-mv", destDir, path, dest];
      moveProcess.exec({});
    }
  }

  function _getDestinationPath(path, targetFolder) {
    const filename = path.split('/').pop();
    let baseDir = "";
    for (let i = 0; i < root.dirs.length; i++) {
      let d = root.dirs[i];
      if (path.indexOf(d) === 0) {
        baseDir = d;
        break;
      }
    }
    if (!baseDir)
      return "";

    for (let j = 0; j < root.dirs.length; j++) {
      let d = root.dirs[j];
      let baseName = d.split('/').filter(s => s !== "").pop();
      if (baseName === targetFolder) {
        return d + "/" + filename;
      }
    }

    return baseDir + "/" + targetFolder + "/" + filename;
  }

  Process {
    id: deleteProcess
  }

  Process {
    id: moveProcess
  }

  Process {
    id: listProcess
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split('\n').filter(l => l.length > 0);
        const folderMap = {};
        const folderList = [];
        lines.forEach(line => {
                        const sepIdx = line.indexOf('|');
                        if (sepIdx > 0) {
                          const folder = line.substring(0, sepIdx);
                          const path = line.substring(sepIdx + 1);
                          if (!folderMap[folder]) {
                            folderMap[folder] = [];
                            folderList.push(folder);
                          }
                          folderMap[folder].push(path);
                        }
                      });
        root.wallpaperMap = folderMap;
        root.folders = folderList;
        if (folderList.length > 0 && !folderList.includes(root.currentFolder)) {
          root.currentFolder = folderList[0];
        }
        root._updateItems();
        Logger.i("LocalSource: loaded", lines.length, "wallpapers into", folderList.length, "folders");
        root.dataLoaded();
      }
    }
    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0 && root.debugMode)
        Logger.d("LocalSource: listProcess failed, exitCode:", exitCode);
    }
  }
}
