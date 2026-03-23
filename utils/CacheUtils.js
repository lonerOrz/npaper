.pragma library
.import "HashUtils.js" as Hash

function getThumbnailPath(cacheDir, wallpaperPath) {
    return cacheDir + '/' + Hash.getThumbnailHash(wallpaperPath) + '.png';
}

function getBackgroundPreviewPath(cacheDir, wallpaperPath) {
    const hash = Hash.getThumbnailHash(wallpaperPath);
    return cacheDir + '/' + hash + '_bg.png';
}

function getAnimatedGifPath(cacheDir, wallpaperPath) {
    const hash = Hash.getThumbnailHash(wallpaperPath);
    return cacheDir + '/' + hash + '_anim.gif';
}

// Check if animated preview exists in cache map
function getCachedAnimatedGif(thumbHashToPath, wallpaperPath) {
    if (!wallpaperPath || wallpaperPath.length === 0 || wallpaperPath.endsWith('/'))
        return "";
    const hash = Hash.getThumbnailHash(wallpaperPath);
    const animFile = hash + '_anim.gif';
    return thumbHashToPath[animFile] || "";
}

// Check if static thumbnail exists in cache map
function getCachedThumb(thumbHashToPath, wallpaperPath) {
    if (!wallpaperPath || wallpaperPath.length === 0 || wallpaperPath.endsWith('/'))
        return "";
    const hash = Hash.getThumbnailHash(wallpaperPath);
    return thumbHashToPath[hash] || "";
}

// Check if background preview exists in cache map
function getCachedBgPreview(thumbHashToPath, wallpaperPath) {
    if (!wallpaperPath || wallpaperPath.length === 0 || wallpaperPath.endsWith('/'))
        return "";
    const hash = Hash.getThumbnailHash(wallpaperPath);
    return thumbHashToPath[hash + '_bg.png'] || "";
}
