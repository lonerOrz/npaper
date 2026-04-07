import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components.settings
import qs.services

/*
* SettingsPanel — mirrors values from AppWindow, writes back to AppWindow.
* Persistence is AppWindow's responsibility via viewModel.
*/
Item {
  id: root

  property bool settingsOpen: false
  property string activeTab: "layout"

  // Mirrored from AppWindow — updated by AppWindow bindings
  property real carouselItemWidth: 0
  property real carouselItemHeight: 0
  property real carouselSpacing: 0
  property real carouselRotation: 0
  property real carouselPerspective: 0
  property bool showBorderGlow: false
  property bool showShadow: false
  property bool showBgPreview: false

  // Animation properties
  property int scrollDuration: 280
  property int scrollContinueInterval: 230
  property int bgSlideDuration: 250
  property int bgParallaxFactor: 40

  signal closeRequested
  signal settingChanged(string key, variant value)

  function _emit(key, val) {
    root.settingChanged(key, val);
  }

  // ── Animated height ──────────────────────────────────────
  z: 999
  width: Style.settingsWidth
  clip: true

  property real _animTarget: 0.0
  property real _animProgress: 0.0
  height: Style.settingsMaxHeight * _animProgress

  onSettingsOpenChanged: {
    _animTarget = settingsOpen ? 1.0 : 0.0;
    _anim.restart();
  }

  NumberAnimation {
    id: _anim
    target: root
    properties: "_animProgress"
    from: _animProgress
    to: _animTarget
    duration: settingsOpen ? Style.animNormal : Style.animFast
    easing.type: Style.easingOutCubic
    onFinished: root.visible = _animProgress > 0.01
  }

  Keys.onEscapePressed: closeRequested()
  focus: settingsOpen

  // ── Background ───────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    radius: Style.settingsRadius
    color: Color.mSurfaceContainerLow
    opacity: root._animProgress
  }

  // ── Tab bar ──────────────────────────────────────────────
  Row {
    id: tabBar
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Style.settingsPadding
    spacing: Style.settingsTabSpacing

    Repeater {
      model: [
        {
          key: "layout",
          label: "Layout"
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
        property bool isActive: root.activeTab === modelData.key
        width: _label.implicitWidth + Style.settingsTabSidePadding
        height: Style.settingsTabHeight
        cursorShape: Qt.PointingHandCursor

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusXL
          color: parent.isActive ? Color.mPrimary : "transparent"
          Behavior on color {
            ColorAnimation {
              duration: Style.animFast
            }
          }
        }

        Text {
          id: _label
          anchors.centerIn: parent
          text: modelData.label
          color: parent.isActive ? Color.mSurfaceContainerLowest : Color.mOutlineVariant
          font.pixelSize: Style.settingsTabFontSize
          font.weight: parent.isActive ? Font.Bold : Font.Normal
          Behavior on color {
            ColorAnimation {
              duration: Style.animFast
            }
          }
        }

        onClicked: root.activeTab = modelData.key
      }
    }
  }

  // ── Content area ─────────────────────────────────────────
  Item {
    anchors.top: tabBar.bottom
    anchors.topMargin: Style.settingsInnerSpacing
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: Style.settingsPadding
    clip: true

    // Layout tab
    Column {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.settingsContentSpacing
      visible: root.activeTab === "layout"

      SettingsInput {
        width: parent.width
        label: "Card Width"
        value: root.carouselItemWidth
        min: 200
        max: 600
        onCommit: function (n) {
          root._emit(Style.cfgCarouselItemWidth, n);
        }
      }
      SettingsInput {
        width: parent.width
        label: "Card Height"
        value: root.carouselItemHeight
        min: 150
        max: 450
        onCommit: function (n) {
          root._emit(Style.cfgCarouselItemHeight, n);
        }
      }
      SettingsInput {
        width: parent.width
        label: "Spacing"
        value: root.carouselSpacing
        min: 0
        max: 60
        onCommit: function (n) {
          root._emit(Style.cfgCarouselSpacing, n);
        }
      }
      SettingsInput {
        width: parent.width
        label: "Rotation"
        value: root.carouselRotation
        min: 0
        max: 90
        onCommit: function (n) {
          root._emit(Style.cfgCarouselRotation, n);
        }
      }
      SettingsInput {
        width: parent.width
        label: "Depth"
        value: root.carouselPerspective
        min: 0.1
        max: 1.0
        step: 0.05
        onCommit: function (n) {
          root._emit(Style.cfgCarouselPerspective, n);
        }
      }
    }

    // Animation tab
    Column {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.settingsContentSpacing
      visible: root.activeTab === "animation"

      SettingsInput {
        width: parent.width
        label: "Scroll Speed"
        value: root.scrollDuration
        min: 100
        max: 500
        step: 10
        onCommit: function (n) {
          root._emit(Style.cfgScrollDuration, n);
        }
      }
      SettingsInput {
        width: parent.width
        label: "Scroll Continue"
        value: root.scrollContinueInterval
        min: 100
        max: 400
        step: 10
        onCommit: function (n) {
          root._emit(Style.cfgScrollContinueInterval, n);
        }
      }
      SettingsInput {
        width: parent.width
        label: "Slide Duration"
        value: root.bgSlideDuration
        min: 100
        max: 500
        step: 10
        onCommit: function (n) {
          root._emit(Style.cfgBgSlideDuration, n);
        }
      }
      SettingsInput {
        width: parent.width
        label: "Parallax"
        value: root.bgParallaxFactor
        min: 10
        max: 80
        step: 5
        onCommit: function (n) {
          root._emit(Style.cfgBgParallaxFactor, n);
        }
      }
    }

    // Appearance tab
    Column {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.settingsContentSpacing
      visible: root.activeTab === "appearance"

      SettingsToggle {
        width: parent.width
        text: "Border Glow"
        checked: root.showBorderGlow
        onToggled: function (val) {
          root._emit(Style.cfgShowBorderGlow, val);
        }
      }
      SettingsToggle {
        width: parent.width
        text: "Card Shadow"
        checked: root.showShadow
        onToggled: function (val) {
          root._emit(Style.cfgShowShadow, val);
        }
      }
      SettingsToggle {
        width: parent.width
        text: "Background Preview"
        checked: root.showBgPreview
        onToggled: function (val) {
          root._emit(Style.cfgShowBgPreview, val);
        }
      }
    }
  }
}
