import QtQuick

// ===== ConfigModel: Single Source of Truth (SSOT) =====
// No IO here. Just state.
QtObject {
    id: root

    // Start with valid defaults to prevent UI binding errors on startup
    property var data: ({})
    property bool ready: false
    property bool dirty: false
}
