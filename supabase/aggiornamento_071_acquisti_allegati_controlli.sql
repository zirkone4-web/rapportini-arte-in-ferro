-- Arte In Ferro - Migrazione ERP 0.7.1
-- Pianificazione, squadre, acquisti, allegati e controllo rifornimenti.
-- Idempotente: può essere eseguita nuovamente senza cancellare dati.

begin;

alter table public.rapportini
  add column if not exists mezzo_id uuid references public.mezzi(id) on delete set null,
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

create table if not exists public.acquisti_azienda (
  id uuid primary key default gen_random_uuid(),
  dipendente_id uuid not null references public.utenti(id) on delete restrict,
  fornitore text not null,
  descrizione text not null,
  importo numeric(12,2) not null check (importo >= 0),
  metodo_pagamento text,
  data_ora timestamptz not null default now(),
  cliente_id uuid references public.clienti(id) on delete set null,
  cantiere_id uuid references public.cantieri(id) on delete set null,
  rapportino_id uuid references public.rapportini(id) on delete set null,
  mezzo_id uuid references public.mezzi(id) on delete set null,
  stato text not null default 'da_verificare'
    check (stato in ('da_verificare','approvato','rifiutato')),
  nota_amministratore text,
  autorizzato_da uuid references public.utenti(id) on delete set null,
  autorizzato_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.allegati_aziendali (
  id uuid primary key default gen_random_uuid(),
  ambito text not null check (
    ambito in ('rapportino','acquisto','anomalia','rifornimento','richiesta_materiale')
  ),
  record_id uuid not null,
  caricato_da uuid not null references public.utenti(id) on delete restrict,
  nome_file text not null,
  storage_path text not null unique,
  mime_type text,
  dimensione_bytes bigint check (dimensione_bytes is null or dimensione_bytes >= 0),
  created_at timestamptz not null default now()
);

alter table public.rifornimenti
  add column if not exists rapportino_id uuid references public.rapportini(id) on delete set null,
  add column if not exists mezzo_assegnato_id uuid references public.mezzi(id) on delete set null,
  add column if not exists stato_verifica text not null default 'coerente',
  add column if not exists motivo_attenzione text,
  add column if not exists autorizzato_da uuid references public.utenti(id) on delete set null,
  add column if not exists autorizzato_at timestamptz,
  add column if not exists nota_amministratore text;

create or replace function app_private.verifica_rifornimento_mezzo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  report_id uuid;
  report_vehicle uuid;
  selected_vehicle uuid;
begin
  report_id := nullif(to_jsonb(new) ->> 'rapportino_id', '')::uuid;
  selected_vehicle := nullif(to_jsonb(new) ->> 'mezzo_id', '')::uuid;

  if report_id is null then
    new.stato_verifica := coalesce(nullif(new.stato_verifica, ''), 'coerente');
    return new;
  end if;

  select nullif(to_jsonb(r) ->> 'mezzo_id', '')::uuid
    into report_vehicle
  from public.rapportini r
  where r.id = report_id;

  new.mezzo_assegnato_id := report_vehicle;

  if report_vehicle is not null
     and selected_vehicle is not null
     and report_vehicle <> selected_vehicle then
    new.stato_verifica := 'da_verificare';
    new.motivo_attenzione :=
      'Mezzo del rifornimento diverso da quello assegnato nel rapportino';
  else
    new.stato_verifica := 'coerente';
    new.motivo_attenzione := null;
  end if;

  return new;
end;
$$;

revoke all on function app_private.verifica_rifornimento_mezzo() from public;

drop trigger if exists trg_rifornimenti_verifica_mezzo on public.rifornimenti;
create trigger trg_rifornimenti_verifica_mezzo
before insert or update of mezzo_id, rapportino_id
on public.rifornimenti
for each row execute function app_private.verifica_rifornimento_mezzo();

create index if not exists idx_rapportini_pianificati
  on public.rapportini(data_ora_inizio, pianificato) where pianificato;
create index if not exists idx_rapportino_collaboratori_dipendente
  on public.rapportino_collaboratori(dipendente_id, rapportino_id);
create index if not exists idx_acquisti_stato_data
  on public.acquisti_azienda(stato, data_ora desc);
create index if not exists idx_allegati_ambito_record
  on public.allegati_aziendali(ambito, record_id, created_at desc);
create index if not exists idx_rifornimenti_verifica
  on public.rifornimenti(stato_verifica, data_ora desc);

alter table public.rapportino_collaboratori enable row level security;
alter table public.acquisti_azienda enable row level security;
alter table public.allegati_aziendali enable row level security;

grant select, insert, update, delete on public.rapportino_collaboratori to authenticated;
grant select, insert, update, delete on public.acquisti_azienda to authenticated;
grant select, insert, delete on public.allegati_aziendali to authenticated;

drop policy if exists rapportino_collaboratori_accesso on public.rapportino_collaboratori;
create policy rapportino_collaboratori_accesso
on public.rapportino_collaboratori
for all to authenticated
using (
  dipendente_id = auth.uid()
  or app_private.is_admin()
  or exists (
    select 1 from public.rapportini r
    where r.id = rapportino_id and r.dipendente_id = auth.uid()
  )
)
with check (
  dipendente_id = auth.uid()
  or app_private.is_admin()
  or exists (
    select 1 from public.rapportini r
    where r.id = rapportino_id and r.dipendente_id = auth.uid()
  )
);

drop policy if exists acquisti_azienda_select on public.acquisti_azienda;
create policy acquisti_azienda_select
on public.acquisti_azienda for select to authenticated
using (dipendente_id = auth.uid() or app_private.is_admin());

drop policy if exists acquisti_azienda_insert on public.acquisti_azienda;
create policy acquisti_azienda_insert
on public.acquisti_azienda for insert to authenticated
with check (dipendente_id = auth.uid() or app_private.is_admin());

drop policy if exists acquisti_azienda_update on public.acquisti_azienda;
create policy acquisti_azienda_update
on public.acquisti_azienda for update to authenticated
using (app_private.is_admin() or (dipendente_id = auth.uid() and stato = 'da_verificare'))
with check (app_private.is_admin() or dipendente_id = auth.uid());

drop policy if exists allegati_aziendali_select on public.allegati_aziendali;
create policy allegati_aziendali_select
on public.allegati_aziendali for select to authenticated
using (caricato_da = auth.uid() or app_private.is_admin());

drop policy if exists allegati_aziendali_insert on public.allegati_aziendali;
create policy allegati_aziendali_insert
on public.allegati_aziendali for insert to authenticated
with check (caricato_da = auth.uid() or app_private.is_admin());

drop policy if exists allegati_aziendali_delete on public.allegati_aziendali;
create policy allegati_aziendali_delete
on public.allegati_aziendali for delete to authenticated
using (caricato_da = auth.uid() or app_private.is_admin());

insert into storage.buckets (id, name, public)
values ('allegati-azienda', 'allegati-azienda', false)
on conflict (id) do update set public = false;

drop policy if exists allegati_azienda_select on storage.objects;
create policy allegati_azienda_select
on storage.objects for select to authenticated
using (
  bucket_id = 'allegati-azienda'
  and (
    app_private.is_admin()
    or (storage.foldername(name))[1] = auth.uid()::text
  )
);

drop policy if exists allegati_azienda_insert on storage.objects;
create policy allegati_azienda_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'allegati-azienda'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists allegati_azienda_delete on storage.objects;
create policy allegati_azienda_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'allegati-azienda'
  and (
    app_private.is_admin()
    or (storage.foldername(name))[1] = auth.uid()::text
  )
);

update public.configurazione_app
set versione_corrente = '0.7.1',
    messaggio = 'Nuova pianificazione lavori e creazione rapportini dall’ufficio.',
    updated_at = now()
where piattaforma = 'android';

notify pgrst, 'reload schema';
commit;

select 'Migrazione ERP 0.7.1 completata' as esito;