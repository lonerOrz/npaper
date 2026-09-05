import QtQuick
import QtQuick.Effects
import "../../utils/CacheUtils.js" as CacheUtils
import qs.services

Item {
  id: root

  property var currentWallpaperItem: null
  property var thumbHashToPath: ({})
  property real parallaxX: 0
  property color dominantColor: Color.mPrimary
  property real overlayOpacity: 0.4
  property bool showPreview: true
  property int slideDuration: Style.defaultBgSlideDuration

  property string _sourceA: ""
  property string _sourceB: ""
  property real crossfadeProgress: 1.0
  property var _prevItem: null

  Timer {
    id: bgSwitchDebounce
    interval: 70
    repeat: false
    onTriggered: _applyBackgroundUpdate(root.currentWallpaperItem)
  }

  onCurrentWallpaperItemChanged: {
    bgSwitchDebounce.restart();
  }

  PropertyAnimation {
    id: bgSlideAnim
    target: root
    properties: "crossfadeProgress"
    from: 0.0
    to: 1.0
    duration: root.slideDuration
    easing.type: Style.easingOutQuad
    onFinished: {
      root._sourceB = "";
    }
  }

  Component.onCompleted: {
    root.thumbHashToPath = ServiceLocator.cacheService ? ServiceLocator.cacheService.thumbHashToPath : ({});
  }

  Connections {
    target: ServiceLocator.cacheService || null
    function onThumbCacheVersionChanged() {
      root.thumbHashToPath = ServiceLocator.cacheService.thumbHashToPath;
    }
  }

  function _applyBackgroundUpdate(newItem) {
    if (!newItem) {
      _sourceA = "";
      _sourceB = "";
      _prevItem = null;
      return;
    }

    const nextSource = CacheUtils.resolveBgSource(root.thumbHashToPath, newItem);
    if (nextSource === _sourceA && _sourceA !== "")
      return;

    const oldItem = _prevItem;
    _prevItem = newItem;

    _sourceB = _sourceA;
    _sourceA = nextSource;

    crossfadeProgress = 0.0;
    bgSlideAnim.restart();
  }

  Image {
    id: bgImageA
    anchors.fill: parent
    scale: 1.0 + (1.0 - root.crossfadeProgress) * 0.02
    z: -2
    visible: root.showPreview && _sourceA !== ""
    opacity: visible ? root.crossfadeProgress : 0
    source: root._sourceA
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
    mipmap: false
    sourceSize: Qt.size(parent.width, parent.height)
    cache: true

    transform: Translate {
      x: root.parallaxX
    }
  }

  Image {
    id: bgImageB
    anchors.fill: parent
    scale: 1.0 + root.crossfadeProgress * 0.02
    z: -2
    visible: root.showPreview && _sourceB !== "" && root.crossfadeProgress < 0.99
    opacity: visible ? (1.0 - root.crossfadeProgress) : 0
    source: root._sourceB
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
    mipmap: false
    sourceSize: Qt.size(parent.width, parent.height)
    cache: true

    transform: Translate {
      x: root.parallaxX
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Color.mScrim
    opacity: root.overlayOpacity
    z: -1
  }
}
