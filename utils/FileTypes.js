.pragma library

function isVideoFile(path) {
    if (!path || path.length === 0 || path.endsWith('/'))
        return false;
    const lower = path.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mkv') || lower.endsWith('.mov') || lower.endsWith('.webm');
}

function isGifFile(path) {
    if (!path || path.length === 0 || path.endsWith('/'))
        return false;
    return path.toLowerCase().endsWith('.gif');
}
