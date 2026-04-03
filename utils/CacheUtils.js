.pragma library
.import "HashUtils.js" as Hash

function getFolderName(wallpaperPath) {
    if (!wallpaperPath || wallpaperPath.length === 0)
        return "wallpapers";
    // Find the wallpapers parent directory and use the next component
    const idx = wallpaperPath.lastIndexOf("/wallpapers/");
    if (idx >= 0) {
        const rest = wallpaperPath.slice(idx + 12);
        const slashIdx = rest.indexOf("/");
        if (slashIdx >= 0)
            return rest.slice(0, slashIdx);
        // File directly in wallpapers/ root → no subfolder
        return "wallpapers";
    }
    // Fallback: non-standard path
    return "wallpapers";
}

function getThumbnailPath(cacheDir, wallpaperPath) {
    const folder = getFolderName(wallpaperPath);
    return cacheDir + '/' + folder + '/' + Hash.getThumbnailHash(wallpaperPath) + '.png';
}

function getBackgroundPreviewPath(cacheDir, wallpaperPath) {
    const folder = getFolderName(wallpaperPath);
    const hash = Hash.getThumbnailHash(wallpaperPath);
    return cacheDir + '/' + folder + '/' + hash + '_bg.png';
}

function getAnimatedGifPath(cacheDir, wallpaperPath) {
    const folder = getFolderName(wallpaperPath);
    const hash = Hash.getThumbnailHash(wallpaperPath);
    return cacheDir + '/' + folder + '/' + hash + '_anim.gif';
}

// Check if animated preview exists in cache map
function getCachedAnimatedGif(thumbHashToPath, wallpaperPath) {
    if (!wallpaperPath || wallpaperPath.length === 0 || wallpaperPath.endsWith('/'))
        return "";
    const hash = Hash.getThumbnailHash(wallpaperPath);
    const folder = getFolderName(wallpaperPath);
    const key = folder + '/' + hash + '_anim.gif';
    return thumbHashToPath[key] || "";
}

// Check if static thumbnail exists in cache map
function getCachedThumb(thumbHashToPath, wallpaperPath) {
    if (!wallpaperPath || wallpaperPath.length === 0 || wallpaperPath.endsWith('/'))
        return "";
    const hash = Hash.getThumbnailHash(wallpaperPath);
    const folder = getFolderName(wallpaperPath);
    const key = folder + '/' + hash + '.png';
    return thumbHashToPath[key] || "";
}

// Check if background preview exists in cache map
function getCachedBgPreview(thumbHashToPath, wallpaperPath) {
    if (!wallpaperPath || wallpaperPath.length === 0 || wallpaperPath.endsWith('/'))
        return "";
    const hash = Hash.getThumbnailHash(wallpaperPath);
    const folder = getFolderName(wallpaperPath);
    const key = folder + '/' + hash + '_bg.png';
    return thumbHashToPath[key] || "";
}
