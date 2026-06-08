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
  property bool hasPhonto: false
  property bool ready: false

  signal allChecked

  readonly property int checkTimeout: 2000

  Timer {
    id: timeoutTimer
    interval: root.checkTimeout
    onTriggered: {
      if (checkProc.running)
        checkProc.running = false;
      root.ready = true;
      root.allChecked();
    }
  }

  Process {
    id: checkProc
    command: ["sh", "-c", "for cmd in ffmpeg magick awww wlr-randr mpvpaper phonto; do command -v \"$cmd\" >/dev/null 2>&1 && echo \"$cmd:OK\" || echo \"$cmd:FAIL\"; done"]
    stdout: StdioCollector {
      id: checkStdout
    }
    onExited: function (code, status) {
      timeoutTimer.stop();
      var lines = checkStdout.text.trim().split(/\r?\n/);
      var resultMap = {};

      for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].split(":");
        if (parts.length === 2) {
          resultMap[parts[0]] = (parts[1] === "OK");
        }
      }

      root.hasFfmpeg = !!resultMap["ffmpeg"];
      root.hasImagemagick = !!resultMap["magick"];
      root.hasAwww = !!resultMap["awww"];
      root.hasWlrRandr = !!resultMap["wlr-randr"];
      root.hasMpvpaper = !!resultMap["mpvpaper"];
      root.hasPhonto = !!resultMap["phonto"];

      root.ready = true;
      root.allChecked();
    }
  }

  function run() {
    timeoutTimer.start();
    checkProc.exec({});
  }
}
