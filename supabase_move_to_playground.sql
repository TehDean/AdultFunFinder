-- Adult Fun Finder: move into the shared "playground" project (Japan2026, ref qsztbfixleqhxovkfaeg).
-- Oct 28, 2026. Applied with the Supabase connector. Safe to run more than once.
-- Tables get a fun_ prefix so they sit apart from the trip site's tables.
-- Function and view names are unchanged, so the page only needed the new project address and key.
-- The review key row is copied separately (never stored in this public repo).

create table if not exists public.fun_votes (
  event_id   text not null check (char_length(event_id) between 1 and 80),
  device_id  uuid not null,
  voter_name text not null check (char_length(voter_name) between 1 and 30),
  created_at timestamptz not null default now(),
  status     text not null default 'interested' check (status in ('interested', 'going')),
  event_type text check (event_type is null or char_length(event_type) <= 20),
  event_name text check (event_name is null or char_length(event_name) <= 120),
  primary key (event_id, device_id)
);

create table if not exists public.fun_suggestions (
  id           bigint generated always as identity primary key,
  created_at   timestamptz not null default now(),
  device_id    uuid not null,
  suggested_by text not null check (char_length(suggested_by) between 1 and 30),
  title        text not null check (char_length(title) between 3 and 120),
  link         text check (link is null or char_length(link) <= 500),
  when_text    text check (when_text is null or char_length(when_text) <= 120),
  where_text   text check (where_text is null or char_length(where_text) <= 160),
  note         text check (note is null or char_length(note) <= 500),
  status       text not null default 'new' check (status in ('new', 'added', 'skipped')),
  review_note  text check (review_note is null or char_length(review_note) <= 200),
  reviewed_at  timestamptz
);

create table if not exists public.fun_comments (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  event_id   text not null check (char_length(event_id) between 1 and 80),
  device_id  uuid not null,
  author     text not null check (char_length(author) between 1 and 30),
  body       text not null check (char_length(body) between 1 and 280)
);
create index if not exists fun_comments_event_idx on public.fun_comments (event_id, created_at);

create table if not exists public.fun_review_keys (key text primary key);

alter table public.fun_votes enable row level security;
alter table public.fun_suggestions enable row level security;
alter table public.fun_comments enable row level security;
alter table public.fun_review_keys enable row level security;
revoke all on public.fun_votes, public.fun_suggestions, public.fun_comments, public.fun_review_keys from anon, authenticated;

-- Views the page and the Thursday task read
create or replace view public.vote_list as
  select event_id, voter_name, created_at, status, event_type, event_name from public.fun_votes;
create or replace view public.comment_list as
  select id, event_id, author, body, created_at from public.fun_comments;
create or replace view public.interest_by_type as
  select coalesce(event_type, 'unknown') as event_type,
    count(*) filter (where status = 'interested') as interested,
    count(*) filter (where status = 'going') as going,
    count(*) filter (where status = 'interested') + 2 * count(*) filter (where status = 'going') as score,
    count(distinct event_id) as events, count(distinct voter_name) as people, max(created_at) as last_vote
  from public.fun_votes group by coalesce(event_type, 'unknown');
create or replace view public.interest_by_area as
  select case when event_id like 'roc-%' then 'roc' else 'nj' end as area,
    coalesce(event_type, 'unknown') as event_type,
    count(*) filter (where status = 'interested') as interested,
    count(*) filter (where status = 'going') as going,
    count(*) filter (where status = 'interested') + 2 * count(*) filter (where status = 'going') as score,
    count(distinct event_id) as events, count(distinct voter_name) as people, max(created_at) as last_vote
  from public.fun_votes group by 1, 2;
revoke all on public.vote_list, public.comment_list, public.interest_by_type, public.interest_by_area from anon, authenticated;
grant select on public.vote_list, public.comment_list, public.interest_by_type, public.interest_by_area to anon, authenticated;

