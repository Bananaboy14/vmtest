
const express = require('express');
const expressWs = require('express-ws');
const net = require('net');
const path = require('path');
const fs = require('fs');
const http = require('http');

const app = express();
const port = 8080;

// Redirect root to the glass UI (vnc_glass.html). Keep old vnc.html as a fallback.
app.get('/', (req, res) => {
    // Primary debug landing page
    res.redirect('/vnc_glass.html');
    // Fallback: res.redirect('/vnc.html');
});

// Enable WebSocket support
expressWs(app);

// Serve static files
app.use(express.static(__dirname));
// Serve noVNC core files at /core
app.use('/core', express.static(path.join(__dirname, 'noVNC/core')));
// Accept JSON request bodies for debug logging
app.use(express.json({ limit: '1mb' }));

// Endpoint to receive mouse mapping diagnostics from the browser and print to server terminal
app.post('/mouse-log', (req, res) => {
    try {
        const payload = req.body;
        // Pretty-print concise object to terminal
        console.log('🖱️ [MOUSE_LOG]', typeof payload === 'object' ? JSON.stringify(payload) : payload);
    } catch (err) {
        console.log('🖱️ [MOUSE_LOG] failed to parse body', err);
    }
    // 204 No Content - caller used beacon/fetch with no need for a response body
    res.sendStatus(204);
});


// WebSocket endpoint for VNC (supports both /websockify and /websocket)
function vncWebSocketHandler(ws, req) {
    console.log('📡 [WS] New WebSocket connection:', req.path);
    ws.on('open', () => {
        console.log('🟢 [WS] WebSocket open');
    });
    ws.on('close', (code, reason) => {
        console.log('🔴 [WS] WebSocket closed:', code, reason);
    });
    ws.on('error', (err) => {
        console.log('❌ [WS] WebSocket error:', err);
    });
    ws.on('message', (data) => {
        console.log('📤 [WS] Message from client:', data.length, 'bytes');
    });

    // Connect to VNC server
    const vncSocket = net.createConnection(5901, '127.0.0.1');
    vncSocket.on('connect', () => {
        console.log('✅ [VNC] Connected to VNC server');
    });
    vncSocket.on('data', (data) => {
        console.log('📥 [VNC] Data from VNC server:', data.length, 'bytes');
        if (ws.readyState === ws.OPEN) {
            ws.send(data);
        }
    });
    vncSocket.on('close', () => {
        console.log('🔌 [VNC] VNC connection closed');
        ws.close();
    });
    vncSocket.on('error', (err) => {
        console.log('❌ [VNC] VNC error:', err);
        ws.close();
    });

    // Forward WebSocket messages to VNC server
    ws.on('message', (data) => {
        if (vncSocket.writable) {
            vncSocket.write(data);
        }
    });
    ws.on('close', () => {
        vncSocket.destroy();
    });
}

app.ws('/websockify', vncWebSocketHandler);
app.ws('/websocket', vncWebSocketHandler);

app.get('/health', (req, res) => {
    res.json({ status: 'ok', port: port });
});

http.createServer(app).listen(port, () => {
    console.log(`🚀 HTTP server running on port ${port}`);
    console.log(`🌐 VNC Client: http://localhost:${port}/vnc.html`);
    console.log(`📡 WebSocket: ws://localhost:${port}/websockify`);
});
