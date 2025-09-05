const express = require('express');
const expressWs = require('express-ws');
const net = require('net');
const path = require('path');

const NOVNC_DIR = process.env.NOVNC_DIR || '/opt/noVNC';
const PORT = parseInt(process.env.NOVNC_PORT || '8080', 10);
const VNC_HOST = process.env.VNC_HOST || '127.0.0.1';
const VNC_PORT = parseInt(process.env.VNC_PORT || '5901', 10);

const app = express();
expressWs(app);

// Log incoming HTTP requests (helps debug reverse-proxy / 502 issues)
app.use((req, res, next) => {
  try {
    console.log('[novnc-proxy] HTTP', req.method, req.url, 'Host:', req.headers && req.headers.host);
  } catch (e) {}
  next();
});

// Basic error handler to capture unexpected errors and return 502 to clients
app.use((err, req, res, next) => {
  console.error('[novnc-proxy] HTTP error', err && err.stack || err);
  try { res.status(502).send('Proxy error'); } catch (e) {}
});

// Redirect root to /vnc.html for convenience
app.get('/', (req, res) => res.redirect('/vnc.html'));
app.get('/vnc.html', (req, res) => {
  res.sendFile(path.join(NOVNC_DIR, 'vnc.html'));
});
// Serve static noVNC files
app.use('/', express.static(NOVNC_DIR));

// Proxy websocket endpoint used by noVNC (/websockify)
app.ws('/websockify', function(ws, req) {
  console.log('[novnc-proxy] ws connection from', req.socket.remoteAddress);

  // Reconnect/backoff state
  let vnc = null;
  let closing = false; // true when ws closed by client
  let reconnectAttempts = 0;
  const MAX_BACKOFF = 16000; // ms

  // Activity/keepalive timers (kept while ws is open)
  let lastActivity = Date.now();
  const LOG_INTERVAL = 30000;
  const PING_INTERVAL = 15000;
  const monitorTimer = setInterval(() => {
    try {
      const age = Date.now() - lastActivity;
      if (age > 60000) {
        console.log('[novnc-proxy] connection idle for %d ms from %s', age, req.socket.remoteAddress);
      }
    } catch (e) {}
  }, LOG_INTERVAL);
  const pingTimer = setInterval(() => {
    try { if (ws && ws.readyState === ws.OPEN) ws.ping(); } catch (e) { console.error('[novnc-proxy] ping error:', e && e.stack || e); }
  }, PING_INTERVAL);

  ws.on('pong', () => { lastActivity = Date.now(); });

  // Buffer outgoing client->VNC messages while disconnected (bounded)
  const messageBuffer = [];
  let bufferedBytes = 0;
  const MAX_BUFFER_BYTES = 1 * 1024 * 1024; // 1MB

  function flushBuffer() {
    if (!vnc || !vnc.writable) return;
    while (messageBuffer.length) {
      const b = messageBuffer.shift();
      bufferedBytes -= b.length;
      try { vnc.write(b); } catch (e) { console.error('[novnc-proxy] flush write error', e && e.stack || e); break; }
    }
  }

  function createVncSocket() {
    if (closing) return;
    if (vnc) try { vnc.destroy(); } catch (e) {}
    vnc = net.connect({ host: VNC_HOST, port: VNC_PORT });

    vnc.on('connect', () => {
      reconnectAttempts = 0;
      lastActivity = Date.now();
      console.log('[novnc-proxy] connected to VNC %s:%s', VNC_HOST, VNC_PORT);
      try { if (typeof vnc.setKeepAlive === 'function') vnc.setKeepAlive(true, 20000); if (typeof vnc.setNoDelay === 'function') vnc.setNoDelay(true); } catch (e) { console.error('[novnc-proxy] failed to configure vnc socket keepalive:', e && e.stack || e); }
      // flush any buffered client frames
      flushBuffer();
    });

    vnc.on('data', (data) => {
      lastActivity = Date.now();
      try {
        if (data && data.length) {
          const prefix = data.slice(0, Math.min(32, data.length)).toString('hex');
          console.log('[novnc-proxy] vnc->ws data len=%d prefix=%s', data.length, prefix);
        }
        if (ws && ws.readyState === ws.OPEN) ws.send(data);
      } catch (e) { console.error('[novnc-proxy] error sending to websocket:', e && e.stack || e); }
    });

    vnc.on('end', () => {
      console.log('[novnc-proxy] VNC socket ended');
    });

    vnc.on('close', (hadError) => {
      console.log('[novnc-proxy] VNC socket closed hadError=%s', !!hadError);
      if (closing) return; // ws already closed
      scheduleReconnect();
    });

    vnc.on('error', (err) => {
      console.error('[novnc-proxy] VNC socket error', err && err.stack || err);
      if (closing) return;
      scheduleReconnect();
    });
  }

  function scheduleReconnect() {
    reconnectAttempts += 1;
    const backoff = Math.min(1000 * Math.pow(2, Math.max(0, reconnectAttempts - 1)), MAX_BACKOFF);
    console.log('[novnc-proxy] scheduling VNC reconnect attempt=%d backoff=%dms', reconnectAttempts, backoff);
    setTimeout(() => {
      if (closing) return;
      console.log('[novnc-proxy] attempting VNC reconnect attempt=%d', reconnectAttempts);
      createVncSocket();
    }, backoff);
  }

  ws.on('message', function(msg) {
    lastActivity = Date.now();
    try {
      const isBuffer = Buffer.isBuffer(msg);
      const buf = isBuffer ? msg : Buffer.from(String(msg), 'utf8');
      console.log('[novnc-proxy] ws->vnc message: type=%s len=%d', isBuffer ? 'Buffer' : typeof msg, buf.length);
      if (vnc && vnc.writable) {
        vnc.write(buf);
      } else {
        // buffer while disconnected, drop oldest if exceeding limit
        messageBuffer.push(buf);
        bufferedBytes += buf.length;
        while (bufferedBytes > MAX_BUFFER_BYTES) {
          const dropped = messageBuffer.shift();
          bufferedBytes -= dropped.length;
          console.log('[novnc-proxy] dropping buffered client data, new bufferedBytes=%d', bufferedBytes);
        }
      }
    } catch (e) { console.error('[novnc-proxy] error handling ws message', e && e.stack || e); }
  });

  const teardown = () => {
    closing = true;
    clearInterval(monitorTimer);
    clearInterval(pingTimer);
    try { if (vnc) vnc.destroy(); } catch (e) {}
  };

  ws.on('close', (code, reason) => {
    console.log('[novnc-proxy] ws closed', code, reason && reason.toString ? reason.toString() : reason);
    teardown();
  });

  ws.on('error', (err) => {
    console.error('[novnc-proxy] ws error', err && err.stack || err);
    teardown();
  });

  // start initial connection
  createVncSocket();
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`novnc-proxy listening on ${PORT}, forwarding to ${VNC_HOST}:${VNC_PORT}`);
});
