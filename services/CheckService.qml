import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property bool hasFfmpeg: true
  property bool hasImagemagick: true
  property bool hasAwww: true
  property bool hasWlrRandr: true
  property bool hasMpvpaper: true
  property bool hasPhonto: false
  property bool ready: true

  signal allChecked

  readonly property int checkTimeout: 1500

  Timer {
    id: timeoutTimer
    interval: root.checkTimeout
    onTriggered: {
      if (checkProc.running)
        checkProc.running = false;
      root.allChecked();
    }
  }

  Process {
    id: checkProc
    command: ["sh", "-c", "for cmd in ffmpeg magick awww wlr-randr mpvpaper phonto; do command -v \"$cmd\" >/dev/null 2>&1 && echo \"$cmd\"; done"]

    stdout: StdioCollector {
      id: checkStdout
      onStreamFinished: {
        timeoutTimer.stop();
        const found = text.trim().split(/\s+/);
        const set = {};
        for (let i = 0; i < found.length; i++) {
          if (found[i])
            set[found[i]] = true;
        }

        root.hasFfmpeg = !!set["ffmpeg"];
        root.hasImagemagick = !!set["magick"];
        root.hasAwww = !!set["awww"];
        root.hasWlrRandr = !!set["wlr-randr"];
        root.hasMpvpaper = !!set["mpvpaper"];
        root.hasPhonto = !!set["phonto"];

        root.ready = true;
        root.allChecked();
      }
    }

    onExited: function (code, status) {
      timeoutTimer.stop();
      if (code !== 0) {
        root.allChecked();
      }
    }
  }

  function run() {
    timeoutTimer.restart();
    checkProc.exec({});
  }

  Component.onCompleted: {
    run();
  }
}
