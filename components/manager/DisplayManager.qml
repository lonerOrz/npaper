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
  property var appViewModel: null
  property var wallhavenFilter: null

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

  readonly property int currentIndex: _activeView ? _activeView.currentIndex : _lastActiveIndex
  readonly property real scrollTarget: _activeView ? _activeView.scrollTarget : _lastActiveIndex
  readonly property real contentOffset: _activeView ? (_activeView.scrollTarget - _activeView.currentIndex) : 0

  property int _lastActiveIndex: 0

  onCurrentIndexChanged: {
    if (_activeView) {
      _lastActiveIndex = _activeView.currentIndex;
    }
  }

  function reset() {
    if (_activeView && typeof _activeView.reset === "function")
      _activeView.reset();
  }

  function scrollTo(idx) {
    _lastActiveIndex = idx;
    if (_activeView && typeof _activeView.scrollTo === "function")
      _activeView.scrollTo(idx);
  }

  function focusView() {
    root.forceActiveFocus();
    if (_activeView && typeof _activeView.focusView === "function")
      _activeView.focusView();
  }

  function queueVisibleThumbnails() {
    if (!root.cacheService || !root.adapter || root.adapter.currentSource !== "local")
      return;
    if (_activeView && typeof _activeView.queueVisibleThumbnails === "function") {
      _activeView.queueVisibleThumbnails();
    }
  }

  onDisplayModeChanged: {
    if (root.displayMode === "carousel")
      _carouselLoaded = true;
    else if (root.displayMode === "grid")
      _gridLoaded = true;
    else if (root.displayMode === "slanted")
      _slantedLoaded = true;

    if (_activeView) {
      _activeView.scrollTo(_lastActiveIndex);
      _activeView.focusView();
      queueVisibleThumbnails();
    }
  }

  Component.onCompleted: {
    Qt.callLater(root.queueVisibleThumbnails);
  }

  function _handleQuit() {
    if (appViewModel)
      appViewModel.handleRequestQuit();
  }
  function _handleSettings() {
    if (appViewModel)
      appViewModel.toggleSettings();
  }
  function _handlePrevFolder() {
    if (appViewModel)
      appViewModel.prevFolder();
  }
  function _handleNextFolder() {
    if (appViewModel)
      appViewModel.nextFolder();
  }
  function _handleFocusSearch() {
    if (appViewModel)
      appViewModel.focusSearch();
  }
  function _handleApplyItem(item) {
    if (appViewModel)
      appViewModel.applyItem(item);
  }
  function _handleToggleWallhaven() {
    if (appViewModel)
      appViewModel.handleRequestToggleWallhaven(root.wallhavenFilter);
  }
  function _handleRefresh() {
    if (appViewModel)
      appViewModel.refreshCache();
  }
  function _handleToggleViewMode() {
    if (appViewModel)
      appViewModel.handleRequestToggleViewMode();
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
        if (root.displayMode === "carousel")
          item.focusView();
        root.queueVisibleThumbnails();
      }
    }

    sourceComponent: CarouselView {
      adapter: root.adapter
      cacheService: root.cacheService
      checkService: root.checkService
      appViewModel: root.appViewModel
      wallhavenFilter: root.wallhavenFilter

      carouselSpacing: root.carouselSpacing
      carouselRotation: root.carouselRotation
      carouselPerspective: root.carouselPerspective
      scrollDuration: root.scrollDuration
      scrollContinueInterval: root.scrollContinueInterval
      parallaxFactor: root.parallaxFactor
      showShadow: root.configViewModel ? root.configViewModel.appearance.showShadow : true

      onRequestQuit: root._handleQuit
      onRequestSettings: root._handleSettings
      onRequestPrevFolder: root._handlePrevFolder
      onRequestNextFolder: root._handleNextFolder
      onRequestFocusSearch: root._handleFocusSearch
      onRequestApplyItem: root._handleApplyItem
      onRequestToggleWallhaven: root._handleToggleWallhaven
      onRequestRefresh: root._handleRefresh
      onRequestToggleViewMode: root._handleToggleViewMode
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
        if (root.displayMode === "grid")
          item.focusView();
        root.queueVisibleThumbnails();
      }
    }

    sourceComponent: GridView {
      adapter: root.adapter
      cacheService: root.cacheService
      appViewModel: root.appViewModel
      wallhavenFilter: root.wallhavenFilter

      onRequestQuit: root._handleQuit
      onRequestSettings: root._handleSettings
      onRequestPrevFolder: root._handlePrevFolder
      onRequestNextFolder: root._handleNextFolder
      onRequestFocusSearch: root._handleFocusSearch
      onRequestApplyItem: root._handleApplyItem
      onRequestToggleWallhaven: root._handleToggleWallhaven
      onRequestRefresh: root._handleRefresh
      onRequestToggleViewMode: root._handleToggleViewMode
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
        if (root.displayMode === "slanted")
          item.focusView();
        root.queueVisibleThumbnails();
      }
    }

    sourceComponent: SlantedView {
      adapter: root.adapter
      cacheService: root.cacheService
      checkService: root.checkService
      appViewModel: root.appViewModel
      wallhavenFilter: root.wallhavenFilter

      scrollDuration: root.scrollDuration
      scrollContinueInterval: root.scrollContinueInterval
      parallaxFactor: root.parallaxFactor
      showShadow: root.configViewModel ? root.configViewModel.appearance.showShadow : true

      onRequestQuit: root._handleQuit
      onRequestSettings: root._handleSettings
      onRequestPrevFolder: root._handlePrevFolder
      onRequestNextFolder: root._handleNextFolder
      onRequestFocusSearch: root._handleFocusSearch
      onRequestApplyItem: root._handleApplyItem
      onRequestToggleWallhaven: root._handleToggleWallhaven
      onRequestRefresh: root._handleRefresh
      onRequestToggleViewMode: root._handleToggleViewMode
    }
  }
}
