-- Arte In Ferro - aggiornamento 0.7.2
-- Mappe opzionali, nuova griglia presenze e notifiche sonore dei rapportini.

begin;

alter table public.rapportini
  add column if not exists maps_url text;

alter table public.rapportini
  drop constraint if exists rapportini_maps_url_check;

alter table public.rapportini
  add constraint rapportini_maps_url_check
  check (
    maps_url is null
    or maps_url ~* '^https?://'
  );

update public.configurazione_app
set versione_corrente = '0.7.2',
    messaggio = 'Mappe facoltative, nuova griglia presenze e notifiche sonore dei lavori assegnati.',
    updated_at = now()
where piattaforma = 'android';

notify pgrst, 'reload schema';

commit;

select
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'rapportini'
      and column_name = 'maps_url'
  ) as maps_url_ok,
  (
    select versione_corrente
    from public.configurazione_app
    where piattaforma = 'android'
    limit 1
  ) as versione_android;
