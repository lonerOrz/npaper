import QtQuick
import "../../utils/CacheUtils.js" as CacheUtils
import qs.services

Item {
  id: root

  required property string wallpaperPath
  required property string filename
  property bool isVideo: false
  property bool isGif: false

  property real itemWidth: Style.carouselItemWidth
  property real itemHeight: Style.carouselItemHeight
  property real itemRadius: Style.radiusM

  property real visualScale: 1.0
  property real visualOpacity: 1.0
  property real visualRotationY: 0
  property int visualZ: 0
  property real visualYOffset: 0
  property real visualShadowOpacity: 0
  property bool showBorderGlow: true
  property bool showShadow: true
  property bool isCenter: false

  property var thumbHashToPath: ({})

  signal clicked(string path)

  width: itemWidth
  height: itemHeight
  scale: visualScale
  opacity: visualOpacity
  z: visualZ
  transformOrigin: Item.Center

  transform: Rotation {
    axis {
      x: 0
      y: 1
      z: 0
    }
    angle: visualRotationY
    origin.x: width / 2
    origin.y: height / 2
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: Style.cardInnerPadding
    anchors.topMargin: Style.cardTopPadding
    radius: itemRadius
    color: Color.mScrim
    opacity: root.showShadow && visualShadowOpacity > 0 ? visualShadowOpacity : 0
    z: -1
  }

  ShaderEffect {
    anchors.fill: parent
    z: 4
    visible: root.isCenter && root.showBorderGlow
    property real time: 0
    property real innerWidth: width
    property real innerHeight: height
    property real innerRadius: itemRadius

    NumberAnimation on time {
      from: 0
      to: 1000
      duration: 30000
      loops: Animation.Infinite
      running: root.isCenter && root.showBorderGlow
    }

    fragmentShader: Qt.resolvedUrl("../../shaders/borderGlow.frag.qsb")
  }

  Rectangle {
    id: cardFrame
    anchors.fill: parent
    anchors.margins: Style.cardInnerPadding
    color: "transparent"
    radius: itemRadius
    border.color: (root.isCenter && !root.showBorderGlow) ? Color.mPrimary : "transparent"
    border.width: Style.borderM

    Rectangle {
      id: imageFrame
      anchors.fill: parent
      anchors.margins: Style.cardImageFrameMargin
      radius: Style.radiusS
      color: Color.mSurfaceContainerLowest
      opacity: Style.cardImageFrameOpacity
      clip: true
      layer.enabled: true
      layer.smooth: true
      layer.mipmap: true

      Item {
        anchors.fill: parent
        anchors.margins: root.isCenter ? Math.ceil(imageFrame.radius * 0.3) : 0

        Rectangle {
          anchors.fill: parent
          color: Color.mSurfaceContainerLow
          visible: !root.isVideo && !root.isGif && staticImage.status !== Image.Ready && animatedGif.status !== AnimatedImage.Ready
        }

        AnimatedImage {
          id: animatedGif
          anchors.fill: parent
          visible: (root.isGif || root.isVideo) && root.isCenter
          source: {
            const cached = CacheUtils.getCachedAnimatedGif(root.thumbHashToPath, root.wallpaperPath);
            return cached ? "file://" + cached : "";
          }
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          smooth: true
          mipmap: true
          playing: visible
          sourceSize: Qt.size(root.itemWidth, root.itemHeight)
        }

        Image {
          id: staticImage
          anchors.fill: parent
          source: {
            const path = root.wallpaperPath;
            if (!path || path.length === 0 || path.endsWith('/'))
              return "";
            if ((root.isGif || root.isVideo) && root.isCenter && animatedGif.status === AnimatedImage.Ready && animatedGif.visible)
              return "";
            const thumb = CacheUtils.getCachedThumb(root.thumbHashToPath, path);
            if (thumb)
              return "file://" + thumb;
            if (root.isVideo)
              return "";
            return "file://" + path;
          }
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          smooth: root.isCenter
          mipmap: true
          opacity: status === Image.Ready ? 1 : 0
          sourceSize: Qt.size(root.itemWidth, root.itemHeight)
        }

        Text {
          anchors.centerIn: parent
          text: "🎬"
          font.pixelSize: Style.cardVideoIconSize
          visible: (root.isVideo || root.isGif) && !root.isCenter && staticImage.status !== Image.Ready
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.clicked(root.wallpaperPath)
        }
      }

      Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Style.cardLabelMargins
        height: Style.cardLabelHeight
        color: "transparent"

        Text {
          anchors.centerIn: parent
          text: root.filename
          color: Color.mInverseSurface
          font.pixelSize: Style.cardLabelFontSize
          font.weight: Font.Medium
          elide: Text.ElideMiddle
        }
      }
    }
  }
}
