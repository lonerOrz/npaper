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
      property string downloadDir: Config.data.wallhaven.downloadDir || ""
    }
    readonly property var appearance: QtObject {
      property bool showShadow: Config.data.appearance ? Config.data.appearance.showShadow : true
      property bool showBgPreview: Config.data.appearance ? Config.data.appearance.showBgPreview : true
      property real bgOverlayOpacity: Config.data.appearance ? Config.data.appearance.bgOverlayOpacity : 0.4
    }
    readonly property var animation: QtObject {
      property int bgSlideDuration: Config.data.animation ? Config.data.animation.bgSlideDuration : Style.defaultBgSlideDuration
      property int bgParallaxFactor: Config.data.animation ? Config.data.animation.bgParallaxFactor : Style.defaultBgParallaxFactor
      property int scrollDuration: Config.data.animation ? Config.data.animation.scrollDuration : Style.defaultScrollDuration
      property int scrollContinueInterval: Config.data.animation ? Config.data.animation.scrollContinueInterval : Style.defaultScrollContinueInterval
    }
    readonly property var carousel: QtObject {
      property int spacing: Config.data.carousel ? Config.data.carousel.spacing : Style.defaultCarouselSpacing
      property int rotation: Config.data.carousel ? Config.data.carousel.rotation : Style.defaultCarouselRotation
      property real perspective: Config.data.carousel ? Config.data.carousel.perspective : Style.defaultCarouselPerspective
    }
    property string videoBackend: Config.data.videoBackend || "mpvpaper"
    property bool debugMode: Config.data.debugMode || false
    function set(key, value) {
      Config.update(key, value);
    }
  }
}
