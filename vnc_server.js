#!/usr/bin/env node

const http = require('http');
const fs = require('fs');
const path = require('path');
const WebSocket = require('ws');
const net = require('net');

const PORT = parseInt(process.env.PORT || '8080', 10);
const VNC_PORT = parseInt(process.env.VNC_PORT || '5901', 10);

console.log(`🚀 Starting All-in-One VNC Server on port ${PORT} (proxy -> localhost:${VNC_PORT})`);

// Create HTTP server for serving files
const server = http.createServer((req, res) => {
    // API endpoints
    if (req.url === '/api/reset-mouse' && req.method === 'POST') {
        const { exec } = require('child_process');
        exec('bash /workspaces/vmtest/fix_mouse_accuracy.sh', (error, stdout, stderr) => {
            if (error) {
                console.error('Mouse reset error:', error);
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Failed to reset mouse settings' }));
            } else {
                console.log('Mouse settings reset:', stdout);
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true, message: 'Mouse settings reset' }));
            }
        });
        return;
    }
    // Lightweight mouse-log receiver for non-visual client debug (204 No Content)
    if (req.url === '/mouse-log' && req.method === 'POST') {
        let body = [];
        req.on('data', (chunk) => {
            body.push(chunk);
        }).on('end', () => {
            try {
                body = Buffer.concat(body).toString() || '';
                // Try parse JSON, but fall back to raw string
                let payload = body;
                try {
                    payload = JSON.parse(body);
                } catch (e) {
                    // not JSON
                }
                console.log('🖱️ [MOUSE_LOG]', typeof payload === 'object' ? JSON.stringify(payload) : payload);
            } catch (err) {
                console.log('🖱️ [MOUSE_LOG] failed to parse body', err);
            }
            // No content response to support navigator.sendBeacon without blocking
            res.writeHead(204);
            res.end();
        });
        return;
    }
    
    let filePath = path.join(__dirname, req.url === '/' ? 'vnc_glass.html' : req.url);
    
    // Security check - don't serve files outside directory
    if (!filePath.startsWith(__dirname)) {
        res.writeHead(403);
        res.end('Forbidden');
        return;
    }
    
    // Check if file exists
    if (!fs.existsSync(filePath)) {
        res.writeHead(404);
        res.end('File not found');
        return;
    }
    
    // Get file extension for MIME type
    const ext = path.extname(filePath).toLowerCase();
    const mimeTypes = {
        '.html': 'text/html',
        '.js': 'application/javascript',
        '.css': 'text/css',
        '.json': 'application/json',
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.gif': 'image/gif',
        '.svg': 'image/svg+xml',
        '.ico': 'image/x-icon'
    };
    
    const contentType = mimeTypes[ext] || 'application/octet-stream';
    
    // Read and serve file
    fs.readFile(filePath, (err, content) => {
        if (err) {
            res.writeHead(500);
            res.end('Server error');
            return;
        }
        
        res.writeHead(200, { 'Content-Type': contentType });
        res.end(content);
    });
});

// Create WebSocket server for VNC proxy
const wss = new WebSocket.Server({ 
    server: server,
    path: '/websocket',
    perMessageDeflate: false,
    maxPayload: 1024 * 1024 * 16, // 16MB max payload
    clientTracking: true
});

console.log('🔗 WebSocket proxy ready on /websocket path');

