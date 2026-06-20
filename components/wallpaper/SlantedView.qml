import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import "../../utils/CacheUtils.js" as CacheUtils
import qs.components.common
import qs.services

FocusScope {
  id: root

  property var adapter: null
  property var cacheService: null
  property var checkService: null
  property var appViewModel: null
  property var wallhavenFilter: null
  readonly property var whService: root.adapter ? root.adapter.whService : null

  property real parallaxFactor: 0.3
  property int scrollContinueInterval: 500

  property int sliceWidth: 100
  property int expandedWidth: 680
  property int skewOffset: 45
  property int sliceSpacing: 2
  property bool showBorderGlow: true
  property bool showShadow: true
  property int scrollDuration: 300

  readonly property int currentIndex: listView.currentIndex
  readonly property real scrollTarget: listView.currentIndex
  readonly property int baseIndex: Math.max(0, listView.currentIndex - 4)
  readonly property int maxIndex: Math.min(listView.currentIndex + 4, (root.adapter ? root.adapter.count : 0) - 1)

  signal requestQuit
  signal requestSettings
  signal requestPrevFolder
  signal requestNextFolder
  signal requestFocusSearch
  signal requestApplyItem(var item)
  signal requestRandom
  signal requestToggleWallhaven
  signal requestRefresh
  signal requestToggleViewMode

  Connections {
    target: root.whService
    function onResultsUpdated() {
      if (!root.whService || root.whService.currentPage !== 1)
        return;
      Qt.callLater(function () {
        listView.positionViewAtBeginning();
        listView.currentIndex = 0;
      });
    }
  }

  function reset() {
    listView.currentIndex = 0;
  }

  function scrollTo(idx) {
    listView.currentIndex = Math.max(0, Math.min(idx, (root.adapter ? root.adapter.count : 0) - 1));
  }

  function positionToCurrent() {
    listView.positionViewAtIndex(listView.currentIndex, ListView.Center);
  }

  function positionToCurrentOnCompleted() {
    Qt.callLater(positionToCurrent);
  }

  function focusView() {
    listView.forceActiveFocus();
  }

  function queueVisibleThumbnails() {
    if (!root.adapter || !root.cacheService || !root.cacheService.queueThumbnail)
      return;
    for (var i = root.baseIndex; i <= root.maxIndex; i++) {
      var item = root.adapter.getItem(i);
      if (item && item.type === "local")
        root.cacheService.queueThumbnail(item.path, item.isVideo, item.isGif);
    }
  }

  onActiveFocusChanged: {
    if (activeFocus)
      queueVisibleThumbnails();
  }

  ListView {
    id: listView
    anchors.fill: parent
    anchors.bottomMargin: Style.keyboardHintBottomMargin + 20
    anchors.topMargin: 20

    orientation: ListView.Horizontal
    model: root.adapter ? root.adapter.items : null

    spacing: root.sliceSpacing - Math.abs(root.skewOffset)

    clip: true
    interactive: false
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    cacheBuffer: Math.round(root.expandedWidth) * 3

    highlightRangeMode: ListView.StrictlyEnforceRange
    preferredHighlightBegin: (listView.width - root.sliceWidth) / 2
    preferredHighlightEnd: (listView.width + root.sliceWidth) / 2
    highlightMoveDuration: root.scrollDuration
    highlightFollowsCurrentItem: true
    highlight: Item {}
    focus: true

    onCurrentIndexChanged: {
      queueVisibleThumbnails();
    }

    onWidthChanged: {
      Qt.callLater(root.positionToCurrent);
    }

    onCountChanged: {
      if (count > 0 && currentIndex >= count)
        currentIndex = count - 1;
    }

    header: Item {
      width: (listView.width - root.expandedWidth) / 2
      height: 1
    }

    footer: Item {
      width: (listView.width - root.expandedWidth) / 2
      height: 1
    }

    delegate: Item {
      id: delegateItem
      required property int index
      readonly property var itemData: root.adapter.getItem(index)

      readonly property bool isRemote: itemData ? (itemData.type === "remote" || (itemData.path && (itemData.path.indexOf("http://") === 0 || itemData.path.indexOf("https://") === 0))) : false
      readonly property bool isLocal: itemData ? (!isRemote) : false
      readonly property real cardRadius: Style.radiusL

      readonly property real targetTranslationX: {
        if (index < listView.currentIndex) {
          return -((root.expandedWidth - root.sliceWidth) / 2);
        } else if (index > listView.currentIndex) {
          return ((root.expandedWidth - root.sliceWidth) / 2);
        } else {
          return 0;
        }
      }

      transform: Translate {
        x: delegateItem.targetTranslationX
        Behavior on x {
          NumberAnimation {
            duration: root.scrollDuration
            easing.type: Easing.OutCubic
          }
        }
      }

      HoverHandler {
        id: itemHover
      }

      readonly property bool isCurrent: ListView.isCurrentItem
      readonly property bool isHovered: itemHover.hovered
      property int itemZ: isCurrent ? 3 : (isHovered ? 2 : 1)
      onItemZChanged: delegateItem.z = itemZ

      readonly property real _sk: root.skewOffset
      readonly property real _skAbs: Math.abs(_sk)
      readonly property real _topLeft: _sk >= 0 ? _skAbs : 0
      readonly property real _topRight: _sk >= 0 ? flipContainer.width : flipContainer.width - _skAbs
      readonly property real _botRight: _sk >= 0 ? flipContainer.width - _skAbs : flipContainer.width
      readonly property real _botLeft: _sk >= 0 ? 0 : _skAbs

      readonly property real _topLeftM: _sk >= 0 ? 0 : _skAbs
      readonly property real _topRightM: _sk >= 0 ? flipContainer.width - _skAbs : flipContainer.width
      readonly property real _botRightM: _sk >= 0 ? flipContainer.width : flipContainer.width - _skAbs
      readonly property real _botLeftM: _sk >= 0 ? _skAbs : 0

      width: root.sliceWidth
      height: listView.height
      property bool flipped: false

      onIsCurrentChanged: {
        if (isCurrent)
          flipped = false;
      }

      Shape {
        id: shadowShape
        z: -1
        x: delegateItem.isCurrent ? 4 : 2
        y: delegateItem.isCurrent ? 10 : 5
        width: flipContainer.width
        height: delegateItem.height
        opacity: delegateItem.isCurrent ? 0.4 : 0.15
        visible: root.showShadow
        anchors.horizontalCenter: parent.horizontalCenter

        Behavior on x {
          NumberAnimation {
            duration: root.scrollDuration
            easing.type: Easing.OutQuad
          }
        }
        Behavior on y {
          NumberAnimation {
            duration: root.scrollDuration
            easing.type: Easing.OutQuad
          }
        }
        Behavior on opacity {
          NumberAnimation {
            duration: root.scrollDuration
            easing.type: Easing.OutQuad
          }
        }

        ShapePath {
          fillColor: "#000000"
          strokeColor: "transparent"
          startX: delegateItem._topLeft + delegateItem.cardRadius
          startY: 0
          PathLine {
            x: flipContainer.width - delegateItem.cardRadius
            y: 0
          }
          PathQuad {
            x: flipContainer.width - (root.skewOffset * 0.12)
            y: delegateItem.cardRadius
            controlX: flipContainer.width
            controlY: 0
          }
          PathLine {
            x: (flipContainer.width - root.skewOffset) + (root.skewOffset * 0.12)
            y: shadowShape.height - delegateItem.cardRadius
          }
          PathQuad {
            x: (flipContainer.width - root.skewOffset) - delegateItem.cardRadius
            y: shadowShape.height
            controlX: (flipContainer.width - root.skewOffset)
            controlY: shadowShape.height
          }
          PathLine {
            x: delegateItem.cardRadius
            y: shadowShape.height
          }
          PathQuad {
            x: (root.skewOffset * 0.12)
            y: shadowShape.height - delegateItem.cardRadius
            controlX: 0
            controlY: shadowShape.height
          }
          PathLine {
            x: delegateItem._topLeft - (root.skewOffset * 0.12)
            y: delegateItem.cardRadius
          }
          PathQuad {
            x: delegateItem._topLeft + delegateItem.cardRadius
            y: 0
            controlX: delegateItem._topLeft
            controlY: 0
          }
        }
      }

      Item {
        id: sharedMask
        width: flipContainer.width
        height: delegateItem.height
        visible: false
        layer.enabled: true
        layer.smooth: true

        Shape {
          anchors.fill: parent
          antialiasing: true
          ShapePath {
            fillColor: "white"
            strokeColor: "transparent"
            startX: delegateItem._topLeft + delegateItem.cardRadius
            startY: 0
            PathLine {
              x: flipContainer.width - delegateItem.cardRadius
              y: 0
            }
            PathQuad {
              x: flipContainer.width - (root.skewOffset * 0.12)
              y: delegateItem.cardRadius
              controlX: flipContainer.width
              controlY: 0
            }
            PathLine {
              x: (flipContainer.width - root.skewOffset) + (root.skewOffset * 0.12)
              y: sharedMask.height - delegateItem.cardRadius
            }
            PathQuad {
              x: (flipContainer.width - root.skewOffset) - delegateItem.cardRadius
              y: sharedMask.height
              controlX: (flipContainer.width - root.skewOffset)
              controlY: sharedMask.height
            }
            PathLine {
              x: delegateItem.cardRadius
              y: sharedMask.height
            }
            PathQuad {
              x: (root.skewOffset * 0.12)
              y: sharedMask.height - delegateItem.cardRadius
              controlX: 0
              controlY: sharedMask.height
            }
            PathLine {
              x: delegateItem._topLeft - (root.skewOffset * 0.12)
              y: delegateItem.cardRadius
            }
            PathQuad {
              x: delegateItem._topLeft + delegateItem.cardRadius
              y: 0
              controlX: delegateItem._topLeft
              controlY: 0
            }
          }
        }
      }

      Item {
        id: flipContainer
        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height
        z: 2

        width: isCurrent ? root.expandedWidth : root.sliceWidth

        transform: Rotation {
          origin.x: flipContainer.width / 2
          origin.y: flipContainer.height / 2
          axis {
            x: 0
            y: 1
            z: 0
          }
          angle: flipContainer.flipProgress * 180
        }

        property real flipProgress: delegateItem.flipped ? 1.0 : 0.0
        Behavior on flipProgress {
          NumberAnimation {
            duration: 350
            easing.type: Easing.InOutCubic
          }
        }

        Item {
          id: frontFace
          anchors.fill: parent
          visible: flipContainer.flipProgress < 0.5
          layer.enabled: true
          layer.smooth: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: sharedMask
            maskThresholdMin: 0.3
            maskSpreadAtMin: 0.3
          }

          Image {
            id: thumbImage
            anchors.fill: parent
            source: {
              if (!delegateItem.itemData)
                return "";
              if (delegateItem.isRemote) {
                return delegateItem.itemData.thumbLarge || delegateItem.itemData.thumb || delegateItem.itemData.path || "";
              }
              var thp = root.cacheService ? root.cacheService.thumbHashToPath : ({});
              return CacheUtils.resolveWallpaperStaticSource(thp, delegateItem.itemData);
            }
            fillMode: Image.PreserveAspectCrop
            smooth: true
            asynchronous: true
            sourceSize {
              width: root.expandedWidth
              height: listView.height
            }
          }

          Rectangle {
            anchors.fill: parent
            visible: thumbImage.status !== Image.Ready
            color: Color.mSurfaceContainer
            opacity: 0.8
          }

          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, delegateItem.isCurrent ? 0 : (delegateItem.isHovered ? 0.15 : 0.4))
            Behavior on color {
              ColorAnimation {
                duration: root.scrollDuration
                easing.type: Easing.OutCubic
              }
            }
          }

          AnimatedImage {
            id: animatedGif
            anchors.fill: parent
            source: {
              if (!delegateItem.itemData || delegateItem.isRemote)
                return "";
              var thp = root.cacheService ? root.cacheService.thumbHashToPath : ({});
              return CacheUtils.resolveWallpaperAnimatedSource(thp, delegateItem.itemData, delegateItem.isCurrent);
            }
            visible: source !== ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            playing: source !== ""
            sourceSize: Qt.size(root.expandedWidth, listView.height)
          }

          Shape {
            id: glowBorder
            anchors.fill: parent
            antialiasing: true
            visible: opacity > 0.01
            opacity: root.showBorderGlow && delegateItem.isCurrent ? 0.8 : 0.0
            z: 5

            Behavior on opacity {
              NumberAnimation {
                duration: root.scrollDuration
                easing.type: Easing.OutQuad
              }
            }

            ShapePath {
              fillColor: "transparent"
              strokeColor: Color.mPrimary
              strokeWidth: 3
              startX: delegateItem._topLeft + delegateItem.cardRadius
              startY: 0
              PathLine {
                x: flipContainer.width - delegateItem.cardRadius
                y: 0
              }
              PathQuad {
                x: flipContainer.width - (root.skewOffset * 0.12)
                y: delegateItem.cardRadius
                controlX: flipContainer.width
                controlY: 0
              }
              PathLine {
                x: (flipContainer.width - root.skewOffset) + (root.skewOffset * 0.12)
                y: glowBorder.height - delegateItem.cardRadius
              }
              PathQuad {
                x: (flipContainer.width - root.skewOffset) - delegateItem.cardRadius
                y: glowBorder.height
                controlX: (flipContainer.width - root.skewOffset)
                controlY: glowBorder.height
              }
              PathLine {
                x: delegateItem.cardRadius
                y: glowBorder.height
              }
              PathQuad {
                x: (root.skewOffset * 0.12)
                y: glowBorder.height - delegateItem.cardRadius
                controlX: 0
                controlY: glowBorder.height
              }
              PathLine {
                x: delegateItem._topLeft - (root.skewOffset * 0.12)
                y: delegateItem.cardRadius
              }
              PathQuad {
                x: delegateItem._topLeft + delegateItem.cardRadius
                y: 0
                controlX: delegateItem._topLeft
                controlY: 0
              }
            }
          }

          Item {
            id: typeBadge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            property real badgeSkew: 4
            property bool onRight: root.skewOffset >= 0
            property real __tl: onRight ? badgeSkew : 0
            property real __tr: onRight ? width : width - badgeSkew
            property real __br: onRight ? width - badgeSkew : width
            property real __bl: onRight ? 0 : badgeSkew

            width: typeText.implicitWidth + 14 + badgeSkew
            height: 16
            z: 10
            x: onRight ? parent.width - width - delegateItem._skAbs - 6 : delegateItem._skAbs + 6
            opacity: delegateItem.isCurrent ? 1.0 : (delegateItem.isHovered ? 0.7 : 0.0)

            Behavior on opacity {
              NumberAnimation {
                duration: Style.animFast
                easing.type: Easing.OutQuad
              }
            }

            Shape {
              anchors.fill: parent
              ShapePath {
                fillColor: Qt.rgba(0, 0, 0, 0.75)
                strokeColor: Qt.rgba(1, 1, 1, 0.15)
                strokeWidth: 1
                startX: typeBadge.__tl
                startY: 0
                PathLine {
                  x: typeBadge.__tr
                  y: 0
                }
                PathLine {
                  x: typeBadge.__br
                  y: typeBadge.height
                }
                PathLine {
                  x: typeBadge.__bl
                  y: typeBadge.height
                }
                PathLine {
                  x: typeBadge.__tl
                  y: 0
                }
              }
            }

            Text {
              id: typeText
              anchors.centerIn: parent
              text: {
                if (!delegateItem.itemData)
                  return "???";
                if (delegateItem.itemData.isVideo)
                  return "VID";
                if (delegateItem.itemData.isGif)
                  return "GIF";
                return "PIC";
              }
              font.pixelSize: 9
              font.weight: Font.Bold
              font.letterSpacing: 0.5
              color: Color.mPrimary
            }
          }

          Rectangle {
            id: videoIndicator
            visible: opacity > 0.01
            x: 6
            y: 6
            width: 18
            height: 18
            radius: 9
            color: Qt.rgba(0, 0, 0, 0.7)
            z: 10
            opacity: delegateItem.itemData && delegateItem.itemData.isVideo ? (delegateItem.isCurrent ? 1.0 : (delegateItem.isHovered ? 0.7 : 0.0)) : 0.0

            Behavior on opacity {
              NumberAnimation {
                duration: Style.animFast
                easing.type: Easing.OutQuad
              }
            }

            Text {
              anchors.centerIn: parent
              text: "▶"
              color: Color.mPrimary
              font.pixelSize: 8
              font.bold: true
            }
          }

          Item {
            id: overlayContainer
            anchors.fill: parent
            visible: opacity > 0.01
            opacity: (delegateItem.isCurrent && !delegateItem.flipped && (delegateItem.isHovered || overlayContainerHover.hovered)) ? 1 : 0
            z: 15
            Behavior on opacity {
              NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
              }
            }

            HoverHandler {
              id: overlayContainerHover
            }

            DownloadOverlay {
              visible: delegateItem.isRemote
              opacity: parent.opacity
              whId: delegateItem.itemData ? String(delegateItem.itemData.id).replace("wallhaven-", "") : ""
              downloadPath: delegateItem.itemData ? delegateItem.itemData.path : ""
              whService: root.whService
              downloadStatus: root.whService ? root.whService.downloadStatus : ({})
              downloadProgress: root.whService ? root.whService.downloadProgress : ({})
              downloadPaths: root.whService ? root.whService.downloadPaths : ({})
              onApplyLocal: function (localPath) {
                var localItem = Object.assign({}, delegateItem.itemData, {
                                                path: localPath,
                                                type: "local"
                                              });
                root.requestApplyItem(localItem);
              }
            }

            LocalOverlay {
              visible: delegateItem.isLocal
              wallpaperPath: delegateItem.itemData ? delegateItem.itemData.path : ""
              itemIndex: delegateItem.index
            }
          }
        }

        Item {
          id: backFace
          anchors.fill: parent
          visible: flipContainer.flipProgress >= 0.5
          layer.enabled: true
          layer.smooth: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: sharedMask
            maskThresholdMin: 0.3
            maskSpreadAtMin: 0.3
          }

          transform: Scale {
            origin.x: backFace.width / 2
            origin.y: backFace.height / 2
            xScale: -1.0
          }

          Rectangle {
            anchors.fill: parent
            color: Color.mSurfaceContainer
          }

          Column {
            anchors.centerIn: parent
            width: Math.max(10, parent.width - 40)
            spacing: 12
            clip: true

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "IMAGE DETAILS"
              color: Color.mPrimary
              font.pixelSize: 11
              font.weight: Font.Bold
              font.letterSpacing: 1.5
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: delegateItem.itemData ? delegateItem.itemData.filename || "Unknown File" : "No Data"
              color: Color.mOnSurface
              font.pixelSize: 15
              font.weight: Font.Medium
              elide: Text.ElideMiddle
              maximumLineCount: 3
              wrapMode: Text.WrapAnywhere
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              width: parent.width * 0.7
              height: 1
              color: Color.mOutlineVariant
            }

            Grid {
              anchors.horizontalCenter: parent.horizontalCenter
              columns: 2
              spacing: 10
              horizontalItemAlignment: Grid.AlignHCenter
              visible: delegateItem.itemData && delegateItem.itemData.resolution

              Text {
                text: "Resolution:"
                color: Color.mOnSurfaceVariant
                font.pixelSize: 11
                font.weight: Font.DemiBold
              }

              Text {
                text: delegateItem.itemData ? delegateItem.itemData.resolution : ""
                color: Color.mOnSurface
                font.pixelSize: 13
                font.weight: Font.DemiBold
              }
            }
          }

          Shape {
            id: backBorderShape
            anchors.fill: parent
            antialiasing: true
            z: 5
            ShapePath {
              fillColor: "transparent"
              strokeColor: Color.mOutline
              strokeWidth: 2
              startX: delegateItem._topLeftM + delegateItem.cardRadius
              startY: 0
              PathLine {
                x: flipContainer.width - delegateItem._topLeftM - delegateItem.cardRadius
                y: 0
              }
              PathQuad {
                x: flipContainer.width - delegateItem._topLeftM - (root.skewOffset * 0.12)
                y: delegateItem.cardRadius
                controlX: flipContainer.width - delegateItem._topLeftM
                controlY: 0
              }
              PathLine {
                x: (flipContainer.width - delegateItem._topLeftM - root.skewOffset) + (root.skewOffset * 0.12)
                y: backBorderShape.height - delegateItem.cardRadius
              }
              PathQuad {
                x: (flipContainer.width - delegateItem._topLeftM - root.skewOffset) - delegateItem.cardRadius
                y: backBorderShape.height
                controlX: (flipContainer.width - delegateItem._topLeftM - root.skewOffset)
                controlY: backBorderShape.height
              }
              PathLine {
                x: delegateItem.cardRadius
                y: backBorderShape.height
              }
              PathQuad {
                x: (root.skewOffset * 0.12)
                y: backBorderShape.height - delegateItem.cardRadius
                controlX: 0
                controlY: backBorderShape.height
              }
              PathLine {
                x: delegateItem._topLeftM - (root.skewOffset * 0.12)
                y: delegateItem.cardRadius
              }
              PathQuad {
                x: delegateItem._topLeftM + delegateItem.cardRadius
                y: 0
                controlX: delegateItem._topLeftM
                controlY: 0
              }
            }
          }
        }
      }

      MouseArea {
        id: itemMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 0

        onClicked: function (mouse) {
          if (mouse.button === Qt.RightButton) {
            delegateItem.flipped = !delegateItem.flipped;
            return;
          }
          if (delegateItem.flipped) {
            delegateItem.flipped = false;
            return;
          }
          if (delegateItem.isCurrent) {
            if (delegateItem.itemData)
              root.adapter.smartApply(delegateItem.itemData);
          } else {
            listView.currentIndex = delegateItem.index;
          }
        }
        onWheel: function (wheel) {
          wheel.accepted = true;
          var step = 1;
          if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
            listView.currentIndex = Math.max(0, listView.currentIndex - step);
          } else if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0) {
            listView.currentIndex = Math.min(listView.count - 1, listView.currentIndex + step);
          }
          if (listView.currentIndex >= listView.count - 3 && root.adapter && root.adapter.currentSource === "remote" && root.whService && root.whService.hasMore && !root.whService.loading) {
            root.whService.loadMore();
          }
        }
      }
    }

    KeyboardHandler {
      id: kbdHandler
      appViewModel: root.appViewModel
      wallhavenFilter: root.wallhavenFilter
      onApplyRequested: {
        var item = root.adapter.getItem(listView.currentIndex);
        if (item)
          root.adapter.smartApply(item);
      }
      onRandomRequested: {
        var count = root.adapter.count;
        if (count > 0)
          listView.currentIndex = Math.floor(Math.random() * count);
      }
      onWallhavenToggled: listView.forceActiveFocus()
    }
    Keys.onPressed: function (event) {
      kbdHandler.handleKeyPress(event);
      if (event.accepted)
        return;
      if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
        var dir = event.key === Qt.Key_Left ? -1 : 1;
        var target = listView.currentIndex + dir;
        if (target >= 0 && target < listView.count) {
          if (event.modifiers & Qt.ShiftModifier) {
            target += dir * 3;
            target = Math.max(0, Math.min(target, listView.count - 1));
          }
          listView.currentIndex = target;
        }
        if (dir === 1 && listView.currentIndex >= listView.count - 3 && root.adapter && root.adapter.currentSource === "remote" && root.whService && root.whService.hasMore && !root.whService.loading) {
          root.whService.loadMore();
        }
        event.accepted = true;
        return;
      }
    }
  }

  Rectangle {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.keyboardHintBottomMargin
    anchors.horizontalCenter: parent.horizontalCenter
    radius: Style.radiusRound
    color: Color.mSurfaceContainer
    opacity: 0.9

    Text {
      anchors.centerIn: parent
      anchors.leftMargin: Style.spaceXL
      anchors.rightMargin: Style.spaceXL
      text: "/ Search  •  ←/→ Navigate  •  Tab Folder  •  [] Toggle View  •  Enter Apply  •  R Random  •  S Settings  •  W Wallhaven  •  Esc Quit"
      color: Color.mOnSurface
      font.pixelSize: Style.keyboardHintFontSize
      font.weight: Font.Medium
    }
  }
}
