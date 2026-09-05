pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  readonly property bool _envDebug: Quickshell.env("NPAPER_DEBUG") === "1"
  property bool isDebug: _envDebug

  function applyDebug(debugMode) {
    root.isDebug = root._envDebug || (debugMode === true);
  }

  function _time() {
    const d = new Date();
    const timeStr = d.toTimeString().split(' ')[0];
    const ms = String(d.getMilliseconds()).padStart(3, '0');
    return timeStr + "." + ms;
  }

  function d(...args) {
    if (root.isDebug)
      console.log("[" + _time() + "][npaper][D]", ...args);
  }

  function i(...args) {
    if (root.isDebug)
      console.log("[" + _time() + "][npaper][I]", ...args);
  }

  function r(...args) {
    if (root.isDebug)
      console.log("[" + _time() + "][npaper][R]", ...args);
  }

  function w(...args) {
    console.warn("[" + _time() + "][npaper][W]", ...args);
  }

  function e(...args) {
    console.error("[" + _time() + "][npaper][E]", ...args);
  }
}
