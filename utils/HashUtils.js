.pragma library



const _hashCache = {};
let _cacheSize = 0;
const MAX_CACHE_SIZE = 3000;

function getThumbnailHash(wallpaperPath) {
    if (!wallpaperPath || typeof wallpaperPath !== "string")
        return "0_0";

    if (_hashCache[wallpaperPath]) {
        return _hashCache[wallpaperPath];
    }

    const len = wallpaperPath.length;
    let h = 5381;
    for (let i = 0; i < len; i++) {
        h = ((h << 5) + h + wallpaperPath.charCodeAt(i)) | 0;
    }

    const result = Math.abs(h).toString(36) + "_" + (len & 0xFF);

    if (_cacheSize >= MAX_CACHE_SIZE) {
        for (let k in _hashCache) {
            delete _hashCache[k];
        }
        _cacheSize = 0;
    }

    _hashCache[wallpaperPath] = result;
    _cacheSize++;

    return result;
}
