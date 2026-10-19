-- Adult Fun Finder: "Interested" and "Going", plus a summary of what kinds of events friends like
-- Adds to the votes setup in supabase_setup.sql. It is safe to run more than once.

-- 1. Each vote now has a level ("interested" or "going") and remembers the event's kind and name,
--    so interest still counts after the event has passed and left the site.
alter table public.votes add column if not exists status text not null default 'interested';
alter table public.votes add column if not exists event_type text;
alter table public.votes add column if not exists event_name text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'votes_status_check') then
    alter table public.votes add constraint votes_status_check check (status in ('interested', 'going'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'votes_event_type_len') then
    alter table public.votes add constraint votes_event_type_len check (event_type is null or char_length(event_type) <= 20);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'votes_event_name_len') then
    alter table public.votes add constraint votes_event_name_len check (event_name is null or char_length(event_name) <= 120);
  end if;
end $$;

-- 2. Votes cast before this change came from the old "I'm in" button. Dean asked for them to count
--    as "interested" (the column's default), so they need no change. Fill in what kind of event each was.
update public.votes v set event_type = x.t, event_name = x.n
  from (values
    ('montclair-zombie-walk', 'fall', 'Montclair Zombie Walk'),
    ('riamede-farm-fall-festival', 'fall', 'Riamede Farm Fall Festival'),
    ('von-thun-farms-fall-festival-weekends', 'fall', 'Von Thun Farms Fall Festival Weekends'),
    ('warwick-drive-in', 'movie', 'Warwick Drive-In'),
    ('demarest-farms-halloween-light-show', 'fall', 'Demarest Farms Halloween Light Show'),
    ('scare-farm-norz-hill', 'fall', 'Scare Farm: The Final Ride')
  ) as x(id, t, n)
  where v.event_id = x.id and v.event_type is null;

-- 3. The public list of votes now shows the level and the event's kind (still no device IDs).
create or replace view public.vote_list as
  select event_id, voter_name, created_at, status, event_type, event_name from public.votes;
revoke all on public.vote_list from anon, authenticated;
grant select on public.vote_list to anon, authenticated;

-- 4. A summary by kind of event, used by the Thursday update to look for more of what people like.
--    score = interested + 2 x going
create or replace view public.interest_by_type as
  select coalesce(event_type, 'unknown') as event_type,
         count(*) filter (where status = 'interested') as interested,
         count(*) filter (where status = 'going') as going,
         count(*) filter (where status = 'interested') + 2 * count(*) filter (where status = 'going') as score,
         count(distinct event_id) as events,
         count(distinct voter_name) as people,
         max(created_at) as last_vote
  from public.votes
  group by 1;
revoke all on public.interest_by_type from anon, authenticated;
grant select on public.interest_by_type to anon, authenticated;

-- 5. Set your own level on an event, and list your own votes with their levels.
create or replace function public.set_interest(p_event text, p_device uuid, p_name text, p_status text,
                                               p_type text default null, p_title text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_status not in ('interested', 'going') then raise exception 'Unknown level' using errcode = 'P0001'; end if;
  insert into public.votes (event_id, device_id, voter_name, status, event_type, event_name)
  values (p_event, p_device, left(trim(p_name), 30), p_status, left(p_type, 20), left(p_title, 120))
  on conflict (event_id, device_id) do update
    set voter_name = excluded.voter_name,
        status     = excluded.status,
        event_type = coalesce(excluded.event_type, votes.event_type),
        event_name = coalesce(excluded.event_name, votes.event_name);
end $$;

create or replace function public.my_interest(p_device uuid)
returns table (event_id text, status text) language sql security definer set search_path = public as $$
  select v.event_id, v.status from public.votes v where v.device_id = p_device;
$$;

revoke all on function public.set_interest(text, uuid, text, text, text, text) from public;
revoke all on function public.my_interest(uuid) from public;
grant execute on function public.set_interest(text, uuid, text, text, text, text) to anon, authenticated;
grant execute on function public.my_interest(uuid) to anon, authenticated;
