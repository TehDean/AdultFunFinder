-- Adult Fun Finder: "Suggest an event"
-- Paste this whole file into Supabase > SQL Editor > New query, then click Run.
-- Before running, replace PUT-YOUR-REVIEW-KEY-HERE (near the bottom) with a long random password.
-- The weekly update uses that key to read and mark suggestions. Never put it in the website.
-- It is safe to run more than once.

-- 1. Suggestions sent from the website
create table if not exists public.suggestions (
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
alter table public.suggestions enable row level security;
revoke all on public.suggestions from anon, authenticated;

-- 2. The private review key (nobody can read this table from the website)
create table if not exists public.review_keys (key text primary key);
alter table public.review_keys enable row level security;
revoke all on public.review_keys from anon, authenticated;

-- 3. Send a suggestion (at most 10 per phone per day)
create or replace function public.suggest_event(p_device uuid, p_by text, p_title text, p_link text, p_when text, p_where text, p_note text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.suggestions where device_id = p_device and created_at > now() - interval '1 day') >= 10 then
    raise exception 'Too many suggestions today' using errcode = 'P0001';
  end if;
  if nullif(trim(p_link), '') is not null and trim(p_link) !~* '^https?://' then
    raise exception 'Links must start with http:// or https://';
  end if;
  insert into public.suggestions (device_id, suggested_by, title, link, when_text, where_text, note)
  values (p_device, left(trim(p_by), 30), left(trim(p_title), 120), nullif(left(trim(p_link), 500), ''),
          nullif(left(trim(p_when), 120), ''), nullif(left(trim(p_where), 160), ''), nullif(left(trim(p_note), 500), ''));
end $$;

-- 4. A phone's own suggestions and whether they were added
create or replace function public.my_suggestions(p_device uuid)
returns table (title text, status text, review_note text, created_at timestamptz)
language sql security definer set search_path = public as $$
  select s.title, s.status, s.review_note, s.created_at from public.suggestions s
  where s.device_id = p_device order by s.created_at desc limit 20;
$$;

-- 5. For the weekly update only (needs the review key)
create or replace function public.review_suggestions(p_key text)
returns table (id bigint, created_at timestamptz, suggested_by text, title text, link text, when_text text, where_text text, note text)
language plpgsql security definer set search_path = public as $$
begin
  if p_key = 'PUT-YOUR-REVIEW-KEY-HERE' or not exists (select 1 from public.review_keys k where k.key = p_key) then raise exception 'Not allowed'; end if;
  return query select s.id, s.created_at, s.suggested_by, s.title, s.link, s.when_text, s.where_text, s.note
    from public.suggestions s where s.status = 'new' order by s.created_at;
end $$;

create or replace function public.mark_suggestion(p_key text, p_id bigint, p_status text, p_note text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_key = 'PUT-YOUR-REVIEW-KEY-HERE' or not exists (select 1 from public.review_keys k where k.key = p_key) then raise exception 'Not allowed'; end if;
  update public.suggestions set status = p_status, review_note = nullif(left(trim(p_note), 200), ''), reviewed_at = now() where id = p_id;
end $$;

revoke all on function public.suggest_event(uuid, text, text, text, text, text, text) from public;
revoke all on function public.my_suggestions(uuid) from public;
revoke all on function public.review_suggestions(text) from public;
revoke all on function public.mark_suggestion(text, bigint, text, text) from public;
grant execute on function public.suggest_event(uuid, text, text, text, text, text, text) to anon, authenticated;
grant execute on function public.my_suggestions(uuid) to anon, authenticated;
grant execute on function public.review_suggestions(text) to anon, authenticated;
grant execute on function public.mark_suggestion(text, bigint, text, text) to anon, authenticated;

-- 6. Your review key
insert into public.review_keys (key) values ('PUT-YOUR-REVIEW-KEY-HERE') on conflict do nothing;
