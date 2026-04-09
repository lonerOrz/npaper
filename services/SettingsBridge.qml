import QtQuick
import qs.services

/*
* SettingsBridge — bridges Config (pure JS) → QtObject viewModel for UI.
*
* Uses QtObject hierarchy so QML bindings automatically track changes.
*/
Item {
  id: root

  readonly property var config: Config

  // QtObject hierarchy — QML bindings auto-track Config.data changes
  property QtObject viewModel: QtObject {
    readonly property var paths: QtObject {
      property var wallpaperDirs: Config.data.wallpaperDirs
      property string cacheDir: Config.data.cacheDir
    }
    readonly property var wallhaven: QtObject {
      property string apiKey: Config.data.wallhaven.apiKey
      property string categories: Config.data.wallhaven.categories
      property string purity: Config.data.wallhaven.purity
      property string sorting: Config.data.wallhaven.sorting
    }
    function set(key, value) {
      Config.update(key, value);
    }
  }
}
