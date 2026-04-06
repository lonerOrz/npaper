import QtQuick
import "../models"

Item {
  id: root

  required property ConfigModel model
  required property var configService

  property Timer saveTimer: Timer {
    interval: 500
    repeat: false
    onTriggered: {
      if (root.model && root.model.dirty) {
        root.configService.save(root.model.data);
        root.model.dirty = false;
      }
    }
  }

  // ===== Public API =====

  // Centralized data access with fallback logic
  // 1. Check Model data
  // 2. Check Service defaults
  // 3. Return provided default value
  function get(key, def) {
    if (model && model.data && model.data[key] !== undefined) {
      return model.data[key];
    }
    // Fallback to service defaults
    return configService.get(key) !== undefined ? configService.get(key) : def;
  }

  function set(key, value) {
    if (!model)
      return;

    // Create new object to trigger property change signal (Immutable update)
    var updated = JSON.parse(JSON.stringify(model.data));
    updated[key] = value;
    model.data = updated;
    model.dirty = true;

    _scheduleSave();
  }

  function toggle(key) {
    var current = get(key, false);
    set(key, !current);
  }

  function _scheduleSave() {
    if (saveTimer.running)
      saveTimer.restart();
    else
      saveTimer.start();
  }
}
