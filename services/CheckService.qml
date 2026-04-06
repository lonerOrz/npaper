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

  readonly property int checkTimeout: 2000

  signal allChecked

  function _onProcessDone(procId, result, nextAction) {
    if (nextAction) nextAction();
  }

  function _onProcessTimeout(proc, defaultValue, nextAction) {
    if (proc.running) {
      proc.running = false;
    }
    if (nextAction) nextAction();
  }

  Timer {
    id: ffmpegTimeout
    interval: root.checkTimeout
    onTriggered: root._onProcessTimeout(ffmpegProcess, false, () => magickProcess.exec({}))
  }

  Timer {
    id: magickTimeout
    interval: root.checkTimeout
    onTriggered: root._onProcessTimeout(magickProcess, false, () => awwwProcess.exec({}))
  }

  Timer {
    id: awwwTimeout
    interval: root.checkTimeout
    onTriggered: root._onProcessTimeout(awwwProcess, false, () => wlrProcess.exec({}))
  }

  Timer {
    id: wlrTimeout
    interval: root.checkTimeout
    onTriggered: root._onProcessTimeout(wlrProcess, false, () => mpvProcess.exec({}))
  }

  Timer {
    id: mpvTimeout
    interval: root.checkTimeout
    onTriggered: root._onProcessTimeout(mpvProcess, false, () => {
      root.allChecked();
      root.ready = true;
    })
  }

  Process {
    id: ffmpegProcess
    command: ["sh", "-c", "command -v ffmpeg >/dev/null 2>&1 && echo OK"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.hasFfmpeg = text.trim() === "OK";
        ffmpegTimeout.stop();
        magickProcess.exec({});
      }
    }
    onExited: function () {
      ffmpegTimeout.stop();
    }
  }

  Process {
    id: magickProcess
    command: ["sh", "-c", "command -v magick >/dev/null 2>&1 && echo OK"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.hasImagemagick = text.trim() === "OK";
        magickTimeout.stop();
        awwwProcess.exec({});
      }
    }
    onExited: function () {
      magickTimeout.stop();
    }
  }

  Process {
    id: awwwProcess
    command: ["sh", "-c", "command -v awww >/dev/null 2>&1 && echo OK"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.hasAwww = text.trim() === "OK";
        awwwTimeout.stop();
        wlrProcess.exec({});
      }
    }
    onExited: function () {
      awwwTimeout.stop();
    }
  }

  Process {
    id: wlrProcess
    command: ["sh", "-c", "command -v wlr-randr >/dev/null 2>&1 && echo OK"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.hasWlrRandr = text.trim() === "OK";
        wlrTimeout.stop();
        mpvProcess.exec({});
      }
    }
    onExited: function () {
      wlrTimeout.stop();
    }
  }

  Process {
    id: mpvProcess
    command: ["sh", "-c", "command -v mpvpaper >/dev/null 2>&1 && echo OK"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.hasMpvpaper = text.trim() === "OK";
        mpvTimeout.stop();
        root.allChecked();
        root.ready = true;
      }
    }
    onExited: function () {
      mpvTimeout.stop();
    }
  }

  function run() {
    ffmpegTimeout.start();
    ffmpegProcess.exec({});
  }
}
