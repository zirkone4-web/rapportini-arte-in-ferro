-- Arte In Ferro - Pianificazione squadre, rapportini assegnati e materiali
-- Versione 0.6.0 - eseguire una sola volta nel SQL Editor di Supabase.

begin;

alter table public.rapportini
  add column if not exists pianificato boolean not null default false,
  add column if not exists pianificato_da uuid references public.utenti(id) on delete set null,
  add column if not exists pianificato_at timestamptz,
  add column if not exists note_pianificazione text,
  add column if not exists esito_lavoro text not null default 'da_eseguire',
  add column if not exists nota_lavoro_incompleto text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'rapportini_esito_lavoro_valido'
  ) then
    alter table public.rapportini add constraint rapportini_esito_lavoro_valido
      check (esito_lavoro in ('da_eseguire', 'completato', 'da_completare', 'materiale_mancante'));
  end if;
end
$$;

alter table public.comunicazioni
  add column if not exists tipo text not null default 'generica',
  add column if not exists cliente_id uuid references public.clienti(id) on delete set null,
  add column if not exists rapportino_id uuid references public.rapportini(id) on delete set null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'comunicazioni_tipo_valido'
  ) then
    alter table public.comunicazioni add constraint comunicazioni_tipo_valido
      check (tipo in ('generica', 'cliente', 'rapportino', 'materiali', 'sistema'));
  end if;
end
$$;

