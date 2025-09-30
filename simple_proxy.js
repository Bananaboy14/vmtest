const WebSocket = require('ws');
const net = require('net');

const PORT = 8083;
const VNC_HOST = '127.0.0.1';
const VNC_PORT = 5901;

console.log(`Starting simple WebSocket proxy on port ${PORT}...`);

const wss = new WebSocket.Server({ port: PORT }, () => {
    console.log(`✅ WebSocket server listening on port ${PORT}`);
    console.log(`Forwarding to VNC server at ${VNC_HOST}:${VNC_PORT}`);
});

wss.on('connection', function connection(ws, req) {
    console.log('📡 New WebSocket connection from:', req.socket.remoteAddress);
    
    // Create connection to VNC server
    const vncSocket = net.createConnection(VNC_PORT, VNC_HOST, () => {
        console.log('✅ Connected to VNC server');
    });
    
    // Forward data from WebSocket to VNC server
    ws.on('message', function message(data) {
        console.log('📤 WS->VNC:', data.length, 'bytes');
        if (vncSocket.readyState === 'open') {
            vncSocket.write(data);
        }
    });
    
    // Forward data from VNC server to WebSocket
    vncSocket.on('data', (data) => {
        console.log('📥 VNC->WS:', data.length, 'bytes');
        if (ws.readyState === WebSocket.OPEN) {
            ws.send(data);
        }
    });
    
    // Handle errors and cleanup
    ws.on('close', () => {
        console.log('🔌 WebSocket closed');
        vncSocket.destroy();
    });
    
    vncSocket.on('close', () => {
        console.log('🔌 VNC connection closed');
        ws.close();
    });
    
    vncSocket.on('error', (err) => {
        console.log('❌ VNC connection error:', err.message);
        ws.close();
    });
    
    ws.on('error', (err) => {
        console.log('❌ WebSocket error:', err.message);
        vncSocket.destroy();
    });
});

wss.on('error', (err) => {
    console.log('❌ WebSocket server error:', err.message);
});

console.log('Server starting...');
