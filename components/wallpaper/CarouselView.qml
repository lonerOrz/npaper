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
    if (!root.adapter || !root.cacheService || root.adapter.currentSource !== "local")
      return;
    const count = root.adapter.count;
    for (let i = root.baseIndex; i <= root.maxIndex && i < count; i++) {
      const item = root.adapter.getItem(i);
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
      _thumbQueueTimer.restart();
    }
  }

  Timer {
    id: _thumbQueueTimer
    interval: 80
    repeat: false
    onTriggered: queueVisibleThumbnails()
  }

  Item {
    id: pathViewContainer
    anchors.fill: parent
    focus: true
    clip: true

    readonly property int itemWidth: Style.carouselItemWidth
    readonly property int itemHeight: Style.carouselItemHeight
    readonly property real spacing: root.carouselSpacing
    readonly property real centerX: width / 2
    readonly property real centerY: height / 2

    MouseArea {
      anchors.fill: parent
      propagateComposedEvents: true
      onWheel: function (wheel) {
        let ticks = Math.round(Math.abs(wheel.angleDelta.y) / 120);
        if (ticks < 1)
          ticks = 1;
        const dir = wheel.angleDelta.y > 0 ? -1 : 1;
        const maxLimit = root.adapter ? root.adapter.count - 1 : 0;
        const base = Math.round(scrollController.scrollTarget);
        const target = Math.max(0, Math.min(base + dir * ticks, maxLimit));
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
          const item = root.adapter.getItem(root.currentIndex);
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
        if (event.modifiers & Qt.ShiftModifier) {
          dir === -1 ? scrollController.fastScrollLeft() : scrollController.fastScrollRight();
        } else {
          dir === -1 ? scrollController.scrollLeft() : scrollController.scrollRight();
        }

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
        readonly property int realIndex: scrollController.baseIndex + index
        readonly property var _item: root.adapter ? root.adapter.getItem(realIndex) : null

        wallpaperPath: _item ? _item.path : ""
        wallpaperItem: _item
        filename: _item ? _item.filename : ""
        isRemote: _item ? _item.type === "remote" : false
        remoteId: (_item && _item.type === "remote") ? _item.id : ""
        isCenter: realIndex === root.currentIndex
        showShadow: root.showShadow
        downloadPath: (_item && _item.type === "remote") ? _item.path : ""

        thumbHashToPath: root.cacheService ? root.cacheService.thumbHashToPath : ({})
        whService: root.whService
        itemIndex: realIndex

        readonly property real _offset: realIndex - scrollController.scrollTarget
        readonly property real _absOffset: Math.abs(_offset)
        readonly property real _perspScale: 1.0 / (1.0 + _absOffset * root.carouselPerspective)
        readonly property real _normFactor: Math.max(0, 1.0 - _absOffset * 0.16)

        visualScale: _perspScale * (0.86 + Math.max(0, 1.0 - _absOffset) * 0.14)
        visualOpacity: _absOffset > 5.5 ? 0.0 : (_normFactor * _normFactor)
        visualRotationY: _offset * -root.carouselRotation
        visualZ: Math.round(100 - _absOffset * 40)
        visualYOffset: _absOffset * 8
        visualShadowOpacity: _absOffset < 0.6 ? 0.25 : 0.0

        x: pathViewContainer.centerX - width / 2 + _offset * (width + pathViewContainer.spacing) * (0.84 - _absOffset * 0.05)
        y: pathViewContainer.centerY - height / 2 + visualYOffset

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
      opacity: 0.92

      Text {
        anchors.centerIn: parent
        anchors.leftMargin: Style.spaceXL
        anchors.rightMargin: Style.spaceXL
        text: "/ 搜索  •  ←/→ 浏览  •  Tab 换文件夹  •  [] 切换视图  •  Enter 应用  •  R 随机  •  S 设置  •  W 远程  •  Esc 退出"
        color: Color.mOnSurface
        font.pixelSize: Style.keyboardHintFontSize
        font.weight: Font.Medium
      }
    }
  }
}
