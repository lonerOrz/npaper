pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
  id: root

  property bool _supported: false
  readonly property bool available: _supported

  Component {
    id: _regionProbe
    Region {}
  }

  Component.onCompleted: {
    try {
      const probe = _regionProbe.createObject(root);
      if (probe) {
        probe.destroy();
        _supported = true;
      }
    } catch (e) {
      _supported = false;
    }
  }
}
