import QtQuick
import Quickshell
import qs.components.common
import qs.services

FocusScope {
  id: root

  readonly property var adapter: ServiceLocator.adapter
  readonly property var cacheService: ServiceLocator.cacheService
  readonly property var checkService: ServiceLocator.checks
  readonly property var whService: root.adapter ? root.adapter.whService : null

  property int carouselSpacing: 20
  property int carouselRotation: 25
  property real carouselPerspective: 0.3
  property int scrollDuration: 280
  property int scrollContinueInterval: 230
  property int parallaxFactor: 40
  property bool showBorderGlow: true
  property bool showShadow: true

  readonly property int currentIndex: scrollController.currentIndex
  readonly property real scrollTarget: scrollController.scrollTarget
  readonly property int baseIndex: scrollController.baseIndex
  readonly property int maxIndex: scrollController.maxIndex

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
    scrollController.reset();
  }

  function scrollTo(idx) {
    scrollController.scrollTo(idx);
  }

  function focusView() {
    pathViewContainer.forceActiveFocus();
  }

  function queueVisibleThumbnails() {
    if (!root.adapter || !root.cacheService)
      return;
    for (let i = root.baseIndex; i <= root.maxIndex && i < root.adapter.items.length; i++) {
      const item = root.adapter.items[i];
      if (item && item.type === "local")
        root.cacheService.queueThumbnail(item.path, item.isVideo, item.isGif);
    }
  }

  ScrollController {
    id: scrollController
    count: root.adapter ? root.adapter.count : 0
    visibleRange: Style.visibleRange
    preloadRange: Style.preloadRange
    animationDuration: root.scrollDuration
    scrollContinueInterval: root.scrollContinueInterval
    parallaxFactor: root.parallaxFactor

    onScrollTargetChanged: {
      queueVisibleThumbnails();
    }
  }

  Item {
    id: pathViewContainer
    anchors.fill: parent
    focus: true
    clip: true

    property int itemWidth: Style.carouselItemWidth
    property int itemHeight: Style.carouselItemHeight
    property real spacing: root.carouselSpacing
    property real centerX: width / 2
    property real centerY: height / 2

    Keys.onPressed: function (event) {
      if (event.key === Qt.Key_Escape) {
        root.requestQuit();
        event.accepted = true;
        return;
      }
      if (event.key === Qt.Key_S && !event.modifiers) {
        root.requestSettings();
        event.accepted = true;
        return;
      }
      if (event.key === Qt.Key_W && !event.modifiers) {
        root.requestToggleWallhaven();
        pathViewContainer.forceActiveFocus();
        event.accepted = true;
        return;
      }
      if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
        event.key === Qt.Key_Tab ? root.requestNextFolder() : root.requestPrevFolder();
        event.accepted = true;
        return;
      }
      if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BraceLeft || event.key === Qt.Key_BracketRight || event.key === Qt.Key_BraceRight) {
        event.accepted = true;
        root.requestToggleViewMode();
        return;
      }
      if (event.key === Qt.Key_Slash || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))) {
        root.requestFocusSearch();
        event.accepted = true;
        return;
      }
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        if (root.adapter && root.adapter.items.length > 0) {
          var item = root.adapter.items[root.currentIndex];
          if (item)
            root.adapter.smartApply(item);
        }
        event.accepted = true;
        return;
      }
      if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
        const dir = event.key === Qt.Key_Left ? -1 : 1;
        event.modifiers & Qt.ShiftModifier ? (dir === -1 ? scrollController.fastScrollLeft() : scrollController.fastScrollRight()) : (dir === -1 ? scrollController.scrollLeft() : scrollController.scrollRight());
        // Auto-load more when scrolling right at the end (Wallhaven remote mode)
        if (dir === 1 && root.adapter && root.adapter.currentSource === "remote"
            && root.whService && root.whService.hasMore && !root.whService.loading
            && root.maxIndex >= root.adapter.count - 2) {
          root.whService.loadMore();
        }
        event.accepted = true;
        return;
      }
      if (event.key === Qt.Key_R && !event.modifiers) {
        scrollController.random();
        root.requestRandom();
        event.accepted = true;
        return;
      }
      if (event.key === Qt.Key_F5) {
        root.requestRefresh();
        event.accepted = true;
        return;
      }
    }

    Keys.onReleased: function (event) {
      if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
        scrollController.handleKeyRelease(event.key === Qt.Key_Left ? -1 : 1);
        event.accepted = true;
      }
    }

    Repeater {
      model: scrollController.loadedCount
      delegate: WallpaperCard {
        required property int index
        property int realIndex: scrollController.baseIndex + index

        readonly property var _item: realIndex < (root.adapter ? root.adapter.items.length : 0) ? root.adapter.items[realIndex] : null
        wallpaperPath: _item ? (_item.type === "remote" ? _item.thumb : _item.path) : ""
        filename: _item ? _item.filename : ""
        isVideo: _item ? _item.isVideo : false
        isGif: _item ? _item.isGif : false
        isRemote: _item ? _item.type === "remote" : false
        remoteId: _item && _item.type === "remote" ? _item.id : ""
        remoteThumb: _item && _item.type === "remote" ? _item.thumb : ""
        isCenter: realIndex === root.currentIndex
        showBorderGlow: root.showBorderGlow
        showShadow: root.showShadow
        downloadPath: _item && _item.type === "remote" ? _item.path : ""

        // Pre-computed visual values to avoid JS object re-creation per frame
        readonly property real _absOffset: Math.abs(realIndex - scrollController.scrollTarget)
        readonly property real _cos: Math.cos(Math.min(_absOffset, 3) * 0.523599)
        readonly property real _perspScale: 1.0 / (1.0 + _absOffset * root.carouselPerspective)
        readonly property real _visualScale: _perspScale * (0.85 + _cos * 0.15) + (isCenter ? 0.06 : 0)
        readonly property real _visualOpacity: _absOffset > 6 ? 0 : Math.pow(Math.max(0, 1 - _absOffset * 0.12), 2.5)
        readonly property real _visualRotationY: (realIndex - scrollController.scrollTarget) * -root.carouselRotation
        readonly property int _visualZ: 100 - _absOffset * 50
        readonly property real _visualSpacingFactor: 0.85 - _absOffset * 0.06
        readonly property real _visualYOffset: _absOffset * 8
        readonly property real _visualShadowOpacity: _absOffset < 0.6 ? 0.25 : 0

        visualScale: _visualScale
        visualOpacity: _visualOpacity
        visualRotationY: _visualRotationY
        visualZ: _visualZ
        visualYOffset: _visualYOffset
        visualShadowOpacity: _visualShadowOpacity
        x: pathViewContainer.centerX - width / 2
           + (realIndex - scrollController.scrollTarget)
             * (width + pathViewContainer.spacing) * _visualSpacingFactor
        y: pathViewContainer.centerY - height / 2 + _visualYOffset
        onClicked: function (path) {
          scrollController.scrollTo(realIndex);
          if (_item)
            root.adapter.smartApply(_item);
        }
      }
    }

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.keyboardHintBottomMargin
      anchors.horizontalCenter: parent.horizontalCenter
      radius: Style.radiusRound
      color: Color.mSurfaceContainer
      opacity: 0.85

      Text {
        anchors.centerIn: parent
        anchors.leftMargin: Style.spaceXL
        anchors.rightMargin: Style.spaceXL
        text: "/ Search  •  ←/→ Navigate  •  Tab Folder  •  [] Toggle View  •  Enter Apply  •  R Random  •  S Settings  •  W Wallhaven  •  Esc Quit"
        color: Color.mOnSurface
        font.pixelSize: Style.keyboardHintFontSize
        font.weight: Font.Medium
        style: Text.Outline
        styleColor: Color.mScrim
        opacity: 0.9
      }
    }
  }
}
