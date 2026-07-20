-- Rapportini di lavoro - Schema Supabase/PostgreSQL
-- Versione: 2026-07-20
-- Eseguire nel SQL Editor di un progetto Supabase nuovo.

begin;

create extension if not exists pgcrypto;

create schema if not exists app_private;
revoke all on schema app_private from public;
grant usage on schema app_private to authenticated;

-- -----------------------------------------------------------------------------
-- Tipi enumerati
-- -----------------------------------------------------------------------------

do $$
begin
  create type public.ruolo_utente as enum ('admin', 'operatore');
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type public.tipo_intervento as enum (
    'montaggio_posa',
    'manutenzione_riparazione',
    'sopralluogo',
    'consegna_ritiro',
    'lavorazione_officina',
    'altro'
  );
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type public.stato_rapportino as enum (
    'bozza',
    'inviato',
    'approvato',
    'respinto'
  );
exception
  when duplicate_object then null;
end
$$;

-- -----------------------------------------------------------------------------
-- Tabelle applicative
-- -----------------------------------------------------------------------------

create table if not exists public.utenti (
  id uuid primary key references auth.users (id) on delete cascade,
  nome_cognome text not null check (char_length(trim(nome_cognome)) between 2 and 150),
  email text not null unique,
  ruolo public.ruolo_utente not null default 'operatore',
  attivo boolean not null default true,
  data_creazione timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.clienti (
  id uuid primary key default gen_random_uuid(),
  ragione_sociale text not null check (char_length(trim(ragione_sociale)) between 2 and 200),
  indirizzo text not null,
  referente text,
  telefono text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.rapportini (
  id uuid primary key default gen_random_uuid(),
  dipendente_id uuid not null references public.utenti (id) on delete restrict,
  cliente_id uuid not null references public.clienti (id) on delete restrict,
  luogo text not null check (char_length(trim(luogo)) between 2 and 300),
  rif_appuntamento text,
  tipologia_intervento public.tipo_intervento not null,
  data_ora_inizio timestamptz not null,
  data_ora_fine timestamptz,
  ore_totali numeric(7,2) not null default 0,
  descrizione text not null default '',

  -- I due campi *_url contengono il path dell'oggetto nel bucket privato,
  -- non un URL pubblico. L'app genera URL firmati temporanei quando servono.
  firma_cliente_url text,

  gps_latitudine numeric(9,6),
  gps_longitudine numeric(9,6),
  gps_precisione_metri numeric(8,2),
  gps_rilevato_at timestamptz,

  stato public.stato_rapportino not null default 'bozza',
  nota_amministratore text,
  approvato_da uuid references public.utenti (id) on delete set null,
  approvato_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  versione bigint not null default 1,

  constraint rapportini_intervallo_valido
    check (data_ora_fine is null or data_ora_fine >= data_ora_inizio),
  constraint rapportini_latitudine_valida
    check (gps_latitudine is null or gps_latitudine between -90 and 90),
  constraint rapportini_longitudine_valida
    check (gps_longitudine is null or gps_longitudine between -180 and 180),
  constraint rapportini_precisione_valida
    check (gps_precisione_metri is null or gps_precisione_metri >= 0),
  constraint rapportini_gps_coerente
    check (
      (gps_latitudine is null and gps_longitudine is null)
      or
      (gps_latitudine is not null and gps_longitudine is not null)
    )
);

create table if not exists public.rapportino_foto (
  id uuid primary key default gen_random_uuid(),
  rapportino_id uuid not null references public.rapportini (id) on delete cascade,
  foto_url text not null,
  created_at timestamptz not null default now(),
  constraint rapportino_foto_path_univoco unique (rapportino_id, foto_url)
);

comment on column public.rapportini.versione is
  'Usata per aggiornamenti ottimistici: il client aggiorna solo se la versione remota coincide.';
comment on column public.rapportini.firma_cliente_url is
  'Path privato: <dipendente_uuid>/<rapportino_uuid>/<file>.png.';
comment on column public.rapportino_foto.foto_url is
  'Path privato: <dipendente_uuid>/<rapportino_uuid>/<file>.jpg.';

-- -----------------------------------------------------------------------------
-- Indici
-- -----------------------------------------------------------------------------

create index if not exists idx_utenti_ruolo_attivo
  on public.utenti (ruolo, attivo);
create index if not exists idx_clienti_ragione_sociale
  on public.clienti (ragione_sociale);
create index if not exists idx_rapportini_dipendente_data
  on public.rapportini (dipendente_id, data_ora_inizio desc);
create index if not exists idx_rapportini_cliente_data
  on public.rapportini (cliente_id, data_ora_inizio desc);
create index if not exists idx_rapportini_stato_data
  on public.rapportini (stato, data_ora_inizio desc);
create index if not exists idx_rapportini_updated_at
  on public.rapportini (updated_at);
create index if not exists idx_rapportini_da_approvare
  on public.rapportini (data_ora_inizio desc)
  where stato = 'inviato';
create index if not exists idx_rapportino_foto_rapportino
  on public.rapportino_foto (rapportino_id);

-- -----------------------------------------------------------------------------
-- Funzioni interne e trigger
-- -----------------------------------------------------------------------------

create or replace function app_private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.utenti u
    where u.id = (select auth.uid())
      and u.ruolo = 'admin'
      and u.attivo = true
  );
$$;

revoke all on function app_private.is_admin() from public;
grant execute on function app_private.is_admin() to authenticated;

create or replace function app_private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function app_private.touch_updated_at() from public;

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
  else
    -- Un operatore non può alterare identità, audit o campi amministrativi.
    if (select auth.uid()) is not null and not app_private.is_admin() then
      if new.id is distinct from old.id
        or new.dipendente_id is distinct from old.dipendente_id
        or new.created_at is distinct from old.created_at
        or new.nota_amministratore is distinct from old.nota_amministratore
        or new.approvato_da is distinct from old.approvato_da
        or new.approvato_at is distinct from old.approvato_at then
        raise exception 'Modifica di campi protetti non consentita';
      end if;
    end if;

    new.created_at := old.created_at;
    new.updated_at := now();
    new.versione := old.versione + 1;
  end if;

  if new.data_ora_fine is null then
    new.ore_totali := 0;
  else
    new.ore_totali := round(
      (extract(epoch from (new.data_ora_fine - new.data_ora_inizio)) / 3600.0)::numeric,
      2
    );
  end if;

  -- Una bozza può essere incompleta; un rapportino inviato deve essere chiuso,
  -- descritto e firmato.
  if new.stato in ('inviato', 'approvato') then
    if new.data_ora_fine is null
      or char_length(trim(new.descrizione)) = 0
      or new.firma_cliente_url is null then
      raise exception
        'Per inviare il rapportino servono ora fine, descrizione e firma cliente';
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

create or replace function app_private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.utenti (id, nome_cognome, email, ruolo)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'nome_cognome'), ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Nuovo utente'
    ),
    coalesce(new.email, new.id::text || '@utente.local'),
    'operatore'
  )
  on conflict (id) do update
    set email = excluded.email,
        updated_at = now();

  return new;
