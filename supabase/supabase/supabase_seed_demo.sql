-- Dati dimostrativi idempotenti per provare subito l'app.
-- Eseguire DOPO supabase_rapportini_schema.sql.

begin;

insert into public.clienti (
  id,
  ragione_sociale,
  indirizzo,
  referente,
  telefono
)
values
  (
    '10000000-0000-4000-8000-000000000001',
    'Condominio Belvedere',
    'Via Roma 10, Palermo',
    'Mario Bianchi',
    '+39 091 0000001'
  ),
  (
    '10000000-0000-4000-8000-000000000002',
    'Edilizia Mediterranea S.r.l.',
    'Via delle Industrie 25, Termini Imerese',
    'Giuseppe Verdi',
    '+39 091 0000002'
  ),
  (
    '10000000-0000-4000-8000-000000000003',
    'Hotel Costa Azzurra',
    'Lungomare 8, Cefalù',
    'Anna Russo',
    '+39 0921 000003'
  )
on conflict (id) do update
set ragione_sociale = excluded.ragione_sociale,
    indirizzo = excluded.indirizzo,
    referente = excluded.referente,
    telefono = excluded.telefono;

commit;

-- Dopo aver creato l'account amministratore da Authentication > Users:
-- update public.utenti set ruolo = 'admin' where email = 'LA-TUA-EMAIL';
