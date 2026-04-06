import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "utils"
import "utils/CacheUtils.js" as CacheUtils
import "utils/FileTypes.js" as FileTypes
import "components"
import "components/SettingsPanel.qml"

PanelWindow {
    id: root

    property var modelData
    property var viewModel
    property var wallpaperModel
    property var cacheService
    property var wallpaperApplier
    property var checkService

    property bool settingsOpen: false
    screen: modelData

    Style { id: styleConstants }

    // ViewModel Bindings (No direct Model access)
    property real carouselItemWidth: viewModel ? viewModel.get("carouselItemWidth", 450) : 450
    property real carouselItemHeight: viewModel ? viewModel.get("carouselItemHeight", 320) : 320
    property real carouselSpacing: viewModel ? viewModel.get("carouselSpacing", 25) : 25
    property real carouselRotation: viewModel ? viewModel.get("carouselRotation", 40) : 40
    property real carouselPerspective: viewModel ? viewModel.get("carouselPerspective", 0.3) : 0.3
    readonly property bool debugMode: viewModel ? viewModel.get("debugMode", false) : false

    visible: true
    color: "transparent"
    implicitWidth: screen.width
    implicitHeight: screen.height

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusiveZone: -1

    property string searchText: ""
    property real scrollIndex: 0
    property real _cachedScrollIndex: 0
    property real scrollVelocity: 0
    property real lastScrollIndex: 0
    property int scrollTimestamp: 0
    property real scrollTarget: 0
    property int keyScrollDirection: 0
    property int keyScrollStep: 1
    property bool isKeyScrolling: false

    readonly property int count: wallpaperModel ? wallpaperModel.count : 0
    readonly property int visibleRange: styleConstants.visibleRange
    readonly property int preloadRange: styleConstants.preloadRange
    readonly property int centerIndex: Math.round(scrollIndex)
    readonly property int baseIndex: Math.max(0, centerIndex - visibleRange - preloadRange)
    readonly property int maxIndex: Math.min(count - 1, centerIndex + visibleRange + preloadRange)
    readonly property int loadedCount: count > 0 ? Math.max(0, maxIndex - baseIndex + 1) : 0

    // Behavior animations using config
    Behavior on scrollTarget {
        NumberAnimation {
            duration: viewModel ? viewModel.get("scrollDuration", 280) : 280
            easing.type: styleConstants.easingOutCubic
        }
    }

    Timer {
        id: scrollContinueTimer
        interval: viewModel ? viewModel.get("scrollContinueInterval", 230) : 230
        repeat: false
        onTriggered: {
            if (isKeyScrolling && keyScrollDirection !== 0 && root.count > 0) {
                const step = keyScrollStep || 1
                const maxIdx = root.count - 1
                const currentIdx = Math.round(scrollTarget)
                let nextIdx = currentIdx
                if (keyScrollDirection === -1) nextIdx = Math.max(0, currentIdx - step)
                else nextIdx = Math.min(maxIdx, currentIdx + step)
                if (nextIdx !== currentIdx) scrollTarget = nextIdx
                else isKeyScrolling = false
            } else isKeyScrolling = false
        }
    }

    onScrollTargetChanged: {
        scrollIndex = scrollTarget;
    }

    Component.onCompleted: {
        scrollTarget = 0
        if (wallpaperModel) wallpaperModel.dataLoaded.connect(applyFolderSelection)
    }

    // Background logic
    property int bgCurrent: -1
    property int bgPrevious: -1
    property real bgSlideProgress: 0.0
    property string _bgSourceA: ""
    property string _bgSourceB: ""

    onBgCurrentChanged: {
        if (!cacheService || !wallpaperModel) return
        if (bgCurrent >= 0 && bgCurrent < wallpaperModel.list.length) {
            const path = wallpaperModel.list[bgCurrent]
            const p = CacheUtils.getCachedBgPreview(cacheService.thumbHashToPath, path)
            _bgSourceA = p ? ("file://" + p) : ("file://" + path)
        }
    }
    onBgPreviousChanged: {
        if (!cacheService || !wallpaperModel) return
        if (bgPrevious >= 0 && bgPrevious < wallpaperModel.list.length) {
            const path = wallpaperModel.list[bgPrevious]
            const p = CacheUtils.getCachedBgPreview(cacheService.thumbHashToPath, path)
            _bgSourceB = p ? ("file://" + p) : ("file://" + path)
        }
    }

    PropertyAnimation {
        id: bgSlideAnim; target: root; properties: "bgSlideProgress"; from: 0; to: 1.0
        duration: viewModel ? viewModel.get("bgSlideDuration", 250) : 250
        easing.type: styleConstants.easingOutQuad
    }

    readonly property real bgBaseParallaxX: (scrollIndex - centerIndex) * (viewModel ? viewModel.get("bgParallaxFactor", 40) : 40)

    onScrollIndexChanged: {
        if (!cacheService || !wallpaperModel) return
        _cachedScrollIndex = scrollIndex
        const now = Date.now(); const dt = now - scrollTimestamp
        if (dt > 0 && dt < 200) scrollVelocity = (scrollIndex - lastScrollIndex) / dt * 1000
        lastScrollIndex = scrollIndex; scrollTimestamp = now

        const c = centerIndex
        if (c !== bgCurrent && c >= 0 && c < wallpaperModel.list.length) {
            bgPrevious = bgCurrent; bgCurrent = c
            bgSlideProgress = 0; bgSlideAnim.restart()
            extractDominantColor(wallpaperModel.list[c])
        }
        let q = 0
        for (let i = baseIndex; i <= maxIndex && i < wallpaperModel.list.length; i++) {
            cacheService.queueThumbnail(wallpaperModel.list[i], FileTypes.isVideoFile(wallpaperModel.list[i]), FileTypes.isGifFile(wallpaperModel.list[i]))
            q++
        }
        if (root.debugMode) console.log("[npaper] scrollTick:", "idx=" + Math.round(scrollIndex), "queue=" + q)
    }

    property string dominantColor: "#6a9eff"

    function extractDominantColor(wp) {
        if (!checkService || !checkService.hasImagemagick || !wp || wp.length === 0) { root.dominantColor = "#6a9eff"; return }
        const t = CacheUtils.getCachedThumb(cacheService.thumbHashToPath, wp)
        if (t) { runColorExtract(t); return }
        if (FileTypes.isVideoFile(wp)) { root.dominantColor = "#6a9eff"; return }
        runColorExtract(wp.toLowerCase().endsWith('.gif') ? wp + '[0]' : wp)
    }
    function runColorExtract(src) {
        if (extractColorProcess.running) extractColorProcess.running = false
        extractColorTimeout.start()
        extractColorProcess.command = ["magick", src, "-resize", "1x1!", "-modulate", "100,180", "txt:"]
        extractColorProcess.exec({})
    }
    function randomWallpaper() { if (root.count > 0) scrollTarget = Math.floor(Math.random() * root.count) }
    function applyFolderSelection() {
        scrollTarget = 0; scrollIndex = 0; _cachedScrollIndex = 0
        bgPrevious = -1; bgCurrent = -1; bgSlideProgress = 1.0
        if (wallpaperModel.list.length > 0) { bgCurrent = 0; extractDominantColor(wallpaperModel.list[0]) }
    }
    function switchFolder(f) { wallpaperModel.switchFolder(f); applyFolderSelection() }
    function refreshCache() {
        const f = wallpaperModel.currentFolder; const ps = wallpaperModel.wallpaperMap[f] || []
        if (ps.length === 0) return
        cacheService.refreshAndQueue(ps, f)
    }
    function setScrollIndex(v) {
        if (root.count === 0) return
        const c = Math.max(0, Math.min(v, root.count - 1))
        if (c !== scrollTarget) scrollTarget = c
    }
    function applyWallpaper(path) { if (wallpaperApplier) wallpaperApplier.apply(path); Qt.quit() }

    Timer { id: extractColorTimeout; interval: 5000; onTriggered: root.dominantColor = "#6a9eff" }
    Process {
        id: extractColorProcess
        stdout: StdioCollector {
            onStreamFinished: {
                extractColorTimeout.stop()
                const m = text.trim().match(/#([0-9A-F]{6})/i)
                root.dominantColor = m ? "#" + m[1].toUpperCase() : "#6a9eff"
            }
        }
        onExited: function (exitCode, exitStatus) { extractColorTimeout.stop(); if (exitCode !== 0) root.dominantColor = "#6a9eff" }
    }
    Timer { id: searchDebounce; interval: styleConstants.searchDebounceMs; onTriggered: {
        wallpaperModel.setSearch(root.searchText)
        if (root.searchText) {
            scrollTarget = 0; scrollIndex = 0; _cachedScrollIndex = 0; bgCurrent = 0; bgSlideProgress = 1.0
            if (wallpaperModel.list.length > 0) extractDominantColor(wallpaperModel.list[0])
        } else wallpaperModel.resetSearch()
    }}

    // Background Images
    Image {
        id: bgImageA; anchors.fill: parent; z: -2
        x: root.bgBaseParallaxX + (root.bgSlideProgress * root.width)
        visible: viewModel ? viewModel.get("showBgPreview", true) : true && root.bgCurrent >= 0 && root.bgCurrent < (wallpaperModel ? wallpaperModel.list.length : 0)
        opacity: visible ? root.bgSlideProgress : 0
        source: _bgSourceA; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; mipmap: true; cache: true
        sourceSize: Qt.size(1920 * screen.devicePixelRatio, 1080 * screen.devicePixelRatio)
    }
    Image {
        id: bgImageB; anchors.fill: parent; z: -2
        x: root.bgBaseParallaxX + ((root.bgSlideProgress - 1) * root.width)
        visible: viewModel ? viewModel.get("showBgPreview", true) : true && root.bgPrevious >= 0 && root.bgPrevious < (wallpaperModel ? wallpaperModel.list.length : 0)
        opacity: visible ? (1.0 - root.bgSlideProgress) : 0
        source: _bgSourceB; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; mipmap: true; cache: true
        sourceSize: Qt.size(Math.min(1920, screen.width) * screen.devicePixelRatio, Math.min(1080, screen.height) * screen.devicePixelRatio)
    }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: viewModel ? viewModel.get("bgOverlayOpacity", 0.4) : 0.4; z: -1 }

    // ===== UI =====
    // Main Content Layout
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        anchors.topMargin: 80 // Space for StatusBar (y=16 + h=44 + padding)
        z: 0

        Item {
            id: pathViewContainer
            Layout.fillWidth: true; Layout.fillHeight: true; focus: true; clip: true

            property int itemWidth: root.carouselItemWidth
            property int itemHeight: root.carouselItemHeight
            property real spacing: root.carouselSpacing
            property real centerX: width / 2
            property real centerY: height / 2

            Rectangle { anchors.fill: parent; color: "#0d0d0dcc" }

            Repeater {
                model: root.loadedCount
                delegate: WallpaperCard {
                    required property int index
                    property int realIndex: root.baseIndex + index
                    wallpaperPath: realIndex < wallpaperModel.list.length ? wallpaperModel.list[realIndex] : ""
                    filename: realIndex < (wallpaperModel ? wallpaperModel.filenames.length : 0) ? (wallpaperModel ? wallpaperModel.filenames[realIndex] : "") : ""
                    isVideo: FileTypes.isVideoFile(wallpaperPath)
                    isGif: FileTypes.isGifFile(wallpaperPath)
                    thumbHashToPath: cacheService ? cacheService.thumbHashToPath : {}
                    isCenter: realIndex === root.centerIndex
                    showBorderGlow: viewModel ? viewModel.get("showBorderGlow", true) : true
                    showShadow: viewModel ? viewModel.get("showShadow", true) : true

                    readonly property var metrics: {
                        const raw = realIndex - root._cachedScrollIndex
                        const abs = Math.abs(raw)
                        return { raw, abs, cos: Math.cos(Math.min(abs, 3) * 0.523599), perspectiveScale: 1.0 / (1.0 + abs * root.carouselPerspective) }
                    }
                    readonly property var visual: {
                        const abs = metrics.abs
                        return {
                            scale: metrics.perspectiveScale * (0.85 + metrics.cos * 0.15) + (isCenter ? 0.06 : 0),
                            opacity: abs > 6 ? 0 : Math.pow(Math.max(0, 1 - abs * 0.12), 2.5),
                            rotationY: metrics.raw * -root.carouselRotation, z: 100 - abs * 50,
                            spacingFactor: 0.45 + metrics.cos * 0.35, yOffset: abs * 8, shadowOpacity: abs < 0.6 ? 0.25 : 0
                        }
                    }
                    visualScale: visual.scale; visualOpacity: visual.opacity
                    visualRotationY: visual.rotationY; visualZ: visual.z
                    visualYOffset: visual.yOffset; visualShadowOpacity: visual.shadowOpacity
                    x: pathViewContainer.centerX - width / 2 + metrics.raw * (width + pathViewContainer.spacing) * visual.spacingFactor
                    y: pathViewContainer.centerY - height / 2 + visual.yOffset
                    onClicked: function(path) { setScrollIndex(realIndex); Qt.callLater(() => applyWallpaper(path)) }
                }
            }

            Text {
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottomMargin: 25
                text: "←/→ Navigate  |  Tab/[ ] Switch Folder  |  Enter Apply  |  R Random  |  F5 Refresh  |  S Settings  |  Esc Quit"
                color: "#888888"; font.pixelSize: 11; style: Text.Outline; styleColor: "#000000"
            }

            Image {
                id: nixosLogo; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 160
                width: 160; height: 160; source: Qt.resolvedUrl("assets/nixos-logo.svg")
                fillMode: Image.PreserveAspectFit; smooth: true; visible: root.count > 0; z: 10
                layer.enabled: true
                layer.effect: MultiEffect {
                    colorization: 1.0; colorizationColor: Qt.color(root.dominantColor)
                    blurEnabled: true; blur: 0.12; brightness: 1.3
                    Behavior on colorizationColor { ColorAnimation { duration: 200 } }
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_S && !event.modifiers) { root.settingsOpen = true; event.accepted = true; return }
                if (event.key === Qt.Key_Backspace) {
                    if (root.searchText) { root.searchText = root.searchText.slice(0, -1); searchDebounce.restart() }
                    event.accepted = true; return
                }
                if (event.key === Qt.Key_Escape) {
                    if (root.settingsOpen) { root.settingsOpen = false; event.accepted = true; return }
                    Qt.quit(); event.accepted = true; return
                }
                if (event.key === Qt.Key_Tab) {
                    const fs = wallpaperModel ? wallpaperModel.folders : []
                    if (fs.length > 0) { const idx = fs.indexOf(wallpaperModel ? wallpaperModel.currentFolder : ""); switchFolder(fs[idx < fs.length - 1 ? idx + 1 : 0]) }
                    event.accepted = true; return
                }
                if (event.key === Qt.Key_Backtab) {
                    const fs = wallpaperModel ? wallpaperModel.folders : []
                    if (fs.length > 0) { const idx = fs.indexOf(wallpaperModel ? wallpaperModel.currentFolder : ""); switchFolder(fs[idx > 0 ? idx - 1 : fs.length - 1]) }
                    event.accepted = true; return
                }
                if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BraceLeft) {
                    const fs = wallpaperModel ? wallpaperModel.folders : []
                    if (fs.length > 0) { const idx = fs.indexOf(wallpaperModel ? wallpaperModel.currentFolder : ""); switchFolder(idx > 0 ? fs[idx - 1] : fs[fs.length - 1]) }
                    event.accepted = true; return
                }
                if (event.key === Qt.Key_BracketRight || event.key === Qt.Key_BraceRight) {
                    const fs = wallpaperModel ? wallpaperModel.folders : []
                    if (fs.length > 0) { const idx = fs.indexOf(wallpaperModel ? wallpaperModel.currentFolder : ""); switchFolder(idx >= 0 && idx < fs.length - 1 ? fs[idx + 1] : fs[0]) }
                    event.accepted = true; return
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.count > 0) { const idx = Math.round(root.scrollIndex); applyWallpaper(wallpaperModel.list[((idx % root.count) + root.count) % root.count]) }
                    event.accepted = true; return
                }
                if (event.key === Qt.Key_R && !event.modifiers) { randomWallpaper(); event.accepted = true; return }
                if (event.key === Qt.Key_F5) { refreshCache(); event.accepted = true; return }
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                    const step = (event.modifiers & Qt.ShiftModifier) ? 5 : 1
                    const dir = (event.key === Qt.Key_Left) ? -1 : 1
                    if (keyScrollDirection !== dir) {
                        keyScrollDirection = dir; keyScrollStep = step; isKeyScrolling = true
                        scrollContinueTimer.stop()
                        const maxIdx = root.count - 1
                        if (dir === -1) scrollTarget = Math.max(0, scrollTarget - step)
                        else scrollTarget = Math.min(maxIdx, scrollTarget + step)
                    } else if (step !== keyScrollStep) { keyScrollStep = step }
                    event.accepted = true; return
                }
                if (event.text && event.text.length === 1 && !event.modifiers) { root.searchText += event.text; searchDebounce.restart(); event.accepted = true }
            }
            Keys.onReleased: event => {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                    if (keyScrollDirection === ((event.key === Qt.Key_Left) ? -1 : 1)) { keyScrollDirection = 0; isKeyScrolling = false; scrollContinueTimer.stop() }
                    event.accepted = true
                }
            }
        }
    }

    // Top Status Bar (Floating, above layout)
    StatusBar {
        id: statusBar
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        z: 100

        folders: wallpaperModel ? wallpaperModel.folders : []
        activeFolder: wallpaperModel ? wallpaperModel.currentFolder : ""
        onFolderClicked: function(folder) { switchFolder(folder) }

        wallpaperCount: root.count
        cachedCount: cacheService ? cacheService.cachedFileCount : 0
        queueCount: cacheService ? cacheService.queueLength + cacheService.thumbnailJobRunning : 0
        
        settingsOpen: root.settingsOpen
        onSettingsToggled: root.settingsOpen = !root.settingsOpen
    }

    // Settings Panel (Anchored to StatusBar)
    SettingsPanel {
        id: settingsPanel
        anchors.top: statusBar.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: statusBar.horizontalCenter
        z: 999
        openDownward: true

        viewModel: root.viewModel
        settingsOpen: root.settingsOpen
        onCloseRequested: {
            root.settingsOpen = false
            // Return focus to main view
            pathViewContainer.forceActiveFocus()
        }
    }
}
