// Robust mouse coordinate transform utility
// Exports:
// - calculateCanvasTransform(canvas, container): returns { scale, offsetX, offsetY }
// - transformMouseCoordinates(clientX, clientY, canvas, container): returns { x, y }
// Works with CSS scaling, devicePixelRatio, object-fit like contain/cover, and pointer lock mode.

export function calculateCanvasTransform(canvas, container = canvas.parentElement) {
    // Returns precise mapping information from CSS/displayed canvas -> logical canvas pixels.
    // Uses the actual displayed canvas rect (getBoundingClientRect) which already accounts for
    // CSS transforms, object-fit, centering, and parent transforms.
    if (!canvas) return { scaleX: 1, scaleY: 1, canvasRect: { left: 0, top: 0, width: 0, height: 0 } };

    // Logical canvas size (drawing buffer pixels)
    const logicalW = canvas.width || 0;
    const logicalH = canvas.height || 0;

    // The displayed size in CSS pixels (already accounts for CSS transforms / object-fit)
    const canvasRect = canvas.getBoundingClientRect();

    // Compute CSS pixels per logical pixel. If the canvas has been upscaled/downscaled,
    // these ratios indicate how to convert CSS coordinates back into logical canvas coords.
    // Use separate scaleX/scaleY to handle non-uniform scaling (rare) safely.
    const scaleX = logicalW > 0 ? (canvasRect.width / logicalW) : 1;
    const scaleY = logicalH > 0 ? (canvasRect.height / logicalH) : 1;

    // Compute the usedRect similarly to transformMouseCoordinates so callers can
    // understand where the framebuffer is actually drawn inside the CSS rect.
    let usedLeft = canvasRect.left;
    let usedTop = canvasRect.top;
    let usedWidth = canvasRect.width;
    let usedHeight = canvasRect.height;

    try {
        if (logicalW > 0 && logicalH > 0) {
            const logicalAspect = logicalW / logicalH;
            const cssAspect = canvasRect.width / canvasRect.height;
            if (Math.abs(logicalAspect - cssAspect) > 0.0001) {
                const cs = window.getComputedStyle && window.getComputedStyle(canvas);
                const objectFit = cs ? cs.getPropertyValue('object-fit') : '';

                if (objectFit === 'cover') {
                    const scale = Math.max(canvasRect.width / logicalW, canvasRect.height / logicalH);
                    usedWidth = logicalW * scale;
                    usedHeight = logicalH * scale;
                    usedLeft = canvasRect.left - (usedWidth - canvasRect.width) / 2;
                    usedTop = canvasRect.top - (usedHeight - canvasRect.height) / 2;
                } else {
                    if (cssAspect > logicalAspect) {
                        usedHeight = canvasRect.height;
                        usedWidth = canvasRect.height * logicalAspect;
                        usedLeft = canvasRect.left + (canvasRect.width - usedWidth) / 2;
                        usedTop = canvasRect.top;
                    } else {
                        usedWidth = canvasRect.width;
                        usedHeight = canvasRect.width / logicalAspect;
                        usedTop = canvasRect.top + (canvasRect.height - usedHeight) / 2;
                        usedLeft = canvasRect.left;
                    }
                }
            }
        }
    } catch (e) {
        usedLeft = canvasRect.left;
        usedTop = canvasRect.top;
        usedWidth = canvasRect.width;
        usedHeight = canvasRect.height;
    }

    const effectiveScaleX = usedWidth / (logicalW || 1);
    const effectiveScaleY = usedHeight / (logicalH || 1);

    return { scaleX, scaleY, canvasRect, logicalW, logicalH, usedRect: { left: usedLeft, top: usedTop, width: usedWidth, height: usedHeight }, effectiveScaleX, effectiveScaleY };
}

