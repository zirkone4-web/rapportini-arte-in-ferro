import { createClient } from 'npm:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
}

type ServiceAccount = {
  client_email: string
  private_key: string
  project_id: string
  token_uri?: string
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const authorization = request.headers.get('Authorization') ?? ''
    if (!authorization.startsWith('Bearer ')) return json({ error: 'Accesso richiesto' }, 401)

    const url = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountJson) return json({ error: 'Firebase non configurato' }, 503)

    const callerClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    })
    const token = authorization.slice('Bearer '.length)
    const { data: authData, error: authError } = await callerClient.auth.getUser(token)
    if (authError || !authData.user) return json({ error: 'Sessione non valida' }, 401)

    const { data: caller } = await callerClient
      .from('utenti')
      .select('ruolo,attivo')
      .eq('id', authData.user.id)
      .single()
    if (!caller?.attivo || caller.ruolo !== 'admin') {
      return json({ error: 'Operazione riservata' }, 403)
    }

    const body = await request.json()
    const recipientIds = Array.isArray(body.recipient_ids)
      ? [...new Set(body.recipient_ids.map((value: unknown) => `${value}`.trim()).filter(Boolean))]
      : []
    const title = `${body.title ?? ''}`.trim()
    const messageBody = `${body.body ?? ''}`.trim()
    if (recipientIds.length === 0 || title.length < 2 || messageBody.length < 2) {
      return json({ error: 'Destinatari o messaggio mancanti' }, 400)
    }

    const admin = createClient(url, serviceKey, { auth: { persistSession: false } })
    const { data: devices, error: deviceError } = await admin
      .from('dispositivi_push')
      .select('token')
      .in('dipendente_id', recipientIds)
      .eq('attivo', true)
    if (deviceError) return json({ error: deviceError.message }, 400)
    if (!devices?.length) return json({ sent: 0, unavailable: recipientIds.length })

    const serviceAccount = JSON.parse(serviceAccountJson) as ServiceAccount
    const accessToken = await createGoogleAccessToken(serviceAccount)
    const payloadData = Object.fromEntries(
      Object.entries(body.data ?? {})
        .filter(([, value]) => value !== null && value !== undefined)
        .map(([key, value]) => [key, `${value}`]),
    )
    const results = await Promise.all(devices.map(async (device: { token: string }) => {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: device.token,
              notification: { title, body: messageBody },
              data: payloadData,
              android: {
                priority: 'high',
                notification: { sound: 'default' },
              },
              apns: { payload: { aps: { sound: 'default' } } },
            },
          }),
        },
      )
      return response.ok
    }))

    return json({ sent: results.filter(Boolean).length, total: results.length })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Errore interno' }, 500)
  }
})

async function createGoogleAccessToken(serviceAccount: ServiceAccount) {
  const now = Math.floor(Date.now() / 1000)
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const claims = base64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }))
  const unsigned = `${header}.${claims}`
  const keyBytes = pemToBytes(serviceAccount.private_key)
  const key = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  )
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`
  const response = await fetch(serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })
  const result = await response.json()
  if (!response.ok || !result.access_token) {
    throw new Error(result.error_description ?? 'Autorizzazione Firebase non riuscita')
  }
  return `${result.access_token}`
}

function pemToBytes(value: string) {
  const base64 = value
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  return Uint8Array.from(atob(base64), (character) => character.charCodeAt(0))
}

function base64Url(value: string | Uint8Array) {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}
