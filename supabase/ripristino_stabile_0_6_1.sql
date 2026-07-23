-- Arte In Ferro Lascari - Ripristino stabile Supabase 0.6.1
-- Non cancella rapportini, clienti, presenze, allegati o utenti.
-- Eseguire una sola volta nel SQL Editor del progetto Supabase.

begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

create schema if not exists app_private;
revoke all on schema app_private from public;
grant usage on schema app_private to authenticated;

alter table public.rapportini
  add column if not exists pianificato boolean not null default false,
  add column if not exists pianificato_da uuid references public.utenti(id) on delete set null,
  add column if not exists pianificato_at timestamptz,
  add column if not exists note_pianificazione text,
  add column if not exists esito_lavoro text not null default 'da_eseguire',
  add column if not exists nota_lavoro_incompleto text;

create table if not exists public.rapportino_collaboratori (
  rapportino_id uuid not null references public.rapportini(id) on delete cascade,
  dipendente_id uuid not null references public.utenti(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (rapportino_id, dipendente_id)
);

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

create or replace function app_private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = off
as $$
  select exists (
    select 1
    from public.utenti u
    where u.id = (select auth.uid())
      and u.ruolo = 'admin'
      and u.attivo = true
  );
$$;

create or replace function app_private.is_rapportino_owner(target_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = off
as $$
  select exists (
    select 1
    from public.rapportini r
    where r.id = target_id
      and r.dipendente_id = (select auth.uid())
  );
$$;

create or replace function app_private.can_access_rapportino(target_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = off
as $$
  select app_private.is_admin()
    or app_private.is_rapportino_owner(target_id)
    or exists (
      select 1
      from public.rapportino_collaboratori rc
      where rc.rapportino_id = target_id
        and rc.dipendente_id = (select auth.uid())
    );
$$;

revoke all on function app_private.is_admin() from public;
revoke all on function app_private.is_rapportino_owner(uuid) from public;
revoke all on function app_private.can_access_rapportino(uuid) from public;
grant execute on function app_private.is_admin() to authenticated;
grant execute on function app_private.is_rapportino_owner(uuid) to authenticated;
grant execute on function app_private.can_access_rapportino(uuid) to authenticated;

create or replace function app_private.before_write_rapportino()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.updated_at := new.created_at;
    new.versione := 1;

    if new.pianificato then
      new.pianificato_at := coalesce(new.pianificato_at, now());
      new.pianificato_da := coalesce(new.pianificato_da, (select auth.uid()));
    end if;
  else
    if (to_jsonb(new) - array['updated_at', 'versione'])
       is not distinct from
       (to_jsonb(old) - array['updated_at', 'versione']) then
      return old;
    end if;

    if (select auth.uid()) is not null and not app_private.is_admin() then
      if new.id is distinct from old.id
        or new.dipendente_id is distinct from old.dipendente_id
        or new.created_at is distinct from old.created_at
        or new.updated_at is distinct from old.updated_at
        or new.versione is distinct from old.versione
        or new.nota_amministratore is distinct from old.nota_amministratore
        or new.approvato_da is distinct from old.approvato_da
        or new.approvato_at is distinct from old.approvato_at
        or new.pianificato is distinct from old.pianificato
        or new.pianificato_da is distinct from old.pianificato_da
        or new.pianificato_at is distinct from old.pianificato_at
        or new.note_pianificazione is distinct from old.note_pianificazione then
        raise exception 'Modifica di campi protetti non consentita'
          using errcode = '42501';
      end if;
    end if;

    new.created_at := old.created_at;
    new.updated_at := now();
    new.versione := old.versione + 1;

    if new.pianificato and new.pianificato_at is null then
      new.pianificato_at := now();
      new.pianificato_da := coalesce(new.pianificato_da, (select auth.uid()));
    end if;
  end if;

  if new.data_ora_fine is null then
    new.ore_totali := 0;
  else
    new.ore_totali := round(
      (extract(epoch from (new.data_ora_fine - new.data_ora_inizio)) / 3600.0)::numeric,
      2
    );
  end if;

  if new.stato in ('inviato', 'approvato') then
    if new.data_ora_fine is null
      or char_length(trim(new.descrizione)) = 0
      or new.firma_cliente_url is null then
      raise exception 'Per inviare il rapportino servono ora fine, descrizione e firma cliente';
    end if;
  end if;

  if new.stato = 'approvato' then
    new.approvato_at := coalesce(new.approvato_at, now());
    new.approvato_da := coalesce(new.approvato_da, (select auth.uid()));
  else
    new.approvato_at := null;
    new.approvato_da := null;
  end if;

  return new;
end;
$$;

revoke all on function app_private.before_write_rapportino() from public;
drop trigger if exists trg_rapportini_before_write on public.rapportini;
create trigger trg_rapportini_before_write
before insert or update on public.rapportini
for each row execute function app_private.before_write_rapportino();

create or replace function app_private.can_access_media_path(
  object_name text,
  require_editable boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = off
as $$
  select exists (
    select 1
    from public.rapportini r
    where r.id::text = (storage.foldername(object_name))[2]
      and app_private.can_access_rapportino(r.id)
      and (
        require_editable = false
        or (
          (storage.foldername(object_name))[1] = (select auth.uid())::text
          and r.stato in ('bozza', 'respinto')
        )
      )
  );
$$;

revoke all on function app_private.can_access_media_path(text, boolean) from public;
grant execute on function app_private.can_access_media_path(text, boolean) to authenticated;

alter table public.rapportini enable row level security;
alter table public.rapportino_collaboratori enable row level security;
alter table public.rapportino_foto enable row level security;
alter table public.richieste_materiale enable row level security;
alter table public.richiesta_materiale_righe enable row level security;
alter table public.configurazione_app enable row level security;

do $$
declare p record;
begin
  for p in
    select tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'rapportini', 'rapportino_collaboratori', 'rapportino_foto',
        'richieste_materiale', 'richiesta_materiale_righe', 'configurazione_app'
      )
  loop
    execute format('drop policy if exists %I on public.%I', p.policyname, p.tablename);
  end loop;
end
$$;

revoke all on public.rapportini, public.rapportino_collaboratori,
  public.rapportino_foto, public.richieste_materiale,
  public.richiesta_materiale_righe, public.configurazione_app
from anon;

grant select, insert, update, delete on public.rapportini to authenticated;
grant select, insert, delete on public.rapportino_collaboratori to authenticated;
grant select, insert, delete on public.rapportino_foto to authenticated;
grant select, insert, update, delete on public.richieste_materiale to authenticated;
grant select, insert, update, delete on public.richiesta_materiale_righe to authenticated;
grant select, update on public.configurazione_app to authenticated;

create policy rapportini_select on public.rapportini
for select to authenticated
using (app_private.can_access_rapportino(id));

create policy rapportini_insert on public.rapportini
for insert to authenticated
with check (
  app_private.is_admin()
  or (
    dipendente_id = (select auth.uid())
    and stato in ('bozza', 'inviato')
    and coalesce(pianificato, false) = false
    and approvato_da is null
    and approvato_at is null
  )
);

create policy rapportini_update on public.rapportini
for update to authenticated
using (
  app_private.is_admin()
  or (app_private.can_access_rapportino(id) and stato in ('bozza', 'respinto'))
)
with check (
  app_private.is_admin()
  or (
    app_private.can_access_rapportino(id)
    and stato in ('bozza', 'inviato')
    and approvato_da is null
    and approvato_at is null
  )
);

create policy rapportini_delete on public.rapportini
for delete to authenticated
using (
  app_private.is_admin()
  or (app_private.is_rapportino_owner(id) and stato = 'bozza')
);

create policy rapportino_collaboratori_select on public.rapportino_collaboratori
for select to authenticated
using (
  app_private.is_admin()
  or dipendente_id = (select auth.uid())
  or app_private.is_rapportino_owner(rapportino_id)
);

create policy rapportino_collaboratori_insert on public.rapportino_collaboratori
for insert to authenticated
with check (
  app_private.is_admin()
  or app_private.is_rapportino_owner(rapportino_id)
);

create policy rapportino_collaboratori_delete on public.rapportino_collaboratori
for delete to authenticated
using (
  app_private.is_admin()
  or app_private.is_rapportino_owner(rapportino_id)
);

create policy rapportino_foto_select on public.rapportino_foto
for select to authenticated
using (app_private.can_access_rapportino(rapportino_id));

create policy rapportino_foto_insert on public.rapportino_foto
for insert to authenticated
with check (
  foto_url like ((select auth.uid())::text || '/' || rapportino_id::text || '/%')
  and app_private.can_access_rapportino(rapportino_id)
  and exists (
    select 1 from public.rapportini r
    where r.id = rapportino_id and r.stato in ('bozza', 'respinto')
  )
);

create policy rapportino_foto_delete on public.rapportino_foto
for delete to authenticated
using (
  foto_url like ((select auth.uid())::text || '/' || rapportino_id::text || '/%')
  and app_private.can_access_rapportino(rapportino_id)
  and exists (
    select 1 from public.rapportini r
    where r.id = rapportino_id and r.stato in ('bozza', 'respinto')
  )
);

create policy richieste_materiale_select on public.richieste_materiale
for select to authenticated
using (dipendente_id = (select auth.uid()) or app_private.is_admin());

create policy richieste_materiale_insert on public.richieste_materiale
for insert to authenticated
with check (dipendente_id = (select auth.uid()) or app_private.is_admin());

create policy richieste_materiale_update on public.richieste_materiale
for update to authenticated
using ((dipendente_id = (select auth.uid()) and stato = 'richiesta') or app_private.is_admin())
with check (dipendente_id = (select auth.uid()) or app_private.is_admin());

create policy richieste_materiale_delete on public.richieste_materiale
for delete to authenticated
using ((dipendente_id = (select auth.uid()) and stato = 'richiesta') or app_private.is_admin());

create policy richiesta_materiale_righe_select on public.richiesta_materiale_righe
for select to authenticated
using (exists (
  select 1 from public.richieste_materiale r
  where r.id = richiesta_id
    and (r.dipendente_id = (select auth.uid()) or app_private.is_admin())
));

create policy richiesta_materiale_righe_insert on public.richiesta_materiale_righe
for insert to authenticated
with check (exists (
  select 1 from public.richieste_materiale r
  where r.id = richiesta_id
    and (r.dipendente_id = (select auth.uid()) or app_private.is_admin())
));

create policy richiesta_materiale_righe_update on public.richiesta_materiale_righe
for update to authenticated
using (exists (
  select 1 from public.richieste_materiale r
  where r.id = richiesta_id
    and ((r.dipendente_id = (select auth.uid()) and r.stato = 'richiesta') or app_private.is_admin())
))
with check (exists (
  select 1 from public.richieste_materiale r
  where r.id = richiesta_id
    and (r.dipendente_id = (select auth.uid()) or app_private.is_admin())
));

create policy richiesta_materiale_righe_delete on public.richiesta_materiale_righe
for delete to authenticated
using (exists (
  select 1 from public.richieste_materiale r
  where r.id = richiesta_id
    and ((r.dipendente_id = (select auth.uid()) and r.stato = 'richiesta') or app_private.is_admin())
));

create policy configurazione_app_select on public.configurazione_app
for select to authenticated using (true);

create policy configurazione_app_update on public.configurazione_app
for update to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

drop policy if exists rapportini_media_select on storage.objects;
drop policy if exists rapportini_media_insert on storage.objects;
drop policy if exists rapportini_media_update on storage.objects;
drop policy if exists rapportini_media_delete on storage.objects;

create policy rapportini_media_select on storage.objects
for select to authenticated
using (
  bucket_id in ('rapportini-foto', 'rapportini-firme')
  and app_private.can_access_media_path(name, false)
);

create policy rapportini_media_insert on storage.objects
for insert to authenticated
with check (
  bucket_id in ('rapportini-foto', 'rapportini-firme')
  and app_private.can_access_media_path(name, true)
);

create policy rapportini_media_update on storage.objects
for update to authenticated
using (
  bucket_id in ('rapportini-foto', 'rapportini-firme')
  and app_private.can_access_media_path(name, true)
)
with check (
  bucket_id in ('rapportini-foto', 'rapportini-firme')
  and app_private.can_access_media_path(name, true)
);

create policy rapportini_media_delete on storage.objects
for delete to authenticated
using (
  bucket_id in ('rapportini-foto', 'rapportini-firme')
  and app_private.can_access_media_path(name, true)
);

do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'comunicazione_destinatari'
  ) then
    alter publication supabase_realtime drop table public.comunicazione_destinatari;
  end if;
exception
  when undefined_object then null;
end
$$;

insert into public.configurazione_app
  (piattaforma, versione_corrente, versione_minima, store_url,
   aggiornamento_obbligatorio, messaggio)
values
  ('android', '0.6.1', '0.4.0',
   'https://play.google.com/store/apps/details?id=com.arteinferrolascari.myapp',
   false, 'È disponibile la release stabile 0.6.1 di Arte In Ferro.'),
  ('ios', '0.6.1', '0.4.0',
   'https://zirkone4-web.github.io/rapportini-arte-in-ferro/',
   false, 'È disponibile la release stabile 0.6.1 di Arte In Ferro.')
on conflict (piattaforma) do update
set versione_corrente = excluded.versione_corrente,
    versione_minima = excluded.versione_minima,
    store_url = excluded.store_url,
    aggiornamento_obbligatorio = excluded.aggiornamento_obbligatorio,
    messaggio = excluded.messaggio,
    updated_at = now();

commit;

select
  'RIPRISTINO_COMPLETATO' as esito,
  (select count(*) from public.rapportini) as rapportini_conservati,
  (select count(*) from public.clienti) as clienti_conservati,
  (select count(*) from public.utenti) as utenti_conservati;
