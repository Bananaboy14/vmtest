const express = require('express');
const expressWs = require('express-ws');
const net = require('net');
const path = require('path');
const fs = require('fs');

// Enhanced configuration for ultimate persistence
const NOVNC_DIR = process.env.NOVNC_DIR || '/opt/noVNC';
const PORT = parseInt(process.env.NOVNC_PORT || '8080', 10);
const VNC_HOST = process.env.VNC_HOST || '127.0.0.1';
const VNC_PORT = parseInt(process.env.VNC_PORT || '5901', 10);

// Persistence configuration
const MAX_RECONNECT_ATTEMPTS = 999;
const BASE_RECONNECT_DELAY = 1000;
const MAX_RECONNECT_DELAY = 30000;
const HEALTH_CHECK_INTERVAL = 5000;
const UPTIME_LOG_INTERVAL = 60000;

// Global state tracking
const serverStats = {
    startTime: Date.now(),
    connections: 0,
    totalConnections: 0,
    reconnectionAttempts: 0,
    lastHealthCheck: Date.now(),
    vncServerHealthy: false,
    errors: []
};

const app = express();
expressWs(app);

// Enhanced logging
function logWithTimestamp(level, message, ...args) {
  const timestamp = new Date().toISOString();
  const fullMessage = `[${timestamp}] [${level}] [novnc-proxy] ${message}`;
  console.log(fullMessage, ...args);
  
  try {
    const logEntry = `${fullMessage} ${args.map(arg => 
      typeof arg === 'object' ? JSON.stringify(arg) : String(arg)
    ).join(' ')}\n`;
    fs.appendFileSync('/var/log/novnc_proxy.log', logEntry);
  } catch (e) {
    // Ignore file logging errors
  }
}

// Health monitoring
function checkVncServerHealth() {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    const timeout = setTimeout(() => {
      socket.destroy();
      resolve(false);
    }, 3000);
    
    socket.connect(VNC_PORT, VNC_HOST, () => {
      clearTimeout(timeout);
      socket.destroy();
      resolve(true);
    });
    
    socket.on('error', () => {
      clearTimeout(timeout);
      resolve(false);
    });
  });
}

async function performHealthCheck() {
  const healthy = await checkVncServerHealth();
  serverStats.vncServerHealthy = healthy;
  serverStats.lastHealthCheck = Date.now();
  
  if (!healthy) {
    logWithTimestamp('WARN', 'VNC server health check failed');
    serverStats.errors.push({
      timestamp: Date.now(),
      error: 'VNC server unreachable'
    });
    if (serverStats.errors.length > 10) {
      serverStats.errors = serverStats.errors.slice(-10);
    }
  }
  
  return healthy;
}

// Start health monitoring
setInterval(performHealthCheck, HEALTH_CHECK_INTERVAL);

// Log server statistics periodically
setInterval(() => {
  const uptime = Date.now() - serverStats.startTime;
  const uptimeMinutes = Math.floor(uptime / 60000);
  logWithTimestamp('INFO', `Server stats: uptime=${uptimeMinutes}m, active_connections=${serverStats.connections}, total_connections=${serverStats.totalConnections}, reconnect_attempts=${serverStats.reconnectionAttempts}, vnc_healthy=${serverStats.vncServerHealthy}`);
}, UPTIME_LOG_INTERVAL);

// Enhanced middleware
app.use((req, res, next) => {
  try {
    logWithTimestamp('HTTP', `${req.method} ${req.url}`, {
      ip: req.ip || req.connection.remoteAddress,
      userAgent: req.get('User-Agent'),
      host: req.get('Host')
    });
  } catch (e) {
    logWithTimestamp('ERROR', 'Request logging failed', e.message);
  }
  next();
});

app.use((err, req, res, next) => {
  logWithTimestamp('ERROR', 'HTTP error', {
    error: err.message,
    url: req.url,
    method: req.method,
    ip: req.ip
  });
  
  serverStats.errors.push({
    timestamp: Date.now(),
    error: err.message,
    url: req.url
  });
  
  try { 
    res.status(502).json({
      error: 'Proxy error',
      message: 'WebSocket proxy encountered an error',
      timestamp: new Date().toISOString()
    });
  } catch (e) {
    logWithTimestamp('ERROR', 'Failed to send error response', e.message);
  }
});

