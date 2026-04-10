import QtQuick

Item {
  id: root

  // Inputs
  property int count: 0
  property int visibleRange: 4
  property int preloadRange: 2
  property int animationDuration: 280
  property real parallaxFactor: 40

  // Outputs (Read-only)
  readonly property int currentIndex: Math.round(scrollTarget)
  readonly property int baseIndex: Math.max(0, currentIndex - visibleRange - preloadRange)
  readonly property int maxIndex: Math.min(count - 1, currentIndex + visibleRange + preloadRange)
  readonly property int loadedCount: count > 0 ? Math.max(0, maxIndex - baseIndex + 1) : 0
  readonly property real parallaxX: (currentIndex - Math.round(scrollTarget)) * parallaxFactor

  // Internal State
  property real scrollTarget: 0
  property int keyScrollDirection: 0
  property int keyScrollStep: 1
  property bool isKeyScrolling: false
  property int scrollContinueInterval: 230

  // Smooth Behavior
  Behavior on scrollTarget {
    NumberAnimation {
      duration: root.animationDuration
      easing.type: Easing.OutCubic
    }
  }

  // Sync currentIndex on change
  onScrollTargetChanged: {
    // This is where we might calculate velocity in the future if needed
  }

  Timer {
    id: scrollContinueTimer
    interval: root.scrollContinueInterval
    repeat: false
    onTriggered: {
      if (root.isKeyScrolling && root.keyScrollDirection !== 0 && root.count > 0) {
        const step = root.keyScrollStep;
        const maxIdx = root.count - 1;
        const currentIdx = Math.round(root.scrollTarget);
        let nextIdx = currentIdx;

        if (root.keyScrollDirection === -1)
          nextIdx = Math.max(0, currentIdx - step);
        else
          nextIdx = Math.min(maxIdx, currentIdx + step);

        if (nextIdx !== currentIdx) {
          root.scrollTarget = nextIdx;
        } else {
          root.isKeyScrolling = false;
        }
      } else {
        root.isKeyScrolling = false;
      }
    }
  }

  // Public Methods
  function scrollLeft() {
    _handleInput(-1);
  }
  function scrollRight() {
    _handleInput(1);
  }
  function fastScrollLeft() {
    _handleInput(-1, 5);
  }
  function fastScrollRight() {
    _handleInput(1, 5);
  }
  function scrollTo(idx) {
    root.scrollTarget = Math.max(0, Math.min(idx, root.count - 1));
  }
  function random() {
    if (root.count > 0)
      root.scrollTarget = Math.floor(Math.random() * root.count);
  }

  function _handleInput(direction, step = 1) {
    if (root.keyScrollDirection !== direction) {
      root.keyScrollDirection = direction;
      root.keyScrollStep = step;
      root.isKeyScrolling = true;
      scrollContinueTimer.stop();

      // Immediate step
      const maxIdx = root.count - 1;
      const currentIdx = Math.round(root.scrollTarget);
      if (direction === -1)
        root.scrollTarget = Math.max(0, currentIdx - step);
      else
        root.scrollTarget = Math.min(maxIdx, currentIdx + step);
    } else if (step !== root.keyScrollStep) {
      root.keyScrollStep = step;
    }
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
