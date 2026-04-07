import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import "../../utils/CacheUtils.js" as CacheUtils
import qs.services

/*
 * GridView — Simple grid view of wallpaper cards.
 * No 3D transforms, no glow — just rounded cards in a scrollable grid.
 *
 * requestApplyItem emits adapter.items[N] with path field guaranteed.
 */
FocusScope {
  id: root

  property var adapter: null
  property var cacheService: null

  readonly property int currentIndex: thumbGridView.currentIndex
  readonly property real scrollTarget: thumbGridView.currentIndex
  readonly property bool ready: thumbGridView.model != null
  readonly property int baseIndex: 0
  readonly property int maxIndex: thumbGridView.model ? thumbGridView.model.length - 1 : 0

  signal requestQuit()
  signal requestSettings()
  signal requestPrevFolder()
  signal requestNextFolder()
  signal requestFocusSearch()
  signal requestApplyItem(var item)
  signal requestRandom()
  signal requestToggleWallhaven()
  signal requestRefresh()

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
    var visibleCount = rows * cols;
    var startIdx = Math.floor(thumbGridView.contentY / thumbGridView.cellHeight) * cols;
    for (let i = startIdx; i < startIdx + visibleCount && i < adapter.items.length; i++) {
      const item = adapter.items[i];
      if (item && item.type === "local")
        cacheService.queueThumbnail(item.path, item.isVideo, item.isGif);
    }
  }

  property real _gridCellW: Style.carouselItemWidth + Style.carouselSpacing * 4
  property real _gridCellH: Style.carouselItemHeight + Style.cardLabelHeight + Style.spaceXXXL * 2

  GridView {
    id: thumbGridView
    anchors.fill: parent
    model: root.adapter ? root.adapter.items : null
    clip: true
    cacheBuffer: 600
    focus: true

    cellWidth: root._gridCellW
    cellHeight: root._gridCellH

    interactive: true
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: true
    keyNavigationWraps: false
    highlightMoveDuration: Style.animFast

    highlight: Item {}
    highlightFollowsCurrentItem: true

    delegate: Item {
      id: gridItem
      width: root._gridCellW - Style.carouselSpacing
      height: root._gridCellH - Style.carouselSpacing

      required property var modelData

      readonly property bool isCurrent: GridView.isCurrentItem
      readonly property bool isHovered: itemMouse.containsMouse

      scale: isCurrent ? 1.03 : (isHovered ? 1.01 : 1.0)
      z: isCurrent ? 10 : (isHovered ? 5 : 0)

      Behavior on scale {
        NumberAnimation {
          duration: Style.animFast
          easing.type: Easing.OutCubic
        }
      }

      // ── Card shadow ─────────────────────────────────────
      Rectangle {
        anchors.fill: parent
        anchors.topMargin: Style.spaceXS
        anchors.leftMargin: Style.spaceXS
        radius: Style.radiusM
        color: Color.mShadow
        opacity: gridItem.isCurrent ? 0.4 : (gridItem.isHovered ? 0.2 : 0)
        z: -1
      }

      // ── Rounded mask ────────────────────────────────────
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
            startX: Style.radiusM
            startY: 0
            PathLine { x: width - Style.radiusM; y: 0 }
            PathArc { x: width; y: Style.radiusM; radiusX: Style.radiusM; radiusY: Style.radiusM }
            PathLine { x: width; y: height - Style.radiusM }
            PathArc { x: width - Style.radiusM; y: height; radiusX: Style.radiusM; radiusY: Style.radiusM }
            PathLine { x: Style.radiusM; y: height }
            PathArc { x: 0; y: height - Style.radiusM; radiusX: Style.radiusM; radiusY: Style.radiusM }
            PathLine { x: 0; y: Style.radiusM }
            PathArc { x: Style.radiusM; y: 0; radiusX: Style.radiusM; radiusY: Style.radiusM }
          }
        }
      }

      // ── Card content (clipped) ──────────────────────────
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

        // Background tint
        Rectangle {
          anchors.fill: parent
          color: {
            if (gridItem.isCurrent)
              return "transparent";
            if (gridItem.isHovered)
              return Qt.rgba(0, 0, 0, 0.15);
            return Qt.rgba(0, 0, 0, 0.4);
          }
          Behavior on color {
            ColorAnimation { duration: Style.animNormal }
          }
        }

        // Image
        Image {
          id: thumbImage
          anchors.fill: parent
          anchors.bottomMargin: Style.cardLabelHeight + Style.spaceM * 2
          source: {
            const item = gridItem.modelData;
            if (!item) return "";
            if (item.type === "remote") return item.thumb;
            const path = item.path;
            if (!path) return "";
            const thumbMap = root.cacheService ? root.cacheService.thumbHashToPath : {};
            const bg = CacheUtils.getCachedBgPreview(thumbMap, path);
            if (bg) return "file://" + bg;
            if (item.isVideo || item.isGif) return "";
            return "file://" + path;
          }
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          smooth: true
          mipmap: true
          sourceSize: Qt.size(Style.cacheAnimWidth, Style.cacheAnimHeight)
          opacity: status === Image.Ready ? 1.0 : 0.0
          Behavior on opacity {
            NumberAnimation { duration: Style.animFast }
          }
        }

        // Filename label
        Item {
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.cardLabelHeight + Style.spaceM * 2
          Rectangle {
            anchors.fill: parent
            gradient: Gradient {
              GradientStop { position: 0.0; color: "transparent" }
              GradientStop { position: 0.3; color: Qt.rgba(0, 0, 0, 0.05) }
              GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
            }
          }
          Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.spaceM
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Style.cardLabelMargins
            text: gridItem.modelData ? gridItem.modelData.filename : ""
            color: Color.mInverseSurface
            font.pixelSize: Style.cardLabelFontSize
            font.weight: Font.Medium
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }

      // ── Border ──────────────────────────────────────────
      Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          fillColor: "transparent"
          strokeColor: {
            if (gridItem.isCurrent)
              return Color.mPrimary;
            if (gridItem.isHovered)
              return Color.mPrimaryContainer;
            return "transparent";
          }
          Behavior on strokeColor {
            ColorAnimation { duration: Style.animFast }
          }
          strokeWidth: gridItem.isCurrent ? Style.borderM : (gridItem.isHovered ? Style.borderS : 0)
          startX: Style.radiusM
          startY: 0
          PathLine { x: width - Style.radiusM; y: 0 }
          PathArc { x: width; y: Style.radiusM; radiusX: Style.radiusM; radiusY: Style.radiusM }
          PathLine { x: width; y: height - Style.radiusM }
          PathArc { x: width - Style.radiusM; y: height; radiusX: Style.radiusM; radiusY: Style.radiusM }
          PathLine { x: Style.radiusM; y: height }
          PathArc { x: 0; y: height - Style.radiusM; radiusX: Style.radiusM; radiusY: Style.radiusM }
          PathLine { x: 0; y: Style.radiusM }
          PathArc { x: Style.radiusM; y: 0; radiusX: Style.radiusM; radiusY: Style.radiusM }
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

    // ── Keyboard handling ─────────────────────────────────
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
          var item = root.adapter.items[root.currentIndex];
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
}
