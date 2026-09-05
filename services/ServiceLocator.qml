pragma Singleton

import QtQuick

QtObject {
  id: root

  property var adapter: null
  property var cacheService: null
  property var applier: null
  property var checks: null

  readonly property bool ready: adapter !== null && cacheService !== null

  signal servicesReady

  onReadyChanged: {
    if (ready)
      root.servicesReady();
  }

  function register(obj) {
    if (!obj)
      return;

    if (obj.adapter)
      root.adapter = obj.adapter;
    if (obj.cacheService)
      root.cacheService = obj.cacheService;
    if (obj.applier)
      root.applier = obj.applier;
    if (obj.checks)
      root.checks = obj.checks;
  }

  function reset() {
    root.adapter = null;
    root.cacheService = null;
    root.applier = null;
    root.checks = null;
  }
}
