import QtQuick
import qs.services

/*
 * SettingsBridge — bridges Config JsonAdapter → plain JS viewModel for UI.
 *
 * UI reads:  SettingsBridge.viewModel.layout.carouselItemWidth
 * UI writes: SettingsBridge.viewModel.set("carousel.itemWidth", 450)
 *
 * viewModel is a plain JS object. _syncViewModel() manually updates all
 * properties on hot-reload.
 */
Item {
  id: root

  readonly property var config: Config

  property var viewModel: null

  Connections {
    target: Config
    function onDataLoaded()  { _buildViewModel(); }
    function onDataUpdated() { _syncViewModel(); }
  }

  Component.onCompleted: {
    if (Config.isLoaded) _buildViewModel();
  }

  function _buildViewModel() {
    var d = Config.data;
    root.viewModel = {
      layout: {
        carouselItemWidth:   d.carousel.itemWidth,
        carouselItemHeight:  d.carousel.itemHeight,
        carouselSpacing:     d.carousel.spacing,
        carouselRotation:    d.carousel.rotation,
        carouselPerspective: d.carousel.perspective
      },
      appearance: {
        showBorderGlow:   d.appearance.showBorderGlow,
        showShadow:       d.appearance.showShadow,
        showBgPreview:    d.appearance.showBgPreview,
        bgOverlayOpacity: d.appearance.bgOverlayOpacity
      },
      timing: {
        scrollDuration:         d.animation.scrollDuration,
        scrollContinueInterval: d.animation.scrollContinueInterval,
        bgSlideDuration:        d.animation.bgSlideDuration,
        bgParallaxFactor:       d.animation.bgParallaxFactor
      },
      system: {
        wallpaperDirs: d.wallpaperDirs,
        cacheDir:     d.cacheDir,
        debugMode:    d.debugMode,
        previewStyle: d.previewStyle
      },
      set: function(key, value) {
        var parts = key.split(".");
        var obj = Config.data;
        for (var i = 0; i < parts.length - 1; i++)
          obj = obj[parts[i]];
        obj[parts[parts.length - 1]] = value;
      }
    };
  }

  function _syncViewModel() {
    if (!root.viewModel) return;
    var d = Config.data;
    root.viewModel.layout.carouselItemWidth   = d.carousel.itemWidth;
    root.viewModel.layout.carouselItemHeight  = d.carousel.itemHeight;
    root.viewModel.layout.carouselSpacing     = d.carousel.spacing;
    root.viewModel.layout.carouselRotation    = d.carousel.rotation;
    root.viewModel.layout.carouselPerspective = d.carousel.perspective;
    root.viewModel.appearance.showBorderGlow  = d.appearance.showBorderGlow;
    root.viewModel.appearance.showShadow      = d.appearance.showShadow;
    root.viewModel.appearance.showBgPreview   = d.appearance.showBgPreview;
    root.viewModel.appearance.bgOverlayOpacity = d.appearance.bgOverlayOpacity;
    root.viewModel.timing.scrollDuration         = d.animation.scrollDuration;
    root.viewModel.timing.scrollContinueInterval = d.animation.scrollContinueInterval;
    root.viewModel.timing.bgSlideDuration        = d.animation.bgSlideDuration;
    root.viewModel.timing.bgParallaxFactor       = d.animation.bgParallaxFactor;
    root.viewModel.system.wallpaperDirs       = d.wallpaperDirs;
    root.viewModel.system.cacheDir            = d.cacheDir;
    root.viewModel.system.debugMode           = d.debugMode;
    root.viewModel.system.previewStyle        = d.previewStyle;
  }
}
