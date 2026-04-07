pragma Singleton

import QtQuick
import Quickshell

/*
* Style constants singleton — design token source for all UI sizing.
* All layout values scale automatically via uiScaleRatio (1.0 = 1080p).
*
* Usage:
*   import qs.utils
*   font.pixelSize: Style.fontM
*   anchors.margins: Style.spaceL
*/
Singleton {
  id: root

  // ==================== Scale Ratio ====================
  // Set once at startup: Style.uiScaleRatio = screen.height / 1080
  property real uiScaleRatio: 1.0

  function _s(v) {
    return Math.round(v * uiScaleRatio);
  }

  // ==================== Font Sizes (NOT scaled — Qt handles DPI) ====================
  readonly property real fontXXS: 8
  readonly property real fontXS: 9
  readonly property real fontS: 10
  readonly property real fontM: 11
  readonly property real fontL: 13
  readonly property real fontXL: 16

  // ==================== Radii ====================
  readonly property int radiusXS: _s(5)
  readonly property int radiusS: _s(8)
  readonly property int radiusM: _s(10)
  readonly property int radiusL: _s(12)
  readonly property int radiusXL: _s(15)
  readonly property int radiusXXL: _s(18)

  // ==================== Margins & Spacing ====================
  readonly property int spaceXXS: _s(1)
  readonly property int spaceXS: _s(2)
  readonly property int spaceS: _s(4)
  readonly property int spaceM: _s(6)
  readonly property int spaceL: _s(8)
  readonly property int spaceXL: _s(10)
  readonly property int spaceXXL: _s(12)
  readonly property int spaceXXXL: _s(16)
  readonly property int space4XL: _s(20)

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
  readonly property int carouselItemWidth: _s(400)
  readonly property int carouselItemHeight: _s(280)
  readonly property int carouselSpacing: _s(20)
  readonly property int carouselRotation: 40
  readonly property real carouselPerspective: 0.3
  readonly property int carouselTopMargin: _s(440)
  readonly property int carouselSideMargin: _s(10)

  // Status Bar
  readonly property int barTopMargin: _s(400)
  readonly property int barHeight: _s(40)
  readonly property int barRadius: _s(20)
  readonly property int barSidePadding: _s(12)
  readonly property int barInnerSpacing: _s(8)
  readonly property int barDividerHeight: _s(18)
  readonly property int barLogoSize: _s(20)
  readonly property int barSearchMinWidth: _s(130)
  readonly property int barSearchWidthBase: _s(100)
  readonly property int barSearchHeight: _s(28)
  readonly property int barTabHeight: _s(28)
  readonly property int barTabSidePadding: _s(14)
  readonly property int barSettingsBtnWidth: _s(32)
  readonly property int barSettingsBtnHeight: _s(28)
  readonly property int barSettingsIconSize: _s(16)
  readonly property real barInfoFontSize: fontS
  readonly property real barSearchPlaceholderFontSize: fontS
  readonly property real barSearchInputFontSize: fontS
  readonly property real barTabFontSize: fontS
  readonly property real barSettingsGearFontSize: fontM

  // Wallpaper Card
  readonly property int cardBorderWidth: _s(2)
  readonly property int cardImageFrameMargin: _s(3)
  readonly property int cardInnerPadding: _s(10)
  readonly property int cardTopPadding: _s(12)
  readonly property real cardLabelFontSize: fontS
  readonly property int cardLabelHeight: _s(24)
  readonly property int cardLabelMargins: _s(12)
  readonly property int cardVideoIconSize: _s(36)
  readonly property real cardShadowOpacity: 0.25
  readonly property real cardImageFrameOpacity: 0.9

  // Settings Panel
  readonly property int settingsWidth: _s(380)
  readonly property int settingsMaxHeight: _s(320)
  readonly property int settingsRadius: _s(10)
  readonly property int settingsPadding: _s(12)
  readonly property int settingsInnerSpacing: _s(10)
  readonly property int settingsTabHeight: _s(24)
  readonly property int settingsTabSidePadding: _s(16)
  readonly property int settingsTabSpacing: _s(4)
  readonly property int settingsContentSpacing: _s(8)
  readonly property real settingsTabFontSize: fontXS

  // Keyboard Hint
  readonly property real keyboardHintFontSize: fontXS
  readonly property int keyboardHintBottomMargin: _s(20)

  // NixOS Logo Watermark
  readonly property int logoSize: _s(160)
  readonly property int logoBottomMargin: _s(120)

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
  readonly property int logoRotationMs: 30000

  // Layout Constants
  readonly property int visibleRange: 4
  readonly property int preloadRange: 2

  // ==================== Border ====================
  readonly property int borderS: _s(1)
  readonly property int borderM: _s(2)

  // ==================== Config Keys (dot-paths for SettingsService) ====================
  readonly property string cfgCarouselItemWidth: "carousel.itemWidth"
  readonly property string cfgCarouselItemHeight: "carousel.itemHeight"
  readonly property string cfgCarouselSpacing: "carousel.spacing"
  readonly property string cfgCarouselRotation: "carousel.rotation"
  readonly property string cfgCarouselPerspective: "carousel.perspective"
  readonly property string cfgShowBorderGlow: "appearance.showBorderGlow"
  readonly property string cfgShowShadow: "appearance.showShadow"
  readonly property string cfgShowBgPreview: "appearance.showBgPreview"
  readonly property string cfgBgOverlayOpacity: "appearance.bgOverlayOpacity"
  readonly property string cfgScrollDuration: "animation.scrollDuration"
  readonly property string cfgScrollContinueInterval: "animation.scrollContinueInterval"
  readonly property string cfgBgSlideDuration: "animation.bgSlideDuration"
  readonly property string cfgBgParallaxFactor: "animation.bgParallaxFactor"
  readonly property string cfgDebugMode: "debugMode"
  readonly property string cfgWallpaperDirs: "wallpaperDirs"
  readonly property string cfgCacheDir: "cacheDir"
  readonly property string cfgPreviewStyle: "previewStyle"
}
