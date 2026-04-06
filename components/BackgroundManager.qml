import QtQuick
import QtQuick.Effects

Item {
  id: root

  property string sourceA: ""
  property string sourceB: ""
  property real crossfadeProgress: 0.0 // 0.0 to 1.0
  property real parallaxX: 0
  property color dominantColor: "#6a9eff"
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
    sourceSize: Qt.size(1920, 1080)
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
    sourceSize: Qt.size(1920, 1080)
    cache: true
  }

  // Dark Overlay
  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: root.overlayOpacity
    z: -1
  }

  // Dominant Color Logo
  Image {
    id: nixosLogo
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 120
    width: 160
    height: 160
    source: Qt.resolvedUrl("../assets/nixos-logo.svg")
    fillMode: Image.PreserveAspectFit
    smooth: true
    z: 10

    layer.enabled: true
    layer.effect: MultiEffect {
      colorization: 1.0
      colorizationColor: Qt.color(root.dominantColor)
      blurEnabled: true
      blur: 0.12
      brightness: 1.3
      Behavior on colorizationColor {
        ColorAnimation {
          duration: 200
        }
      }
    }
  }
}
