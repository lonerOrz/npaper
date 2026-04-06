import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  required property var dirs
  required property string scriptPath
  property bool debugMode: false

  function apply(path) {
    const dirsArg = root.dirs.join("|");
    const cmd = [
      "bash", "-c",
      'NPAPER_WALLPAPER_DIRS="$1" "$2" --apply "$3" || notify-send -u critical "npaper" "Failed to apply wallpaper: $3"',
      "npaper-apply",
      dirsArg,
      root.scriptPath,
      path
    ];
    Quickshell.execDetached(cmd);
  }
}
