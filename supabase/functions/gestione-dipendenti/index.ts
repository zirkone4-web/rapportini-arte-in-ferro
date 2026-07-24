import { createClient } from 'npm:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const authorization = request.headers.get('Authorization') ?? ''
    if (!authorization.startsWith('Bearer ')) return fail('Accesso richiesto', 401)

    const url = Deno.env.get('SUPABASE_URL')
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!url || !anonKey || !serviceKey) {
      return fail('Configurazione server Supabase incompleta', 503)
    }

    const token = authorization.slice('Bearer '.length)
    const callerClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    })
    const { data: authData, error: authError } = await callerClient.auth.getUser(token)
    if (authError || !authData.user) return fail('Sessione non valida', 401)

    const { data: caller, error: callerError } = await callerClient
      .from('utenti')
      .select('ruolo,attivo')
      .eq('id', authData.user.id)
      .single()
    if (callerError) return fail(`Profilo amministratore non leggibile: ${callerError.message}`, 403)
    if (!caller?.attivo || caller.ruolo !== 'admin') {
      return fail('Operazione riservata agli amministratori', 403)
    }

    const body = await request.json()
    const admin = createClient(url, serviceKey, { auth: { persistSession: false } })

    if (body.action === 'create') {
      const email = `${body.email ?? ''}`.trim().toLowerCase()
      const fullName = `${body.nome_cognome ?? ''}`.trim()
      const password = `${body.password ?? ''}`
      if (!email.includes('@') || fullName.length < 3 || password.length < 10) {
        return fail('Nome, email o password temporanea non validi', 400)
      }

      const { data, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { nome_cognome: fullName, ruolo: 'operatore' },
      })
      if (error || !data.user) return fail(error?.message ?? 'Utente non creato', 400)

      const { error: userError } = await admin.from('utenti').upsert({
        id: data.user.id,
        email,
        nome_cognome: fullName,
        ruolo: 'operatore',
        attivo: true,
      }, { onConflict: 'id' })

      if (userError) {
        await admin.auth.admin.deleteUser(data.user.id)
        return fail(`Profilo applicativo non creato: ${userError.message}`, 400)
      }

      const { error: profileError } = await admin.from('dipendente_profili').upsert({
        dipendente_id: data.user.id,
        telefono: emptyToNull(body.telefono),
        mansione: emptyToNull(body.mansione),
        reparto: emptyToNull(body.reparto),
        data_assunzione: emptyToNull(body.data_assunzione),
      }, { onConflict: 'dipendente_id' })

      if (profileError) {
        await admin.from('utenti').delete().eq('id', data.user.id)
        await admin.auth.admin.deleteUser(data.user.id)
        return fail(`Profilo dipendente non creato: ${profileError.message}`, 400)
      }

      return json({
        id: data.user.id,
        email,
        nome_cognome: fullName,
        message: 'Dipendente e accesso creati correttamente',
      })
    }

    if (body.action === 'set_active') {
      const id = `${body.id ?? ''}`
      const active = body.attivo === true
      if (!id) return fail('Dipendente mancante', 400)

      const { error } = await admin.auth.admin.updateUserById(id, {
        ban_duration: active ? 'none' : '876000h',
      })
      if (error) return fail(error.message, 400)

      const { error: profileError } = await admin
        .from('utenti')
        .update({ attivo: active })
        .eq('id', id)
      if (profileError) return fail(profileError.message, 400)

      return json({ id, attivo: active, message: 'Stato accesso aggiornato' })
    }

    if (body.action === 'temporary_password') {
      const id = `${body.id ?? ''}`
      const password = `${body.password ?? ''}`
      if (!id || password.length < 10) return fail('Password non valida', 400)

      const { error } = await admin.auth.admin.updateUserById(id, { password })
      if (error) return fail(error.message, 400)
      return json({ id, updated: true, message: 'Password temporanea aggiornata' })
    }

    return fail('Azione non riconosciuta', 400)
  } catch (error) {
    return fail(error instanceof Error ? error.message : 'Errore interno', 500)
  }
})

function emptyToNull(value: unknown) {
  const text = `${value ?? ''}`.trim()
  return text.length === 0 ? null : text
}

function fail(message: string, status: number) {
  return json({ error: message, message }, status)
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}
