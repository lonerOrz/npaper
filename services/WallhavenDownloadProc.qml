import QtQuick
import Quickshell.Io

Process {
  id: root

  property string whId: ""
  property string dest: ""

  signal progressUpdate(string id, real pct)
  signal done(string id, bool success)

  stderr: SplitParser {
    splitMarker: "\r"
    onRead: data => {
      const match = data.match(/([\d.]+)\s*%/);
      if (match) {
        const val = parseFloat(match[1]) / 100.0;
        if (!isNaN(val)) {
          root.progressUpdate(root.whId, Math.max(0.0, Math.min(1.0, val)));
        }
      }
    }
  }

  onExited: function (exitCode, exitStatus) {
    if (exitCode === 0) {
      root.progressUpdate(root.whId, 1.0);
      root.done(root.whId, true);
    } else {
      root.done(root.whId, false);
    }
  }
}
