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
    // Try new format first
    const newKey = folder + '/' + hash + '_thumb.png';
    if (thumbHashToPath[newKey]) return thumbHashToPath[newKey];
    // Fall back to old format for backward compatibility
    const oldKey = folder + '/' + hash + '.png';
    return thumbHashToPath[oldKey] || "";
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

// ── High-level source URL builders ────────────────────────

// Static image source — for GridView delegate or WallpaperCard
// Returns file:// URL, http:// URL (remote), or "" (video/GIF without cache)
function getStaticThumbSource(thumbHashToPath, item) {
    if (!item) return "";
    if (item.type === "remote") return item.thumb;
    const path = item.path;
    if (!path || path.length === 0 || path.endsWith('/')) return "";
    // Try small thumbnail first (fast decode, 400x225)
    const thumb = getCachedThumb(thumbHashToPath, path);
    if (thumb) return "file://" + thumb;
    // Fall back to large background preview if thumb not ready
    const bg = getCachedBgPreview(thumbHashToPath, path);
    if (bg) return "file://" + bg;
    // Video/GIF without cache: return empty to avoid loading .mp4
    if (item.isVideo || item.isGif) return "";
    // Final fallback: original image (Qt sourceSize limits decode)
    return "file://" + path;
}

// Animated GIF preview source — for AnimatedImage
// Returns file:// URL if cache exists, otherwise ""
function getAnimatedPreviewSource(thumbHashToPath, item) {
    if (!item || !item.path || item.path.length === 0) return "";
    if (item.type === "remote") return "";
    if (!item.isVideo && !item.isGif) return "";
    const anim = getCachedAnimatedGif(thumbHashToPath, item.path);
    return anim ? "file://" + anim : "";
}

// Property-driven interface — for WallpaperCard
function getWallpaperStaticSource(thumbHashToPath, wallpaperPath, isVideo, isGif, isRemote, remoteThumb) {
    if (isRemote) return remoteThumb || "";
    if (!wallpaperPath || wallpaperPath.length === 0 || wallpaperPath.endsWith('/')) return "";
    const bg = getCachedBgPreview(thumbHashToPath, wallpaperPath);
    if (bg) return "file://" + bg;
    if (isVideo || isGif) return "";
    return "file://" + wallpaperPath;
}

function getWallpaperAnimatedSource(thumbHashToPath, wallpaperPath, isVideo, isGif, isCenter) {
    if (!isCenter) return "";
    if (!wallpaperPath || wallpaperPath.length === 0) return "";
    if (!isVideo && !isGif) return "";
    const anim = getCachedAnimatedGif(thumbHashToPath, wallpaperPath);
    return anim ? "file://" + anim : "";
}