end;
$$;

revoke all on function app_private.handle_new_auth_user() from public;

create or replace function app_private.sync_auth_user_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.utenti
  set email = coalesce(new.email, new.id::text || '@utente.local'),
      updated_at = now()
  where id = new.id;

  return new;
end;
$$;

revoke all on function app_private.sync_auth_user_email() from public;

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
  select
    app_private.is_admin()
    or exists (
      select 1
      from public.rapportini r
      where r.dipendente_id = (select auth.uid())
        and r.id::text = (storage.foldername(object_name))[2]
        and (storage.foldername(object_name))[1] = (select auth.uid())::text
        and (
          require_editable = false
          or r.stato in ('bozza', 'respinto')
        )
    );
$$;

revoke all on function app_private.can_access_media_path(text, boolean) from public;
grant execute on function app_private.can_access_media_path(text, boolean) to authenticated;

drop trigger if exists trg_utenti_updated_at on public.utenti;
create trigger trg_utenti_updated_at
before update on public.utenti
for each row execute function app_private.touch_updated_at();

drop trigger if exists trg_clienti_updated_at on public.clienti;
create trigger trg_clienti_updated_at
before update on public.clienti
for each row execute function app_private.touch_updated_at();

drop trigger if exists trg_rapportini_before_write on public.rapportini;
create trigger trg_rapportini_before_write
before insert or update on public.rapportini
for each row execute function app_private.before_write_rapportino();

