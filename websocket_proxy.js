#!/usr/bin/env node

const WebSocket = require('ws');
const net = require('net');

console.log('Starting WebSocket to VNC proxy on port 3000...');

const wss = new WebSocket.Server({ 
    port: 3000,
    perMessageDeflate: false
});

console.log('WebSocket proxy listening on port 3000');

wss.on('connection', function connection(ws) {
    console.log('Client connected to WebSocket proxy');
    
    // Connect to VNC server on port 8080
    const vncSocket = net.createConnection(8080, 'localhost', function() {
        console.log('Connected to VNC server on port 8080');
    });
    
    // Forward data from VNC server to WebSocket client
    vncSocket.on('data', function(data) {
        if (ws.readyState === WebSocket.OPEN) {
            ws.send(data);
        }
    });
    
    // Forward data from WebSocket client to VNC server
    ws.on('message', function(message) {
        vncSocket.write(Buffer.from(message));
    });
    
    // Handle WebSocket close
    ws.on('close', function() {
        console.log('WebSocket client disconnected');
        vncSocket.end();
    });
    
    // Handle VNC socket close
    vncSocket.on('close', function() {
        console.log('VNC connection closed');
        if (ws.readyState === WebSocket.OPEN) {
            ws.close();
        }
    });
    
    // Handle errors
    ws.on('error', function(err) {
        console.error('WebSocket error:', err);
        vncSocket.end();
    });
    
    vncSocket.on('error', function(err) {
        console.error('VNC socket error:', err);
        if (ws.readyState === WebSocket.OPEN) {
            ws.close();
        }
    });
});

console.log('WebSocket proxy ready - connects clients on :3000 to VNC server on :8080');
