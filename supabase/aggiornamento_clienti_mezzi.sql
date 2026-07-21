begin;

alter table public.rapportini
  add column if not exists targa_mezzo text,
  add column if not exists km_mezzo integer;

alter table public.rapportini
  drop constraint if exists rapportini_km_mezzo_validi;
alter table public.rapportini
  add constraint rapportini_km_mezzo_validi
  check (km_mezzo is null or km_mezzo >= 0);

grant insert on public.clienti to authenticated;

drop policy if exists clienti_operatore_insert on public.clienti;
create policy clienti_operatore_insert
on public.clienti
for insert
to authenticated
with check (
  exists (
    select 1 from public.utenti u
    where u.id = (select auth.uid()) and u.attivo
  )
);

commit;
