import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/FileTypes.js" as FileTypes
import qs.utils

Item {
  id: root

  property var dirs: []
  property string scriptPath: ""
  property bool debugMode: false

  property string currentFolder: ""
  property var folders: []
  property var wallpaperMap: ({})

  property string searchText: ""
  signal dataLoaded

  readonly property var list: _filterList()
  readonly property var filenames: _extractFilenames(list)
  readonly property int count: list.length

  // ========== Logic ==========

  function _filterList() {
    const folder = root.wallpaperMap[root.currentFolder];
    if (!folder)
      return [];
    if (!root.searchText)
      return folder;
    const lower = root.searchText.toLowerCase();
    return folder.filter(p => p.toLowerCase().includes(lower));
  }

  function _extractFilenames(paths) {
    return paths.map(p => p.split('/').pop());
  }

  function switchFolder(folder) {
    if (root.debugMode)
      Logger.d("Switch folder:", folder);
    root.currentFolder = folder;
    root.searchText = "";
  }

  function refresh(folder, cacheService) {
    if (!cacheService)
      return;
    if (root.debugMode)
      Logger.d("Refresh folder:", folder);
    const paths = root.wallpaperMap[folder] || [];
    if (paths.length === 0)
      return;
    cacheService.refreshAndQueue(paths, folder);
  }

  function load() {
    if (root.dirs.length === 0 || !root.scriptPath) {
      if (root.debugMode)
        Logger.d("Model: Skipping load due to missing dirs or scriptPath");
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
          Logger.d("Folders:", f);
        listProcess.exec({});
      }
    }
    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0) {
        if (root.debugMode)
          Logger.d("folderListProcess failed, falling back");
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
        if (root.debugMode)
          Logger.d("Model: loaded", lines.length, "wallpapers");
        root.dataLoaded();
      }
    }
    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0 && root.debugMode)
        Logger.d("listProcess failed, exitCode:", exitCode);
    }
  }
}
