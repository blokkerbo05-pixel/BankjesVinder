-- ============================================================
--  BANKJESVINDER: database voor Supabase
--  Plak dit hele bestand in Supabase -> SQL Editor -> New query -> Run.
--  Je mag het meerdere keren draaien: bestaande onderdelen blijven staan.
-- ============================================================

-- ---------- Instellingen voor het keuren (pas hier aan in het dashboard) ----------
create table if not exists public.keur_instellingen (
  id int primary key default 1 check (id = 1),
  stemmen_nodig int not null default 1,            -- testmodus: 1 stem is genoeg. Zet op 5 als er meer gebruikers zijn.
  goedkeur_drempel numeric not null default 0.7    -- aandeel "goed bankje" (0 t/m 1) om goed te keuren
);
insert into public.keur_instellingen (id) values (1) on conflict (id) do nothing;

-- ---------- Bankjes die gebruikers zelf toevoegen ----------
create table if not exists public.benches (
  id uuid primary key,
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  place text not null,
  lat double precision not null,
  lon double precision not null,
  tags text[] not null default '{}',
  rating int not null default 0,
  note text not null default '',
  photo_path text,                                  -- pad in de opslag-bucket "bankjes-fotos"
  created_at timestamptz not null default now()
);

-- ---------- Stemmen (één per gebruiker per bankje; ook voor OpenStreetMap-bankjes) ----------
create table if not exists public.votes (
  bench_id text not null,                           -- bankje-ID uit de app (UUID of "osm-123")
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  goed boolean not null,
  created_at timestamptz not null default now(),
  primary key (bench_id, user_id)
);

-- ---------- Status per bankje (wordt automatisch berekend, de app leest alleen) ----------
create table if not exists public.keur_status (
  bench_id text primary key,
  status text not null check (status in ('stemmen', 'goedgekeurd', 'afgekeurd')),
  aantal_stemmen int not null default 0,
  aantal_goed int not null default 0,
  reden text,
  updated_at timestamptz not null default now()
);

