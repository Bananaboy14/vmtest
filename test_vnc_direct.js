const WebSocket = require('ws');

console.log('Testing websocket connection to noVNC proxy...');
const ws = new WebSocket('ws://localhost:8080/websockify');

ws.on('open', () => {
  console.log('✅ WebSocket connected');
  
  // Send VNC handshake
  const vncVersion = Buffer.from('RFB 003.008\n');
  ws.send(vncVersion);
  console.log('📤 Sent VNC version handshake');
});

ws.on('message', (data) => {
  console.log('📥 Received:', data.length, 'bytes');
  if (data.length > 0) {
    const str = data.toString('ascii', 0, Math.min(20, data.length));
    console.log('   Content (first 20 chars):', JSON.stringify(str));
    
    if (str.startsWith('RFB ')) {
      console.log('✅ Got VNC version response');
      ws.close();
    }
  }
});

ws.on('error', (err) => {
  console.error('❌ WebSocket error:', err.message);
});

ws.on('close', (code, reason) => {
  console.log('🔌 Connection closed:', code, reason?.toString());
  process.exit(code === 1000 ? 0 : 1);
});

// Timeout after 10 seconds
setTimeout(() => {
  console.log('⏰ Timeout - closing connection');
  ws.close();
}, 10000);