// Health endpoint
app.get('/health', (req, res) => {
  const uptime = Date.now() - serverStats.startTime;
  const health = {
    status: serverStats.vncServerHealthy ? 'healthy' : 'degraded',
    uptime: uptime,
    uptimeHuman: `${Math.floor(uptime / 60000)}m ${Math.floor((uptime % 60000) / 1000)}s`,
    connections: serverStats.connections,
    totalConnections: serverStats.totalConnections,
    reconnectionAttempts: serverStats.reconnectionAttempts,
    vncServerHealthy: serverStats.vncServerHealthy,
    lastHealthCheck: new Date(serverStats.lastHealthCheck).toISOString(),
    errors: serverStats.errors.slice(-5),
    version: 'Ultimate Persistent VNC Proxy v1.0'
  };
  
  res.json(health);
});

// Statistics endpoint
app.get('/stats', (req, res) => {
  res.json(serverStats);
});

// Redirect root to enhanced VNC client
app.get('/', (req, res) => res.redirect('/vnc.html'));

app.get('/vnc.html', (req, res) => {
  const enhancedVncPath = '/workspaces/vmtest/vnc.html';
  if (fs.existsSync(enhancedVncPath)) {
    res.sendFile(enhancedVncPath);
  } else {
    res.sendFile(path.join(NOVNC_DIR, 'vnc.html'));
  }
});

// Serve static noVNC files
app.use('/', express.static(NOVNC_DIR));

