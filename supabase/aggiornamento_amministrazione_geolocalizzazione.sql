-- ARTE IN FERRO - AMMINISTRAZIONE, CANTIERI E CONTROLLO PRESENZE
-- Aggiornamento incrementale: non elimina dati esistenti.
-- Eseguire nel SQL Editor di Supabase dopo aggiornamento_app_arte_in_ferro.sql.

begin;

do $$ begin
  create type public.modalita_timbratura as enum ('sede', 'cantiere', 'trasferta');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.stato_verifica_timbratura as enum (
    'valida', 'da_verificare', 'rifiutata'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.stato_autorizzazione_ore as enum (
    'da_autorizzare', 'autorizzata', 'rifiutata'
  );
exception when duplicate_object then null; end $$;

alter table public.configurazione_azienda
  add column if not exists gps_latitudine numeric(10,7)
    check (gps_latitudine is null or gps_latitudine between -90 and 90),
  add column if not exists gps_longitudine numeric(10,7)
    check (gps_longitudine is null or gps_longitudine between -180 and 180),
  add column if not exists raggio_presenza_metri integer not null default 200
    check (raggio_presenza_metri between 20 and 5000),
  add column if not exists controllo_gps_presenze boolean not null default false,
  add column if not exists motivo_modifica text;

alter table public.utenti
  add column if not exists motivo_modifica text;

alter table public.dipendente_profili
  add column if not exists motivo_modifica text;

alter table public.clienti
  add column if not exists attivo boolean not null default true,
  add column if not exists motivo_modifica text;

alter table public.rapportini
  add column if not exists motivo_modifica text;

create table if not exists public.cantieri (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references public.clienti(id) on delete restrict,
  nome text not null check (length(trim(nome)) >= 2),
  indirizzo text not null,
  gps_latitudine numeric(10,7) not null check (gps_latitudine between -90 and 90),
  gps_longitudine numeric(10,7) not null check (gps_longitudine between -180 and 180),
  raggio_presenza_metri integer not null default 200
    check (raggio_presenza_metri between 20 and 5000),
  attivo boolean not null default true,
  note text,
  motivo_modifica text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.timbrature
  alter column gps_latitudine drop not null,
  alter column gps_longitudine drop not null,
  add column if not exists cantiere_id uuid references public.cantieri(id) on delete set null,
  add column if not exists modalita public.modalita_timbratura not null default 'sede',
  add column if not exists trasferta_motivo text,
  add column if not exists stato_verifica public.stato_verifica_timbratura
    not null default 'valida',
  add column if not exists distanza_riferimento_metri numeric(10,2),
  add column if not exists forzata_da_amministratore boolean not null default false,
  add column if not exists autorizzata_da uuid references public.utenti(id) on delete set null,
  add column if not exists autorizzata_at timestamptz;

create table if not exists public.presenze_revisioni (
  id uuid primary key default gen_random_uuid(),
  dipendente_id uuid not null references public.utenti(id) on delete restrict,
  giorno date not null,
  stato public.stato_autorizzazione_ore not null default 'da_autorizzare',
  ore_autorizzate numeric(6,2)
    check (ore_autorizzate is null or ore_autorizzate between 0 and 24),
  nota_amministratore text,
  motivo_modifica text not null,
  autorizzata_da uuid not null references public.utenti(id) on delete restrict,
  autorizzata_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (dipendente_id, giorno)
);

create table if not exists public.registro_modifiche_amministrative (
  id bigint generated always as identity primary key,
  tabella text not null,
  record_id text,
  operazione text not null check (operazione in ('INSERT', 'UPDATE', 'DELETE')),
  valore_precedente jsonb,
  valore_nuovo jsonb,
  motivo text not null,
  modificata_da uuid references public.utenti(id) on delete set null,
  modificata_at timestamptz not null default now()
);

create index if not exists idx_cantieri_cliente_attivo
  on public.cantieri(cliente_id, attivo, nome);
create index if not exists idx_timbrature_cantiere_data
  on public.timbrature(cantiere_id, registrata_at desc);
create index if not exists idx_timbrature_verifica
  on public.timbrature(stato_verifica, registrata_at desc);
create index if not exists idx_presenze_revisioni_giorno
  on public.presenze_revisioni(giorno desc, stato);
create index if not exists idx_registro_modifiche_data
  on public.registro_modifiche_amministrative(modificata_at desc);

create or replace function app_private.distanza_metri(
  lat1 numeric,
  lon1 numeric,
  lat2 numeric,
  lon2 numeric
)
returns numeric
language sql
immutable
set search_path = pg_catalog
as $$
  select case
    when lat1 is null or lon1 is null or lat2 is null or lon2 is null then null
    else 6371000 * 2 * asin(sqrt(
      power(sin(radians((lat2 - lat1)::double precision) / 2), 2) +
      cos(radians(lat1::double precision)) * cos(radians(lat2::double precision)) *
      power(sin(radians((lon2 - lon1)::double precision) / 2), 2)
    ))
  end::numeric;
$$;

create or replace function app_private.valida_posizione_timbratura()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, app_private
as $$
declare
  controllo_attivo boolean;
  lat_riferimento numeric;
  lon_riferimento numeric;
  raggio integer;
  distanza numeric;
begin
  -- L'amministratore che timbra per se stesso usa le stesse regole GPS di un
  -- dipendente. Il percorso privilegiato vale solo per una forzatura esplicita.
  if app_private.is_admin() and (
    coalesce(new.forzata_da_amministratore, false)
    or new.dipendente_id is distinct from auth.uid()
  ) then
    new.forzata_da_amministratore := true;
    new.modificata_da := auth.uid();
    if new.stato_verifica = 'da_verificare' and new.autorizzata_da is not null then
      new.stato_verifica := 'valida';
    end if;
    return new;
  end if;

  if new.dipendente_id is distinct from auth.uid() then
    raise exception using errcode = '42501',
      message = 'Non puoi registrare la presenza per un altro dipendente.';
  end if;

  if new.gps_latitudine is null or new.gps_longitudine is null then
    raise exception using errcode = '23514',
      message = 'La posizione è obbligatoria per registrare la presenza.';
  end if;

  new.forzata_da_amministratore := false;
  new.modificata_da := null;
  new.autorizzata_da := null;
  new.autorizzata_at := null;

  if new.modalita = 'trasferta' then
    if length(trim(coalesce(new.trasferta_motivo, ''))) < 3 then
      raise exception using errcode = '23514',
        message = 'Indica il motivo della presenza in trasferta.';
    end if;
    new.cantiere_id := null;
    new.stato_verifica := 'da_verificare';
    new.distanza_riferimento_metri := null;
    return new;
  end if;

  new.trasferta_motivo := null;
  select controllo_gps_presenze into controllo_attivo
  from public.configurazione_azienda where id = true;

  if new.modalita = 'cantiere' then
    if new.cantiere_id is null then
      raise exception using errcode = '23514',
        message = 'Seleziona il cantiere prima di registrare la presenza.';
    end if;
    select c.gps_latitudine, c.gps_longitudine, c.raggio_presenza_metri
      into lat_riferimento, lon_riferimento, raggio
    from public.cantieri c
    where c.id = new.cantiere_id and c.attivo;
    if not found then
      raise exception using errcode = '23514', message = 'Cantiere non disponibile.';
    end if;
  else
    new.cantiere_id := null;
    select c.gps_latitudine, c.gps_longitudine, c.raggio_presenza_metri
      into lat_riferimento, lon_riferimento, raggio
    from public.configurazione_azienda c where c.id = true;
  end if;

  distanza := app_private.distanza_metri(
    new.gps_latitudine, new.gps_longitudine, lat_riferimento, lon_riferimento
  );
  new.distanza_riferimento_metri := distanza;

  if coalesce(controllo_attivo, false) then
    if distanza is null then
      raise exception using errcode = '23514',
        message = 'La posizione della sede o del cantiere non è configurata.';
    end if;
    if distanza > raggio then
      raise exception using errcode = '23514',
        message = format(
          'Sei fuori dall’area autorizzata (%s metri). Seleziona Presenza in trasferta.',
          round(distanza)
        );
    end if;
  end if;

  new.stato_verifica := case
    when distanza is null then 'da_verificare'::public.stato_verifica_timbratura
    else 'valida'::public.stato_verifica_timbratura
  end;
  return new;
end;
$$;

drop trigger if exists trg_timbrature_posizione on public.timbrature;
create trigger trg_timbrature_posizione
before insert on public.timbrature
for each row execute function app_private.valida_posizione_timbratura();

-- Gli operatori mantengono il controllo anti-doppia timbratura. Un amministratore
-- può invece inserire una registrazione storica o forzata, sempre tracciata.
create or replace function app_private.valida_sequenza_timbratura()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, app_private
as $$
declare ultimo_tipo public.tipo_timbratura;
begin
  if app_private.is_admin() and coalesce(new.forzata_da_amministratore, false) then
    return new;
  end if;
  select t.tipo into ultimo_tipo
  from public.timbrature t
  where t.dipendente_id = new.dipendente_id
  order by t.registrata_at desc, t.created_at desc
  limit 1;
  if ultimo_tipo = new.tipo then
    raise exception using
      errcode = '23514',
      message = case when new.tipo = 'entrata'
        then 'Hai già registrato l’entrata. Registra prima l’uscita.'
        else 'Hai già registrato l’uscita. Registra prima una nuova entrata.' end;
  end if;
  return new;
end;
$$;

create or replace function app_private.registra_audit_amministrativo()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, app_private
as $$
declare
  vecchio jsonb;
  nuovo jsonb;
  ragione text;
  identificativo text;
begin
  if not app_private.is_admin() then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;
  vecchio := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  nuovo := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  ragione := coalesce(
    nullif(trim(nuovo ->> 'motivo_modifica'), ''),
    nullif(trim(vecchio ->> 'motivo_modifica'), ''),
    'Operazione amministrativa'
  );
  identificativo := coalesce(
    nuovo ->> 'id', vecchio ->> 'id',
    nuovo ->> 'dipendente_id', vecchio ->> 'dipendente_id'
  );
  insert into public.registro_modifiche_amministrative (
    tabella, record_id, operazione, valore_precedente, valore_nuovo,
    motivo, modificata_da
  ) values (
    tg_table_name, identificativo, tg_op, vecchio, nuovo, ragione, auth.uid()
  );
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists trg_cantieri_updated_at on public.cantieri;
create trigger trg_cantieri_updated_at before update on public.cantieri
for each row execute function app_private.touch_updated_at();
drop trigger if exists trg_presenze_revisioni_updated_at on public.presenze_revisioni;
create trigger trg_presenze_revisioni_updated_at before update on public.presenze_revisioni
for each row execute function app_private.touch_updated_at();

drop trigger if exists trg_audit_utenti on public.utenti;
create trigger trg_audit_utenti after insert or update or delete on public.utenti
for each row execute function app_private.registra_audit_amministrativo();
drop trigger if exists trg_audit_configurazione_azienda on public.configurazione_azienda;
create trigger trg_audit_configurazione_azienda
after insert or update or delete on public.configurazione_azienda
for each row execute function app_private.registra_audit_amministrativo();
drop trigger if exists trg_audit_dipendente_profili on public.dipendente_profili;
create trigger trg_audit_dipendente_profili
after insert or update or delete on public.dipendente_profili
for each row execute function app_private.registra_audit_amministrativo();
drop trigger if exists trg_audit_clienti on public.clienti;
create trigger trg_audit_clienti after insert or update or delete on public.clienti
for each row execute function app_private.registra_audit_amministrativo();
drop trigger if exists trg_audit_cantieri on public.cantieri;
create trigger trg_audit_cantieri after insert or update or delete on public.cantieri
for each row execute function app_private.registra_audit_amministrativo();
drop trigger if exists trg_audit_timbrature on public.timbrature;
create trigger trg_audit_timbrature after insert or update or delete on public.timbrature
for each row execute function app_private.registra_audit_amministrativo();
drop trigger if exists trg_audit_rapportini on public.rapportini;
create trigger trg_audit_rapportini after insert or update or delete on public.rapportini
for each row execute function app_private.registra_audit_amministrativo();
drop trigger if exists trg_audit_presenze_revisioni on public.presenze_revisioni;
create trigger trg_audit_presenze_revisioni
after insert or update or delete on public.presenze_revisioni
for each row execute function app_private.registra_audit_amministrativo();

alter table public.cantieri enable row level security;
alter table public.presenze_revisioni enable row level security;
alter table public.registro_modifiche_amministrative enable row level security;

grant select on public.cantieri, public.presenze_revisioni,
  public.registro_modifiche_amministrative to authenticated;
grant insert, update, delete on public.cantieri, public.presenze_revisioni
  to authenticated;
grant update (nome_cognome, ruolo, attivo, motivo_modifica)
  on public.utenti to authenticated;
grant usage, select on sequence public.registro_modifiche_amministrative_id_seq
  to authenticated;

drop policy if exists cantieri_select on public.cantieri;
create policy cantieri_select on public.cantieri for select to authenticated
using (attivo or app_private.is_admin());
drop policy if exists cantieri_admin_all on public.cantieri;
create policy cantieri_admin_all on public.cantieri for all to authenticated
using (app_private.is_admin()) with check (app_private.is_admin());

drop policy if exists presenze_revisioni_select on public.presenze_revisioni;
create policy presenze_revisioni_select on public.presenze_revisioni for select to authenticated
using (dipendente_id = auth.uid() or app_private.is_admin());
drop policy if exists presenze_revisioni_admin_all on public.presenze_revisioni;
create policy presenze_revisioni_admin_all on public.presenze_revisioni for all to authenticated
using (app_private.is_admin()) with check (app_private.is_admin());

drop policy if exists registro_modifiche_admin_select
  on public.registro_modifiche_amministrative;
create policy registro_modifiche_admin_select
on public.registro_modifiche_amministrative for select to authenticated
using (app_private.is_admin());

create or replace view public.v_timbrature_amministrazione
with (security_invoker = true)
as
select
  t.id,
  t.dipendente_id,
  u.nome_cognome,
  t.tipo,
  t.registrata_at,
  t.gps_latitudine,
  t.gps_longitudine,
  t.gps_precisione_metri,
  t.luogo,
  t.nota,
  t.modalita,
  t.trasferta_motivo,
  t.stato_verifica,
  t.distanza_riferimento_metri,
  t.forzata_da_amministratore,
  t.cantiere_id,
  c.nome as cantiere_nome,
  cl.ragione_sociale as cliente_nome,
  t.mezzo_id,
  t.modificata_da,
  t.motivo_modifica,
  t.created_at,
  t.updated_at
from public.timbrature t
join public.utenti u on u.id = t.dipendente_id
left join public.cantieri c on c.id = t.cantiere_id
left join public.clienti cl on cl.id = c.cliente_id;

create or replace view public.v_presenze_giornaliere
with (security_invoker = true)
as
with riepilogo as (
  select
    t.dipendente_id,
    u.nome_cognome,
    (t.registrata_at at time zone 'Europe/Rome')::date as giorno,
    min(t.registrata_at) filter (where t.tipo = 'entrata') as prima_entrata,
    max(t.registrata_at) filter (where t.tipo = 'uscita') as ultima_uscita,
    bool_or(t.stato_verifica = 'da_verificare') as contiene_trasferta_da_verificare,
    bool_or(t.stato_verifica = 'rifiutata') as contiene_timbratura_rifiutata
  from public.timbrature t
  join public.utenti u on u.id = t.dipendente_id
  group by t.dipendente_id, u.nome_cognome,
    (t.registrata_at at time zone 'Europe/Rome')::date
), calcolo as (
  select r.*,
    case when r.prima_entrata is null or r.ultima_uscita is null then null
      else round((extract(epoch from (r.ultima_uscita - r.prima_entrata)) / 3600)::numeric, 2)
    end as ore_calcolate
  from riepilogo r
)
select
  c.dipendente_id,
  c.nome_cognome,
  c.giorno,
  c.prima_entrata,
  c.ultima_uscita,
  c.ore_calcolate as ore_totali,
  case when c.ore_calcolate is null then null
    else greatest(0, c.ore_calcolate - cfg.ore_ordinarie_giornaliere)
  end as ore_straordinarie,
  coalesce(pr.stato, 'da_autorizzare'::public.stato_autorizzazione_ore) as stato_ore,
  pr.ore_autorizzate,
  pr.nota_amministratore,
  c.contiene_trasferta_da_verificare,
  c.contiene_timbratura_rifiutata
from calcolo c
cross join public.configurazione_azienda cfg
left join public.presenze_revisioni pr
  on pr.dipendente_id = c.dipendente_id and pr.giorno = c.giorno;

grant select on public.v_timbrature_amministrazione,
  public.v_presenze_giornaliere to authenticated;

commit;

select 'Aggiornamento amministrazione e geolocalizzazione pronto' as esito;
