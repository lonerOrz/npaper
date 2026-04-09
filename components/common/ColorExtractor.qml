import QtQuick
import Quickshell.Io
import "../../utils/CacheUtils.js" as CacheUtils
import "../../utils/FileTypes.js" as FileTypes
import qs.services

/*
* ColorExtractor - extracts dominant color from images via ImageMagick.
*
* Input:
*   - sourcePath: string - path to image
*   - hasImageMagick: bool - whether ImageMagick is available
*   - thumbHashToPath: map - cached thumbnail paths
*
* Output:
*   - color: string - hex color (#RRGGBB) or default
*/
Item {
  id: root

  property var thumbHashToPath: ({})
  property bool hasImageMagick: false
  property string defaultColor: Color.mPrimary

  readonly property string color: _color

  property string _color: defaultColor

  // Run color extraction on a wallpaper path
  function run(wp) {
    if (!hasImageMagick || !wp || wp.length === 0) {
      _color = defaultColor;
      return;
    }

    // Check cache first
    const bg = CacheUtils.getCachedBgPreview(root.thumbHashToPath, wp);
    if (bg) {
      _extractFrom(bg);
      return;
    }

    // Skip video/gif color extraction (use default)
    if (FileTypes.isVideoFile(wp) || wp.toLowerCase().endsWith('.gif')) {
      _color = defaultColor;
      return;
    }

    // Extract from original
    _extractFrom(wp);
  }

  function _extractFrom(src) {
    if (_extractProc.running)
      _extractProc.running = false;

    _timeout.start();
    _extractProc.command = ["magick", src, "-resize", "1x1!", "-modulate", "100,180", "txt:"];
    _extractProc.exec({});
  }

  Timer {
    id: _timeout
    interval: 5000
    onTriggered: _color = defaultColor
  }

  Process {
    id: _extractProc
    stdout: StdioCollector {
      onStreamFinished: {
        _timeout.stop();
        const m = text.trim().match(/#([0-9A-F]{6})/i);
        _color = m ? "#" + m[1].toUpperCase() : defaultColor;
      }
    }
    onExited: function (code) {
      _timeout.stop();
      if (code !== 0)
        _color = defaultColor;
    }
  }
}
