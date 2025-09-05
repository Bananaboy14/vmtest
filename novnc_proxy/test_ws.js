const WebSocket = require('ws');

const URL = process.env.URL || 'ws://127.0.0.1:8080/websockify';
console.log('Connecting to', URL);
const ws = new WebSocket(URL);

ws.on('open', () => {
  console.log('OPEN');
});

ws.on('message', (m) => {
  try {
    const buf = Buffer.isBuffer(m) ? m : Buffer.from(String(m));
    console.log('MSG len=', buf.length, 'prefix=', buf.slice(0, Math.min(32, buf.length)).toString('hex'));
  } catch (e) { console.error('msg parse err', e && e.stack); }
});

ws.on('error', (err) => {
  console.error('ERROR', err && err.stack || err);
});

ws.on('close', (code, reason) => {
  console.log('CLOSE', code, reason && reason.toString());
  process.exit(0);
});

// Close after 10s if still open
setTimeout(() => {
  if (ws.readyState === ws.OPEN) {
    console.log('TIMEOUT closing');
    ws.close();
  }
}, 10000);
