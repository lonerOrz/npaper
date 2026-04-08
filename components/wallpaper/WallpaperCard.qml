import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../../utils/CacheUtils.js" as CacheUtils
import qs.services

Item {
  id: root

  property string wallpaperPath: ""
  property string filename: ""
  property bool isVideo: false
  property bool isGif: false

  // Remote wallpaper properties
  property bool isRemote: false
  property string remoteId: ""
  property string remoteThumb: ""

  property real itemWidth: Style.carouselItemWidth > 0 ? Style.carouselItemWidth : 480
  property real itemHeight: Style.carouselItemHeight > 0 ? Style.carouselItemHeight : 270
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

  property bool _isHovered: false

  width: itemWidth
  height: itemHeight
  scale: visualScale * (_isHovered ? 1.02 : 1.0)
  opacity: visualOpacity
  z: visualZ + (_isHovered ? 10 : 0)
  transformOrigin: Item.Center

  Behavior on scale {
    NumberAnimation {
      duration: Style.animFast
      easing.type: Easing.OutCubic
    }
  }

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

  // ── Rounded rect mask ──────────────────────────────────────
  Item {
    id: roundMask
    width: itemWidth
    height: itemHeight
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
        startX: root.itemRadius
        startY: 0
        PathLine {
          x: root.itemWidth - root.itemRadius
          y: 0
        }
        PathArc {
          x: root.itemWidth
          y: root.itemRadius
          radiusX: root.itemRadius
          radiusY: root.itemRadius
        }
        PathLine {
          x: root.itemWidth
          y: root.itemHeight - root.itemRadius
        }
        PathArc {
          x: root.itemWidth - root.itemRadius
          y: root.itemHeight
          radiusX: root.itemRadius
          radiusY: root.itemRadius
        }
        PathLine {
          x: root.itemRadius
          y: root.itemHeight
        }
        PathArc {
          x: 0
          y: root.itemHeight - root.itemRadius
          radiusX: root.itemRadius
          radiusY: root.itemRadius
        }
        PathLine {
          x: 0
          y: root.itemRadius
        }
        PathArc {
          x: root.itemRadius
          y: 0
          radiusX: root.itemRadius
          radiusY: root.itemRadius
        }
      }
    }
  }

  // ── Shadow (sibling, NO transform) ─────────────────────────
  Rectangle {
    id: shadowItem
    anchors.fill: parent
    radius: itemRadius
    color: Color.mShadow
    opacity: root.showShadow ? visualShadowOpacity : 0
    z: -1
    x: Style.spaceXS
    y: Style.spaceS
    visible: root.showShadow && visualShadowOpacity > 0
  }

  // ── Card content (clipped via MultiEffect mask) ────────────
  Item {
    id: cardContent
    anchors.fill: parent
    visible: visualOpacity > 0.01
    layer.enabled: true
    layer.smooth: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: roundMask
      maskThresholdMin: 0.3
      maskSpreadAtMin: 0.3
    }

    Rectangle {
      anchors.fill: parent
      color: {
        if (root.isCenter)
          return "transparent";
        if (root._isHovered)
          return Qt.rgba(0, 0, 0, 0.15);
        return Qt.rgba(0, 0, 0, 0.4);
      }
      Behavior on color {
        ColorAnimation {
          duration: Style.animNormal
        }
      }
    }

    Image {
      id: staticImage
      anchors.fill: parent
      source: CacheUtils.getWallpaperStaticSource(root.thumbHashToPath, root.wallpaperPath, root.isVideo, root.isGif, root.isRemote, root.remoteThumb)
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      smooth: root.isCenter || root.isRemote
      mipmap: true
      sourceSize: Qt.size(root.itemWidth, root.itemHeight)
      opacity: status === Image.Ready ? 1.0 : 0.0
      Behavior on opacity {
        NumberAnimation {
          duration: Style.animFast
        }
      }

      // Download indicator overlay for remote items
      Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.spaceM
        width: indicatorIcon.implicitWidth + Style.spaceM * 2
        height: Style.spaceXL * 2
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: root.isRemote

        Text {
          id: indicatorIcon
          anchors.centerIn: parent
          text: "↓"
          font.pixelSize: Style.cardLabelFontSize
          color: Color.mPrimary
        }
      }
    }

    AnimatedImage {
      id: animatedGif
      anchors.fill: parent
      source: CacheUtils.getWallpaperAnimatedSource(root.thumbHashToPath, root.wallpaperPath, root.isVideo, root.isGif, root.isCenter)
      visible: source !== ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      smooth: true
      mipmap: true
      playing: visible
      sourceSize: Qt.size(Style.cacheAnimWidth, Style.cacheAnimHeight)
    }

    Item {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: Style.cardLabelHeight + Style.spaceM * 2
      Rectangle {
        anchors.fill: parent
        gradient: Gradient {
          GradientStop {
            position: 0.0
            color: "transparent"
          }
          GradientStop {
            position: 0.3
            color: Qt.rgba(0, 0, 0, 0.05)
          }
          GradientStop {
            position: 1.0
            color: Qt.rgba(0, 0, 0, 0.55)
          }
        }
      }
      Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.spaceM
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Style.cardLabelMargins
        text: root.filename
        color: Color.mInverseSurface
        font.pixelSize: Style.cardLabelFontSize
        font.weight: Font.Medium
        elide: Text.ElideMiddle
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }

  // ── Border (on top, NOT clipped) ───────────────────────────
  Shape {
    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    visible: !(root.isCenter && root.showBorderGlow)

    ShapePath {
      fillColor: "transparent"
      strokeColor: {
        if (root.isCenter)
          return Color.mPrimary;
        if (root._isHovered)
          return Color.mPrimaryContainer;
        return "transparent";
      }
      Behavior on strokeColor {
        ColorAnimation {
          duration: Style.animFast
        }
      }
      strokeWidth: root.isCenter ? Style.borderM : (root._isHovered ? Style.borderS : 0)
      startX: root.itemRadius
      startY: 0
      PathLine {
        x: root.itemWidth - root.itemRadius
        y: 0
      }
      PathArc {
        x: root.itemWidth
        y: root.itemRadius
        radiusX: root.itemRadius
        radiusY: root.itemRadius
      }
      PathLine {
        x: root.itemWidth
        y: root.itemHeight - root.itemRadius
      }
      PathArc {
        x: root.itemWidth - root.itemRadius
        y: root.itemHeight
        radiusX: root.itemRadius
        radiusY: root.itemRadius
      }
      PathLine {
        x: root.itemRadius
        y: root.itemHeight
      }
      PathArc {
        x: 0
        y: root.itemHeight - root.itemRadius
        radiusX: root.itemRadius
        radiusY: root.itemRadius
      }
      PathLine {
        x: 0
        y: root.itemRadius
      }
      PathArc {
        x: root.itemRadius
        y: 0
        radiusX: root.itemRadius
        radiusY: root.itemRadius
      }
    }
  }

  // ── Glow shader ────────────────────────────────────────────
  ShaderEffect {
    anchors.fill: parent
    z: 5
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

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onContainsMouseChanged: root._isHovered = containsMouse
    onClicked: root.clicked(root.wallpaperPath)
  }
}
