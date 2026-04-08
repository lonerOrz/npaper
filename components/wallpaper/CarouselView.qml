import QtQuick
import Quickshell
import qs.components.common
import qs.services

/*
* CarouselView — 3D perspective carousel of wallpaper cards.
*
* Inputs:
*   adapter, cacheService, checkService
*
* Outputs (properties):
*   currentIndex, scrollTarget, ready, baseIndex, maxIndex
*
* Outputs (signals):
*   All 7 request* signals + toggleWallhaven + refresh
*
* Note: requestApplyItem emits adapter.items[N] with path field guaranteed.
*/
FocusScope {
  id: root

  property var adapter: null
  property var cacheService: null

  // Config-derived values (passed from DisplayManager)
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
    if (!adapter || !cacheService)
      return;
    for (let i = baseIndex; i <= maxIndex && i < adapter.items.length; i++) {
      const item = adapter.items[i];
      if (item && item.type === "local")
        cacheService.queueThumbnail(item.path, item.isVideo, item.isGif);
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
      // ===== Escape =====
      if (event.key === Qt.Key_Escape) {
        root.requestQuit();
        event.accepted = true;
        return;
      }

      // ===== Settings (S) =====
      if (event.key === Qt.Key_S && !event.modifiers) {
        root.requestSettings();
        event.accepted = true;
        return;
      }

      // ===== Wallhaven (W) =====
      if (event.key === Qt.Key_W && !event.modifiers) {
        root.requestToggleWallhaven();
        pathViewContainer.forceActiveFocus();
        event.accepted = true;
        return;
      }

      // ===== Folder (Tab/[ / ]) =====
      if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
        event.key === Qt.Key_Tab ? root.requestNextFolder() : root.requestPrevFolder();
        event.accepted = true;
        return;
      }
      if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BraceLeft) {
        root.requestPrevFolder();
        event.accepted = true;
        return;
      }
      if (event.key === Qt.Key_BracketRight || event.key === Qt.Key_BraceRight) {
        root.requestNextFolder();
        event.accepted = true;
        return;
      }

      // ===== Search (/, Ctrl+F) =====
      if (event.key === Qt.Key_Slash || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))) {
        root.requestFocusSearch();
        event.accepted = true;
        return;
      }

      // ===== Apply (Enter) =====
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        if (root.adapter && root.adapter.items.length > 0)
          root.requestApplyItem(root.adapter.items[root.currentIndex]);
        event.accepted = true;
        return;
      }

      // ===== Navigate (←/→) =====
      if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
        const dir = event.key === Qt.Key_Left ? -1 : 1;
        event.modifiers & Qt.ShiftModifier ? (dir === -1 ? scrollController.fastScrollLeft() : scrollController.fastScrollRight()) : (dir === -1 ? scrollController.scrollLeft() : scrollController.scrollRight());
        event.accepted = true;
        return;
      }

      // ===== Random (R) =====
      if (event.key === Qt.Key_R && !event.modifiers) {
        scrollController.random();
        root.requestRandom();
        event.accepted = true;
        return;
      }

      // ===== Refresh (F5) =====
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
        thumbHashToPath: _item && _item.type === "local" ? (root.cacheService ? root.cacheService.thumbHashToPath : {}) : {}
        isCenter: realIndex === root.currentIndex
        showBorderGlow: root.showBorderGlow
        showShadow: root.showShadow

        readonly property var metrics: {
          const raw = realIndex - scrollController.scrollTarget;
          const abs = Math.abs(raw);
          return {
            raw,
            abs,
            cos: Math.cos(Math.min(abs, 3) * 0.523599),
            perspectiveScale: 1.0 / (1.0 + abs * root.carouselPerspective)
          };
        }
        readonly property var visual: {
          const abs = metrics.abs;
          return {
            scale: metrics.perspectiveScale * (0.85 + metrics.cos * 0.15) + (isCenter ? 0.06 : 0),
            opacity: abs > 6 ? 0 : Math.pow(Math.max(0, 1 - abs * 0.12), 2.5),
            rotationY: metrics.raw * -root.carouselRotation,
            z: 100 - abs * 50,
            spacingFactor: 0.85 - metrics.abs * 0.06,
            yOffset: abs * 8,
            shadowOpacity: abs < 0.6 ? 0.25 : 0
          };
        }
        visualScale: visual.scale
        visualOpacity: visual.opacity
        visualRotationY: visual.rotationY
        visualZ: visual.z
        visualYOffset: visual.yOffset
        visualShadowOpacity: visual.shadowOpacity
        x: pathViewContainer.centerX - width / 2 + metrics.raw * (width + pathViewContainer.spacing) * visual.spacingFactor
        y: pathViewContainer.centerY - height / 2 + visual.yOffset
        onClicked: function (path) {
          scrollController.scrollTo(realIndex);
          if (_item)
            root.requestApplyItem(_item);
        }
      }
    }

    Text {
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottomMargin: Style.keyboardHintBottomMargin
      text: "/ Search  |  ←/→ Navigate  |  Tab/[] Folder  |  Enter Apply  |  R Random  |  F5 Refresh  |  S Settings  |  W Wallhaven  |  Esc Quit"
      color: Color.mOutline
      font.pixelSize: Style.keyboardHintFontSize
      style: Text.Outline
      styleColor: Color.mScrim
    }
  }
}
