import QtQuick
import QtQuick.Effects
import "../../utils/CacheUtils.js" as CacheUtils
import qs.services

Item {
  id: root

  property var currentWallpaperItem: null
  property real parallaxX: 0
  property color dominantColor: Color.mPrimary
  property real overlayOpacity: 0.4
  property bool showPreview: true
  property int slideDuration: Style.defaultBgSlideDuration

  property string _sourceA: ""
  property string _sourceB: ""
  property real crossfadeProgress: 1.0

  property var _prevItem: null

  PropertyAnimation {
    id: bgSlideAnim
    target: root
    properties: "crossfadeProgress"
    from: 0
    to: 1.0
    duration: root.slideDuration
    easing.type: Style.easingOutQuad
  }

  onCurrentWallpaperItemChanged: {
    updateBackground(currentWallpaperItem);
  }

  Connections {
    target: ServiceLocator.cacheService || null
    function onThumbCacheVersionChanged() {
      root._updateSources(root.currentWallpaperItem, root._prevItem);
    }
  }

  function updateBackground(newItem) {
    if (!newItem) {
      _sourceA = "";
      _sourceB = "";
      _prevItem = null;
      return;
    }

    const oldItem = _prevItem;
    _prevItem = newItem;

    crossfadeProgress = 0.0;
    bgSlideAnim.restart();

    _updateSources(newItem, oldItem);
  }

  function _updateSources(activeItem, outgoingItem) {
    _sourceA = _resolvePath(activeItem);
    _sourceB = _resolvePath(outgoingItem);
  }

  function _resolvePath(item) {
    if (!item)
      return "";
    if (item.type === "local") {
      const cacheService = ServiceLocator.cacheService;
      const thumbMap = cacheService ? cacheService.thumbHashToPath : {};
      const p = CacheUtils.getCachedBgPreview(thumbMap, item.path);
      if (p) {
        return "file://" + p;
      } else if (!item.isVideo && !item.isGif) {
        return "file://" + item.path;
      } else {
        return "";
      }
    } else if (item.type === "remote" && item.thumb) {
      return item.thumb;
    }
    return "";
  }

  Image {
    id: bgImageA
    anchors.fill: parent
    x: root.parallaxX
    scale: 1.0 + (1.0 - root.crossfadeProgress) * 0.03
    z: -2
    visible: root.showPreview && _sourceA !== ""
    opacity: visible ? root.crossfadeProgress : 0
    source: root._sourceA
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
    mipmap: true
    sourceSize: Qt.size(parent.width, parent.height)
    cache: true
  }

  Image {
    id: bgImageB
    anchors.fill: parent
    x: root.parallaxX
    scale: 1.0 + root.crossfadeProgress * 0.03
    z: -2
    visible: root.showPreview && _sourceB !== ""
    opacity: visible ? (1.0 - root.crossfadeProgress) : 0
    source: root._sourceB
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
    mipmap: true
    sourceSize: Qt.size(parent.width, parent.height)
    cache: true
  }

  Rectangle {
    anchors.fill: parent
    color: Color.mScrim
    opacity: root.overlayOpacity
    z: -1
  }
}
