import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import "../../utils/CacheUtils.js" as CacheUtils
import qs.components.common
import qs.services

FocusScope {
  id: root
  clip: true

  property var adapter: null
  property var cacheService: null
  property var appViewModel: null
  property var wallhavenFilter: null

  property bool gridScrollActive: false

  readonly property int currentIndex: thumbGridView.currentIndex
  readonly property real scrollTarget: thumbGridView.currentIndex
  readonly property int baseIndex: 0
  readonly property int maxIndex: thumbGridView.model ? (thumbGridView.model.count !== undefined ? thumbGridView.model.count : thumbGridView.model.length) - 1 : 0

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
    if (!root.adapter || !root.cacheService)
      return;
    var model = thumbGridView.model;
    if (!model)
      return;
    var modelLen = model.count !== undefined ? model.count : model.length;
    var cols = Math.max(1, Math.ceil(thumbGridView.width / thumbGridView.cellWidth));
    var rows = Math.max(1, Math.ceil(thumbGridView.height / thumbGridView.cellHeight));
    var preloadRows = 2;
    var startRow = Math.max(0, Math.floor(thumbGridView.contentY / thumbGridView.cellHeight) - preloadRows);
    var endRow = Math.min(Math.ceil((thumbGridView.contentY + thumbGridView.height) / thumbGridView.cellHeight) + preloadRows, Math.ceil(modelLen / cols));
    var startIdx = startRow * cols;
    var endIdx = endRow * cols;
    var itemsLen = root.adapter.items.length;
    for (let i = startIdx; i < endIdx && i < itemsLen; i++) {
      const item = root.adapter.items[i];
      if (item && item.type === "local")
        root.cacheService.queueThumbnail(item.path, item.isVideo, item.isGif);
    }
  }

  readonly property int _gridCellW: Style.gridCellWidth
  readonly property int _gridCellH: Style.gridCellHeight
  readonly property int _gridCellSpacing: Style.gridCellSpacing
  readonly property int _gridCellPadding: Style.gridCellPadding

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

    cacheBuffer: cellHeight * 3

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
    focus: true
    highlightMoveDuration: Style.animNormal
    highlight: Item {}

    property real _savedContentY: 0
    property bool _modelChanging: false

    property real _scrollTarget: 0
    onContentYChanged: {
      if (!_modelChanging)
        _savedContentY = contentY;
      if (!_gridScrollAnim.running)
        _scrollTarget = contentY;
      if (!_gridScrollAnim.running) {
        _thumbQueueTimer.restart();
        _whLoadMoreTimer.restart();
      }
    }

    onModelChanged: {
      _modelChanging = true;
      Qt.callLater(function () {
        thumbGridView.contentY = thumbGridView._savedContentY;
        _modelChanging = false;
      });
    }

    Timer {
      id: _whLoadMoreTimer
      interval: 300
      onTriggered: {
        if (root.adapter && root.adapter.currentSource === "remote" && root.adapter.whService && root.adapter.whService.hasMore && !root.adapter.whService.loading && !root.adapter._whLoadingMore) {
          var maxY = thumbGridView.contentHeight - thumbGridView.height;
          if (maxY > 0 && thumbGridView.contentY >= maxY - Style.gridCellHeight) {
            root.adapter._whLoadingMore = true;
            root.adapter.whService.loadMore();
          }
        }
      }
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
      onFinished: {
        _thumbQueueTimer.restart();
        _whLoadMoreTimer.restart();
      }
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

    displaced: Transition {
      NumberAnimation {
        properties: "x,y"
        duration: Style.animNormal
        easing.type: Easing.OutCubic
      }
    }

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

      required property int index
      property var modelData: null

      HoverHandler {
        id: gridItemHover
      }

      readonly property bool isCurrent: GridView.isCurrentItem
      readonly property bool isHovered: gridItemHover.hovered

      function _resolveItem() {
        var m = thumbGridView.model;
        if (m && index >= 0 && index < m.count)
          return m.get(index);
        return null;
      }

      Component.onCompleted: {
        gridItem.modelData = gridItem._resolveItem();
      }
      onIndexChanged: {
        gridItem.modelData = gridItem._resolveItem();
      }

      Connections {
        target: root.adapter ? root.adapter.whService : null
        function onResultsUpdated() {
          gridItem.modelData = gridItem._resolveItem();
        }
      }

      scale: isCurrent ? 1.05 : 1.0
      z: isCurrent ? 20 : 0

      Behavior on scale {
        NumberAnimation {
          duration: Style.animNormal
          easing.type: Easing.OutCubic
        }
      }

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
          source: CacheUtils.resolveGridStaticSource(root.cacheService ? root.cacheService.thumbHashToPath : {}, gridItem.modelData)
          visible: source !== ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          smooth: true
          mipmap: false
          sourceSize: Qt.size(root._gridCellW, root._gridCellH)
          opacity: status === Image.Ready ? 1.0 : (status === Image.Error ? 0.3 : 0.0)
          Behavior on opacity {
            NumberAnimation {
              duration: 100
            }
          }
        }

        AnimatedImage {
          id: animatedGif
          anchors.fill: parent
          source: CacheUtils.resolveGridAnimatedSource(root.cacheService ? root.cacheService.thumbHashToPath : {}, gridItem.modelData)
          visible: source !== "" && gridItem.isCurrent
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          smooth: true
          mipmap: true
          cache: true
          sourceSize: Qt.size(root._gridCellW, root._gridCellH)
          playing: source !== ""
          opacity: status === AnimatedImage.Ready ? 1.0 : 0.0
          Behavior on opacity {
            NumberAnimation {
              duration: Style.animFast
            }
          }
        }
      }

      readonly property bool _needsDownload: {
        if (!(root.adapter && root.adapter.currentSource === "remote"))
          return false;
        var id = gridItem.modelData ? gridItem.modelData.id.replace("wallhaven-", "") : "";
        if (!id)
          return false;
        var ws = root.adapter.whService;
        if (!ws || !ws.localWallhavenPaths)
          return true;
        return !ws.localWallhavenPaths[id];
      }

      Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.spaceM
        width: dlIndicator.implicitWidth + Style.spaceM * 2
        height: Style.spaceXL * 2
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: _needsDownload

        Text {
          id: dlIndicator
          anchors.centerIn: parent
          text: "↓"
          font.pixelSize: Style.cardLabelFontSize
          color: Color.mPrimary
        }
      }

      Rectangle {
        anchors.fill: parent
        radius: Style.radiusL
        color: "transparent"
        z: 20
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

      Rectangle {
        anchors.fill: parent
        radius: Style.radiusL
        color: "transparent"
        visible: root.adapter && root.adapter.currentSource === "remote" && !!gridItem.modelData
        opacity: gridItem.isHovered ? 1 : 0
        z: 15

        Behavior on opacity {
          NumberAnimation {
            duration: Style.animFast
          }
        }

        DownloadOverlay {
          opacity: parent.opacity
          whId: gridItem.modelData ? gridItem.modelData.id.replace("wallhaven-", "") : ""
          downloadPath: gridItem.modelData ? gridItem.modelData.path : ""
          whService: root.adapter ? root.adapter.whService : null
          downloadStatus: (root.adapter && root.adapter.whService && root.adapter.whService.downloadStatus) ? root.adapter.whService.downloadStatus : ({})
          downloadProgress: (root.adapter && root.adapter.whService && root.adapter.whService.downloadProgress) ? root.adapter.whService.downloadProgress : ({})
          downloadPaths: (root.adapter && root.adapter.whService && root.adapter.whService.downloadPaths) ? root.adapter.whService.downloadPaths : ({})
          onApplyLocal: function (localPath) {
            var localItem = Object.assign({}, gridItem.modelData, {
                                            path: localPath,
                                            type: "local"
                                          });
            root.requestApplyItem(localItem);
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        radius: Style.radiusL
        color: "transparent"
        visible: root.adapter && root.adapter.currentSource === "local" && !!gridItem.modelData
        opacity: gridItem.isHovered ? 1 : 0
        z: 15

        Behavior on opacity {
          NumberAnimation {
            duration: Style.animFast
          }
        }

        LocalOverlay {
          opacity: parent.opacity
          wallpaperPath: gridItem.modelData ? gridItem.modelData.path : ""
          itemIndex: index
        }
      }

      MouseArea {
        id: itemMouse
        anchors.fill: parent
        hoverEnabled: true
        z: 1
        cursorShape: Qt.PointingHandCursor
        onEntered: {
          thumbGridView.currentIndex = gridItem.index;
        }
        onClicked: {
          if (gridItem.modelData)
            root.adapter.smartApply(gridItem.modelData);
        }
      }
    }

    KeyboardHandler {
      id: kbdHandler
      appViewModel: root.appViewModel
      wallhavenFilter: root.wallhavenFilter
      onApplyRequested: {
        if (root.adapter.count > 0 && thumbGridView.currentIndex < root.adapter.count) {
          var item = root.adapter.getItem(thumbGridView.currentIndex);
          if (item)
            root.adapter.smartApply(item);
        }
      }
      onRandomRequested: {
        if (root.adapter.count > 0)
          thumbGridView.currentIndex = Math.floor(Math.random() * root.adapter.count);
      }
      onWallhavenToggled: thumbGridView.forceActiveFocus()
    }
    Keys.onPressed: function (event) {
      kbdHandler.handleKeyPress(event);
    }
  }

  Timer {
    id: gridScrollFadeTimer
    interval: 800
    onTriggered: root.gridScrollActive = false
  }

  Rectangle {
    anchors.right: parent.right
    anchors.top: thumbGridView.top
    anchors.bottom: parent.bottom
    anchors.rightMargin: Style.spaceS
    width: 4
    radius: 2
    color: Color.mPrimary
    opacity: root.gridScrollActive ? 0.5 : 0

    property real scrollProgress: thumbGridView.visibleArea.heightRatio < 1.0 ? thumbGridView.visibleArea.yPosition / (1.0 - thumbGridView.visibleArea.heightRatio) : 0
    property real scrollHeight: thumbGridView.visibleArea.heightRatio < 1.0 ? thumbGridView.visibleArea.heightRatio * (height) : 20

    y: scrollProgress * (parent.height - scrollHeight)
    height: Math.max(20, scrollHeight)

    Behavior on opacity {
      NumberAnimation {
        duration: root.gridScrollActive ? Style.animVeryFast : Style.animSlow
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
      text: "↑/↓/←/→ Navigate  •  Enter Apply  •  Tab Folder  •  [] Toggle View  •  S Settings  •  Esc Quit"
      color: Color.mOnSurface
      font.pixelSize: Style.keyboardHintFontSize
      font.weight: Font.Medium
      style: Text.Outline
      styleColor: Color.mScrim
      opacity: 0.9
    }
  }
}
