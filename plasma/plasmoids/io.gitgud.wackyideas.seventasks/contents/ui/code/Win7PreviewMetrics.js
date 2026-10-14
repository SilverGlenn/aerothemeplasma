.pragma library

// Logical pixels; Qt applies the screen's scale factor, not this policy.
var previewWidth = 164;
var previewHeight = 94;
var peekDelay = 800;
var dragActivationDelay = 250;

function boundedSize(preferred, available) {
    return Math.max(1, Math.min(preferred, available));
}

function horizontalExtent(count, width, gutter) {
    return count > 0 ? count * width + (count - 1) * gutter : 0;
}

function needsList(count, width, gutter, availableWidth) {
    return horizontalExtent(count, width, gutter) > availableWidth;
}

function fitPreview(width, height, maxWidth, maxHeight) {
    if (width <= 0 || height <= 0) {
        return { width: maxWidth, height: maxHeight };
    }
    var ratio = Math.min(maxWidth / width, maxHeight / height);
    return { width: Math.floor(width * ratio), height: Math.floor(height * ratio) };
}
