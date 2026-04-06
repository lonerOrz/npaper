import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property string configPath: ""
  property var config: ({})
  property bool ready: false

  function get(key) {
    return config[key];
  }

  function _resolvePath(pathStr) {
    if (!pathStr) return "";
    if (pathStr.indexOf("$HOME") === 0)
      return Quickshell.env("HOME") + pathStr.slice(5);
    return pathStr;
  }

  function getResolved(key) {
    const val = config[key];
    if (typeof val === "string")
      return _resolvePath(val);
    if (Array.isArray(val)) {
      var result = [];
      for (var i = 0; i < val.length; i++)
        result.push(_resolvePath(val[i]));
      return result;
    }
    return val;
  }

  function loadPath(p) {
    fileView.path = p;
  }

  FileView {
    id: fileView
    printErrors: true

    onLoaded: {
      try {
        root.config = JSON.parse(text());
        root.ready = true;
      } catch (e) {
        console.error("[npaper] Config parse error:", e);
        root.config = {};
        root.ready = true;
      }
    }

    onLoadFailed: function (error) {
      console.error("[npaper] Config load failed:", error);
      root.config = {};
      root.ready = true;
    }
  }
}
