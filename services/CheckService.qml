import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property bool hasFfmpeg: false
  property bool hasImagemagick: false
  property bool hasAwww: false
  property bool hasWlrRandr: false
  property bool hasMpvpaper: false
  property bool ready: false

  signal allChecked

  readonly property int checkTimeout: 2000

  readonly property var _checks: [
    { key: "hasFfmpeg",      cmd: "command -v ffmpeg >/dev/null 2>&1 && echo OK" },
    { key: "hasImagemagick", cmd: "command -v magick >/dev/null 2>&1 && echo OK" },
    { key: "hasAwww",        cmd: "command -v awww >/dev/null 2>&1 && echo OK" },
    { key: "hasWlrRandr",    cmd: "command -v wlr-randr >/dev/null 2>&1 && echo OK" },
    { key: "hasMpvpaper",    cmd: "command -v mpvpaper >/dev/null 2>&1 && echo OK" }
  ]

  property int _idx: 0

  Timer {
    id: timeoutTimer
    interval: root.checkTimeout
    onTriggered: {
      if (checkProc.running) checkProc.running = false;
      _finishCheck(false);
    }
  }

  Process {
    id: checkProc
    onExited: function (code, status) {
      timeoutTimer.stop();
      _finishCheck(code === 0);
    }
  }

  function _finishCheck(ok) {
    root[root._checks[root._idx].key] = ok;
    root._idx++;
    if (root._idx < root._checks.length) {
      _runNext();
    } else {
      root.ready = true;
      root.allChecked();
    }
  }

  function _runNext() {
    checkProc.command = ["sh", "-c", root._checks[root._idx].cmd];
    timeoutTimer.start();
    checkProc.exec({});
  }

  function run() {
    root._idx = 0;
    _runNext();
  }
}
