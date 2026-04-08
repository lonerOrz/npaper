import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import "../../utils/CacheUtils.js" as CacheUtils
import qs.services

/*
* GridView — Simple grid view of wallpaper cards.
* Inspired by org/qml/wallpaper/WallpaperSelector.qml thumbGridView.
*
* Features:
*   - Snap scroll (wheel → cellHeight steps, 400ms OutCubic)
*   - Keyboard navigation (Up/Down/Left/Right with _ensureVisible)
*   - Entry/displaced transitions (opacity + scale OutBack)
*   - Vertical scrollbar
*   - Cell size animations
*
* requestApplyItem emits adapter.items[N] with path field guaranteed.
*/
FocusScope {
  id: root

  property var adapter: null
  property var cacheService: null

  // Scrollbar state (at root level, not inside Flickable)
  property bool gridScrollActive: false

  readonly property int currentIndex: thumbGridView.currentIndex
  readonly property real scrollTarget: thumbGridView.currentIndex
  readonly property int baseIndex: 0
  readonly property int maxIndex: thumbGridView.model ? thumbGridView.model.length - 1 : 0

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
    thumbGridView.currentIndex = 0;
    thumbGridView.positionViewAtIndex(0, GridView.Beginning);
  }

  function scrollTo(idx) {
    thumbGridView.positionViewAtIndex(idx, GridView.Beginning);
    thumbGridView.currentIndex = idx;
  }

  function focusView() {
    thumbGridView.forceActiveFocus();
  }

  function queueVisibleThumbnails() {
    if (!adapter || !cacheService)
      return;
    var model = thumbGridView.model;
    if (!model)
      return;
    var cols = Math.max(1, Math.ceil(thumbGridView.width / thumbGridView.cellWidth));
    var rows = Math.max(1, Math.ceil(thumbGridView.height / thumbGridView.cellHeight));
    // Preload extra rows above/below visible area
    var preloadRows = 2;
    var startRow = Math.max(0, Math.floor(thumbGridView.contentY / thumbGridView.cellHeight) - preloadRows);
    var endRow = Math.min(Math.ceil((thumbGridView.contentY + thumbGridView.height) / thumbGridView.cellHeight) + preloadRows, Math.ceil(model.length / cols));
    var startIdx = startRow * cols;
    var endIdx = endRow * cols;
    for (let i = startIdx; i < endIdx && i < adapter.items.length; i++) {
      const item = adapter.items[i];
      if (item && item.type === "local")
        cacheService.queueThumbnail(item.path, item.isVideo, item.isGif);
    }
  }

  // Grid dimensions — bound to Style singletons
  readonly property int _gridCellW: Style.gridCellWidth
  readonly property int _gridCellH: Style.gridCellHeight
  readonly property int _gridCellSpacing: Style.gridCellSpacing
  readonly property int _gridCellPadding: Style.gridCellPadding

  // Calculate columns based on parent width
  property real _availableWidth: Math.max(1, (parent.width > 0 ? parent.width : 1920) - _gridCellPadding * 2)
  property int _columns: Math.max(1, Math.floor(_availableWidth / (_gridCellW + _gridCellSpacing)))
  property real _gridWidth: _columns * (_gridCellW + _gridCellSpacing)

  GridView {
    id: thumbGridView
    width: Math.min(root._gridWidth, root._availableWidth)
    anchors.top: parent.top
    anchors.topMargin: Style.spaceXXXL
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.keyboardHintBottomMargin + 40
    anchors.horizontalCenter: parent.horizontalCenter
    model: root.adapter ? root.adapter.items : null
    clip: false

    Behavior on width {
      NumberAnimation {
        duration: Style.animNormal
        easing.type: Easing.OutCubic
      }
    }

    cellWidth: root._gridCellW + root._gridCellSpacing
    cellHeight: root._gridCellH + root._gridCellSpacing
    Behavior on cellWidth {
      NumberAnimation {
        duration: Style.animNormal
        easing.type: Easing.OutCubic
      }
    }
    Behavior on cellHeight {
      NumberAnimation {
        duration: Style.animNormal
        easing.type: Easing.OutCubic
      }
    }

    interactive: false
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: true
    keyNavigationWraps: false
    highlightMoveDuration: Style.animNormal
    highlight: Item {}

    property real _scrollTarget: 0
    onContentYChanged: {
      if (!_gridScrollAnim.running)
        _scrollTarget = contentY;
      _thumbQueueTimer.restart();
    }

    Timer {
      id: _thumbQueueTimer
      interval: 150
      onTriggered: queueVisibleThumbnails()
    }

    NumberAnimation {
      id: _gridScrollAnim
      target: thumbGridView
      property: "contentY"
      duration: 400
      easing.type: Easing.OutCubic
    }

    function _snapScroll(delta) {
      if (!_gridScrollAnim.running)
        _scrollTarget = contentY;
      var step = cellHeight;
      _scrollTarget += (delta > 0 ? -step : step);
      var maxY = contentHeight - height;
      _scrollTarget = Math.max(0, Math.min(_scrollTarget, maxY));
      _gridScrollAnim.stop();
      _gridScrollAnim.from = contentY;
      _gridScrollAnim.to = _scrollTarget;
      _gridScrollAnim.start();
    }

    function _snapScrollTo(target) {
      var maxY = contentHeight - height;
      _scrollTarget = Math.max(0, Math.min(target, maxY));
      _gridScrollAnim.stop();
      _gridScrollAnim.from = contentY;
      _gridScrollAnim.to = _scrollTarget;
      _gridScrollAnim.start();
    }

    function _ensureVisible(idx) {
      var row = Math.floor(idx / Math.max(1, Math.ceil(thumbGridView.width / thumbGridView.cellWidth)));
      var rowTop = row * cellHeight;
      var rowBottom = rowTop + cellHeight;
      if (rowTop < contentY)
        _snapScrollTo(rowTop);
      else if (rowBottom > contentY + height)
        _snapScrollTo(rowBottom - height);
    }

    // Enhanced entry transition
    add: Transition {
      ParallelAnimation {
        NumberAnimation {
          property: "opacity"
          from: 0
          to: 1
          duration: Style.animEnter
          easing.type: Easing.OutCubic
        }
        NumberAnimation {
          property: "scale"
          from: 0.8
          to: 1.0
          duration: Style.animEnter
          easing.type: Easing.OutBack
          easing.overshoot: 1.5
        }
      }
    }
    
    // Smooth exit transition
    remove: Transition {
      ParallelAnimation {
        NumberAnimation {
          property: "opacity"
          to: 0
          duration: Style.animFast
          easing.type: Easing.InCubic
        }
        NumberAnimation {
          property: "scale"
          to: 0.95
          duration: Style.animFast
          easing.type: Easing.InCubic
        }
      }
    }
    
    // Refined displaced transition
    displaced: Transition {
      NumberAnimation {
        properties: "x,y"
        duration: Style.animNormal
        easing.type: Easing.OutCubic
      }
    }

    // Mouse wheel → snap scroll
    MouseArea {
      anchors.fill: parent
      propagateComposedEvents: true
      onWheel: function (wheel) {
        thumbGridView._snapScroll(wheel.angleDelta.y);
        root.gridScrollActive = true;
        gridScrollFadeTimer.restart();
        thumbGridView.forceActiveFocus();
      }
      onPressed: mouse => mouse.accepted = false
      onReleased: mouse => mouse.accepted = false
      onClicked: mouse => mouse.accepted = false
    }

    delegate: Item {
      id: gridItem
      width: root._gridCellW
      height: root._gridCellH

      required property var modelData

      readonly property bool isCurrent: GridView.isCurrentItem
      readonly property bool isHovered: itemMouse.containsMouse

      // Enhanced scale animation with smoother transitions
      scale: isCurrent ? 1.04 : (isHovered ? 1.02 : 1.0)
      z: isCurrent ? 20 : (isHovered ? 10 : 0)

      Behavior on scale {
        NumberAnimation {
          duration: Style.animNormal
          easing.type: Easing.OutCubic
        }
      }

      // Enhanced card shadow with depth
      Rectangle {
        anchors.fill: parent
        anchors.margins: gridItem.isCurrent ? Style.spaceM : Style.spaceS
        radius: Style.radiusL
        color: Color.mShadow
        opacity: gridItem.isCurrent ? 0.35 : (gridItem.isHovered ? 0.25 : 0.15)
        z: -1

        Behavior on opacity {
          NumberAnimation {
            duration: Style.animNormal
            easing.type: Easing.OutCubic
          }
        }
      }

      // Rounded mask - refined corners
      Item {
        id: cardMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Shape {
          anchors.fill: parent
          antialiasing: true
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "white"
            strokeColor: "transparent"
            strokeWidth: 0
            startX: Style.radiusL
            startY: 0
            PathLine {
              x: width - Style.radiusL
              y: 0
            }
            PathArc {
              x: width
              y: Style.radiusL
              radiusX: Style.radiusL
              radiusY: Style.radiusL
            }
            PathLine {
              x: width
              y: height - Style.radiusL
            }
            PathArc {
              x: width - Style.radiusL
              y: height
              radiusX: Style.radiusL
              radiusY: Style.radiusL
            }
            PathLine {
              x: Style.radiusL
              y: height
            }
            PathArc {
              x: 0
              y: height - Style.radiusL
              radiusX: Style.radiusL
              radiusY: Style.radiusL
            }
            PathLine {
              x: 0
              y: Style.radiusL
            }
            PathArc {
              x: Style.radiusL
              y: 0
              radiusX: Style.radiusL
              radiusY: Style.radiusL
            }
          }
        }
      }

      // Card content
      Item {
        id: cardContent
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: cardMask
          maskThresholdMin: 0.3
          maskSpreadAtMin: 0.3
        }

        Rectangle {
          anchors.fill: parent
          color: {
            if (gridItem.isCurrent)
              return "transparent";
            if (gridItem.isHovered)
              return Qt.rgba(0, 0, 0, 0.12);
            return Qt.rgba(0, 0, 0, 0.35);
          }
          Behavior on color {
            ColorAnimation {
              duration: Style.animNormal
              easing.type: Easing.OutCubic
            }
          }
        }

        Image {
          id: thumbImage
          anchors.fill: parent
          source: CacheUtils.getStaticThumbSource(root.cacheService ? root.cacheService.thumbHashToPath : {}, gridItem.modelData)
          visible: source !== ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          smooth: true
          mipmap: true
          sourceSize: Qt.size(root._gridCellW, root._gridCellH)
          opacity: status === Image.Ready ? 1.0 : 0.0
          Behavior on opacity {
            NumberAnimation {
              duration: Style.animFast
            }
          }
        }

        // Animated GIF/Video preview — only for current/selected item
        AnimatedImage {
          id: animatedGif
          anchors.fill: parent
          source: CacheUtils.getAnimatedPreviewSource(root.cacheService ? root.cacheService.thumbHashToPath : {}, gridItem.modelData)
          visible: source !== "" && gridItem.isCurrent
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          smooth: true
          mipmap: true
          cache: true
          sourceSize: Qt.size(root._gridCellW, root._gridCellH)
          playing: visible && source !== ""
          opacity: status === AnimatedImage.Ready ? 1.0 : 0.0
          Behavior on opacity {
            NumberAnimation {
              duration: Style.animFast
            }
          }
        }
      }

      // Border with smooth animation (Rectangle instead of Shape for performance)
      Rectangle {
        anchors.fill: parent
        radius: Style.radiusL
        color: "transparent"
        border.color: {
          if (gridItem.isCurrent)
            return Color.mPrimary;
          if (gridItem.isHovered)
            return Qt.lighter(Color.mPrimaryContainer, 1.1);
          return "transparent";
        }
        Behavior on border.color {
          ColorAnimation {
            duration: Style.animNormal
            easing.type: Easing.OutCubic
          }
        }
        border.width: gridItem.isCurrent ? Style.borderM : (gridItem.isHovered ? Style.borderS : 0)
        Behavior on border.width {
          NumberAnimation {
            duration: Style.animNormal
            easing.type: Easing.OutCubic
          }
        }
      }

      MouseArea {
        id: itemMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (gridItem.modelData)
            root.requestApplyItem(gridItem.modelData);
        }
      }
    }

    // Keyboard handling
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
        thumbGridView.forceActiveFocus();
        event.accepted = true;
        return;
      }
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
      if (event.key === Qt.Key_Slash || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))) {
        root.requestFocusSearch();
        event.accepted = true;
        return;
      }
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        if (root.adapter && root.adapter.items.length > 0) {
          var item = root.adapter.items[thumbGridView.currentIndex];
          if (item)
            root.requestApplyItem(item);
        }
        event.accepted = true;
        return;
      }
      if (event.key === Qt.Key_R && !event.modifiers) {
        if (root.adapter && root.adapter.items.length > 0)
          thumbGridView.currentIndex = Math.floor(Math.random() * root.adapter.items.length);
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
  }

  // Scroll fade timer (sibling of GridView, not inside Flickable)
  Timer {
    id: gridScrollFadeTimer
    interval: 800
    onTriggered: root.gridScrollActive = false
  }

  // Custom scrollbar (sibling of GridView, stays fixed in viewport)
  Rectangle {
    anchors.right: parent.right
    anchors.top: thumbGridView.top
    anchors.bottom: parent.bottom
    anchors.rightMargin: Style.spaceS
    width: 4
    radius: 2
    color: Color.mPrimary
    opacity: root.gridScrollActive ? 0.5 : 0

    property real scrollProgress: thumbGridView.visibleArea.heightRatio < 1.0 ?
      thumbGridView.visibleArea.yPosition / (1.0 - thumbGridView.visibleArea.heightRatio) : 0
    property real scrollHeight: thumbGridView.visibleArea.heightRatio < 1.0 ?
      thumbGridView.visibleArea.heightRatio * (height) : 20

    y: scrollProgress * (parent.height - scrollHeight)
    height: Math.max(20, scrollHeight)

    Behavior on opacity {
      NumberAnimation {
        duration: root.gridScrollActive ? Style.animVeryFast : Style.animSlow
      }
    }
  }

  // Enhanced keybinds hint with pill design
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
      text: "↑/↓/←/→ Navigate  •  Enter Apply  •  R Random  •  F5 Refresh  •  S Settings  •  Esc Quit"
      color: Color.mOnSurface
      font.pixelSize: Style.keyboardHintFontSize
      font.weight: Font.Medium
      style: Text.Outline
      styleColor: Color.mScrim
      opacity: 0.9
    }
  }
}
