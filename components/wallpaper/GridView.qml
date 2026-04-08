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
        anchors.bottom: keybindsText.top
        anchors.horizontalCenter: parent.horizontalCenter
        model: root.adapter ? root.adapter.items : null
        clip: false

        Behavior on width {
            NumberAnimation {
                duration: Style.animExpand
                easing.type: Easing.OutCubic
            }
        }

        cellWidth: root._gridCellW + root._gridCellSpacing
        cellHeight: root._gridCellH + root._gridCellSpacing
        Behavior on cellWidth {
            NumberAnimation {
                duration: Style.animExpand
                easing.type: Easing.OutCubic
            }
        }
        Behavior on cellHeight {
            NumberAnimation {
                duration: Style.animExpand
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

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Style.animEnter
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.85
                to: 1
                duration: Style.animEnter
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }
        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Style.animVeryFast
                easing.type: Easing.InCubic
            }
        }
        displaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Style.animFast
                easing.type: Easing.OutCubic
            }
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 4
            contentItem: Rectangle {
                radius: 2
                color: Color.mPrimary
                opacity: 0.4
            }
        }

        // Mouse wheel → snap scroll
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onWheel: function (wheel) {
                thumbGridView._snapScroll(wheel.angleDelta.y);
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

            scale: isCurrent ? 1.03 : (isHovered ? 1.01 : 1.0)
            z: isCurrent ? 10 : (isHovered ? 5 : 0)

            Behavior on scale {
                NumberAnimation {
                    duration: Style.animFast
                    easing.type: Easing.OutCubic
                }
            }

            // Card shadow
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: Style.spaceXS
                anchors.leftMargin: Style.spaceXS
                radius: Style.radiusM
                color: Color.mShadow
                opacity: gridItem.isCurrent ? 0.4 : (gridItem.isHovered ? 0.2 : 0)
                z: -1
            }

            // Rounded mask
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
                            return Qt.rgba(0, 0, 0, 0.15);
                        return Qt.rgba(0, 0, 0, 0.4);
                    }
                    Behavior on color {
                        ColorAnimation { duration: Style.animNormal }
                    }
                }

                Image {
                    id: thumbImage
                    anchors.fill: parent
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
                    sourceSize: Qt.size(root._gridCellW, root._gridCellH)
                    opacity: status === Image.Ready ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: Style.animFast }
                    }
                }

                // Animated GIF/Video preview — only for current/selected item
                AnimatedImage {
                    id: animatedGif
                    anchors.fill: parent
                    visible: gridItem.isCurrent
                             && gridItem.modelData
                             && (gridItem.modelData.isGif || gridItem.modelData.isVideo)
                             && source !== ""
                    source: {
                        const item = gridItem.modelData;
                        if (!item || item.type === "remote") return "";
                        const path = item.path;
                        if (!path) return "";
                        const thumbMap = root.cacheService ? root.cacheService.thumbHashToPath : {};
                        const anim = CacheUtils.getCachedAnimatedGif(thumbMap, path);
                        return anim ? "file://" + anim : "";
                    }
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    cache: true
                    sourceSize: Qt.size(root._gridCellW, root._gridCellH)
                    playing: visible && source !== ""
                    opacity: status === AnimatedImage.Ready ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: Style.animFast }
                    }
                }
            }

            // Border
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

    // Keybinds hint
    Text {
        id: keybindsText
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.keyboardHintBottomMargin
        anchors.horizontalCenter: parent.horizontalCenter
        text: "↑/↓/←/→ Navigate  |  Enter Apply  |  R Random  |  F5 Refresh  |  S Settings  |  Esc Quit"
        color: Color.mOutline
        font.pixelSize: Style.keyboardHintFontSize
        style: Text.Outline
        styleColor: Color.mScrim
    }
}
