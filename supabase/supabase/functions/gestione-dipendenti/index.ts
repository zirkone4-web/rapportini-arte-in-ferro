import { createClient } from 'npm:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const authorization = request.headers.get('Authorization') ?? ''
    if (!authorization.startsWith('Bearer ')) return json({ error: 'Accesso richiesto' }, 401)

    const url = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const token = authorization.slice('Bearer '.length)

    const callerClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    })
    const { data: authData, error: authError } = await callerClient.auth.getUser(token)
    if (authError || !authData.user) return json({ error: 'Sessione non valida' }, 401)

    const { data: caller } = await callerClient
      .from('utenti')
      .select('ruolo,attivo')
      .eq('id', authData.user.id)
      .single()
    if (!caller?.attivo || caller.ruolo !== 'admin') return json({ error: 'Operazione riservata' }, 403)

    const body = await request.json()
    const admin = createClient(url, serviceKey, { auth: { persistSession: false } })

    if (body.action === 'create') {
      const email = `${body.email ?? ''}`.trim().toLowerCase()
      const fullName = `${body.nome_cognome ?? ''}`.trim()
      const password = `${body.password ?? ''}`
      if (!email.includes('@') || fullName.length < 3 || password.length < 10) {
        return json({ error: 'Nome, email o password temporanea non validi' }, 400)
      }
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { nome_cognome: fullName, ruolo: 'operatore' },
      })
      if (error) return json({ error: error.message }, 400)
      await admin.from('utenti').update({
        nome_cognome: fullName,
        ruolo: 'operatore',
        attivo: true,
      }).eq('id', data.user.id)
      await admin.from('dipendente_profili').upsert({
        dipendente_id: data.user.id,
        telefono: emptyToNull(body.telefono),
        mansione: emptyToNull(body.mansione),
        reparto: emptyToNull(body.reparto),
        data_assunzione: emptyToNull(body.data_assunzione),
      })
      return json({ id: data.user.id, email, nome_cognome: fullName })
    }

    if (body.action === 'set_active') {
      const id = `${body.id ?? ''}`
      const active = body.attivo === true
      if (!id) return json({ error: 'Dipendente mancante' }, 400)
      const { error } = await admin.auth.admin.updateUserById(id, {
        ban_duration: active ? 'none' : '876000h',
      })
      if (error) return json({ error: error.message }, 400)
      await admin.from('utenti').update({ attivo: active }).eq('id', id)
      return json({ id, attivo: active })
    }

    if (body.action === 'temporary_password') {
      const id = `${body.id ?? ''}`
      const password = `${body.password ?? ''}`
      if (!id || password.length < 10) return json({ error: 'Password non valida' }, 400)
      const { error } = await admin.auth.admin.updateUserById(id, { password })
      if (error) return json({ error: error.message }, 400)
      return json({ id, updated: true })
    }

    return json({ error: 'Azione non riconosciuta' }, 400)
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Errore interno' }, 500)
  }
})

function emptyToNull(value: unknown) {
  const text = `${value ?? ''}`.trim()
  return text.length === 0 ? null : text
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}