drop trigger if exists trg_rapportini_auth_user_created on auth.users;
create trigger trg_rapportini_auth_user_created
after insert on auth.users
for each row execute function app_private.handle_new_auth_user();

drop trigger if exists trg_rapportini_auth_email_updated on auth.users;
create trigger trg_rapportini_auth_email_updated
after update of email on auth.users
for each row
when (old.email is distinct from new.email)
execute function app_private.sync_auth_user_email();

-- -----------------------------------------------------------------------------
-- Privilegi SQL: anon non accede ai dati applicativi.
-- -----------------------------------------------------------------------------

revoke all on public.utenti, public.clienti, public.rapportini, public.rapportino_foto
  from anon, authenticated;

grant select on public.utenti, public.clienti, public.rapportini, public.rapportino_foto
  to authenticated;
grant update (nome_cognome, ruolo, attivo) on public.utenti to authenticated;
grant insert, update, delete on public.clienti to authenticated;
grant insert, update, delete on public.rapportini to authenticated;
grant insert, delete on public.rapportino_foto to authenticated;

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------

alter table public.utenti enable row level security;
alter table public.clienti enable row level security;
alter table public.rapportini enable row level security;
alter table public.rapportino_foto enable row level security;

-- utenti
drop policy if exists utenti_select on public.utenti;
create policy utenti_select
on public.utenti
for select
to authenticated
using (id = (select auth.uid()) or app_private.is_admin());

drop policy if exists utenti_admin_update on public.utenti;
create policy utenti_admin_update
on public.utenti
for update
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

-- clienti
drop policy if exists clienti_select on public.clienti;
create policy clienti_select
on public.clienti
for select
to authenticated
using (true);

drop policy if exists clienti_admin_insert on public.clienti;
create policy clienti_admin_insert
on public.clienti
for insert
to authenticated
with check (app_private.is_admin());

drop policy if exists clienti_admin_update on public.clienti;
create policy clienti_admin_update
on public.clienti
for update
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

drop policy if exists clienti_admin_delete on public.clienti;
create policy clienti_admin_delete
on public.clienti
for delete
to authenticated
using (app_private.is_admin());

-- rapportini: l'operatore vede solo i propri; l'admin vede e gestisce tutto.
drop policy if exists rapportini_select on public.rapportini;
create policy rapportini_select
on public.rapportini
for select
to authenticated
using (
  dipendente_id = (select auth.uid())
  or app_private.is_admin()
);

drop policy if exists rapportini_operatore_insert on public.rapportini;
create policy rapportini_operatore_insert
on public.rapportini
for insert
to authenticated
with check (
  dipendente_id = (select auth.uid())
  and stato in ('bozza', 'inviato')
  and approvato_da is null
  and approvato_at is null
  and (
    firma_cliente_url is null
    or firma_cliente_url like ((select auth.uid())::text || '/' || id::text || '/%')
  )
);

drop policy if exists rapportini_operatore_update on public.rapportini;
create policy rapportini_operatore_update
on public.rapportini
for update
to authenticated
using (
  dipendente_id = (select auth.uid())
  and stato in ('bozza', 'respinto')
)
with check (
  dipendente_id = (select auth.uid())
  and stato in ('bozza', 'inviato')
  and approvato_da is null
  and approvato_at is null
  and (
    firma_cliente_url is null
    or firma_cliente_url like ((select auth.uid())::text || '/' || id::text || '/%')
  )
);

drop policy if exists rapportini_operatore_delete_bozza on public.rapportini;
create policy rapportini_operatore_delete_bozza
on public.rapportini
for delete
to authenticated
using (
  dipendente_id = (select auth.uid())
  and stato = 'bozza'
);

