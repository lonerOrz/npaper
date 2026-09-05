pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
  id: root

  property real uiScaleRatio: 1.0

  function _s(v) {
    if (v <= 0)
      return 0;
    const scaled = Math.round(v * uiScaleRatio);
    return (v >= 1) ? Math.max(1, scaled) : scaled;
  }

  readonly property real fontXXS: 8
  readonly property real fontXS: 9
  readonly property real fontS: 10
  readonly property real fontM: 11
  readonly property real fontL: 13
  readonly property real fontXL: 16

  readonly property int radiusTiny: _s(2)
  readonly property int radiusXS: _s(4)
  readonly property int radiusS: _s(6)
  readonly property int radiusM: _s(8)
  readonly property int radiusL: _s(10)
  readonly property int radiusXL: _s(14)
  readonly property int radiusXXL: _s(18)
  readonly property int radiusRound: _s(24)
  readonly property int radiusCircle: _s(50)
  readonly property int settingsRadius: _s(12)

  readonly property int spaceXXS: _s(1)
  readonly property int spaceXS: _s(2)
  readonly property int spaceS: _s(4)
  readonly property int spaceM: _s(6)
  readonly property int spaceL: _s(8)
  readonly property int spaceXL: _s(10)
  readonly property int spaceXXL: _s(12)
  readonly property int spaceXXXL: _s(16)
  readonly property int space4XL: _s(20)

  readonly property int space2XS: spaceXS * 2
  readonly property int space2M: spaceM * 2
  readonly property int space2L: spaceL * 2

  readonly property int carouselItemWidth: _s(480)
  readonly property int carouselItemHeight: _s(270)
  readonly property int carouselTopMargin: _s(410)
  readonly property int carouselSideMargin: _s(10)

  readonly property int defaultCarouselSpacing: _s(24)
  readonly property int defaultCarouselRotation: 41
  readonly property real defaultCarouselPerspective: 0.45

  readonly property int defaultScrollDuration: 170
  readonly property int defaultScrollContinueInterval: 140
  readonly property int defaultBgSlideDuration: 220
  readonly property int defaultBgParallaxFactor: 40

  readonly property int cacheBgWidth: _s(1920)
  readonly property int cacheBgHeight: _s(1080)
  readonly property int cacheAnimWidth: _s(640)
  readonly property int cacheAnimHeight: _s(360)

  readonly property int gridCellWidth: _s(400)
  readonly property int gridCellHeight: _s(225)
  readonly property int gridCellSpacing: _s(20)
  readonly property int gridCellPadding: _s(32)

  readonly property int barTopMargin: _s(350)
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

  readonly property int filterFlowWidth: _s(900)
  readonly property int settingsWidth: _s(380)
  readonly property int settingsMaxHeight: _s(340)
  readonly property int settingsPadding: _s(12)
  readonly property int settingsInnerSpacing: _s(10)
  readonly property int settingsTabHeight: _s(26)
  readonly property int settingsTabPadding: _s(4)
  readonly property int settingsTabSidePadding: _s(14)
  readonly property int settingsTabSpacing: _s(6)
  readonly property int settingsContentSpacing: _s(10)
  readonly property real settingsTabFontSize: fontXS

  readonly property real keyboardHintFontSize: fontXS
  readonly property int keyboardHintBottomMargin: _s(20)

  readonly property real opacityLight: 0.15
  readonly property real opacityDivider: 0.3

  readonly property real barBlurAlpha: 0.5
  readonly property real filterBlurAlpha: 0.6
  readonly property real settingsBlurAlpha: 0.65

  readonly property real childBgAlpha: 0.4
  readonly property real childHoverAlpha: 0.5

  readonly property int animVeryFast: 90
  readonly property int animFast: 140
  readonly property int animNormal: 240
  readonly property int animEnter: 280
  readonly property int animSlow: 380

  readonly property int easingOutCubic: Easing.OutCubic
  readonly property int easingOutQuad: Easing.OutQuad
  readonly property int easingOutBack: Easing.OutBack

  readonly property int searchDebounceMs: 140
  readonly property int remoteSearchDebounceMs: 700
  readonly property int logoRotationMs: 32000

  readonly property int visibleRange: 4
  readonly property int preloadRange: 2

  readonly property int borderS: _s(1)
  readonly property int borderM: _s(2)
}
