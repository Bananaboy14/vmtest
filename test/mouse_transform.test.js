/**
 * @jest-environment jsdom
 */

const fs = require('fs');
const path = require('path');

// Load the module under test by evaluating its source in the jsdom environment
const src = fs.readFileSync(path.join(__dirname, '..', 'scripts', 'mouse_transform.js'), 'utf8');
let exportsObj = {};

// The source file uses ES module syntax (export ...). Transform it into
// a form that can be executed in this CommonJS test environment by
// removing the `export` keywords and assigning the default export to
// `exportsObj.default`.
let transformed = src.replace(/^export\s+function/gm, 'function');
transformed = transformed.replace(/export\s+default\s+\{([\s\S]*?)\};?\s*$/m, (m, p1) => {
    return `exportsObj.default = { ${p1.trim()} };`;
});

const moduleWrapper = `(function(exportsObj){\n${transformed}\n})(exportsObj);`;
eval(moduleWrapper);

const { calculateCanvasTransform, transformMouseCoordinates } = exportsObj.default || exportsObj;

describe('mouse_transform', () => {
    test('calculateCanvasTransform and transformMouseCoordinates - contain (letterbox)', () => {
        // Create a fake canvas element with logical size 1280x720 and displayed rect 1280x360 (letterboxed vertically)
        const canvas = document.createElement('canvas');
        canvas.width = 1280;
        canvas.height = 720;
        // Simulate CSS bounding rect (e.g., scaled to 1280x360 centered horizontally)
        // jsdom doesn't implement getBoundingClientRect with real numbers, so mock it
        canvas.getBoundingClientRect = () => ({ left: 100, top: 50, width: 1280, height: 360 });

        const container = document.createElement('div');
        container.getBoundingClientRect = () => ({ left: 0, top: 0, width: 1440, height: 360 });

        const t = calculateCanvasTransform(canvas, container);
        expect(t.logicalW).toBe(1280);
        expect(t.logicalH).toBe(720);
        // usedRect should be centered horizontally in this case due to letterboxing
        expect(t.usedRect.width).toBeCloseTo(640, 0); // since aspect differs, usedWidth should be <= rect.width

        // Click in the center of the used region
        const clientX = t.usedRect.left + t.usedRect.width / 2;
        const clientY = t.usedRect.top + t.usedRect.height / 2;

        const coords = transformMouseCoordinates(clientX, clientY, canvas, container);
        expect(coords).not.toBeNull();
        // logical center should be near half of logical dimensions
        expect(coords.x).toBeGreaterThan(600);
        expect(coords.x).toBeLessThan(700);
        expect(coords.y).toBeGreaterThan(300);
        expect(coords.y).toBeLessThan(420);
    });

    test('calculateCanvasTransform and transformMouseCoordinates - cover (cropped)', () => {
        const canvas = document.createElement('canvas');
        canvas.width = 1920;
        canvas.height = 1080;
        canvas.getBoundingClientRect = () => ({ left: 0, top: 0, width: 1366, height: 768 });
        // Simulate object-fit: cover
        const origGetComputedStyle = window.getComputedStyle;
        window.getComputedStyle = () => ({ getPropertyValue: () => 'cover' });

        const t = calculateCanvasTransform(canvas, document.body);
        expect(t.logicalW).toBe(1920);
        expect(t.logicalH).toBe(1080);
        // For cover, usedRect may start at negative left/top due to cropping
        expect(t.usedRect.width).toBeGreaterThanOrEqual(1366);
        expect(t.usedRect.height).toBeGreaterThanOrEqual(768);

        // Click near center of viewport should map within logical bounds
        const clientX = 1366 / 2;
        const clientY = 768 / 2;
        const coords = transformMouseCoordinates(clientX, clientY, canvas, document.body);
        expect(coords).not.toBeNull();
        expect(coords.x).toBeGreaterThanOrEqual(0);
        expect(coords.y).toBeGreaterThanOrEqual(0);

        // restore
        window.getComputedStyle = origGetComputedStyle;
    });
});