drop policy if exists rapportini_admin_insert on public.rapportini;
create policy rapportini_admin_insert
on public.rapportini
for insert
to authenticated
with check (app_private.is_admin());

drop policy if exists rapportini_admin_update on public.rapportini;
create policy rapportini_admin_update
on public.rapportini
for update
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

drop policy if exists rapportini_admin_delete on public.rapportini;
create policy rapportini_admin_delete
on public.rapportini
for delete
to authenticated
using (app_private.is_admin());

-- fotografie
drop policy if exists rapportino_foto_select on public.rapportino_foto;
create policy rapportino_foto_select
on public.rapportino_foto
for select
to authenticated
using (
  app_private.is_admin()
  or exists (
    select 1
    from public.rapportini r
    where r.id = rapportino_id
      and r.dipendente_id = (select auth.uid())
  )
);

drop policy if exists rapportino_foto_operatore_insert on public.rapportino_foto;
create policy rapportino_foto_operatore_insert
on public.rapportino_foto
for insert
to authenticated
with check (
  foto_url like ((select auth.uid())::text || '/' || rapportino_id::text || '/%')
  and exists (
    select 1
    from public.rapportini r
    where r.id = rapportino_id
      and r.dipendente_id = (select auth.uid())
      and r.stato in ('bozza', 'respinto')
  )
);

drop policy if exists rapportino_foto_operatore_delete on public.rapportino_foto;
create policy rapportino_foto_operatore_delete
on public.rapportino_foto
for delete
to authenticated
using (
  exists (
    select 1
    from public.rapportini r
    where r.id = rapportino_id
      and r.dipendente_id = (select auth.uid())
      and r.stato in ('bozza', 'respinto')
  )
);

drop policy if exists rapportino_foto_admin_insert on public.rapportino_foto;
create policy rapportino_foto_admin_insert
on public.rapportino_foto
for insert
to authenticated
with check (app_private.is_admin());

drop policy if exists rapportino_foto_admin_delete on public.rapportino_foto;
create policy rapportino_foto_admin_delete
on public.rapportino_foto
for delete
to authenticated
using (app_private.is_admin());

-- -----------------------------------------------------------------------------
-- Bucket Storage privati e relative policy
-- Path obbligatorio: <dipendente_uuid>/<rapportino_uuid>/<nome_file>
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'rapportini-foto',
    'rapportini-foto',
    false,
    10485760,
    array['image/jpeg', 'image/png']
  ),
  (
    'rapportini-firme',
    'rapportini-firme',
    false,
    2097152,
    array['image/png']
  )
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists rapportini_media_select on storage.objects;
create policy rapportini_media_select
on storage.objects
for select
to authenticated
using (
  bucket_id in ('rapportini-foto', 'rapportini-firme')
  and app_private.can_access_media_path(name, false)
);

drop policy if exists rapportini_media_insert on storage.objects;
create policy rapportini_media_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id in ('rapportini-foto', 'rapportini-firme')
  and app_private.can_access_media_path(name, true)
);

drop policy if exists rapportini_media_update on storage.objects;
create policy rapportini_media_update
on storage.objects
for update
to authenticated
using (
  bucket_id in ('rapportini-foto', 'rapportini-firme')
  and app_private.can_access_media_path(name, true)
)
with check (
  bucket_id in ('rapportini-foto', 'rapportini-firme')
  and app_private.can_access_media_path(name, true)
);

drop policy if exists rapportini_media_delete on storage.objects;
create policy rapportini_media_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id in ('rapportini-foto', 'rapportini-firme')
  and app_private.can_access_media_path(name, true)
);

commit;

-- -----------------------------------------------------------------------------
-- BOOTSTRAP AMMINISTRATORE (eseguire UNA VOLTA dopo aver creato l'utente Auth)
-- Sostituire l'indirizzo e-mail e togliere i due trattini iniziali.
-- -----------------------------------------------------------------------------
-- update public.utenti
-- set ruolo = 'admin'
-- where email = 'admin@azienda.it';
