import QtQuick
import Quickshell.Io

Process {
  id: dlProc

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
          dlProc.progressUpdate(dlProc.whId, Math.max(0.0, Math.min(1.0, val)));
        }
      }
    }
  }

  onExited: function (exitCode, exitStatus) {
    if (exitCode === 0) {
      dlProc.progressUpdate(dlProc.whId, 1.0);
      verifyProc.running = true;
    } else {
      cleanupProc.running = true;
    }
  }

  Process {
    id: verifyProc
    command: ["sh", "-c", 'test -s "$1" || { rm -f "$1"; exit 1; }; if command -v file >/dev/null 2>&1; then file --brief --mime-type "$1" | grep -qi "^image/" || { rm -f "$1"; exit 1; }; fi', "npaper-verify", dlProc.dest]
    onExited: function (code) {
      dlProc.done(dlProc.whId, code === 0);
    }
  }

  Process {
    id: cleanupProc
    command: ["rm", "-f", dlProc.dest]
    onExited: function () {
      dlProc.done(dlProc.whId, false);
    }
  }
}
