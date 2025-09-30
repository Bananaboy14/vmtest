// Debug mouse handling for noVNC
// Add this to browser console to debug mouse coordinates

function debugMouseHandling() {
    const canvas = document.querySelector('#noVNC_canvas');
    if (!canvas) {
        console.log('noVNC canvas not found');
        return;
    }
    
    // Override clientToElement for debugging
    const originalClientToElement = window.clientToElement;
    
    function debugClientToElement(x, y, elem) {
        const bounds = elem.getBoundingClientRect();
        const scaleX = elem.width / bounds.width;
        const scaleY = elem.height / bounds.height;
        
        const elementX = (x - bounds.left) * scaleX;
        const elementY = (y - bounds.top) * scaleY;
        
        console.log(`Mouse Debug:
            Client: (${x}, ${y})
            Bounds: left=${bounds.left}, top=${bounds.top}, width=${bounds.width}, height=${bounds.height}
            Canvas: width=${elem.width}, height=${elem.height}
            Style: width=${elem.style.width}, height=${elem.style.height}
            Scale: X=${scaleX}, Y=${scaleY}
            Element: (${elementX}, ${elementY})`);
            
        return { x: elementX, y: elementY };
    }
    
    // Add click listener for debugging
    canvas.addEventListener('click', (e) => {
        console.log('=== MOUSE CLICK DEBUG ===');
        const pos = debugClientToElement(e.clientX, e.clientY, canvas);
        
        // Get display object if possible
        const rfb = window.UI?.rfb;
        if (rfb && rfb._display) {
            const absX = rfb._display.absX(pos.x);
            const absY = rfb._display.absY(pos.y);
            const scale = rfb._display.scale;
            const viewport = rfb._display._viewportLoc;
            
            console.log(`Display Debug:
                Scale: ${scale}
                Viewport: x=${viewport.x}, y=${viewport.y}, w=${viewport.w}, h=${viewport.h}
                Final VNC coords: (${absX}, ${absY})`);
        }
        console.log('=== END DEBUG ===');
    });
    
    console.log('Mouse debugging enabled - click on canvas to see coordinate transformation');
}

// Auto-run when noVNC is loaded
if (typeof window !== 'undefined') {
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            setTimeout(debugMouseHandling, 1000);
        });
    } else {
        setTimeout(debugMouseHandling, 1000);
    }
}