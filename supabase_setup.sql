-- Adult Fun Finder: shared votes
-- Paste this whole file into Supabase > SQL Editor > New query, then click Run.
-- It is safe to run more than once.

-- 1. The votes table. One row per event per device.
create table if not exists public.votes (
  event_id   text not null check (char_length(event_id) between 1 and 80),
  device_id  uuid not null,
  voter_name text not null check (char_length(voter_name) between 1 and 30),
  created_at timestamptz not null default now(),
  primary key (event_id, device_id)
);

-- 2. Lock the table: visitors can't read or change it directly.
--    (This keeps each phone's private device ID hidden, so nobody can remove someone else's vote.)
alter table public.votes enable row level security;
revoke all on public.votes from anon, authenticated;

-- 3. A public, read-only list of who voted for what (names only, no device IDs).
create or replace view public.vote_list as
  select event_id, voter_name, created_at from public.votes;
revoke all on public.vote_list from anon, authenticated;
grant select on public.vote_list to anon, authenticated;

-- 4. The only ways to change votes: add/rename your own vote, remove your own vote, list your own votes.
create or replace function public.cast_vote(p_event text, p_device uuid, p_name text)
returns void language sql security definer set search_path = public as $$
  insert into public.votes (event_id, device_id, voter_name)
  values (p_event, p_device, left(trim(p_name), 30))
  on conflict (event_id, device_id) do update set voter_name = excluded.voter_name;
$$;

create or replace function public.remove_vote(p_event text, p_device uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.votes where event_id = p_event and device_id = p_device;
$$;

create or replace function public.my_votes(p_device uuid)
returns table (event_id text) language sql security definer set search_path = public as $$
  select v.event_id from public.votes v where v.device_id = p_device;
$$;

revoke all on function public.cast_vote(text, uuid, text) from public;
revoke all on function public.remove_vote(text, uuid) from public;
revoke all on function public.my_votes(uuid) from public;
grant execute on function public.cast_vote(text, uuid, text) to anon, authenticated;
grant execute on function public.remove_vote(text, uuid) to anon, authenticated;
grant execute on function public.my_votes(uuid) to anon, authenticated;
