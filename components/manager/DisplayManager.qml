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
  property var configViewModel: null

  property int carouselSpacing: configViewModel ? configViewModel.carousel.spacing : Style.defaultCarouselSpacing
  property int carouselRotation: configViewModel ? configViewModel.carousel.rotation : Style.defaultCarouselRotation
  property real carouselPerspective: configViewModel ? configViewModel.carousel.perspective : Style.defaultCarouselPerspective
  property int scrollDuration: configViewModel ? configViewModel.animation.scrollDuration : Style.defaultScrollDuration
  property int scrollContinueInterval: configViewModel ? configViewModel.animation.scrollContinueInterval : Style.defaultScrollContinueInterval
  property int parallaxFactor: configViewModel ? configViewModel.animation.bgParallaxFactor : Style.defaultBgParallaxFactor

  property bool _carouselLoaded: root.displayMode === "carousel"
  property bool _gridLoaded: root.displayMode === "grid"
  property bool _slantedLoaded: root.displayMode === "slanted"

  readonly property var _activeView: {
    if (root.displayMode === "grid")
      return gridLoader.item;
    if (root.displayMode === "slanted")
      return slantedLoader.item;
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
    else if (root.displayMode === "slanted" && slantedLoader.item)
      slantedLoader.item.queueVisibleThumbnails();
    else if (carouselLoader.item)
      carouselLoader.item.queueVisibleThumbnails();
  }

  onDisplayModeChanged: {
    if (root.displayMode === "carousel")
      _carouselLoaded = true;
    else if (root.displayMode === "grid")
      _gridLoaded = true;
    else if (root.displayMode === "slanted")
      _slantedLoaded = true;

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
    else if (root.displayMode === "slanted")
      _slantedLoaded = true;

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
      showBorderGlow: root.configViewModel ? root.configViewModel.appearance.showBorderGlow : true
      showShadow: root.configViewModel ? root.configViewModel.appearance.showShadow : true

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
    id: slantedLoader
    anchors.fill: parent
    active: root._slantedLoaded
    visible: root.displayMode === "slanted"
    asynchronous: true
    focus: visible

    onLoaded: {
      if (item) {
        item.scrollTo(root._lastActiveIndex);
        if (root.displayMode === "slanted") {
          item.focusView();
        }
        root.queueVisibleThumbnails();
      }
    }

    sourceComponent: SlantedView {
      adapter: root.adapter
      cacheService: root.cacheService
      checkService: root.checkService

      scrollDuration: root.scrollDuration
      scrollContinueInterval: root.scrollContinueInterval
      parallaxFactor: root.parallaxFactor
      showBorderGlow: root.configViewModel ? root.configViewModel.appearance.showBorderGlow : true
      showShadow: root.configViewModel ? root.configViewModel.appearance.showShadow : true

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
