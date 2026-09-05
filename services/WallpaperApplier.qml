import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Item {
  id: root

  property var dirs: []
  property string scriptPath: ""
  property bool debugMode: false
  property string videoBackend: "mpvpaper"

  function apply(path) {
    if (!path || typeof path !== "string" || path.trim().length === 0) {
      Logger.w("WallpaperApplier: Cannot apply empty wallpaper path");
      return;
    }

    if (!root.scriptPath || root.scriptPath.length === 0) {
      Logger.e("WallpaperApplier: scriptPath is missing");
      return;
    }

    const cleanPath = path.trim();
    const dirsArg = (root.dirs && Array.isArray(root.dirs)) ? root.dirs.join("|") : "";
    const backend = root.videoBackend || "mpvpaper";

    if (root.debugMode) {
      Logger.d("WallpaperApplier: Executing wallpaper apply ->", cleanPath, "Backend:", backend);
    }

    const cmd = ["bash", "-c", 'NPAPER_WALLPAPER_DIRS="$1" NPAPER_VIDEO_BACKEND="$4" "$2" --apply "$3" || { command -v notify-send >/dev/null 2>&1 && notify-send -u critical "npaper" "Failed to apply wallpaper: $3"; }', "npaper-apply", dirsArg, root.scriptPath, cleanPath, backend];

    Quickshell.execDetached(cmd);
  }
}
