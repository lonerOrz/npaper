.pragma library
.import "HashUtils.js" as Hash



function getFolderName(wallpaperPath) {
    if (!wallpaperPath || typeof wallpaperPath !== "string")
        return "wallpapers";

    const lower = wallpaperPath.toLowerCase();
    const wpIdx = lower.lastIndexOf("/wallpapers/");
    if (wpIdx >= 0) {
        const rest = wallpaperPath.slice(wpIdx + 12);
        const slashIdx = rest.indexOf("/");
        if (slashIdx > 0)
            return rest.slice(0, slashIdx);
        return "wallpapers";
    }

    const parts = wallpaperPath.split("/").filter(Boolean);
    if (parts.length >= 2) {
        return parts[parts.length - 2];
    }

    return "wallpapers";
}

function getThumbnailPath(cacheDir, wallpaperPath) {
    const folder = getFolderName(wallpaperPath);
    const hash = Hash.getThumbnailHash(wallpaperPath);
    return cacheDir + '/' + folder + '/' + hash + '_thumb.jpg';
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
    if (!wallpaperPath || !thumbHashToPath) return "";
    const folder = getFolderName(wallpaperPath);
    const hash = Hash.getThumbnailHash(wallpaperPath);
    const keyPrefix = folder + '/' + hash;
    return thumbHashToPath[keyPrefix + '_thumb.jpg'] || thumbHashToPath[keyPrefix + '_thumb.png'] || "";
}

function resolveBgPreview(thumbHashToPath, wallpaperPath) {
    if (!wallpaperPath || !thumbHashToPath) return "";
    const folder = getFolderName(wallpaperPath);
    const hash = Hash.getThumbnailHash(wallpaperPath);
    const keyPrefix = folder + '/' + hash;
    return thumbHashToPath[keyPrefix + '_bg.jpg'] || thumbHashToPath[keyPrefix + '_bg.png'] || "";
}

function resolveAnimatedGif(thumbHashToPath, wallpaperPath) {
    if (!wallpaperPath || !thumbHashToPath) return "";
    const folder = getFolderName(wallpaperPath);
    const hash = Hash.getThumbnailHash(wallpaperPath);
    return thumbHashToPath[folder + '/' + hash + '_anim.gif'] || "";
}

function resolveWallpaperStaticSource(thumbHashToPath, item) {
    if (!item || !item.path) return "";
    if (item.type === "remote") return item.thumbLarge || item.thumb || "";

    const folder = getFolderName(item.path);
    const hash = Hash.getThumbnailHash(item.path);
    const prefix = folder + '/' + hash;
    const map = thumbHashToPath || {};

    const bg = map[prefix + '_bg.jpg'] || map[prefix + '_bg.png'];
    if (bg) return "file://" + bg;

    if (item.isVideo || item.isGif) return "";
    return "file://" + item.path;
}

function resolveWallpaperAnimatedSource(thumbHashToPath, item, isCenter) {
    if (!isCenter || !item || !item.path) return "";
    if (!item.isVideo && !item.isGif) return "";
    const anim = resolveAnimatedGif(thumbHashToPath, item.path);
    return anim ? ("file://" + anim) : "";
}

function resolveGridStaticSource(thumbHashToPath, item) {
    if (!item) return "";
    if (item.type === "remote") return item.thumbLarge || item.thumb || "";

    const folder = getFolderName(item.path);
    const hash = Hash.getThumbnailHash(item.path);
    const prefix = folder + '/' + hash;
    const map = thumbHashToPath || {};

    const thumb = map[prefix + '_thumb.jpg'] || map[prefix + '_thumb.png'];
    if (thumb) return "file://" + thumb;

    const bg = map[prefix + '_bg.jpg'] || map[prefix + '_bg.png'];
    if (bg) return "file://" + bg;

    if (!item.isVideo && !item.isGif) return "file://" + item.path;
    return "";
}

function resolveGridAnimatedSource(thumbHashToPath, item) {
    if (!item || !item.path || item.type === "remote") return "";
    if (!item.isVideo && !item.isGif) return "";
    const anim = resolveAnimatedGif(thumbHashToPath, item.path);
    return anim ? ("file://" + anim) : "";
}

function resolveBgSource(thumbHashToPath, item) {
    if (!item) return "";
    if (item.type === "remote") return item.thumbLarge || item.thumb || "";

    const folder = getFolderName(item.path);
    const hash = Hash.getThumbnailHash(item.path);
    const prefix = folder + '/' + hash;
    const map = thumbHashToPath || {};

    const bg = map[prefix + '_bg.jpg'] || map[prefix + '_bg.png'];
    if (bg) return "file://" + bg;

    if (!item.isVideo && !item.isGif) return "file://" + item.path;
    return "";
}
