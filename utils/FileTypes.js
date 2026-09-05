.pragma library



const VIDEO_EXTENSIONS = {
    "mp4": true,
    "mkv": true,
    "mov": true,
    "webm": true,
    "avi": true,
    "flv": true
};

const IMAGE_EXTENSIONS = {
    "jpg": true,
    "jpeg": true,
    "png": true,
    "webp": true,
    "bmp": true,
    "tiff": true,
    "gif": true
};

function getExtension(path) {
    if (!path || typeof path !== "string" || path.endsWith("/"))
        return "";
    const dotIdx = path.lastIndexOf(".");
    if (dotIdx < 0 || dotIdx === path.length - 1)
        return "";
    return path.substring(dotIdx + 1).toLowerCase();
}

function isVideoFile(path) {
    const ext = getExtension(path);
    return !!VIDEO_EXTENSIONS[ext];
}

function isGifFile(path) {
    const ext = getExtension(path);
    return ext === "gif";
}

function isImageFile(path) {
    const ext = getExtension(path);
    return !!IMAGE_EXTENSIONS[ext];
}
