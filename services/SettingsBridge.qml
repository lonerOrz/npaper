import QtQuick
import qs.services

/*
 * SettingsBridge — bridge between SettingsService and UI layer.
 *
 * Exposes a viewModel with typed sub-objects that AppWindow and
 * SettingsPanel consume. Never call SettingsService directly from UI.
 */
Item {
  id: root

  required property SettingsService settings

  readonly property alias settingsService: root.settings

  property var viewModel: null

  Connections {
    target: settings
    function onDataLoaded()  { _buildViewModel(); }
    function onDataChanged() { _syncViewModel(); }
  }

  Component.onCompleted: {
    if (settings.ready) _buildViewModel();
  }

  function _buildViewModel() {
    var c = settings.config;
    root.viewModel = {
      layout: {
        carouselItemWidth:   c.carousel.itemWidth,
        carouselItemHeight:  c.carousel.itemHeight,
        carouselSpacing:     c.carousel.spacing,
        carouselRotation:    c.carousel.rotation,
        carouselPerspective: c.carousel.perspective
      },
      appearance: {
        showBorderGlow:  c.appearance.showBorderGlow,
        showShadow:      c.appearance.showShadow,
        showBgPreview:   c.appearance.showBgPreview,
        bgOverlayOpacity: c.appearance.bgOverlayOpacity
      },
      timing: {
        scrollDuration:         c.animation.scrollDuration,
        scrollContinueInterval: c.animation.scrollContinueInterval,
        bgSlideDuration:        c.animation.bgSlideDuration,
        bgParallaxFactor:       c.animation.bgParallaxFactor
      },
      system: {
        wallpaperDirs: c.wallpaperDirs,
        cacheDir:     c.cacheDir,
        debugMode:    c.debugMode,
        previewStyle: c.previewStyle
      },
      set: function(key, value) { settings.update(key, value); }
    };
  }

  function _syncViewModel() {
    if (!root.viewModel) return;
    var c = settings.config;
    root.viewModel.layout.carouselItemWidth   = c.carousel.itemWidth;
    root.viewModel.layout.carouselItemHeight  = c.carousel.itemHeight;
    root.viewModel.layout.carouselSpacing     = c.carousel.spacing;
    root.viewModel.layout.carouselRotation    = c.carousel.rotation;
    root.viewModel.layout.carouselPerspective = c.carousel.perspective;
    root.viewModel.appearance.showBorderGlow  = c.appearance.showBorderGlow;
    root.viewModel.appearance.showShadow      = c.appearance.showShadow;
    root.viewModel.appearance.showBgPreview   = c.appearance.showBgPreview;
    root.viewModel.appearance.bgOverlayOpacity = c.appearance.bgOverlayOpacity;
    root.viewModel.timing.scrollDuration         = c.animation.scrollDuration;
    root.viewModel.timing.scrollContinueInterval = c.animation.scrollContinueInterval;
    root.viewModel.timing.bgSlideDuration        = c.animation.bgSlideDuration;
    root.viewModel.timing.bgParallaxFactor       = c.animation.bgParallaxFactor;
    root.viewModel.system.wallpaperDirs       = c.wallpaperDirs;
    root.viewModel.system.cacheDir            = c.cacheDir;
    root.viewModel.system.debugMode           = c.debugMode;
    root.viewModel.system.previewStyle        = c.previewStyle;
  }
}
