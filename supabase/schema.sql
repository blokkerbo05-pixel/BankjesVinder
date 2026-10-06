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
  ai boolean;
  bestaand text;
begin
  -- Is de eindbeoordeling al gestart of klaar? Dan verandert de status niet meer door extra of ingetrokken stemmen.
  select status into bestaand from public.keur_status where bench_id = p_bench;
  if bestaand in ('in_beoordeling', 'goedgekeurd', 'afgekeurd') then
    return;
  end if;

  select count(*), count(*) filter (where goed) into n, g from public.votes where bench_id = p_bench;
  select stemmen_nodig, ai_beoordeling into nodig, ai from public.keur_instellingen where id = 1;

  if n = 0 then
    delete from public.keur_status where bench_id = p_bench;
    return;
  end if;

  insert into public.keur_status (bench_id, status, aantal_stemmen, aantal_goed, reden, updated_at)
  values (p_bench, case when n < nodig then 'stemmen' else 'in_beoordeling' end, n, g, null, now())
  on conflict (bench_id) do update set
    status = excluded.status,
    aantal_stemmen = excluded.aantal_stemmen,
    aantal_goed = excluded.aantal_goed,
    reden = null,
    updated_at = excluded.updated_at;

  -- Genoeg stemmen en de AI staat uit: de database rondt zelf af met de rekenregel.
  -- (Staat de AI aan, dan doet de Edge Function "beoordeel" dit.)
  if n >= nodig and not ai then
    perform public.eindbeoordeling_regel(p_bench);
  end if;
end;
$$;

-- De eindbeoordeling met de rekenregel (goed als minstens de drempel "goed" stemde).
create or replace function public.eindbeoordeling_regel(p_bench text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  g int;
  drempel numeric;
  aandeel numeric;
  procent int;
  goed boolean;
  tekst text;
begin
  select aantal_stemmen, aantal_goed into n, g
    from public.keur_status where bench_id = p_bench and status = 'in_beoordeling';
  if not found then
    return;
  end if;
  select goedkeur_drempel into drempel from public.keur_instellingen where id = 1;

  aandeel := g::numeric / n;
  procent := round(aandeel * 100);
  goed := aandeel >= drempel;
  tekst := case when goed
    then procent || '% vond dit een goed bankje (' || g || ' van ' || n || ')'
    else 'Slechts ' || procent || '% vond dit een goed bankje (' || g || ' van ' || n || ')' end;

  -- Goedgekeurd: de reden is voor iedereen te zien. Afgekeurd: alleen de maker ziet de reden (tabel keur_afwijzing).
  update public.keur_status
    set status = case when goed then 'goedgekeurd' else 'afgekeurd' end,
        reden = case when goed then tekst else null end,
        updated_at = now()
    where bench_id = p_bench;
  if not goed then
    insert into public.keur_afwijzing (bench_id, reden) values (p_bench, tekst)
    on conflict (bench_id) do update set reden = excluded.reden, updated_at = now();
  end if;
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

-- ============================================================
--  FASE 4: meerdere foto's per bankje, verwijderen en melden
-- ============================================================
create table if not exists public.bench_photos (
  id uuid primary key default gen_random_uuid(),
  bench_id text not null,                                   -- bankje-ID (kleine letters)
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  path text not null,                                       -- pad in de bucket "bankjes-fotos"
  verborgen boolean not null default false,                 -- true = gemeld, niet meer zichtbaar voor gebruikers
  created_at timestamptz not null default now()
);
create index if not exists bench_photos_bench_idx on public.bench_photos (bench_id);

-- Wie heeft welke foto gemeld. Jij bekijkt dit in Table Editor -> photo_reports.
create table if not exists public.photo_reports (
  photo_id uuid not null references public.bench_photos(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (photo_id, user_id)
);

-- Eenmalig: de foto's uit fase 3 (kolom photo_path) overnemen.
insert into public.bench_photos (bench_id, user_id, path)
select lower(b.id::text), b.created_by, b.photo_path
from public.benches b
where b.photo_path is not null
  and not exists (select 1 from public.bench_photos p where p.path = b.photo_path);

-- Een melding verbergt de foto meteen.
create or replace function public.foto_gemeld()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.bench_photos set verborgen = true where id = new.photo_id;
  return null;
end;
$$;

drop trigger if exists foto_na_melding on public.photo_reports;
create trigger foto_na_melding
  after insert on public.photo_reports
  for each row execute function public.foto_gemeld();

-- Bankje verwijderd: ook de foto-gegevens opruimen (uitbreiding van de eerdere opruimfunctie).
create or replace function public.bench_opruimen()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.votes where bench_id = old.id::text;
  delete from public.keur_status where bench_id = old.id::text;
  delete from public.bench_photos where bench_id = old.id::text;
  return null;
end;
$$;

alter table public.bench_photos enable row level security;
alter table public.photo_reports enable row level security;

-- Foto's: iedereen ziet de niet-gemelde foto's; ingelogd voeg je er toe; je verwijdert alleen je eigen foto's.
drop policy if exists "foto's lezen" on public.bench_photos;
create policy "foto's lezen" on public.bench_photos for select using (verborgen = false);

drop policy if exists "foto toevoegen aan bankje" on public.bench_photos;
create policy "foto toevoegen aan bankje" on public.bench_photos for insert to authenticated
  with check (user_id = auth.uid() and verborgen = false);

drop policy if exists "eigen foto verwijderen" on public.bench_photos;
create policy "eigen foto verwijderen" on public.bench_photos for delete to authenticated
  using (user_id = auth.uid());

-- Melden: ingelogd mag je een melding doen; lezen kan alleen jij via het dashboard.
drop policy if exists "foto melden" on public.photo_reports;
create policy "foto melden" on public.photo_reports for insert to authenticated
  with check (user_id = auth.uid());

grant select on public.bench_photos to anon, authenticated;
grant insert, delete on public.bench_photos to authenticated;
grant insert on public.photo_reports to authenticated;

-- ============================================================
--  FASE 5 en 6: eindbeoordeling (status "in_beoordeling"), AI-schakelaar en reden voor de maker
-- ============================================================
alter table public.keur_instellingen add column if not exists ai_beoordeling boolean not null default false;
-- false = de database beslist met de rekenregel. true = de Edge Function "beoordeel" (met AI) beslist.

alter table public.keur_status drop constraint if exists keur_status_status_check;
alter table public.keur_status add constraint keur_status_status_check
  check (status in ('stemmen', 'in_beoordeling', 'goedgekeurd', 'afgekeurd'));

-- De reden van een afkeuring: alleen de maker van het bankje ziet die.
create table if not exists public.keur_afwijzing (
  bench_id text primary key,
  reden text not null,
  updated_at timestamptz not null default now()
);
alter table public.keur_afwijzing enable row level security;

drop policy if exists "afwijzing lezen door maker" on public.keur_afwijzing;
create policy "afwijzing lezen door maker" on public.keur_afwijzing for select to authenticated
  using (exists (select 1 from public.benches b where b.id::text = keur_afwijzing.bench_id and b.created_by = auth.uid()));

grant select on public.keur_afwijzing to authenticated;

-- Bankje verwijderd: ook de reden opruimen.
create or replace function public.bench_opruimen()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.votes where bench_id = old.id::text;
  delete from public.keur_status where bench_id = old.id::text;
  delete from public.keur_afwijzing where bench_id = old.id::text;
  delete from public.bench_photos where bench_id = old.id::text;
  return null;
end;
$$;
