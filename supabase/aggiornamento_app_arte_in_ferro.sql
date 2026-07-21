-- APP ARTE IN FERRO - MODULI AZIENDALI
-- Puo essere rilanciato in sicurezza nel SQL Editor di Supabase.
-- Mantiene intatti utenti, clienti e rapportini gia esistenti.

begin;

create extension if not exists pgcrypto;

do $$ begin
  create type public.tipo_timbratura as enum ('entrata', 'uscita');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.stato_anomalia as enum ('aperta', 'in_lavorazione', 'risolta', 'annullata');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.tipo_anomalia as enum (
    'sicurezza', 'mezzo', 'attrezzatura', 'cantiere', 'materiale', 'qualita', 'altro'
  );
exception when duplicate_object then null; end $$;

create table if not exists public.configurazione_azienda (
  id boolean primary key default true check (id),
  ragione_sociale text not null default 'Arte in Ferro Lascari S.r.l.',
  partita_iva text,
  codice_fiscale text,
  indirizzo text,
  comune text,
  provincia text,
  cap text,
  email text,
  pec text,
  telefono_principale text,
  sito_web text,
  logo_url text,
  ore_ordinarie_giornaliere numeric(4,2) not null default 8
    check (ore_ordinarie_giornaliere > 0 and ore_ordinarie_giornaliere <= 24),
  tolleranza_minuti integer not null default 5 check (tolleranza_minuti between 0 and 120),
  updated_at timestamptz not null default now()
);

insert into public.configurazione_azienda (id)
values (true)
on conflict (id) do nothing;

