import QtQuick
import qs.components.wallpaper
import qs.services

/*
 * DisplayManager — unified display manager with Loader-based mode switching.
 *
 * Inputs:
 *   adapter, cacheService
 *
 * Outputs (properties):
 *   currentIndex, scrollTarget
 *
 * Outputs (signals — all proxied from active child):
 *   requestQuit, requestSettings, requestPrevFolder, requestNextFolder,
 *   requestFocusSearch, requestApplyItem, requestRandom,
 *   requestToggleWallhaven, requestRefresh
 *
 * Methods:
 *   reset(), scrollTo(idx), focusView()
 *
 * Internal:
 *   Auto-manages thumbnail queue on data load
 *   Auto-refreshes background sources on cache version change
 *
 * Switching: Config.previewStyle ("carousel" | "grid")
 */
FocusScope {
    id: root

    focus: true

    property var adapter: null
    property var cacheService: null

    readonly property var _activeView: carouselLoader.active && carouselLoader.item
        ? carouselLoader.item
        : (gridLoader.item || null)
    readonly property int currentIndex: _activeView ? _activeView.currentIndex : 0
    readonly property real scrollTarget: _activeView ? _activeView.scrollTarget : 0

    signal requestQuit()
    signal requestSettings()
    signal requestPrevFolder()
    signal requestNextFolder()
    signal requestFocusSearch()
    signal requestApplyItem(var item)
    signal requestRandom()
    signal requestToggleWallhaven()
    signal requestRefresh()

    // ── Public API ─────────────────────────────────────────
    function reset() {
        if (_activeView) _activeView.reset();
    }

    function scrollTo(idx) {
        if (_activeView) _activeView.scrollTo(idx);
    }

    function focusView() {
        if (_activeView) _activeView.focusView();
    }

    function queueVisibleThumbnails() {
        root._queueVisibleThumbnails();
    }

    // ── Internal: thumbnail queue management ───────────────
    function _queueVisibleThumbnails() {
        if (!adapter || !cacheService)
            return;
        if (adapter.currentSource !== "local")
            return;
        if (carouselLoader.item) carouselLoader.item.queueVisibleThumbnails();
        if (gridLoader.item) gridLoader.item.queueVisibleThumbnails();
    }

    Component.onCompleted: {
        Qt.callLater(root._queueVisibleThumbnails);
    }

    // ── Carousel Loader ────────────────────────────────────
    Loader {
        id: carouselLoader
        anchors.fill: parent
        active: Config.previewStyle !== "grid"
        asynchronous: true
        focus: active

        onLoaded: {
            if (item) {
                item.focusView();
                root._queueVisibleThumbnails();
            }
        }

        sourceComponent: CarouselView {
            adapter: root.adapter
            cacheService: root.cacheService

            onRequestQuit: root.requestQuit()
            onRequestSettings: root.requestSettings()
            onRequestPrevFolder: root.requestPrevFolder()
            onRequestNextFolder: root.requestNextFolder()
            onRequestFocusSearch: root.requestFocusSearch()
            onRequestApplyItem: function(item) { root.requestApplyItem(item) }
            onRequestRandom: root.requestRandom()
            onRequestToggleWallhaven: root.requestToggleWallhaven()
            onRequestRefresh: root.requestRefresh()
        }
    }

    // ── Grid Loader ────────────────────────────────────────
    Loader {
        id: gridLoader
        anchors.fill: parent
        active: Config.previewStyle === "grid"
        asynchronous: true
        focus: active

        onLoaded: {
            if (item) {
                item.focusView();
                root._queueVisibleThumbnails();
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
            onRequestApplyItem: function(item) { root.requestApplyItem(item) }
            onRequestRandom: root.requestRandom()
            onRequestToggleWallhaven: root.requestToggleWallhaven()
            onRequestRefresh: root.requestRefresh()
        }
    }
}
