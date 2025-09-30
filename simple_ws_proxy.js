const WebSocket = require('ws');
const net = require('net');

const VNC_HOST = '127.0.0.1';
const VNC_PORT = 5901;
const PROXY_PORT = 8080;

console.log('Starting simple VNC WebSocket proxy...');

const wss = new WebSocket.Server({ port: PROXY_PORT, path: '/websockify' });

wss.on('connection', function(ws) {
    console.log('WebSocket connection established');
    
    // Connect to VNC server
    const vncSocket = new net.Socket();
    
    vncSocket.connect(VNC_PORT, VNC_HOST, function() {
        console.log('Connected to VNC server');
    });
    
    // Forward WebSocket data to VNC server
    ws.on('message', function(data) {
        if (vncSocket.writable) {
            vncSocket.write(data);
        }
    });
    
    // Forward VNC server data to WebSocket
    vncSocket.on('data', function(data) {
        if (ws.readyState === WebSocket.OPEN) {
            ws.send(data);
        }
    });
    
    // Handle disconnections
    ws.on('close', function() {
        console.log('WebSocket closed');
        vncSocket.destroy();
    });
    
    vncSocket.on('close', function() {
        console.log('VNC connection closed');
        ws.close();
    });
    
    vncSocket.on('error', function(err) {
        console.log('VNC error:', err.message);
        ws.close();
    });
});

wss.on('listening', function() {
    console.log('WebSocket server listening on port', PROXY_PORT);
    console.log('Path: /websockify');
    console.log('Forwarding to VNC server at', VNC_HOST + ':' + VNC_PORT);
});

wss.on('error', function(err) {
    console.error('WebSocket server error:', err.message);
});
