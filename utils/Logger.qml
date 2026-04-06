pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Start by checking environment variable
    property bool isDebug: Quickshell.env("NPAPER_DEBUG") === "1"

    // Initialization function called when config loads
    function init(configDebugMode) {
        if (configDebugMode === true) {
            root.isDebug = true;
        }
    }

    // Logging Levels (using rest parameters for cleaner usage)
    function d(...args) {
        if (root.isDebug) console.log("[npaper][D]", ...args);
    }
    function i(...args) {
        if (root.isDebug) console.log("[npaper][I]", ...args);
    }
    function w(...args) {
        console.warn("[npaper][W]", ...args);
    }
    function r(...args) {
        if (root.isDebug) console.log("[npaper][R]", ...args);
    }
    function e(...args) {
        console.error("[npaper][E]", ...args);
    }
}
