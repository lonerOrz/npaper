import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "SettingsInput.qml"
import qs.utils

Item {
  id: settingsPanel

  property bool settingsOpen: false
  property string activeTab: "layout"

  // Direct property bindings from AppWindow
  property real carouselItemWidth: Style.carouselItemWidth
  property real carouselItemHeight: Style.carouselItemHeight
  property real carouselSpacing: Style.carouselSpacing
  property real carouselRotation: Style.carouselRotation
  property real carouselPerspective: Style.carouselPerspective
  property bool showBorderGlow: true
  property bool showShadow: true
  property bool showBgPreview: true

  signal closeRequested

  z: 999
  width: Style.settingsWidth
  height: Math.min(Style.settingsMaxHeight, (tabRow ? tabRow.height : 0) + (contentArea ? contentArea.implicitHeight : 0) + Style.space2XXL)

  visible: settingsOpen
  opacity: settingsOpen ? Style.opacityFull : Style.opacityNone
  scale: settingsOpen ? Style.opacityFull : 0.95
  transformOrigin: Item.Bottom
  Behavior on opacity {
    NumberAnimation {
      duration: Style.animFast
      easing.type: Style.easingOutCubic
    }
  }
  Behavior on scale {
    NumberAnimation {
      duration: Style.animFast
      easing.type: Style.easingOutCubic
    }
  }

  Keys.onEscapePressed: closeRequested()
  focus: settingsOpen

  // Background
  Rectangle {
    anchors.fill: parent
    radius: Style.settingsRadius
    color: Color.mSurfaceContainerLow
  }

  Column {
    id: mainCol
    anchors.fill: parent
    anchors.margins: Style.settingsPadding
    spacing: Style.settingsInnerSpacing

    // Tabs Row
    Row {
      id: tabRow
      spacing: Style.settingsTabSpacing

      Repeater {
        model: [
          {
            key: "layout",
            label: "Layout"
          },
          {
            key: "appearance",
            label: "Appearance"
          }
        ]
        delegate: MouseArea {
          required property var modelData
          property bool isActive: settingsPanel.activeTab === modelData.key
          width: tabText.implicitWidth + Style.space2L
          height: Style.settingsTabHeight
          cursorShape: Qt.PointingHandCursor

          Rectangle {
            anchors.fill: parent
            radius: Style.radiusXL
            color: parent.isActive ? Color.mPrimary : "transparent"
            Behavior on color { ColorAnimation { duration: Style.animFast } }
          }

          Text {
            id: tabText
            anchors.centerIn: parent
            text: modelData.label
            color: parent.isActive ? Color.mSurfaceContainerLowest : Color.mOutlineVariant
            font.pixelSize: Style.settingsTabFontSize
            font.weight: parent.isActive ? Font.Bold : Font.Normal
            Behavior on color { ColorAnimation { duration: Style.animFast } }
          }

          onClicked: settingsPanel.activeTab = modelData.key
        }
      }
    }

    // Content Area
    Item {
      id: contentArea
      width: parent.width
      height: childrenRect.height
      clip: true

      // 1. Layout Tab
      Column {
        id: layoutContent
        visible: settingsPanel.activeTab === "layout"
        width: parent.width
        spacing: Style.settingsContentSpacing

        SettingsInput {
          label: "Card Width"
          value: root.carouselItemWidth
          min: 200
          max: 600
          onCommit: function (n) {
            root.carouselItemWidth = n;
          }
        }
        SettingsInput {
          label: "Card Height"
          value: root.carouselItemHeight
          min: 150
          max: 450
          onCommit: function (n) {
            root.carouselItemHeight = n;
          }
        }
        SettingsInput {
          label: "Spacing"
          value: root.carouselSpacing
          min: 0
          max: 60
          onCommit: function (n) {
            root.carouselSpacing = n;
          }
        }
        SettingsInput {
          label: "Rotation"
          value: root.carouselRotation
          min: 0
          max: 90
          onCommit: function (n) {
            root.carouselRotation = n;
          }
        }
        SettingsInput {
          label: "Depth"
          value: root.carouselPerspective
          min: 0.1
          max: 1.0
          step: 0.05
          onCommit: function (n) {
            root.carouselPerspective = n;
          }
        }
      }

      // 2. Appearance Tab
      Column {
        id: appearanceContent
        visible: settingsPanel.activeTab === "appearance"
        width: parent.width
        spacing: Style.settingsContentSpacing

        SettingsToggle {
          text: "Border Glow"
          checked: root.showBorderGlow
          onToggled: function (val) {
            root.showBorderGlow = val;
          }
        }
        SettingsToggle {
          text: "Card Shadow"
          checked: root.showShadow
          onToggled: function (val) {
            root.showShadow = val;
          }
        }
        SettingsToggle {
          text: "Background Preview"
          checked: root.showBgPreview
          onToggled: function (val) {
            root.showBgPreview = val;
          }
        }
      }
    }
  }
}