wss.on('connection', function connection(ws, req) {
    const clientAddr = req.connection.remoteAddress;
    console.log('📱 Client connected to WebSocket proxy from:', clientAddr);
    
    let vncSocket;
    let connectionActive = true;
    let bytesReceived = 0;
    let bytesSent = 0;
    let pingInterval;

    // WebSocket error/close logging
    ws.on('error', (err) => {
        console.error('WebSocket error:', err);
    });
    ws.on('close', (code, reason) => {
        console.warn(`WebSocket closed: code=${code}, reason=${reason}`);
        clearInterval(pingInterval);
    });

    // Keepalive ping (every 20s)
    pingInterval = setInterval(() => {
        if (ws.readyState === ws.OPEN && connectionActive) {
            ws.ping();
        }
    }, 20000);

    // Configure WebSocket
    ws.binaryType = 'arraybuffer';
    
    ws.on('pong', () => {
        console.log('🏓 Pong received from client');
    });
    
    // Connect to VNC server on configured port
    try {
        vncSocket = net.createConnection(VNC_PORT, 'localhost', function() {
            console.log('🖥️  Connected to VNC server on port', VNC_PORT);
        });
    } catch (err) {
        console.error('❌ Failed to create VNC connection:', err);
        ws.close();
        return;
    }
    
    // Forward data from VNC server to WebSocket client
    vncSocket.on('data', function(data) {
        if (ws.readyState === WebSocket.OPEN && connectionActive) {
            bytesReceived += data.length;
            try {
                // Check if WebSocket buffer is getting full
                if (ws.bufferedAmount > 1024 * 1024) { // 1MB buffer limit
                    console.warn('⚠️  WebSocket buffer is full, pausing VNC socket');
                    vncSocket.pause();
                    
                    // Resume when buffer is drained
                    const checkBuffer = setInterval(() => {
                        if (ws.bufferedAmount < 512 * 1024) { // Resume at 512KB
                            console.log('✅ WebSocket buffer drained, resuming VNC socket');
                            vncSocket.resume();
                            clearInterval(checkBuffer);
                        }
                    }, 100);
                    
                    return;
                }
                
                // Send as binary data
                ws.send(data, { binary: true });
                // Only log every 50KB to reduce noise
                if (bytesReceived % 50000 < data.length) {
                    console.log('📤 Sent', bytesReceived, 'bytes total to client');
                }
            } catch (err) {
                console.error('❌ Error sending to WebSocket:', err);
                connectionActive = false;
                clearInterval(pingInterval);
                if (vncSocket) vncSocket.end();
            }
        } else if (ws.readyState !== WebSocket.OPEN) {
            console.log('⚠️  VNC data received but WebSocket not ready, state:', ws.readyState);
            connectionActive = false;
            clearInterval(pingInterval);
            if (vncSocket) vncSocket.end();
        }
    });
    
    // Forward data from WebSocket client to VNC server
    ws.on('message', function(message) {
        if (vncSocket && connectionActive) {
            bytesSent += message.length;
            try {
                vncSocket.write(Buffer.from(message));
                // Only log every 1KB to reduce noise  
                if (bytesSent % 1000 < message.length) {
                    console.log('📥 Received', bytesSent, 'bytes total from client');
                }
            } catch (err) {
                console.error('❌ Error writing to VNC socket:', err);
                connectionActive = false;
                ws.close();
            }
        }
    });
    
    // Handle WebSocket close
    ws.on('close', function(code, reason) {
        console.log('📱 WebSocket client disconnected - Code:', code, 'Reason:', reason?.toString() || 'none');
        console.log('📊 Session stats - Received:', bytesReceived, 'Sent:', bytesSent);
        connectionActive = false;
        clearInterval(pingInterval);
        if (vncSocket) {
            vncSocket.end();
        }
    });
    
    // Handle VNC socket close
    vncSocket.on('close', function(hadError) {
        console.log('🖥️  VNC connection closed, hadError:', hadError);
        console.log('📊 Session stats - Received:', bytesReceived, 'Sent:', bytesSent);
        connectionActive = false;
        clearInterval(pingInterval);
        if (ws.readyState === WebSocket.OPEN) {
            ws.close(1000, 'VNC connection closed');
        }
    });
    
    // Handle VNC socket errors
    vncSocket.on('error', function(err) {
        console.error('🖥️  VNC socket error:', err.message);
        connectionActive = false;
        clearInterval(pingInterval);
        if (ws.readyState === WebSocket.OPEN) {
            ws.close(1011, 'VNC server error');
        }
    });
    
    // Handle timeout
    vncSocket.setTimeout(60000, function() {
        console.warn('⏰ VNC socket timeout');
        connectionActive = false;
        clearInterval(pingInterval);
        vncSocket.destroy();
        if (ws.readyState === WebSocket.OPEN) {
            ws.close(1008, 'VNC connection timeout');
        }
    });

    // Handle errors with detailed logging
    ws.on('error', function(err) {
        console.error('📱 WebSocket error from', clientAddr, ':', err.message);
        connectionActive = false;
        clearInterval(pingInterval);
        if (vncSocket) {
            vncSocket.end();
        }
    });
    
    vncSocket.on('error', function(err) {
        console.error('🖥️  VNC socket error:', err.message, 'Code:', err.code, 'Full error:', err);
        connectionActive = false;
        clearInterval(pingInterval);
        if (ws.readyState === WebSocket.OPEN) {
            ws.close(1000, 'VNC socket error: ' + err.message);
        }
    });
    
    // Connection timeout detection
    setTimeout(() => {
        if (connectionActive && bytesReceived === 0) {
            console.log('⚠️  No data received from VNC server after 5 seconds, checking connection...');
        }
    }, 5000);
});

// Start server
server.listen(PORT, () => {
    console.log(`✅ All-in-One VNC Server running on http://localhost:${PORT}`);
    console.log('📁 Serving files from:', __dirname);
    console.log(`🔗 WebSocket proxy available at ws://localhost:${PORT}/websocket`);
    console.log(`🎯 Direct access: http://localhost:${PORT}/ will load vnc_glass.html`);
});