create table if not exists public.contatti_azienda (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (length(trim(nome)) >= 2),
  ruolo_reparto text not null,
  telefono text,
  email text,
  tipo text not null default 'collaboratore'
    check (tipo in ('ufficio', 'collaboratore', 'emergenza', 'sicurezza')),
  ordine integer not null default 0,
  visibile_operatori boolean not null default true,
  attivo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.mezzi (
  id uuid primary key default gen_random_uuid(),
  targa text not null unique,
  descrizione text not null,
  marca text,
  modello text,
  km_attuali integer check (km_attuali is null or km_attuali >= 0),
  attivo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.timbrature (
  id uuid primary key default gen_random_uuid(),
  dipendente_id uuid not null references public.utenti(id) on delete restrict,
  tipo public.tipo_timbratura not null,
  registrata_at timestamptz not null,
  ricevuta_server_at timestamptz not null default now(),
  gps_latitudine numeric(10,7) not null check (gps_latitudine between -90 and 90),
  gps_longitudine numeric(10,7) not null check (gps_longitudine between -180 and 180),
  gps_precisione_metri numeric(8,2) check (gps_precisione_metri is null or gps_precisione_metri >= 0),
  luogo text,
  nota text,
  modificata_da uuid references public.utenti(id) on delete set null,
  motivo_modifica text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.rapportino_collaboratori (
  rapportino_id uuid not null references public.rapportini(id) on delete cascade,
  dipendente_id uuid not null references public.utenti(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (rapportino_id, dipendente_id)
);

create table if not exists public.rifornimenti (
  id uuid primary key default gen_random_uuid(),
  dipendente_id uuid not null references public.utenti(id) on delete restrict,
  mezzo_id uuid not null references public.mezzi(id) on delete restrict,
  data_ora timestamptz not null,
  km integer not null check (km >= 0),
  litri numeric(8,2) not null check (litri > 0),
  importo numeric(10,2) check (importo is null or importo >= 0),
  distributore text,
  ricevuta_url text,
  gps_latitudine numeric(10,7) check (gps_latitudine is null or gps_latitudine between -90 and 90),
  gps_longitudine numeric(10,7) check (gps_longitudine is null or gps_longitudine between -180 and 180),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.anomalie (
  id uuid primary key default gen_random_uuid(),
  segnalata_da uuid not null references public.utenti(id) on delete restrict,
  tipo public.tipo_anomalia not null,
  stato public.stato_anomalia not null default 'aperta',
  titolo text not null check (length(trim(titolo)) >= 3),
  descrizione text not null check (length(trim(descrizione)) >= 3),
  mezzo_id uuid references public.mezzi(id) on delete set null,
  rapportino_id uuid references public.rapportini(id) on delete set null,
  luogo text,
  foto_url text,
  gps_latitudine numeric(10,7) check (gps_latitudine is null or gps_latitudine between -90 and 90),
  gps_longitudine numeric(10,7) check (gps_longitudine is null or gps_longitudine between -180 and 180),
  nota_risoluzione text,
  risolta_da uuid references public.utenti(id) on delete set null,
  risolta_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Profilo amministrativo del dipendente. L'account Auth e public.utenti
-- continuano a essere creati automaticamente dal trigger gia installato.
create table if not exists public.dipendente_profili (
  dipendente_id uuid primary key references public.utenti(id) on delete cascade,
  telefono text,
  mansione text,
  reparto text,
  data_assunzione date,
  data_cessazione date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (data_cessazione is null or data_assunzione is null or data_cessazione >= data_assunzione)
);

-- Corsi, patentini, visite/idoneita e incarichi di sicurezza.
-- Il dipendente puo leggere i propri record autorizzati, mai modificarli.
create table if not exists public.dipendente_documenti (
  id uuid primary key default gen_random_uuid(),
  dipendente_id uuid not null references public.utenti(id) on delete cascade,
  categoria text not null check (categoria in (
    'corso', 'patentino', 'visita_medica', 'incarico_sicurezza', 'altro'
  )),
  titolo text not null check (length(trim(titolo)) >= 2),
  ente_rilascio text,
  numero_documento text,
  data_rilascio date,
  data_scadenza date,
  esito_idoneita text,
  prescrizioni_visibili text,
  documento_url text,
  visibile_dipendente boolean not null default true,
  attivo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (data_scadenza is null or data_rilascio is null or data_scadenza >= data_rilascio)
);

create table if not exists public.scadenze_mezzi (
  id uuid primary key default gen_random_uuid(),
  mezzo_id uuid not null references public.mezzi(id) on delete cascade,
  tipo text not null check (tipo in (
    'assicurazione', 'revisione', 'bollo', 'tagliando', 'manutenzione',
    'verifica_gru', 'tachigrafo', 'altro'
  )),
  descrizione text not null,
  fornitore_ente text,
  numero_documento text,
  data_inizio date,
  data_scadenza date not null,
  documento_url text,
  completata boolean not null default false,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.certificazioni_azienda (
  id uuid primary key default gen_random_uuid(),
  categoria text not null check (categoria in (
    'iso_9001', 'en_1090', 'iso_3834', 'rina', 'white_list',
    'qualifica_saldatura', 'taratura', 'autorizzazione', 'altro'
  )),
  titolo text not null,
  ente_rilascio text,
  numero_certificato text,
  responsabile_id uuid references public.utenti(id) on delete set null,
  data_rilascio date,
  data_scadenza date,
  prossima_sorveglianza date,
  documento_url text,
  attiva boolean not null default true,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Token notifiche: un dipendente puo registrare e rimuovere solo i propri dispositivi.
create table if not exists public.dispositivi_push (
  id uuid primary key default gen_random_uuid(),
  dipendente_id uuid not null references public.utenti(id) on delete cascade,
  token text not null unique,
  piattaforma text not null check (piattaforma in ('android', 'ios', 'windows')),
  nome_dispositivo text,
  attivo boolean not null default true,
  ultimo_accesso_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.comunicazioni (
  id uuid primary key default gen_random_uuid(),
  creata_da uuid not null references public.utenti(id) on delete restrict,
  titolo text not null check (length(trim(titolo)) >= 2),
  messaggio text not null check (length(trim(messaggio)) >= 2),
  priorita text not null default 'normale'
    check (priorita in ('normale', 'importante', 'urgente')),
  allegato_url text,
  richiede_conferma boolean not null default false,
  pubblicata_at timestamptz not null default now(),
  scade_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.comunicazione_destinatari (
  comunicazione_id uuid not null references public.comunicazioni(id) on delete cascade,
  dipendente_id uuid not null references public.utenti(id) on delete cascade,
  consegnata_at timestamptz,
  letta_at timestamptz,
  confermata_at timestamptz,
  primary key (comunicazione_id, dipendente_id)
);

alter table public.rapportini
  add column if not exists mezzo_id uuid references public.mezzi(id) on delete set null;
alter table public.timbrature
  add column if not exists mezzo_id uuid references public.mezzi(id) on delete set null;

create index if not exists idx_timbrature_dipendente_data
  on public.timbrature(dipendente_id, registrata_at desc);
create index if not exists idx_timbrature_data
  on public.timbrature(registrata_at desc);
create index if not exists idx_rapportino_collaboratori_dipendente
  on public.rapportino_collaboratori(dipendente_id, rapportino_id);
create index if not exists idx_rifornimenti_mezzo_data
  on public.rifornimenti(mezzo_id, data_ora desc);
create index if not exists idx_rifornimenti_dipendente_data
  on public.rifornimenti(dipendente_id, data_ora desc);
create index if not exists idx_anomalie_stato_data
  on public.anomalie(stato, created_at desc);
create index if not exists idx_contatti_visibili
  on public.contatti_azienda(attivo, visibile_operatori, ordine);
create index if not exists idx_dipendente_documenti_scadenza
  on public.dipendente_documenti(dipendente_id, data_scadenza);
create index if not exists idx_scadenze_mezzi_data
  on public.scadenze_mezzi(data_scadenza, completata);
create index if not exists idx_certificazioni_scadenza
  on public.certificazioni_azienda(data_scadenza, prossima_sorveglianza);
create index if not exists idx_comunicazioni_pubblicata
  on public.comunicazioni(pubblicata_at desc);
create index if not exists idx_comunicazioni_destinatario
  on public.comunicazione_destinatari(dipendente_id, letta_at);

-- Evita doppie entrate o doppie uscite consecutive per errore.
create or replace function app_private.valida_sequenza_timbratura()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, app_private
as $$
declare ultimo_tipo public.tipo_timbratura;
begin
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

drop trigger if exists trg_timbrature_sequenza on public.timbrature;
create trigger trg_timbrature_sequenza
before insert on public.timbrature
for each row execute function app_private.valida_sequenza_timbratura();

drop trigger if exists trg_configurazione_azienda_updated_at on public.configurazione_azienda;
create trigger trg_configurazione_azienda_updated_at
before update on public.configurazione_azienda
for each row execute function app_private.touch_updated_at();

drop trigger if exists trg_contatti_azienda_updated_at on public.contatti_azienda;
create trigger trg_contatti_azienda_updated_at
before update on public.contatti_azienda
for each row execute function app_private.touch_updated_at();

drop trigger if exists trg_mezzi_updated_at on public.mezzi;
create trigger trg_mezzi_updated_at
before update on public.mezzi
for each row execute function app_private.touch_updated_at();

drop trigger if exists trg_timbrature_updated_at on public.timbrature;
create trigger trg_timbrature_updated_at
before update on public.timbrature
for each row execute function app_private.touch_updated_at();

drop trigger if exists trg_rifornimenti_updated_at on public.rifornimenti;
create trigger trg_rifornimenti_updated_at
before update on public.rifornimenti
for each row execute function app_private.touch_updated_at();

drop trigger if exists trg_anomalie_updated_at on public.anomalie;
create trigger trg_anomalie_updated_at
before update on public.anomalie
for each row execute function app_private.touch_updated_at();

drop trigger if exists trg_dipendente_profili_updated_at on public.dipendente_profili;
create trigger trg_dipendente_profili_updated_at
before update on public.dipendente_profili
for each row execute function app_private.touch_updated_at();

drop trigger if exists trg_dipendente_documenti_updated_at on public.dipendente_documenti;
create trigger trg_dipendente_documenti_updated_at
before update on public.dipendente_documenti
for each row execute function app_private.touch_updated_at();

drop trigger if exists trg_scadenze_mezzi_updated_at on public.scadenze_mezzi;
create trigger trg_scadenze_mezzi_updated_at
before update on public.scadenze_mezzi
for each row execute function app_private.touch_updated_at();

drop trigger if exists trg_certificazioni_azienda_updated_at on public.certificazioni_azienda;
create trigger trg_certificazioni_azienda_updated_at
before update on public.certificazioni_azienda
for each row execute function app_private.touch_updated_at();

alter table public.configurazione_azienda enable row level security;
alter table public.contatti_azienda enable row level security;
alter table public.mezzi enable row level security;
alter table public.timbrature enable row level security;
alter table public.rapportino_collaboratori enable row level security;
alter table public.rifornimenti enable row level security;
alter table public.anomalie enable row level security;
alter table public.dipendente_profili enable row level security;
alter table public.dipendente_documenti enable row level security;
alter table public.scadenze_mezzi enable row level security;
alter table public.certificazioni_azienda enable row level security;
alter table public.dispositivi_push enable row level security;
alter table public.comunicazioni enable row level security;
alter table public.comunicazione_destinatari enable row level security;

grant select on public.configurazione_azienda, public.contatti_azienda, public.mezzi,
  public.timbrature, public.rapportino_collaboratori, public.rifornimenti, public.anomalie
  , public.dipendente_profili, public.dipendente_documenti, public.scadenze_mezzi
  , public.certificazioni_azienda, public.comunicazioni, public.comunicazione_destinatari
  , public.dispositivi_push
to authenticated;
grant insert on public.timbrature, public.rapportino_collaboratori,
  public.rifornimenti, public.anomalie, public.dispositivi_push,
  public.comunicazione_destinatari to authenticated;
grant update, delete on public.configurazione_azienda, public.contatti_azienda,
  public.mezzi, public.timbrature, public.rapportino_collaboratori,
  public.rifornimenti, public.anomalie, public.dipendente_profili,
  public.dipendente_documenti, public.scadenze_mezzi, public.certificazioni_azienda,
  public.dispositivi_push, public.comunicazioni
to authenticated;
grant update (letta_at, confermata_at) on public.comunicazione_destinatari
to authenticated;
grant insert on public.dipendente_profili, public.dipendente_documenti,
  public.scadenze_mezzi, public.certificazioni_azienda, public.comunicazioni
to authenticated;

-- Consente di rilanciare in sicurezza la migrazione durante gli aggiornamenti.
drop policy if exists configurazione_select on public.configurazione_azienda;
drop policy if exists configurazione_admin_all on public.configurazione_azienda;
drop policy if exists contatti_select on public.contatti_azienda;
drop policy if exists contatti_admin_all on public.contatti_azienda;
drop policy if exists mezzi_select on public.mezzi;
drop policy if exists mezzi_admin_all on public.mezzi;
drop policy if exists timbrature_select on public.timbrature;
drop policy if exists timbrature_operatore_insert on public.timbrature;
drop policy if exists timbrature_admin_all on public.timbrature;
drop policy if exists rapportino_collaboratori_select on public.rapportino_collaboratori;
drop policy if exists rapportino_collaboratori_owner_insert on public.rapportino_collaboratori;
drop policy if exists rapportino_collaboratori_owner_delete on public.rapportino_collaboratori;
drop policy if exists rapportino_collaboratori_admin_all on public.rapportino_collaboratori;
drop policy if exists rifornimenti_select on public.rifornimenti;
drop policy if exists rifornimenti_operatore_insert on public.rifornimenti;
drop policy if exists rifornimenti_admin_all on public.rifornimenti;
drop policy if exists anomalie_select on public.anomalie;
drop policy if exists anomalie_operatore_insert on public.anomalie;
drop policy if exists anomalie_admin_all on public.anomalie;
drop policy if exists dipendente_profili_select on public.dipendente_profili;
drop policy if exists dipendente_profili_admin_all on public.dipendente_profili;
drop policy if exists dipendente_documenti_select on public.dipendente_documenti;
drop policy if exists dipendente_documenti_admin_all on public.dipendente_documenti;
drop policy if exists scadenze_mezzi_admin_all on public.scadenze_mezzi;
drop policy if exists certificazioni_azienda_admin_all on public.certificazioni_azienda;
drop policy if exists dispositivi_push_owner_select on public.dispositivi_push;
drop policy if exists dispositivi_push_owner_insert on public.dispositivi_push;
drop policy if exists dispositivi_push_owner_update on public.dispositivi_push;
drop policy if exists dispositivi_push_owner_delete on public.dispositivi_push;
drop policy if exists comunicazioni_select on public.comunicazioni;
drop policy if exists comunicazioni_admin_all on public.comunicazioni;
drop policy if exists comunicazione_destinatari_select on public.comunicazione_destinatari;
drop policy if exists comunicazione_destinatari_owner_update on public.comunicazione_destinatari;
drop policy if exists comunicazione_destinatari_admin_all on public.comunicazione_destinatari;

create policy configurazione_select on public.configurazione_azienda
for select to authenticated using (true);
create policy configurazione_admin_all on public.configurazione_azienda
for all to authenticated using (app_private.is_admin()) with check (app_private.is_admin());

create policy contatti_select on public.contatti_azienda
for select to authenticated
using (attivo and (visibile_operatori or app_private.is_admin()));
create policy contatti_admin_all on public.contatti_azienda
for all to authenticated using (app_private.is_admin()) with check (app_private.is_admin());

create policy mezzi_select on public.mezzi
for select to authenticated using (attivo or app_private.is_admin());
create policy mezzi_admin_all on public.mezzi
for all to authenticated using (app_private.is_admin()) with check (app_private.is_admin());

create policy timbrature_select on public.timbrature
for select to authenticated
using (dipendente_id = auth.uid() or app_private.is_admin());
create policy timbrature_operatore_insert on public.timbrature
for insert to authenticated
with check (dipendente_id = auth.uid() and modificata_da is null and motivo_modifica is null);
create policy timbrature_admin_all on public.timbrature
for all to authenticated using (app_private.is_admin()) with check (app_private.is_admin());

create policy rapportino_collaboratori_select on public.rapportino_collaboratori
for select to authenticated
using (
  app_private.is_admin() or dipendente_id = auth.uid() or exists (
    select 1 from public.rapportini r
    where r.id = rapportino_id and r.dipendente_id = auth.uid()
  )
);
create policy rapportino_collaboratori_owner_insert on public.rapportino_collaboratori
for insert to authenticated
with check (exists (
  select 1 from public.rapportini r
  where r.id = rapportino_id and r.dipendente_id = auth.uid()
));
create policy rapportino_collaboratori_owner_delete on public.rapportino_collaboratori
for delete to authenticated
using (app_private.is_admin() or exists (
  select 1 from public.rapportini r
  where r.id = rapportino_id and r.dipendente_id = auth.uid() and r.stato in ('bozza', 'respinto')
));
create policy rapportino_collaboratori_admin_all on public.rapportino_collaboratori
for all to authenticated using (app_private.is_admin()) with check (app_private.is_admin());

create policy rifornimenti_select on public.rifornimenti
for select to authenticated
using (dipendente_id = auth.uid() or app_private.is_admin());
create policy rifornimenti_operatore_insert on public.rifornimenti
for insert to authenticated with check (dipendente_id = auth.uid());
create policy rifornimenti_admin_all on public.rifornimenti
for all to authenticated using (app_private.is_admin()) with check (app_private.is_admin());

create policy anomalie_select on public.anomalie
for select to authenticated
using (segnalata_da = auth.uid() or app_private.is_admin());
create policy anomalie_operatore_insert on public.anomalie
for insert to authenticated
with check (segnalata_da = auth.uid() and stato = 'aperta' and risolta_da is null);
create policy anomalie_admin_all on public.anomalie
for all to authenticated using (app_private.is_admin()) with check (app_private.is_admin());

create policy dipendente_profili_select on public.dipendente_profili
for select to authenticated
using (dipendente_id = auth.uid() or app_private.is_admin());
create policy dipendente_profili_admin_all on public.dipendente_profili
for all to authenticated using (app_private.is_admin()) with check (app_private.is_admin());

create policy dipendente_documenti_select on public.dipendente_documenti
for select to authenticated
using (
  app_private.is_admin() or
  (dipendente_id = auth.uid() and visibile_dipendente and attivo)
);
create policy dipendente_documenti_admin_all on public.dipendente_documenti
for all to authenticated using (app_private.is_admin()) with check (app_private.is_admin());

create policy scadenze_mezzi_admin_all on public.scadenze_mezzi
for all to authenticated using (app_private.is_admin()) with check (app_private.is_admin());
create policy certificazioni_azienda_admin_all on public.certificazioni_azienda
for all to authenticated using (app_private.is_admin()) with check (app_private.is_admin());

create policy dispositivi_push_owner_select on public.dispositivi_push
for select to authenticated using (dipendente_id = auth.uid() or app_private.is_admin());
create policy dispositivi_push_owner_insert on public.dispositivi_push
for insert to authenticated with check (dipendente_id = auth.uid());
create policy dispositivi_push_owner_update on public.dispositivi_push
for update to authenticated using (dipendente_id = auth.uid())
with check (dipendente_id = auth.uid());
create policy dispositivi_push_owner_delete on public.dispositivi_push
for delete to authenticated using (dipendente_id = auth.uid() or app_private.is_admin());

create policy comunicazioni_select on public.comunicazioni
for select to authenticated
using (app_private.is_admin() or exists (
  select 1 from public.comunicazione_destinatari d
  where d.comunicazione_id = id and d.dipendente_id = auth.uid()
));
create policy comunicazioni_admin_all on public.comunicazioni
for all to authenticated using (app_private.is_admin()) with check (app_private.is_admin());

create policy comunicazione_destinatari_select on public.comunicazione_destinatari
for select to authenticated
using (dipendente_id = auth.uid() or app_private.is_admin());
create policy comunicazione_destinatari_owner_update on public.comunicazione_destinatari
for update to authenticated using (dipendente_id = auth.uid())
with check (dipendente_id = auth.uid());
create policy comunicazione_destinatari_admin_all on public.comunicazione_destinatari
for all to authenticated using (app_private.is_admin()) with check (app_private.is_admin());

-- Rubrica minima per comporre le squadre: non espone email o dati HR.
create or replace view public.v_collaboratori_attivi
with (security_barrier = true)
as
select id, nome_cognome
from public.utenti
where attivo and ruolo = 'operatore';

revoke all on public.v_collaboratori_attivi from anon;
grant select on public.v_collaboratori_attivi to authenticated;

-- Viste amministrative per dashboard, presenze, straordinari e scadenze.
create or replace view public.v_presenze_giornaliere
with (security_invoker = true)
as
select
  t.dipendente_id,
  u.nome_cognome,
  (t.registrata_at at time zone 'Europe/Rome')::date as giorno,
  min(t.registrata_at) filter (where t.tipo = 'entrata') as prima_entrata,
  max(t.registrata_at) filter (where t.tipo = 'uscita') as ultima_uscita,
  case
    when min(t.registrata_at) filter (where t.tipo = 'entrata') is null
      or max(t.registrata_at) filter (where t.tipo = 'uscita') is null then null
    else round((extract(epoch from (
      max(t.registrata_at) filter (where t.tipo = 'uscita') -
      min(t.registrata_at) filter (where t.tipo = 'entrata')
    )) / 3600)::numeric, 2)
  end as ore_totali,
  case
    when min(t.registrata_at) filter (where t.tipo = 'entrata') is null
      or max(t.registrata_at) filter (where t.tipo = 'uscita') is null then null
    else greatest(0, round((extract(epoch from (
      max(t.registrata_at) filter (where t.tipo = 'uscita') -
      min(t.registrata_at) filter (where t.tipo = 'entrata')
    )) / 3600)::numeric, 2) - c.ore_ordinarie_giornaliere)
  end as ore_straordinarie
from public.timbrature t
join public.utenti u on u.id = t.dipendente_id
cross join public.configurazione_azienda c
group by t.dipendente_id, u.nome_cognome,
  (t.registrata_at at time zone 'Europe/Rome')::date,
  c.ore_ordinarie_giornaliere;

create or replace view public.v_scadenziario
with (security_invoker = true)
as
select
  'dipendente'::text as ambito,
  d.id as elemento_id,
  u.nome_cognome as soggetto,
  d.categoria as categoria,
  d.titolo,
  d.data_scadenza,
  d.documento_url,
  (d.data_scadenza - current_date) as giorni_rimanenti
from public.dipendente_documenti d
join public.utenti u on u.id = d.dipendente_id
where d.attivo and d.data_scadenza is not null
union all
select
  'mezzo', s.id, concat(m.targa, ' · ', m.descrizione), s.tipo,
  s.descrizione, s.data_scadenza, s.documento_url,
  (s.data_scadenza - current_date)
from public.scadenze_mezzi s
join public.mezzi m on m.id = s.mezzo_id
where not s.completata
union all
select
  'azienda', a.id, 'Arte in Ferro Lascari', a.categoria,
  a.titolo,
  case
    when a.data_scadenza is null then a.prossima_sorveglianza
    when a.prossima_sorveglianza is null then a.data_scadenza
    else least(a.data_scadenza, a.prossima_sorveglianza)
  end,
  a.documento_url,
  (case
    when a.data_scadenza is null then a.prossima_sorveglianza
    when a.prossima_sorveglianza is null then a.data_scadenza
    else least(a.data_scadenza, a.prossima_sorveglianza)
  end - current_date)
from public.certificazioni_azienda a
where a.attiva and (a.data_scadenza is not null or a.prossima_sorveglianza is not null);

grant select on public.v_presenze_giornaliere, public.v_scadenziario to authenticated;

commit;

-- Verifica finale: devono comparire quattordici righe.
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'configurazione_azienda', 'contatti_azienda', 'mezzi', 'timbrature',
    'rapportino_collaboratori', 'rifornimenti', 'anomalie',
    'dipendente_profili', 'dipendente_documenti', 'scadenze_mezzi',
    'certificazioni_azienda', 'dispositivi_push', 'comunicazioni',
    'comunicazione_destinatari'
  )
order by table_name;