// Enhanced WebSocket proxy with ultimate persistence
app.ws('/websockify', function(ws, req) {
  serverStats.connections++;
  serverStats.totalConnections++;
  const connectionId = serverStats.totalConnections;
  
  logWithTimestamp('INFO', `WebSocket connection #${connectionId} established from ${req.socket.remoteAddress}`);

  let vnc = null;
  let closing = false;
  let reconnectAttempts = 0;
  const connectionStartTime = Date.now();

  let lastActivity = Date.now();
  let bytesReceived = 0;
  let bytesSent = 0;
  
  const monitorTimer = setInterval(() => {
    try {
      const age = Date.now() - lastActivity;
      const uptime = Date.now() - connectionStartTime;
      const uptimeMinutes = Math.floor(uptime / 60000);
      
      logWithTimestamp('DEBUG', `Connection #${connectionId} stats: uptime=${uptimeMinutes}m, idle=${Math.floor(age/1000)}s, bytes_rx=${bytesReceived}, bytes_tx=${bytesSent}, reconnect_attempts=${reconnectAttempts}`);
    } catch (e) {
      logWithTimestamp('ERROR', `Monitor timer error for connection #${connectionId}`, e.message);
    }
  }, 30000);
  
  const pingTimer = setInterval(() => {
    try { 
      if (ws && ws.readyState === ws.OPEN) {
        ws.ping();
      }
    } catch (e) { 
      logWithTimestamp('ERROR', `Ping error for connection #${connectionId}`, e.message);
    }
  }, 15000);

  ws.on('pong', () => { 
    lastActivity = Date.now();
  });

  // Enhanced message buffering
  const messageBuffer = [];
  let bufferedBytes = 0;
  const MAX_BUFFER_BYTES = 2 * 1024 * 1024;

  function flushBuffer() {
    if (!vnc || !vnc.writable || messageBuffer.length === 0) return;
    
    let flushedMessages = 0;
    while (messageBuffer.length > 0) {
      const b = messageBuffer.shift();
      bufferedBytes -= b.length;
      try { 
        vnc.write(b);
        flushedMessages++;
      } catch (e) { 
        logWithTimestamp('ERROR', `Buffer flush error for connection #${connectionId}`, e.message);
        break;
      }
    }
    
    if (flushedMessages > 0) {
      logWithTimestamp('INFO', `Flushed ${flushedMessages} buffered messages for connection #${connectionId}`);
    }
  }

  function createVncSocket() {
    if (closing) return;
    
    if (vnc) {
      try { vnc.destroy(); } catch (e) {}
      vnc = null;
    }
    
    reconnectAttempts++;
    serverStats.reconnectionAttempts++;
    
    if (reconnectAttempts > MAX_RECONNECT_ATTEMPTS) {
      logWithTimestamp('ERROR', `Connection #${connectionId} exceeded maximum reconnection attempts (${MAX_RECONNECT_ATTEMPTS})`);
      return;
    }
    
    logWithTimestamp('INFO', `Creating VNC socket for connection #${connectionId}, attempt ${reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS}`);
    
    vnc = net.connect({ host: VNC_HOST, port: VNC_PORT });

    vnc.on('connect', () => {
      const connectionTime = Date.now() - connectionStartTime;
      logWithTimestamp('INFO', `VNC connection #${connectionId} established (attempt ${reconnectAttempts}, time=${connectionTime}ms)`);
      
      lastActivity = Date.now();
      
      try { 
        if (typeof vnc.setKeepAlive === 'function') vnc.setKeepAlive(true, 20000);
        if (typeof vnc.setNoDelay === 'function') vnc.setNoDelay(true);
      } catch (e) { 
        logWithTimestamp('ERROR', `Failed to configure VNC socket for connection #${connectionId}`, e.message);
      }
      
      flushBuffer();
    });

    vnc.on('data', (data) => {
      lastActivity = Date.now();
      bytesReceived += data.length;
      
      try {
        if (ws && ws.readyState === ws.OPEN) {
          ws.send(data);
          bytesSent += data.length;
        }
      } catch (e) { 
        logWithTimestamp('ERROR', `Error sending VNC data to WebSocket #${connectionId}`, e.message);
      }
    });

    vnc.on('end', () => {
      logWithTimestamp('INFO', `VNC socket ended for connection #${connectionId}`);
    });

    vnc.on('close', (hadError) => {
      logWithTimestamp('INFO', `VNC socket closed for connection #${connectionId}, hadError=${!!hadError}`);
      if (closing) return;
      scheduleReconnect();
    });

    vnc.on('error', (err) => {
      logWithTimestamp('ERROR', `VNC socket error for connection #${connectionId}`, err.message);
      if (closing) return;
      scheduleReconnect();
    });
  }

  function scheduleReconnect() {
    if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
      logWithTimestamp('ERROR', `Connection #${connectionId} exceeded maximum reconnection attempts`);
      return;
    }
    
    const backoff = Math.min(
      BASE_RECONNECT_DELAY * Math.pow(2, Math.max(0, reconnectAttempts - 1)), 
      MAX_RECONNECT_DELAY
    );
    
    logWithTimestamp('INFO', `Scheduling VNC reconnect for connection #${connectionId}: attempt=${reconnectAttempts + 1}/${MAX_RECONNECT_ATTEMPTS}, backoff=${backoff}ms`);
    
    setTimeout(() => {
      if (closing) return;
      createVncSocket();
    }, backoff);
  }

  ws.on('message', function(msg) {
    lastActivity = Date.now();
    try {
      const isBuffer = Buffer.isBuffer(msg);
      const buf = isBuffer ? msg : Buffer.from(String(msg), 'utf8');
      
      if (vnc && vnc.writable) {
        vnc.write(buf);
      } else {
        messageBuffer.push(buf);
        bufferedBytes += buf.length;
        while (bufferedBytes > MAX_BUFFER_BYTES) {
          const dropped = messageBuffer.shift();
          bufferedBytes -= dropped.length;
          logWithTimestamp('WARN', `Dropping buffered client data for connection #${connectionId}, bufferedBytes=${bufferedBytes}`);
        }
      }
    } catch (e) { 
      logWithTimestamp('ERROR', `Error handling WebSocket message for connection #${connectionId}`, e.message);
    }
  });

  const teardown = () => {
    closing = true;
    serverStats.connections--;
    clearInterval(monitorTimer);
    clearInterval(pingTimer);
    try { if (vnc) vnc.destroy(); } catch (e) {}
    
    const sessionTime = Date.now() - connectionStartTime;
    logWithTimestamp('INFO', `Connection #${connectionId} closed after ${Math.floor(sessionTime/1000)}s, ${reconnectAttempts} reconnection attempts`);
  };

  ws.on('close', (code, reason) => {
    logWithTimestamp('INFO', `WebSocket #${connectionId} closed: code=${code}, reason=${reason && reason.toString ? reason.toString() : reason}`);
    teardown();
  });

  ws.on('error', (err) => {
    logWithTimestamp('ERROR', `WebSocket #${connectionId} error`, err.message);
    teardown();
  });

  // Start initial connection
  createVncSocket();
});

app.listen(PORT, '0.0.0.0', () => {
  logWithTimestamp('INFO', `Ultimate Persistent VNC Proxy listening on port ${PORT}, forwarding to ${VNC_HOST}:${VNC_PORT}`);
  logWithTimestamp('INFO', `Health endpoint available at /health`);
  logWithTimestamp('INFO', `Statistics endpoint available at /stats`);
});