export function transformMouseCoordinates(clientX, clientY, canvas, container = canvas.parentElement) {
    // If pointer locked, callers should use movementX/movementY instead
    const lockElem = document.pointerLockElement;
    if (lockElem === canvas) {
        // When pointer locked, clientX/Y are meaningless; return null to signal caller to use deltas
        return null;
    }

    const { scaleX, scaleY, canvasRect, logicalW, logicalH } = calculateCanvasTransform(canvas, container);

    // Fallback if canvasRect isn't available
    const rect = canvasRect || canvas.getBoundingClientRect();

    // Map client coordinates (CSS pixels relative to viewport) to canvas logical pixels
    // rect.left/top are viewport-relative coordinates
    const cssX = clientX - rect.left;
    const cssY = clientY - rect.top;

    // Detect letterboxing/pillarboxing: the canvas rect may be larger than the
    // actual drawn framebuffer area when aspect ratios differ. Compute the
    // displayed framebuffer area inside the canvas rect and map to that region.
    // usedRect describes the displayed framebuffer area inside the canvas element
    let usedLeft = rect.left;
    let usedTop = rect.top;
    let usedWidth = rect.width;
    let usedHeight = rect.height;

    try {
        // logicalW/logicalH are the canvas drawing buffer dimensions
        if (logicalW > 0 && logicalH > 0) {
            const logicalAspect = logicalW / logicalH;
            const cssAspect = rect.width / rect.height;
            if (Math.abs(logicalAspect - cssAspect) > 0.0001) {
                // We need to handle both 'contain' (letterbox/pillarbox) and
                // 'cover' (crop) behaviors. By default browsers will use
                // 'object-fit: contain' semantics when sizing a canvas element
                // via width/height while preserving aspect ratio; however some
                // styles (notably in fullscreen) may set 'object-fit: cover'
                // which fills the container and crops overflow. We detect the
                // applied object-fit and compute the used framebuffer rect
                // accordingly.
                const cs = window.getComputedStyle && window.getComputedStyle(canvas);
                const objectFit = cs ? cs.getPropertyValue('object-fit') : '';

                if (objectFit === 'cover') {
                    // COVER: scale to fill container, crop overflowing parts
                    // scale = max(cssW / logicalW, cssH / logicalH)
                    const scale = Math.max(rect.width / logicalW, rect.height / logicalH);
                    usedWidth = logicalW * scale;
                    usedHeight = logicalH * scale;
                    // usedLeft/Top are such that the used image is centered and
                    // overflows the container; therefore the left of the used
                    // image is rect.left - overflow/2
                    usedLeft = rect.left - (usedWidth - rect.width) / 2;
                    usedTop = rect.top - (usedHeight - rect.height) / 2;
                } else {
                    // CONTAIN (or default): scale to fit inside container, may
                    // leave letterbox/pillarbox bars
                    if (cssAspect > logicalAspect) {
                        // container is wider than logical -> image fits full height
                        usedHeight = rect.height;
                        usedWidth = rect.height * logicalAspect;
                        usedLeft = rect.left + (rect.width - usedWidth) / 2;
                        usedTop = rect.top;
                    } else {
                        // container is taller than logical -> image fits full width
                        usedWidth = rect.width;
                        usedHeight = rect.width / logicalAspect;
                        usedTop = rect.top + (rect.height - usedHeight) / 2;
                        usedLeft = rect.left;
                    }
                }
            }
        }
    } catch (e) {
        // If anything goes wrong, fall back to whole-canvas mapping
        usedLeft = rect.left;
        usedTop = rect.top;
        usedWidth = rect.width;
        usedHeight = rect.height;
    }

    // Clamp to canvas CSS bounds to avoid sending coords outside
    // Compute CSS coordinates relative to used image region (viewport coords -> usedRect coords)
    const relCssX = clientX - usedLeft;
    const relCssY = clientY - usedTop;

    const clampedCssX = Math.max(0, Math.min(relCssX, usedWidth));
    const clampedCssY = Math.max(0, Math.min(relCssY, usedHeight));

    // Convert CSS pixels -> logical canvas pixels. Since scaleX = cssWidth / logicalWidth,
    // dividing by scaleX gives logical pixels: logicalX = cssX / (cssWidth/logicalWidth)
    // Convert CSS pixels inside used image region -> logical pixels.
    // scaleX/scaleY = cssWidth / logicalWidth for the full canvas rect, but for the
    // used region we must compute effective CSS-per-logical for that region.
    const effectiveScaleX = usedWidth / (logicalW || 1);
    const effectiveScaleY = usedHeight / (logicalH || 1);

    // Logical (framebuffer) coordinates as floats — callers may round as appropriate
    const xf = (clampedCssX) / (effectiveScaleX || 1);
    const yf = (clampedCssY) / (effectiveScaleY || 1);

    // Clamp to valid logical bounds
    const x = Math.max(0, Math.min((logicalW || 1) - 1, Math.round(xf)));
    const y = Math.max(0, Math.min((logicalH || 1) - 1, Math.round(yf)));

    return {
        x,
        y,
        xf,
        yf,
        cssX: clampedCssX,
        cssY: clampedCssY,
        scaleX,
        scaleY,
        effectiveScaleX,
        effectiveScaleY,
        canvasRect: rect,
        usedRect: { left: usedLeft, top: usedTop, width: usedWidth, height: usedHeight }
    };
}

export default { calculateCanvasTransform, transformMouseCoordinates };
