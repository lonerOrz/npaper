import QtQuick
import QtQuick.Effects
import "../../utils/CacheUtils.js" as CacheUtils
import qs.services

Item {
  id: root

  property var thumbHashToPath: ({})
  property var whService: null
  property int itemIndex: -1

  property var wallpaperItem: null

  property string wallpaperPath: ""
  property string filename: ""
  property bool isRemote: false
  property string remoteId: ""

  property real itemWidth: Style.carouselItemWidth > 0 ? Style.carouselItemWidth : 480
  property real itemHeight: Style.carouselItemHeight > 0 ? Style.carouselItemHeight : 270
  property real itemRadius: Style.radiusL

  property real visualScale: 1.0
  property real visualOpacity: 1.0
  property real visualRotationY: 0
  property int visualZ: 0
  property real visualYOffset: 0
  property real visualShadowOpacity: 0
  property bool showShadow: true
  property bool isCenter: false

  readonly property var downloadStatus: (whService && whService.downloadStatus) ? whService.downloadStatus : ({})
  readonly property var downloadProgress: (whService && whService.downloadProgress) ? whService.downloadProgress : ({})
  readonly property var downloadPaths: (whService && whService.downloadPaths) ? whService.downloadPaths : ({})
  property string downloadPath: ""

  signal clicked(string path)

  readonly property bool _isHovered: cardHover.hovered

  width: itemWidth
  height: itemHeight
  scale: visualScale
  opacity: visualOpacity
  z: visualZ + (_isHovered ? 15 : 0)
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

  HoverHandler {
    id: cardHover
  }

  Item {
    id: roundMask
    anchors.fill: parent
    visible: false
    layer.enabled: true

    Rectangle {
      anchors.fill: parent
      radius: root.itemRadius
      color: "white"
      antialiasing: true
    }
  }

  Item {
    id: shadowItem
    anchors.fill: parent
    anchors.topMargin: -8
    anchors.leftMargin: -8
    anchors.rightMargin: -8
    anchors.bottomMargin: -8
    z: -1
    visible: root.showShadow && visualShadowOpacity > 0.01

    layer.enabled: visible
    layer.effect: MultiEffect {
      blurEnabled: true
      blur: 1.0
      blurMax: 32
    }

    Rectangle {
      anchors.fill: parent
      radius: root.itemRadius + 4
      color: Color.mShadow
      opacity: root.showShadow ? visualShadowOpacity * 2.5 : 0

      Behavior on opacity {
        NumberAnimation {
          duration: Style.animNormal
          easing.type: Easing.OutCubic
        }
      }
    }
  }

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

    scale: 1.0

    Rectangle {
      anchors.fill: parent
      color: {
        if (root.isCenter)
          return "transparent";
        if (root._isHovered)
          return Qt.rgba(0, 0, 0, 0.10);
        return Qt.rgba(0, 0, 0, 0.30);
      }
      Behavior on color {
        ColorAnimation {
          duration: Style.animNormal
          easing.type: Easing.OutCubic
        }
      }
    }

    Image {
      id: staticImage
      anchors.fill: parent
      source: CacheUtils.resolveWallpaperStaticSource(root.thumbHashToPath, root.wallpaperItem)
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      smooth: root.isCenter || root.isRemote
      mipmap: false
      sourceSize: Qt.size(root.itemWidth, root.itemHeight)
      opacity: status === Image.Ready ? 1.0 : (status === Image.Error ? 0.3 : 0.0)

      Behavior on opacity {
        NumberAnimation {
          duration: 100
        }
      }

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
      source: CacheUtils.resolveWallpaperAnimatedSource(root.thumbHashToPath, root.wallpaperItem, root.isCenter)
      visible: source !== ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      smooth: true
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

  Rectangle {
    anchors.fill: parent
    radius: root.itemRadius
    color: "transparent"
    z: 20
    visible: !root.isCenter && root._isHovered
    border.width: Style.borderS
    border.color: Qt.lighter(Color.mPrimaryContainer, 1.15)

    Behavior on border.color {
      ColorAnimation {
        duration: Style.animNormal
        easing.type: Easing.OutCubic
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: root.itemRadius
    color: "transparent"
    visible: root.isRemote
    opacity: root._isHovered ? 1 : 0
    z: 10

    Behavior on opacity {
      NumberAnimation {
        duration: Style.animFast
      }
    }

    DownloadOverlay {
      opacity: parent.opacity
      whId: root.remoteId.replace("wallhaven-", "")
      downloadPath: root.downloadPath
      whService: root.whService
      downloadStatus: root.downloadStatus
      downloadProgress: root.downloadProgress
      downloadPaths: root.downloadPaths
      onApplyLocal: function (localPath) {
        root.clicked(localPath);
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: root.itemRadius
    color: "transparent"
    visible: !root.isRemote
    opacity: root._isHovered ? 1 : 0
    z: 10

    Behavior on opacity {
      NumberAnimation {
        duration: Style.animFast
      }
    }

    LocalOverlay {
      opacity: parent.opacity
      wallpaperPath: root.wallpaperPath
      itemIndex: root.itemIndex
    }
  }

  MouseArea {
    anchors.fill: parent
    z: 1
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked(root.wallpaperPath)
  }
}
