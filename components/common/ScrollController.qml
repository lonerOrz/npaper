import QtQuick

Item {
  id: root

  property int count: 0
  property int visibleRange: 4
  property int preloadRange: 2
  property int animationDuration: 260
  property real parallaxFactor: 40

  property real scrollTarget: 0
  property int keyScrollDirection: 0
  property int keyScrollStep: 1
  property bool isKeyScrolling: false
  property int scrollContinueInterval: 140

  readonly property int currentIndex: Math.max(0, Math.min(Math.round(scrollTarget), root.count > 0 ? (root.count - 1) : 0))
  readonly property int baseIndex: Math.max(0, currentIndex - visibleRange - preloadRange)
  readonly property int maxIndex: root.count > 0 ? Math.min(root.count - 1, currentIndex + visibleRange + preloadRange) : 0
  readonly property int loadedCount: root.count > 0 ? Math.max(0, maxIndex - baseIndex + 1) : 0
  readonly property real parallaxX: (scrollTarget - currentIndex) * parallaxFactor

  Behavior on scrollTarget {
    NumberAnimation {
      duration: root.animationDuration
      easing.type: Easing.OutCubic
    }
  }

  Timer {
    id: scrollContinueTimer
    interval: root.scrollContinueInterval
    repeat: true
    onTriggered: {
      if (root.isKeyScrolling && root.keyScrollDirection !== 0 && root.count > 0) {
        root._advanceStep(root.keyScrollDirection, root.keyScrollStep);
      } else {
        stop();
      }
    }
  }

  function _advanceStep(direction, step) {
    if (root.count <= 0)
      return;

    const maxIdx = root.count - 1;
    const currentBase = Math.round(root.scrollTarget);
    const nextIdx = Math.max(0, Math.min(maxIdx, currentBase + direction * step));

    if (nextIdx !== root.scrollTarget) {
      root.scrollTarget = nextIdx;
    } else {
      root.isKeyScrolling = false;
      scrollContinueTimer.stop();
    }
  }

  function scrollLeft() {
    _handleInput(-1, 1);
  }

  function scrollRight() {
    _handleInput(1, 1);
  }

  function fastScrollLeft() {
    _handleInput(-1, 4);
  }

  function fastScrollRight() {
    _handleInput(1, 4);
  }

  function scrollTo(idx) {
    if (root.count <= 0) {
      root.scrollTarget = 0;
      return;
    }
    root.scrollTarget = Math.max(0, Math.min(idx, root.count - 1));
  }

  function random() {
    if (root.count > 0) {
      root.scrollTarget = Math.floor(Math.random() * root.count);
    }
  }

  function _handleInput(direction, step) {
    root.keyScrollDirection = direction;
    root.keyScrollStep = step || 1;
    root.isKeyScrolling = true;

    _advanceStep(direction, root.keyScrollStep);
    scrollContinueTimer.restart();
  }

  function handleKeyRelease(direction) {
    if (root.keyScrollDirection === direction) {
      root.keyScrollDirection = 0;
      root.isKeyScrolling = false;
      scrollContinueTimer.stop();
    }
  }

  function reset() {
    root.scrollTarget = 0;
    root.keyScrollDirection = 0;
    root.isKeyScrolling = false;
    scrollContinueTimer.stop();
  }
}