create table if not exists public.richieste_materiale (
  id uuid primary key default gen_random_uuid(),
  dipendente_id uuid not null references public.utenti(id) on delete restrict,
  rapportino_id uuid references public.rapportini(id) on delete set null,
  categoria text not null check (categoria in ('materia_prima', 'consumo')),
  stato text not null default 'richiesta'
    check (stato in ('richiesta', 'presa_in_carico', 'ordinata', 'evasa', 'annullata')),
  note text,
  motivo_modifica text,
  creata_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.richiesta_materiale_righe (
  id uuid primary key default gen_random_uuid(),
  richiesta_id uuid not null references public.richieste_materiale(id) on delete cascade,
  descrizione text not null check (length(trim(descrizione)) >= 2),
  quantita numeric(10,2) not null check (quantita > 0),
  unita text not null default 'pz' check (length(trim(unita)) between 1 and 20),
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.configurazione_app (
  piattaforma text primary key check (piattaforma in ('android', 'ios')),
  versione_corrente text not null,
  versione_minima text not null,
  store_url text not null,
  aggiornamento_obbligatorio boolean not null default false,
  messaggio text,
  updated_at timestamptz not null default now()
);

insert into public.configurazione_app
  (piattaforma, versione_corrente, versione_minima, store_url, aggiornamento_obbligatorio, messaggio)
values
  ('android', '0.4.0', '0.3.0',
   'https://play.google.com/store/apps/details?id=com.arteinferrolascari.myapp',
   false, 'È disponibile una nuova versione di Arte In Ferro.'),
  ('ios', '0.4.0', '0.3.0',
   'https://apps.apple.com/', false,
   'È disponibile una nuova versione di Arte In Ferro.')
on conflict (piattaforma) do nothing;

create index if not exists idx_rapportini_pianificati_data
  on public.rapportini(data_ora_inizio, pianificato) where pianificato;
create index if not exists idx_richieste_materiale_stato_categoria
  on public.richieste_materiale(stato, categoria, creata_at desc);
create index if not exists idx_richieste_materiale_dipendente
  on public.richieste_materiale(dipendente_id, creata_at desc);
create index if not exists idx_richiesta_materiale_righe_richiesta
  on public.richiesta_materiale_righe(richiesta_id);

drop trigger if exists trg_richieste_materiale_updated_at on public.richieste_materiale;
create trigger trg_richieste_materiale_updated_at
before update on public.richieste_materiale
for each row execute function app_private.touch_updated_at();

drop trigger if exists trg_configurazione_app_updated_at on public.configurazione_app;
create trigger trg_configurazione_app_updated_at
before update on public.configurazione_app
for each row execute function app_private.touch_updated_at();

create or replace function app_private.can_access_rapportino(target_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app_private.is_admin()
    or exists (
      select 1 from public.rapportini r
      where r.id = target_id and r.dipendente_id = (select auth.uid())
    )
    or exists (
      select 1 from public.rapportino_collaboratori rc
      where rc.rapportino_id = target_id and rc.dipendente_id = (select auth.uid())
    );
$$;

revoke all on function app_private.can_access_rapportino(uuid) from public;
grant execute on function app_private.can_access_rapportino(uuid) to authenticated;

drop policy if exists rapportini_select on public.rapportini;
create policy rapportini_select on public.rapportini
for select to authenticated
using (app_private.can_access_rapportino(id));

drop policy if exists rapportini_operatore_update on public.rapportini;
create policy rapportini_operatore_update on public.rapportini
for update to authenticated
using (app_private.can_access_rapportino(id) and stato in ('bozza', 'respinto'))
with check (app_private.can_access_rapportino(id) and stato in ('bozza', 'inviato'));

create or replace function app_private.can_access_media_path(
  object_name text,
  require_editable boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app_private.is_admin()
    or (
      (storage.foldername(object_name))[1] = (select auth.uid())::text
      and exists (
        select 1 from public.rapportini r
        where r.id::text = (storage.foldername(object_name))[2]
          and app_private.can_access_rapportino(r.id)
          and (require_editable = false or r.stato in ('bozza', 'respinto'))
      )
    );
$$;

revoke all on function app_private.can_access_media_path(text, boolean) from public;
grant execute on function app_private.can_access_media_path(text, boolean) to authenticated;

-- Anche un compagno di squadra può vedere e aggiungere fotografie al lavoro
-- assegnato. Il percorso mantiene sempre l'ID del telefono che ha caricato il file.
drop policy if exists rapportino_foto_select on public.rapportino_foto;
create policy rapportino_foto_select on public.rapportino_foto
for select to authenticated
using (app_private.can_access_rapportino(rapportino_id));

drop policy if exists rapportino_foto_operatore_insert on public.rapportino_foto;
create policy rapportino_foto_operatore_insert on public.rapportino_foto
for insert to authenticated
with check (
  foto_url like ((select auth.uid())::text || '/' || rapportino_id::text || '/%')
  and app_private.can_access_rapportino(rapportino_id)
  and exists (
    select 1 from public.rapportini r
    where r.id = rapportino_id and r.stato in ('bozza', 'respinto')
  )
);

drop policy if exists rapportino_foto_operatore_delete on public.rapportino_foto;
create policy rapportino_foto_operatore_delete on public.rapportino_foto
for delete to authenticated
using (
  foto_url like ((select auth.uid())::text || '/' || rapportino_id::text || '/%')
  and app_private.can_access_rapportino(rapportino_id)
  and exists (
    select 1 from public.rapportini r
    where r.id = rapportino_id and r.stato in ('bozza', 'respinto')
  )
);

alter table public.richieste_materiale enable row level security;
alter table public.richiesta_materiale_righe enable row level security;
alter table public.configurazione_app enable row level security;

grant select, insert on public.richieste_materiale,
  public.richiesta_materiale_righe to authenticated;
grant update, delete on public.richieste_materiale,
  public.richiesta_materiale_righe to authenticated;
grant select on public.configurazione_app to authenticated;
grant update on public.configurazione_app to authenticated;

drop policy if exists richieste_materiale_select on public.richieste_materiale;
create policy richieste_materiale_select on public.richieste_materiale
for select to authenticated
using (dipendente_id = auth.uid() or app_private.is_admin());

drop policy if exists richieste_materiale_insert on public.richieste_materiale;
create policy richieste_materiale_insert on public.richieste_materiale
for insert to authenticated
with check (dipendente_id = auth.uid() or app_private.is_admin());

drop policy if exists richieste_materiale_owner_update on public.richieste_materiale;
create policy richieste_materiale_owner_update on public.richieste_materiale
for update to authenticated
using ((dipendente_id = auth.uid() and stato = 'richiesta') or app_private.is_admin())
with check (dipendente_id = auth.uid() or app_private.is_admin());

drop policy if exists richieste_materiale_owner_delete on public.richieste_materiale;
create policy richieste_materiale_owner_delete on public.richieste_materiale
for delete to authenticated
using ((dipendente_id = auth.uid() and stato = 'richiesta') or app_private.is_admin());

drop policy if exists richiesta_materiale_righe_select on public.richiesta_materiale_righe;
create policy richiesta_materiale_righe_select on public.richiesta_materiale_righe
for select to authenticated
using (exists (
  select 1 from public.richieste_materiale r
  where r.id = richiesta_id and (r.dipendente_id = auth.uid() or app_private.is_admin())
));

drop policy if exists richiesta_materiale_righe_insert on public.richiesta_materiale_righe;
create policy richiesta_materiale_righe_insert on public.richiesta_materiale_righe
for insert to authenticated
with check (exists (
  select 1 from public.richieste_materiale r
  where r.id = richiesta_id and (r.dipendente_id = auth.uid() or app_private.is_admin())
));

drop policy if exists richiesta_materiale_righe_update on public.richiesta_materiale_righe;
create policy richiesta_materiale_righe_update on public.richiesta_materiale_righe
for update to authenticated
using (exists (
  select 1 from public.richieste_materiale r
  where r.id = richiesta_id and (r.dipendente_id = auth.uid() or app_private.is_admin())
))
with check (exists (
  select 1 from public.richieste_materiale r
  where r.id = richiesta_id and (r.dipendente_id = auth.uid() or app_private.is_admin())
));

drop policy if exists richiesta_materiale_righe_delete on public.richiesta_materiale_righe;
create policy richiesta_materiale_righe_delete on public.richiesta_materiale_righe
for delete to authenticated
using (exists (
  select 1 from public.richieste_materiale r
  where r.id = richiesta_id and (r.dipendente_id = auth.uid() or app_private.is_admin())
));

drop policy if exists configurazione_app_select on public.configurazione_app;
create policy configurazione_app_select on public.configurazione_app
for select to authenticated using (true);

drop policy if exists configurazione_app_admin_update on public.configurazione_app;
create policy configurazione_app_admin_update on public.configurazione_app
for update to authenticated using (app_private.is_admin()) with check (app_private.is_admin());

-- Le comunicazioni vengono ascoltate in tempo reale dall'app quando è aperta.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'comunicazione_destinatari'
  ) then
    alter publication supabase_realtime add table public.comunicazione_destinatari;
  end if;
end
$$;

commit;

select 'Pianificazione squadre, rapportini assegnati e materiali attivati' as esito;