-- ============================================================
--  Automatisch de status berekenen bij elke stem
-- ============================================================
create or replace function public.herbereken_keur(p_bench text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  g int;
  nodig int;
  drempel numeric;
  aandeel numeric;
  procent int;
begin
  select count(*), count(*) filter (where goed) into n, g from public.votes where bench_id = p_bench;
  select stemmen_nodig, goedkeur_drempel into nodig, drempel from public.keur_instellingen where id = 1;

  if n = 0 then
    delete from public.keur_status where bench_id = p_bench;
    return;
  end if;

  aandeel := g::numeric / n;
  procent := round(aandeel * 100);

  insert into public.keur_status (bench_id, status, aantal_stemmen, aantal_goed, reden, updated_at)
  values (
    p_bench,
    case when n < nodig then 'stemmen' when aandeel >= drempel then 'goedgekeurd' else 'afgekeurd' end,
    n, g,
    case when n < nodig then null
         when aandeel >= drempel then procent || '% vond dit een goed bankje (' || g || ' van ' || n || ')'
         else 'Slechts ' || procent || '% vond dit een goed bankje (' || g || ' van ' || n || ')' end,
    now()
  )
  on conflict (bench_id) do update set
    status = excluded.status,
    aantal_stemmen = excluded.aantal_stemmen,
    aantal_goed = excluded.aantal_goed,
    reden = excluded.reden,
    updated_at = excluded.updated_at;
end;
$$;

create or replace function public.votes_na_wijziging()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.herbereken_keur(old.bench_id);
  else
    perform public.herbereken_keur(new.bench_id);
  end if;
  return null;
end;
$$;

drop trigger if exists votes_status_bijwerken on public.votes;
create trigger votes_status_bijwerken
  after insert or update or delete on public.votes
  for each row execute function public.votes_na_wijziging();

-- Bankje verwijderd: ook zijn stemmen en status opruimen.
create or replace function public.bench_opruimen()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.votes where bench_id = old.id::text;
  delete from public.keur_status where bench_id = old.id::text;
  return null;
end;
$$;

drop trigger if exists bench_na_verwijderen on public.benches;
create trigger bench_na_verwijderen
  after delete on public.benches
  for each row execute function public.bench_opruimen();

-- ============================================================
--  Row Level Security: wie mag wat
-- ============================================================
alter table public.keur_instellingen enable row level security;
alter table public.benches enable row level security;
alter table public.votes enable row level security;
alter table public.keur_status enable row level security;

-- Instellingen en statussen: iedereen mag lezen, niemand mag schrijven (alleen de database zelf).
drop policy if exists "instellingen lezen" on public.keur_instellingen;
create policy "instellingen lezen" on public.keur_instellingen for select using (true);

drop policy if exists "status lezen" on public.keur_status;
create policy "status lezen" on public.keur_status for select using (true);

-- Bankjes:
--  * Zonder account zie je alleen goedgekeurde bankjes.
--  * Ingelogd zie je ook bankjes die nog in keuring zijn (anders kan niemand ze beoordelen).
--    De app toont die alleen in de Keuren-tab (en jouw eigen bankjes ook op de kaart).
drop policy if exists "bankjes lezen" on public.benches;
create policy "bankjes lezen" on public.benches for select using (
  auth.uid() is not null
  or exists (select 1 from public.keur_status s where s.bench_id = benches.id::text and s.status = 'goedgekeurd')
);

drop policy if exists "bankje toevoegen" on public.benches;
create policy "bankje toevoegen" on public.benches for insert to authenticated
  with check (created_by = auth.uid());

drop policy if exists "eigen bankje wijzigen" on public.benches;
create policy "eigen bankje wijzigen" on public.benches for update to authenticated
  using (created_by = auth.uid()) with check (created_by = auth.uid());

drop policy if exists "eigen bankje verwijderen" on public.benches;
create policy "eigen bankje verwijderen" on public.benches for delete to authenticated
  using (created_by = auth.uid());

-- Stemmen: je ziet en wijzigt alleen je eigen stemmen.
-- (Testmodus: stemmen op je eigen bankje mag. Wil je dat later verbieden, voeg dan een controle toe aan "stem uitbrengen".)
drop policy if exists "eigen stemmen lezen" on public.votes;
create policy "eigen stemmen lezen" on public.votes for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "stem uitbrengen" on public.votes;
create policy "stem uitbrengen" on public.votes for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "eigen stem wijzigen" on public.votes;
create policy "eigen stem wijzigen" on public.votes for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "eigen stem verwijderen" on public.votes;
create policy "eigen stem verwijderen" on public.votes for delete to authenticated
  using (user_id = auth.uid());

-- Rechten op de tabellen (Row Level Security hierboven bepaalt wat er echt mag).
grant usage on schema public to anon, authenticated;
grant select on public.keur_instellingen, public.keur_status to anon, authenticated;
grant select on public.benches to anon, authenticated;
grant insert, update, delete on public.benches to authenticated;
grant select, insert, update, delete on public.votes to authenticated;

-- ============================================================
--  Foto's (opslag): iedereen mag kijken, je mag alleen in je eigen map schrijven
-- ============================================================
insert into storage.buckets (id, name, public)
values ('bankjes-fotos', 'bankjes-fotos', true)
on conflict (id) do nothing;

drop policy if exists "foto toevoegen" on storage.objects;
create policy "foto toevoegen" on storage.objects for insert to authenticated
  with check (bucket_id = 'bankjes-fotos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "foto wijzigen" on storage.objects;
create policy "foto wijzigen" on storage.objects for update to authenticated
  using (bucket_id = 'bankjes-fotos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "foto verwijderen" on storage.objects;
create policy "foto verwijderen" on storage.objects for delete to authenticated
  using (bucket_id = 'bankjes-fotos' and (storage.foldername(name))[1] = auth.uid()::text);
