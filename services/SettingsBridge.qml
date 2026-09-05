import QtQuick
import qs.services

QtObject {
  id: root

  readonly property QtObject viewModel: QtObject {
    id: vm

    readonly property var paths: QtObject {
      property var wallpaperDirs: (Config.data && Config.data.wallpaperDirs) ? Config.data.wallpaperDirs : []
      property string cacheDir: (Config.data && Config.data.cacheDir) ? Config.data.cacheDir : ""
    }

    readonly property var wallhaven: QtObject {
      property string apiKey: (Config.data && Config.data.wallhaven) ? (Config.data.wallhaven.apiKey || "") : ""
      property string categories: (Config.data && Config.data.wallhaven) ? (Config.data.wallhaven.categories || "111") : "111"
      property string purity: (Config.data && Config.data.wallhaven) ? (Config.data.wallhaven.purity || "100") : "100"
      property string sorting: (Config.data && Config.data.wallhaven) ? (Config.data.wallhaven.sorting || "toplist") : "toplist"
      property string downloadDir: (Config.data && Config.data.wallhaven) ? (Config.data.wallhaven.downloadDir || "") : ""
    }

    readonly property var appearance: QtObject {
      property bool showShadow: (Config.data && Config.data.appearance) ? !!Config.data.appearance.showShadow : true
      property bool showBgPreview: (Config.data && Config.data.appearance) ? !!Config.data.appearance.showBgPreview : true
      property real bgOverlayOpacity: (Config.data && Config.data.appearance && Config.data.appearance.bgOverlayOpacity !== undefined) ? Config.data.appearance.bgOverlayOpacity : 0.4
    }

    readonly property var animation: QtObject {
      property int bgSlideDuration: (Config.data && Config.data.animation && Config.data.animation.bgSlideDuration !== undefined) ? Config.data.animation.bgSlideDuration : Style.defaultBgSlideDuration
      property int bgParallaxFactor: (Config.data && Config.data.animation && Config.data.animation.bgParallaxFactor !== undefined) ? Config.data.animation.bgParallaxFactor : Style.defaultBgParallaxFactor
      property int scrollDuration: (Config.data && Config.data.animation && Config.data.animation.scrollDuration !== undefined) ? Config.data.animation.scrollDuration : Style.defaultScrollDuration
      property int scrollContinueInterval: (Config.data && Config.data.animation && Config.data.animation.scrollContinueInterval !== undefined) ? Config.data.animation.scrollContinueInterval : Style.defaultScrollContinueInterval
    }

    readonly property var carousel: QtObject {
      property int spacing: (Config.data && Config.data.carousel && Config.data.carousel.spacing !== undefined) ? Config.data.carousel.spacing : Style.defaultCarouselSpacing
      property int rotation: (Config.data && Config.data.carousel && Config.data.carousel.rotation !== undefined) ? Config.data.carousel.rotation : Style.defaultCarouselRotation
      property real perspective: (Config.data && Config.data.carousel && Config.data.carousel.perspective !== undefined) ? Config.data.carousel.perspective : Style.defaultCarouselPerspective
    }

    property string videoBackend: (Config.data && Config.data.videoBackend) ? Config.data.videoBackend : "mpvpaper"
    property bool debugMode: (Config.data && Config.data.debugMode) ? !!Config.data.debugMode : false

    function set(key, value) {
      Config.update(key, value);
    }
  }
}
