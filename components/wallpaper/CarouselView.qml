import QtQuick
import Quickshell
import qs.components.common
import qs.services

FocusScope {
  id: root

  property var adapter: null
  property var cacheService: null
  property var checkService: null
  property var appViewModel: null
  property var wallhavenFilter: null
  readonly property var whService: root.adapter ? root.adapter.whService : null

  property int carouselSpacing: 20
  property int carouselRotation: 25
  property real carouselPerspective: 0.3
  property int scrollDuration: 280
  property int scrollContinueInterval: 230
  property int parallaxFactor: 40
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
    var items = root.adapter.items;
    if (!items)
      return;
    var count = items.count !== undefined ? items.count : items.length;
    for (let i = root.baseIndex; i <= root.maxIndex && i < count; i++) {
      const item = items.get !== undefined ? items.get(i) : items[i];
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

    MouseArea {
      anchors.fill: parent
      propagateComposedEvents: true
      onWheel: function (wheel) {
        var ticks = Math.round(Math.abs(wheel.angleDelta.y) / 120);
        if (ticks < 1)
          ticks = 1;
        var dir = wheel.angleDelta.y > 0 ? -1 : 1;
        var target = Math.max(0, Math.min(scrollController.currentIndex + dir * ticks, root.adapter ? root.adapter.count - 1 : 0));
        scrollController.scrollTo(target);
      }
      onPressed: mouse => mouse.accepted = false
      onReleased: mouse => mouse.accepted = false
      onClicked: mouse => mouse.accepted = false
    }

    KeyboardHandler {
      id: kbdHandler
      appViewModel: root.appViewModel
      wallhavenFilter: root.wallhavenFilter
      onApplyRequested: {
        if (root.adapter && root.adapter.count > 0) {
          var item = root.adapter.getItem(root.currentIndex);
          if (item)
            root.adapter.smartApply(item);
        }
      }
      onRandomRequested: scrollController.random()
      onWallhavenToggled: pathViewContainer.forceActiveFocus()
    }
    Keys.onPressed: function (event) {
      kbdHandler.handleKeyPress(event);
      if (event.accepted)
        return;
      if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
        const dir = event.key === Qt.Key_Left ? -1 : 1;
        event.modifiers & Qt.ShiftModifier ? (dir === -1 ? scrollController.fastScrollLeft() : scrollController.fastScrollRight()) : (dir === -1 ? scrollController.scrollLeft() : scrollController.scrollRight());
        if (dir === 1 && root.adapter && root.adapter.currentSource === "remote" && root.whService && root.whService.hasMore && !root.whService.loading && root.maxIndex >= root.adapter.count - 2) {
          root.whService.loadMore();
        }
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

        readonly property var _item: {
          if (!root.adapter || !root.adapter.items)
            return null;
          var items = root.adapter.items;
          var count = items.count !== undefined ? items.count : items.length;
          if (realIndex >= 0 && realIndex < count) {
            return items.get !== undefined ? items.get(realIndex) : items[realIndex];
          }
          return null;
        }
        wallpaperPath: _item ? _item.path : ""
        wallpaperItem: _item
        filename: _item ? _item.filename : ""
        isRemote: _item ? _item.type === "remote" : false
        remoteId: _item && _item.type === "remote" ? _item.id : ""
        isCenter: realIndex === root.currentIndex
        showShadow: root.showShadow
        downloadPath: _item && _item.type === "remote" ? _item.path : ""

        thumbHashToPath: root.cacheService ? root.cacheService.thumbHashToPath : ({})
        whService: root.whService
        itemIndex: realIndex

        readonly property real _absOffset: Math.abs(realIndex - scrollController.scrollTarget)
        readonly property real _cos: Math.cos(Math.min(_absOffset, 3) * 0.523599)
        readonly property real _perspScale: 1.0 / (1.0 + _absOffset * root.carouselPerspective)
        readonly property real _visualScale: _perspScale * (0.85 + _cos * 0.15) + (Math.max(0, 1 - _absOffset) * 0.06)
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
        x: pathViewContainer.centerX - width / 2 + (realIndex - scrollController.scrollTarget) * (width + pathViewContainer.spacing) * _visualSpacingFactor
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
