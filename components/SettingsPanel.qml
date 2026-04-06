import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "SettingsInput.qml"
import qs.utils

Item {
  id: settingsPanel

  property bool settingsOpen: false
  property string activeTab: "carousel"
  property bool openDownward: false

  // Accessors
  property var viewModel
  function get(key, def) {
    return viewModel ? viewModel.get(key, def) : def;
  }
  function set(key, val) {
    if (viewModel)
      viewModel.set(key, val);
  }

  signal closeRequested

  z: 999
  width: 580
  height: Math.min(600, (tabRow ? tabRow.height : 0) + (contentArea ? contentArea.implicitHeight : 0) + 40)

  visible: settingsOpen
  opacity: settingsOpen ? 1 : 0
  scale: settingsOpen ? 1 : 0.95
  Behavior on opacity {
    NumberAnimation {
      duration: 150
      easing.type: Easing.OutCubic
    }
  }
  Behavior on scale {
    NumberAnimation {
      duration: 150
      easing.type: Easing.OutCubic
    }
  }

  Keys.onEscapePressed: closeRequested()
  focus: settingsOpen

  // Background
  Rectangle {
    anchors.fill: parent
    radius: 12
    color: Color.mSurfaceContainerLow
  }

  Column {
    id: mainCol
    anchors.fill: parent
    anchors.margins: 20
    spacing: 16

    // Tabs Row
    Row {
      id: tabRow
      spacing: 8

      Repeater {
        model: [
          {
            key: "carousel",
            label: "Carousel"
          },
          {
            key: "animation",
            label: "Animation"
          },
          {
            key: "appearance",
            label: "Appearance"
          }
        ]
        delegate: MouseArea {
          required property var modelData
          property bool isActive: settingsPanel.activeTab === modelData.key
          width: tabText.implicitWidth + 24
          height: 32
          cursorShape: Qt.PointingHandCursor

          Rectangle {
            anchors.fill: parent
            radius: 16
            color: parent.isActive ? Color.mPrimary : "transparent"
            Behavior on color {
              ColorAnimation {
                duration: 150
              }
            }
          }

          Text {
            id: tabText
            anchors.centerIn: parent
            text: modelData.label
            color: parent.isActive ? Color.mSurfaceContainerLowest : Color.mOutlineVariant
            font.pixelSize: 13
            font.weight: parent.isActive ? Font.Bold : Font.Normal
            Behavior on color {
              ColorAnimation {
                duration: 150
              }
            }
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

      // 1. Carousel Tab
      Column {
        id: carouselContent
        visible: settingsPanel.activeTab === "carousel"
        width: parent.width
        spacing: 16

        SectionHeader {
          text: "Dimensions"
        }
        SettingsInput {
          label: "Card Width"
          value: get("carouselItemWidth")
          min: 200
          max: 800
          onCommit: function (n) {
            set("carouselItemWidth", n);
          }
        }
        SettingsInput {
          label: "Card Height"
          value: get("carouselItemHeight")
          min: 150
          max: 600
          onCommit: function (n) {
            set("carouselItemHeight", n);
          }
        }
        SettingsInput {
          label: "Spacing"
          value: get("carouselSpacing")
          min: 0
          max: 100
          onCommit: function (n) {
            set("carouselSpacing", n);
          }
        }

        SectionHeader {
          text: "3D Perspective"
        }
        SettingsInput {
          label: "Rotation"
          value: get("carouselRotation")
          min: 0
          max: 90
          onCommit: function (n) {
            set("carouselRotation", n);
          }
        }
        SettingsInput {
          label: "Depth"
          value: get("carouselPerspective")
          min: 0.1
          max: 1.0
          step: 0.05
          onCommit: function (n) {
            set("carouselPerspective", n);
          }
        }
      }

      // 2. Animation Tab
      Column {
        id: animationContent
        visible: settingsPanel.activeTab === "animation"
        width: parent.width
        spacing: 16

        SectionHeader {
          text: "Timing"
        }
        SettingsInput {
          label: "Scroll Speed"
          value: get("scrollDuration")
          min: 100
          max: 800
          onCommit: function (n) {
            set("scrollDuration", n);
          }
        }
        SettingsInput {
          label: "Hold Delay"
          value: get("scrollContinueInterval")
          min: 50
          max: 500
          onCommit: function (n) {
            set("scrollContinueInterval", n);
          }
        }
        SettingsInput {
          label: "Transition"
          value: get("bgSlideDuration")
          min: 100
          max: 1000
          onCommit: function (n) {
            set("bgSlideDuration", n);
          }
        }

        SectionHeader {
          text: "Parallax"
        }
        SettingsInput {
          label: "Intensity"
          value: get("bgParallaxFactor")
          min: 0
          max: 100
          onCommit: function (n) {
            set("bgParallaxFactor", n);
          }
        }
      }

      // 3. Appearance Tab
      Column {
        id: appearanceContent
        visible: settingsPanel.activeTab === "appearance"
        width: parent.width
        spacing: 16

        SectionHeader {
          text: "Effects"
        }
        SettingsToggle {
          text: "Border Glow"
          checked: get("showBorderGlow")
          onToggled: function (val) {
            set("showBorderGlow", val);
          }
        }
        SettingsToggle {
          text: "Card Shadow"
          checked: get("showShadow")
          onToggled: function (val) {
            set("showShadow", val);
          }
        }
        SettingsToggle {
          text: "BG Preview"
          checked: get("showBgPreview")
          onToggled: function (val) {
            set("showBgPreview", val);
          }
        }

        SectionHeader {
          text: "Atmosphere"
        }
        SettingsInput {
          label: "Dimming"
          value: get("bgOverlayOpacity")
          min: 0.0
          max: 1.0
          step: 0.05
          onCommit: function (n) {
            set("bgOverlayOpacity", n);
          }
        }

        SectionHeader {
          text: "System"
        }
        SettingsToggle {
          text: "Debug Mode"
          checked: get("debugMode")
          onToggled: function (val) {
            set("debugMode", val);
          }
        }
      }
    }
  }
}
