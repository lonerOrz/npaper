import QtQuick
import Quickshell.Io
import "../../utils/CacheUtils.js" as CacheUtils
import "../../utils/FileTypes.js" as FileTypes
import qs.services

Item {
  id: root

  property var thumbHashToPath: ({})
  property bool hasImageMagick: false
  property string defaultColor: Color.mPrimary

  readonly property string color: _color
  property string _color: defaultColor

  property var _colorCache: ({})
  property string _pendingPath: ""

  Timer {
    id: debounceTimer
    interval: 80
    repeat: false
    onTriggered: _executeExtraction()
  }

  function run(wp) {
    if (!hasImageMagick || !wp || wp.length === 0) {
      _color = defaultColor;
      return;
    }

    if (_colorCache[wp]) {
      debounceTimer.stop();
      if (_extractProc.running)
        _extractProc.running = false;
      _color = _colorCache[wp];
      return;
    }

    if (FileTypes.isVideoFile(wp) || FileTypes.isGifFile(wp)) {
      _color = defaultColor;
      return;
    }

    _pendingPath = wp;
    debounceTimer.restart();
  }

  function _executeExtraction() {
    const wp = _pendingPath;
    if (!wp)
      return;

    const thumb = CacheUtils.resolveThumb(root.thumbHashToPath, wp);
    const bg = CacheUtils.resolveBgPreview(root.thumbHashToPath, wp);
    const target = thumb || bg;

    if (!target) {
      _color = defaultColor;
      return;
    }

    _extractFrom(target, wp);
  }

  function _extractFrom(src, originalWp) {
    if (_extractProc.running)
      _extractProc.running = false;

    _extractProc.currentWallpaper = originalWp;
    _timeout.restart();

    _extractProc.command = ["magick", src, "-sample", "1x1", "-modulate", "100,180", "txt:"];
    _extractProc.exec({});
  }

  Timer {
    id: _timeout
    interval: 2000
    onTriggered: {
      if (_extractProc.running)
        _extractProc.running = false;
      _color = defaultColor;
    }
  }

  Process {
    id: _extractProc
    property string currentWallpaper: ""

    stdout: StdioCollector {
      onStreamFinished: {
        _timeout.stop();
        const m = text.trim().match(/#([0-9A-F]{6})/i);
        const resolved = m ? ("#" + m[1].toUpperCase()) : root.defaultColor;

        if (_extractProc.currentWallpaper) {
          root._colorCache[_extractProc.currentWallpaper] = resolved;
        }
        root._color = resolved;
      }
    }

    onExited: function (code) {
      _timeout.stop();
      if (code !== 0) {
        root._color = root.defaultColor;
      }
    }
  }
}
