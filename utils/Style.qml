pragma Singleton

import QtQuick
import Quickshell

/*
* Style constants singleton — design token source for all UI sizing.
*
* Usage:
*   import qs.utils
*   font.pixelSize: Style.fontM
*/
Singleton {
  id: root

  // ==================== Font Sizes ====================
  readonly property real fontXXS: 8
  readonly property real fontXS: 9
  readonly property real fontS: 10
  readonly property real fontM: 11
  readonly property real fontL: 13
  readonly property real fontXL: 16

  // ==================== Radii ====================
  readonly property int radiusXS: 5
  readonly property int radiusS: 8
  readonly property int radiusM: 10
  readonly property int radiusL: 12
  readonly property int radiusXL: 15
  readonly property int radiusXXL: 18

  // ==================== Margins & Spacing ====================
  readonly property int spaceXXS: 1
  readonly property int spaceXS: 2
  readonly property int spaceS: 4
  readonly property int spaceM: 6
  readonly property int spaceL: 8
  readonly property int spaceXL: 10
  readonly property int spaceXXL: 12
  readonly property int spaceXXXL: 16
  readonly property int space4XL: 20

  // Double spacing helper
  readonly property int space2XXS: spaceXXS * 2
  readonly property int space2XS: spaceXS * 2
  readonly property int space2S: spaceS * 2
  readonly property int space2M: spaceM * 2
  readonly property int space2L: spaceL * 2
  readonly property int space2XL: spaceXL * 2
  readonly property int space2XXL: space2XL * 2
  readonly property int space2XXXL: spaceXXXL * 2

  // ==================== Layout ====================
  // Carousel
  readonly property int carouselItemWidth: 340
  readonly property int carouselItemHeight: 240
  readonly property int carouselSpacing: 16
  readonly property int carouselRotation: 40
  readonly property real carouselPerspective: 0.3
  readonly property int carouselTopMargin: 200
  readonly property int carouselSideMargin: 10

  // Status Bar
  readonly property int barTopMargin: 140
  readonly property int barHeight: 30
  readonly property int barSidePadding: 8
  readonly property int barInnerSpacing: 5
  readonly property int barDividerHeight: 12
  readonly property int barSearchMinWidth: 100
  readonly property int barSearchWidthBase: 80
  readonly property int barSearchHeight: 22
  readonly property int barTabHeight: 22
  readonly property int barTabSidePadding: 10
  readonly property int barSettingsBtnWidth: 24
  readonly property int barSettingsBtnHeight: 22
  readonly property int barSettingsIconSize: 12
  readonly property real barInfoFontSize: fontXS
  readonly property real barSearchPlaceholderFontSize: fontXS
  readonly property real barSearchInputFontSize: fontXS
  readonly property real barTabFontSize: fontXS

  // Wallpaper Card
  readonly property int cardBorderWidth: 2
  readonly property int cardImageFrameMargin: 3
  readonly property int cardInnerPadding: 10
  readonly property int cardTopPadding: 12
  readonly property real cardLabelFontSize: fontS
  readonly property int cardLabelHeight: 24
  readonly property int cardLabelMargins: 12
  readonly property int cardVideoIconSize: 36
  readonly property real cardShadowOpacity: 0.25

  // Settings Panel
  readonly property int settingsWidth: 380
  readonly property int settingsMaxHeight: 320
  readonly property int settingsRadius: 10
  readonly property int settingsPadding: 12
  readonly property int settingsInnerSpacing: 10
  readonly property int settingsTabHeight: 24
  readonly property int settingsTabSidePadding: 16
  readonly property int settingsTabSpacing: 4
  readonly property int settingsContentSpacing: 8
  readonly property real settingsTabFontSize: fontXS

  // Keyboard Hint
  readonly property real keyboardHintFontSize: fontXS
  readonly property int keyboardHintBottomMargin: 20

  // NixOS Logo Watermark
  readonly property int logoSize: 160
  readonly property int logoBottomMargin: 120

  // ==================== Opacity ====================
  readonly property real opacityNone: 0.0
  readonly property real opacityLight: 0.15
  readonly property real opacityDivider: 0.3
  readonly property real opacityMedium: 0.5
  readonly property real opacityHeavy: 0.75
  readonly property real opacityAlmost: 0.95
  readonly property real opacityFull: 1.0
  readonly property real bgOverlayOpacity: 0.4

  // ==================== Animation Duration (ms) ====================
  readonly property int animVeryFast: 100
  readonly property int animFast: 150
  readonly property int animNormal: 250
  readonly property int animEnter: 300
  readonly property int animSlow: 400

  // Easing Types (Integer values)
  readonly property int easingOutCubic: 6
  readonly property int easingOutQuad: 2
  readonly property int easingOutBack: 14
  readonly property int easingInCubic: 7

  // Tunable Timers
  readonly property int searchDebounceMs: 150
  readonly property int bgFadeDuration: 400

  // Layout Constants
  readonly property int visibleRange: 4
  readonly property int preloadRange: 2

  // ==================== Border ====================
  readonly property int borderS: 1
  readonly property int borderM: 2
}
