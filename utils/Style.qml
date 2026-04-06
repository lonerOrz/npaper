import QtQuick

QtObject {
  // Durations (ms)
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
}
