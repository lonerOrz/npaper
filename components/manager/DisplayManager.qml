import QtQuick
import qs.components.wallpaper
import qs.services

FocusScope {
  id: root

  focus: true

  property string displayMode: Config.previewStyle

  property int carouselSpacing: Config.data.carousel ? Config.data.carousel.spacing : Style.defaultCarouselSpacing
  property int carouselRotation: Config.data.carousel ? Config.data.carousel.rotation : Style.defaultCarouselRotation
  property real carouselPerspective: Config.data.carousel ? Config.data.carousel.perspective : Style.defaultCarouselPerspective
  property int scrollDuration: Config.data.animation ? Config.data.animation.scrollDuration : Style.defaultScrollDuration
  property int scrollContinueInterval: Config.data.animation ? Config.data.animation.scrollContinueInterval : Style.defaultScrollContinueInterval
  property int parallaxFactor: Config.data.animation ? Config.data.animation.bgParallaxFactor : Style.defaultBgParallaxFactor

  readonly property var _activeView: carouselLoader.active && carouselLoader.item ? carouselLoader.item : (gridLoader.item || null)

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
    if (!ServiceLocator.ready)
      return;
    if (ServiceLocator.adapter && ServiceLocator.adapter.currentSource !== "local")
      return;
    if (carouselLoader.item)
      carouselLoader.item.queueVisibleThumbnails();
    if (gridLoader.item)
      gridLoader.item.queueVisibleThumbnails();
  }

  Component.onCompleted: {
    Qt.callLater(root.queueVisibleThumbnails);
  }

  Loader {
    id: carouselLoader
    anchors.fill: parent
    active: root.displayMode !== "grid"
    asynchronous: true
    focus: active

    onLoaded: {
      if (item) {
        item.focusView();
        root.queueVisibleThumbnails();
      }
    }

    sourceComponent: CarouselView {
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
    active: root.displayMode === "grid"
    asynchronous: true
    focus: active

    onLoaded: {
      if (item) {
        item.focusView();
        root.queueVisibleThumbnails();
      }
    }

    sourceComponent: GridView {
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
