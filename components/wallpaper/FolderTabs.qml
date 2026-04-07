import QtQuick
import qs.services

/*
* FolderTabs — folder switching tabs with capsule indicator.
*
* The active tab is highlighted by a rounded pill that slides
* between tabs with an elastic OutBack bounce animation.
*/
Item {
  id: root

  required property var model
  required property string activeFolder
  property real tabHeight: 36

  signal folderClicked(string folder)

  width: tabsRow.childrenRect.width
  height: root.tabHeight

  property real _pillX: 0
  property real _pillW: 0

  Connections {
    target: root
    function onActiveFolderChanged() {
      tabsRow.updatePill();
    }
  }

  // ── Capsule indicator with elastic bounce ──────────────────
  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    height: root.tabHeight - 4
    radius: height / 2
    color: Color.mSurfaceContainerLow
    border.color: Color.mOutlineVariant
    border.width: 1

    x: root._pillX
    width: root._pillW

    // OutBack easing gives the elastic overshoot/bounce feel
    Behavior on x {
      NumberAnimation {
        duration: Style.animEnter
        easing.type: Easing.OutBack
        easing.overshoot: 1.2
      }
    }
    Behavior on width {
      NumberAnimation {
        duration: Style.animEnter
        easing.type: Easing.OutBack
        easing.overshoot: 1.2
      }
    }
  }

  Row {
    id: tabsRow
    anchors.centerIn: parent
    spacing: 8
    height: root.tabHeight - 4

    Repeater {
      id: tabsRepeater
      model: root.model

      delegate: MouseArea {
        required property string modelData
        property bool active: root.activeFolder === modelData
        property real tabWidth: tabText.implicitWidth + 22

        width: tabWidth
        height: root.tabHeight - 4
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: root.folderClicked(modelData)

        Text {
          id: tabText
          anchors.centerIn: parent
          text: modelData
          color: parent.active ? Color.mInverseSurface : Color.mOutlineVariant
          font.pixelSize: 13
          font.weight: parent.active ? Font.Medium : Font.Normal
          Behavior on color {
            ColorAnimation {
              duration: Style.animFast
            }
          }
        }

        Component.onCompleted: {
          if (active)
            tabsRow.updatePill();
        }
      }
    }

    Component.onCompleted: updatePill()

    function updatePill() {
      for (let i = 0; i < tabsRepeater.count; i++) {
        const item = tabsRepeater.itemAt(i);
        if (item && item.active) {
          root._pillX = item.x;
          root._pillW = item.width;
        }
      }
    }
  }
}
