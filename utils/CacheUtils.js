.pragma library
.import "HashUtils.js" as Hash

function getFolderName(wallpaperPath) {
    if (!wallpaperPath || wallpaperPath.length === 0)
        return "wallpapers";
    const idx = wallpaperPath.lastIndexOf("/wallpapers/");
    if (idx >= 0) {
        const rest = wallpaperPath.slice(idx + 12);
        const slashIdx = rest.indexOf("/");
        if (slashIdx >= 0)
            return rest.slice(0, slashIdx);
        return "wallpapers";
    }
    return "wallpapers";
}

function getThumbnailPath(cacheDir, wallpaperPath) {
    const folder = getFolderName(wallpaperPath);
    return cacheDir + '/' + folder + '/' + Hash.getThumbnailHash(wallpaperPath) + '_thumb.jpg';
}

function getBackgroundPreviewPath(cacheDir, wallpaperPath) {
    const folder = getFolderName(wallpaperPath);
    const hash = Hash.getThumbnailHash(wallpaperPath);
    return cacheDir + '/' + folder + '/' + hash + '_bg.jpg';
}

function getAnimatedGifPath(cacheDir, wallpaperPath) {
    const folder = getFolderName(wallpaperPath);
    const hash = Hash.getThumbnailHash(wallpaperPath);
    return cacheDir + '/' + folder + '/' + hash + '_anim.gif';
}

function resolveThumb(thumbHashToPath, wallpaperPath) {
    if (!wallpaperPath) return "";
    const hash = Hash.getThumbnailHash(wallpaperPath);
    const folder = getFolderName(wallpaperPath);
    return thumbHashToPath[folder + '/' + hash + '_thumb.jpg'] || "";
}

function resolveBgPreview(thumbHashToPath, wallpaperPath) {
    if (!wallpaperPath) return "";
    const hash = Hash.getThumbnailHash(wallpaperPath);
    const folder = getFolderName(wallpaperPath);
    return thumbHashToPath[folder + '/' + hash + '_bg.jpg'] || "";
}

function resolveAnimatedGif(thumbHashToPath, wallpaperPath) {
    if (!wallpaperPath) return "";
    const hash = Hash.getThumbnailHash(wallpaperPath);
    const folder = getFolderName(wallpaperPath);
    return thumbHashToPath[folder + '/' + hash + '_anim.gif'] || "";
}

function resolveWallpaperStaticSource(thumbHashToPath, item) {
    if (!item || !item.path) return "";
    if (item.type === "remote") return item.thumb || "";
    const bg = resolveBgPreview(thumbHashToPath, item.path);
    if (bg) return "file://" + bg;
    if (item.isVideo || item.isGif) return "";
    return "file://" + item.path;
}

function resolveWallpaperAnimatedSource(thumbHashToPath, item, isCenter) {
    if (!isCenter) return "";
    if (!item || !item.path) return "";
    if (!item.isVideo && !item.isGif) return "";
    const anim = resolveAnimatedGif(thumbHashToPath, item.path);
    return anim ? "file://" + anim : "";
}

function resolveGridStaticSource(thumbHashToPath, item) {
    if (!item) return "";
    if (item.type === "remote") return item.thumbLarge || item.thumb || "";
    const thumb = resolveThumb(thumbHashToPath, item.path);
    if (thumb) return "file://" + thumb;
    const bg = resolveBgPreview(thumbHashToPath, item.path);
    if (bg) return "file://" + bg;
    if (!item.isVideo && !item.isGif) return "file://" + item.path;
    return "";
}

function resolveGridAnimatedSource(thumbHashToPath, item) {
    if (!item || !item.path || item.type === "remote") return "";
    if (!item.isVideo && !item.isGif) return "";
    const anim = resolveAnimatedGif(thumbHashToPath, item.path);
    return anim ? "file://" + anim : "";
}

function resolveBgSource(thumbHashToPath, item) {
    if (!item) return "";
    if (item.type === "remote") return item.thumb || "";
    const bg = resolveBgPreview(thumbHashToPath, item.path);
    if (bg) return "file://" + bg;
    if (!item.isVideo && !item.isGif) return "file://" + item.path;
    return "";
}
