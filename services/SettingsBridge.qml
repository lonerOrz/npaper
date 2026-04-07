import QtQuick
import qs.services

/*
* SettingsBridge — bridges Config (pure JS) → QtObject viewModel for UI.
*
* Uses QtObject hierarchy so QML bindings automatically track changes.
* No manual _syncViewModel needed — QML re-evaluates when Config.data changes.
*
* UI reads:  SettingsBridge.viewModel.layout.carouselSpacing
* UI writes: SettingsBridge.viewModel.set("carousel.spacing", 25)
*/
Item {
  id: root

  readonly property var config: Config

  // QtObject hierarchy — QML bindings auto-track Config.data changes
  property QtObject viewModel: QtObject {
    readonly property var layout: QtObject {
      property real carouselSpacing: Config.data.carousel.spacing
      property real carouselRotation: Config.data.carousel.rotation
      property real carouselPerspective: Config.data.carousel.perspective
    }
    readonly property var appearance: QtObject {
      property bool showBorderGlow: Config.data.appearance.showBorderGlow
      property bool showShadow: Config.data.appearance.showShadow
      property bool showBgPreview: Config.data.appearance.showBgPreview
      property real bgOverlayOpacity: Config.data.appearance.bgOverlayOpacity
    }
    readonly property var timing: QtObject {
      property int scrollDuration: Config.data.animation.scrollDuration
      property int scrollContinueInterval: Config.data.animation.scrollContinueInterval
      property int bgSlideDuration: Config.data.animation.bgSlideDuration
      property int bgParallaxFactor: Config.data.animation.bgParallaxFactor
    }
    readonly property var system: QtObject {
      property var wallpaperDirs: Config.data.wallpaperDirs
      property string cacheDir: Config.data.cacheDir
      property bool debugMode: Config.data.debugMode
      property string previewStyle: Config.data.previewStyle
    }
    function set(key, value) {
      Config.update(key, value);
    }
  }
}
