import QtQuick
import qs.components.wallpaper
import qs.services

FocusScope {
  id: root

  focus: true

  property string displayMode: Config.previewStyle

  property var adapter: null
  property var cacheService: null
  property var wallpaperApplier: null
  property var checkService: null

  property int carouselSpacing: Config.data.carousel ? Config.data.carousel.spacing : Style.defaultCarouselSpacing
  property int carouselRotation: Config.data.carousel ? Config.data.carousel.rotation : Style.defaultCarouselRotation
  property real carouselPerspective: Config.data.carousel ? Config.data.carousel.perspective : Style.defaultCarouselPerspective
  property int scrollDuration: Config.data.animation ? Config.data.animation.scrollDuration : Style.defaultScrollDuration
  property int scrollContinueInterval: Config.data.animation ? Config.data.animation.scrollContinueInterval : Style.defaultScrollContinueInterval
  property int parallaxFactor: Config.data.animation ? Config.data.animation.bgParallaxFactor : Style.defaultBgParallaxFactor

  readonly property var _activeView: root.displayMode !== "grid" ? carouselLoader.item : gridLoader.item

  signal toggleViewMode
  readonly property int currentIndex: _activeView ? _activeView.currentIndex : 0
  readonly property real scrollTarget: _activeView ? _activeView.scrollTarget : 0
  readonly property real contentOffset: _activeView ? _activeView.scrollTarget - _activeView.currentIndex : 0

  signal requestQuit
  signal requestSettings
  signal requestPrevFolder
  signal requestNextFolder
  signal requestFocusSearch
  signal requestApplyItem(var item)
  signal requestRandom
  signal requestToggleWallhaven
  signal requestRefresh
  signal requestToggleViewMode

  function reset() {
    if (_activeView)
      _activeView.reset();
  }

  function scrollTo(idx) {
    if (_activeView)
      _activeView.scrollTo(idx);
  }

  function focusView() {
    if (_activeView)
      _activeView.focusView();
  }

  function queueVisibleThumbnails() {
    if (!root.cacheService || !root.adapter)
      return;
    if (root.adapter.currentSource !== "local")
      return;
    if (root.displayMode !== "grid" && carouselLoader.item)
      carouselLoader.item.queueVisibleThumbnails();
    else if (root.displayMode === "grid" && gridLoader.item)
      gridLoader.item.queueVisibleThumbnails();
  }

  onDisplayModeChanged: {
    _syncIndexAndFocus();
  }

  function _syncIndexAndFocus() {
    if (!carouselLoader.item || !gridLoader.item)
      return;

    if (root.displayMode === "grid") {
      let savedIdx = carouselLoader.item.currentIndex;
      gridLoader.item.scrollTo(savedIdx);
      gridLoader.item.focusView();
    } else {
      let savedIdx = gridLoader.item.currentIndex;
      carouselLoader.item.scrollTo(savedIdx);
      carouselLoader.item.focusView();
    }
    root.queueVisibleThumbnails();
  }

  Component.onCompleted: {
    Qt.callLater(root.queueVisibleThumbnails);
  }

  Loader {
    id: carouselLoader
    anchors.fill: parent
    active: true
    visible: root.displayMode !== "grid"
    asynchronous: true
    focus: visible

    onLoaded: {
      if (item) {
        if (root.displayMode !== "grid") {
          item.focusView();
        } else if (gridLoader.item) {
          item.scrollTo(gridLoader.item.currentIndex);
        }
        root.queueVisibleThumbnails();
      }
    }

    sourceComponent: CarouselView {
      adapter: root.adapter
      cacheService: root.cacheService
      checkService: root.checkService

      carouselSpacing: root.carouselSpacing
      carouselRotation: root.carouselRotation
      carouselPerspective: root.carouselPerspective
      scrollDuration: root.scrollDuration
      scrollContinueInterval: root.scrollContinueInterval
      parallaxFactor: root.parallaxFactor
      showBorderGlow: Config.data.appearance ? Config.data.appearance.showBorderGlow : true
      showShadow: Config.data.appearance ? Config.data.appearance.showShadow : true

      onRequestQuit: root.requestQuit()
      onRequestSettings: root.requestSettings()
      onRequestPrevFolder: root.requestPrevFolder()
      onRequestNextFolder: root.requestNextFolder()
      onRequestFocusSearch: root.requestFocusSearch()
      onRequestApplyItem: function (item) {
        root.requestApplyItem(item);
      }
      onRequestRandom: root.requestRandom()
      onRequestToggleWallhaven: root.requestToggleWallhaven()
      onRequestRefresh: root.requestRefresh()
      onRequestToggleViewMode: root.requestToggleViewMode()
    }
  }

  Loader {
    id: gridLoader
    anchors.fill: parent
    active: true
    visible: root.displayMode === "grid"
    asynchronous: true
    focus: visible

    onLoaded: {
      if (item) {
        if (root.displayMode === "grid") {
          item.focusView();
        } else if (carouselLoader.item) {
          item.scrollTo(carouselLoader.item.currentIndex);
        }
        root.queueVisibleThumbnails();
      }
    }

    sourceComponent: GridView {
      adapter: root.adapter
      cacheService: root.cacheService

      onRequestQuit: root.requestQuit()
      onRequestSettings: root.requestSettings()
      onRequestPrevFolder: root.requestPrevFolder()
      onRequestNextFolder: root.requestNextFolder()
      onRequestFocusSearch: root.requestFocusSearch()
      onRequestApplyItem: function (item) {
        root.requestApplyItem(item);
      }
      onRequestRandom: root.requestRandom()
      onRequestToggleWallhaven: root.requestToggleWallhaven()
      onRequestRefresh: root.requestRefresh()
      onRequestToggleViewMode: root.requestToggleViewMode()
    }
  }
}