-- Votes
create or replace function public.set_interest(p_event text, p_device uuid, p_name text, p_status text, p_type text default null, p_title text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_status not in ('interested', 'going') then raise exception 'Unknown level' using errcode = 'P0001'; end if;
  insert into public.fun_votes (event_id, device_id, voter_name, status, event_type, event_name)
  values (p_event, p_device, left(trim(p_name), 30), p_status, left(p_type, 20), left(p_title, 120))
  on conflict (event_id, device_id) do update
    set voter_name = excluded.voter_name,
        status     = excluded.status,
        event_type = coalesce(excluded.event_type, fun_votes.event_type),
        event_name = coalesce(excluded.event_name, fun_votes.event_name);
end $$;

create or replace function public.cast_vote(p_event text, p_device uuid, p_name text)
returns void language sql security definer set search_path = public as $$
  insert into public.fun_votes (event_id, device_id, voter_name)
  values (p_event, p_device, left(trim(p_name), 30))
  on conflict (event_id, device_id) do update set voter_name = excluded.voter_name;
$$;

create or replace function public.remove_vote(p_event text, p_device uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.fun_votes where event_id = p_event and device_id = p_device;
$$;

create or replace function public.my_interest(p_device uuid)
returns table(event_id text, status text) language sql security definer set search_path = public as $$
  select v.event_id, v.status from public.fun_votes v where v.device_id = p_device;
$$;

create or replace function public.my_votes(p_device uuid)
returns table(event_id text) language sql security definer set search_path = public as $$
  select v.event_id from public.fun_votes v where v.device_id = p_device;
$$;

-- Suggestions
create or replace function public.suggest_event(p_device uuid, p_by text, p_title text, p_link text, p_when text, p_where text, p_note text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.fun_suggestions where device_id = p_device and created_at > now() - interval '1 day') >= 10 then
    raise exception 'Too many suggestions today' using errcode = 'P0001';
  end if;
  if nullif(trim(p_link), '') is not null and trim(p_link) !~* '^https?://' then
    raise exception 'Links must start with http:// or https://';
  end if;
  insert into public.fun_suggestions (device_id, suggested_by, title, link, when_text, where_text, note)
  values (p_device, left(trim(p_by), 30), left(trim(p_title), 120), nullif(left(trim(p_link), 500), ''),
          nullif(left(trim(p_when), 120), ''), nullif(left(trim(p_where), 160), ''), nullif(left(trim(p_note), 500), ''));
end $$;

create or replace function public.my_suggestions(p_device uuid)
returns table(title text, status text, review_note text, created_at timestamptz) language sql security definer set search_path = public as $$
  select s.title, s.status, s.review_note, s.created_at from public.fun_suggestions s
  where s.device_id = p_device order by s.created_at desc limit 20;
$$;

create or replace function public.review_suggestions(p_key text)
returns table(id bigint, created_at timestamptz, suggested_by text, title text, link text, when_text text, where_text text, note text)
language plpgsql security definer set search_path = public as $$
begin
  if p_key = 'PUT-YOUR-REVIEW-KEY-HERE' or not exists (select 1 from public.fun_review_keys k where k.key = p_key) then raise exception 'Not allowed'; end if;
  return query select s.id, s.created_at, s.suggested_by, s.title, s.link, s.when_text, s.where_text, s.note
    from public.fun_suggestions s where s.status = 'new' order by s.created_at;
end $$;

create or replace function public.mark_suggestion(p_key text, p_id bigint, p_status text, p_note text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_key = 'PUT-YOUR-REVIEW-KEY-HERE' or not exists (select 1 from public.fun_review_keys k where k.key = p_key) then raise exception 'Not allowed'; end if;
  update public.fun_suggestions set status = p_status, review_note = nullif(left(trim(p_note), 200), ''), reviewed_at = now() where id = p_id;
end $$;

-- Comments
create or replace function public.add_comment(p_event text, p_device uuid, p_name text, p_body text)
returns bigint language plpgsql security definer set search_path = public as $$
declare new_id bigint;
begin
  if (select count(*) from public.fun_comments where device_id = p_device and created_at > now() - interval '1 day') >= 30 then
    raise exception 'Too many comments today' using errcode = 'P0001';
  end if;
  insert into public.fun_comments (event_id, device_id, author, body)
  values (p_event, p_device, left(trim(p_name), 30), left(trim(p_body), 280))
  returning id into new_id;
  return new_id;
end $$;

create or replace function public.delete_comment(p_id bigint, p_device uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.fun_comments where id = p_id and device_id = p_device;
$$;

create or replace function public.my_comment_ids(p_device uuid)
returns table(id bigint) language sql security definer set search_path = public as $$
  select c.id from public.fun_comments c where c.device_id = p_device;
$$;

create or replace function public.rename_my_comments(p_device uuid, p_name text)
returns void language sql security definer set search_path = public as $$
  update public.fun_comments set author = left(trim(p_name), 30) where device_id = p_device;
$$;

create or replace function public.remove_comment(p_key text, p_id bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_key = 'PUT-YOUR-REVIEW-KEY-HERE' or not exists (select 1 from public.fun_review_keys k where k.key = p_key) then raise exception 'Not allowed'; end if;
  delete from public.fun_comments where id = p_id;
end $$;
