import QtQuick
import QtQuick.Effects
import qs.services

Item {
  id: root

  property string sourceA: ""
  property string sourceB: ""
  property real crossfadeProgress: 0.0 // 0.0 to 1.0
  property real parallaxX: 0
  property color dominantColor: Color.mPrimary
  property real overlayOpacity: 0.4
  property bool showPreview: true

  // Image A (Active/Outgoing)
  Image {
    id: bgImageA
    anchors.fill: parent
    x: root.parallaxX + (root.crossfadeProgress * width)
    z: -2
    visible: root.showPreview && sourceA !== ""
    opacity: visible ? root.crossfadeProgress : 0
    source: root.sourceA
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
    mipmap: true
    sourceSize: Qt.size(parent.width, parent.height)
    cache: true
  }

  // Image B (Incoming/Previous)
  Image {
    id: bgImageB
    anchors.fill: parent
    x: root.parallaxX + ((root.crossfadeProgress - 1) * width)
    z: -2
    visible: root.showPreview && sourceB !== ""
    opacity: visible ? (1.0 - root.crossfadeProgress) : 0
    source: root.sourceB
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
    mipmap: true
    sourceSize: Qt.size(parent.width, parent.height)
    cache: true
  }

  // Dark Overlay
  Rectangle {
    anchors.fill: parent
    color: Color.mScrim
    opacity: root.overlayOpacity
    z: -1
  }
}
