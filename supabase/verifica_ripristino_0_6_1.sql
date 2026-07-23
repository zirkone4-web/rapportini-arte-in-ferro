-- Verifica ripristino Arte In Ferro 0.6.1
select
  piattaforma,
  versione_corrente,
  versione_minima,
  aggiornamento_obbligatorio,
  store_url
from public.configurazione_app
order by piattaforma;

select
  tablename,
  policyname,
  cmd
from pg_policies
where schemaname = 'public'
  and tablename in (
    'rapportini',
    'rapportino_collaboratori',
    'rapportino_foto',
    'richieste_materiale',
    'richiesta_materiale_righe',
    'configurazione_app'
  )
order by tablename, policyname;

select
  routine_schema,
  routine_name
from information_schema.routines
where routine_schema = 'app_private'
  and routine_name in (
    'is_admin',
    'is_rapportino_owner',
    'can_access_rapportino',
    'can_access_media_path',
    'before_write_rapportino'
  )
order by routine_name;

select
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'comunicazione_destinatari'
  ) as comunicazioni_realtime_ancora_attive;

select
  (select count(*) from public.utenti) as utenti,
  (select count(*) from public.clienti) as clienti,
  (select count(*) from public.rapportini) as rapportini,
  (select count(*) from public.rapportino_collaboratori) as assegnazioni;
