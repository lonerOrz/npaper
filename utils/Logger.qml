pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  // Check env var on startup
  property bool isDebug: Quickshell.env("NPAPER_DEBUG") === "1"

  // Called by SettingsService once config loads
  function applyDebug(debugMode) {
    if (debugMode === true)
      root.isDebug = true;
  }

  // Logging Levels
  function d(...args) { if (root.isDebug) console.log("[npaper][D]", ...args); }
  function i(...args) { if (root.isDebug) console.log("[npaper][I]", ...args); }
  function w(...args) { console.warn("[npaper][W]", ...args); }
  function r(...args) { if (root.isDebug) console.log("[npaper][R]", ...args); }
  function e(...args) { console.error("[npaper][E]", ...args); }
}
