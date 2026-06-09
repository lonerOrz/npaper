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

  property bool _carouselLoaded: root.displayMode === "carousel"
  property bool _gridLoaded: root.displayMode === "grid"
  property bool _helixLoaded: root.displayMode === "helix"

  readonly property var _activeView: {
    if (root.displayMode === "grid")
      return gridLoader.item;
    if (root.displayMode === "helix")
      return helixLoader.item;
    return carouselLoader.item;
  }

  signal toggleViewMode
  readonly property int currentIndex: _activeView ? _activeView.currentIndex : _lastActiveIndex
  readonly property real scrollTarget: _activeView ? _activeView.scrollTarget : _lastActiveIndex
  readonly property real contentOffset: _activeView ? _activeView.scrollTarget - _activeView.currentIndex : 0

  property int _lastActiveIndex: 0

  onCurrentIndexChanged: {
    if (_activeView) {
      _lastActiveIndex = _activeView.currentIndex;
    }
  }

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
    _lastActiveIndex = idx;
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
    if (root.displayMode === "grid" && gridLoader.item)
      gridLoader.item.queueVisibleThumbnails();
    else if (root.displayMode === "helix" && helixLoader.item)
      helixLoader.item.queueVisibleThumbnails();
    else if (carouselLoader.item)
      carouselLoader.item.queueVisibleThumbnails();
  }

  onDisplayModeChanged: {
    if (root.displayMode === "carousel")
      _carouselLoaded = true;
    else if (root.displayMode === "grid")
      _gridLoaded = true;
    else if (root.displayMode === "helix")
      _helixLoaded = true;

    _syncIndexAndFocus();
  }

  function _syncIndexAndFocus() {
    if (_activeView) {
      _activeView.scrollTo(_lastActiveIndex);
      _activeView.focusView();
      root.queueVisibleThumbnails();
    }
  }

  Component.onCompleted: {
    if (root.displayMode === "carousel")
      _carouselLoaded = true;
    else if (root.displayMode === "grid")
      _gridLoaded = true;
    else if (root.displayMode === "helix")
      _helixLoaded = true;

    Qt.callLater(root.queueVisibleThumbnails);
  }

  Loader {
    id: carouselLoader
    anchors.fill: parent
    active: root._carouselLoaded
    visible: root.displayMode === "carousel"
    asynchronous: true
    focus: visible

    onLoaded: {
      if (item) {
        item.scrollTo(root._lastActiveIndex);
        if (root.displayMode === "carousel") {
          item.focusView();
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
    active: root._gridLoaded
    visible: root.displayMode === "grid"
    asynchronous: true
    focus: visible

    onLoaded: {
      if (item) {
        item.scrollTo(root._lastActiveIndex);
        if (root.displayMode === "grid") {
          item.focusView();
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

  Loader {
    id: helixLoader
    anchors.fill: parent
    active: root._helixLoaded
    visible: root.displayMode === "helix"
    asynchronous: true
    focus: visible

    onLoaded: {
      if (item) {
        item.scrollTo(root._lastActiveIndex);
        if (root.displayMode === "helix") {
          item.focusView();
        }
        root.queueVisibleThumbnails();
      }
    }

    sourceComponent: HelixView {
      adapter: root.adapter
      cacheService: root.cacheService
      checkService: root.checkService

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
}
