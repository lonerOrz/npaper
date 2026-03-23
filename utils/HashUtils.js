.pragma library

// djb2 hash algorithm for generating short, unique filenames
function getThumbnailHash(wallpaperPath) {
    let h = 5381;
    for (let i = 0; i < wallpaperPath.length; i++) {
        h = ((h << 5) + h + wallpaperPath.charCodeAt(i)) | 0;
    }
    return Math.abs(h).toString(36) + "_" + (wallpaperPath.length & 0xFF);
}
