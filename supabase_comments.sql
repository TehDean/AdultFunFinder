-- Adult Fun Finder: comments on events
-- Paste this whole file into Supabase > SQL Editor > New query, then click Run.
-- It is safe to run more than once.

-- 1. Comments (one row per comment)
create table if not exists public.comments (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  event_id   text not null check (char_length(event_id) between 1 and 80),
  device_id  uuid not null,
  author     text not null check (char_length(author) between 1 and 30),
  body       text not null check (char_length(body) between 1 and 280)
);
create index if not exists comments_event_idx on public.comments (event_id, created_at);

-- 2. Lock the table: visitors can't read or change it directly (keeps device IDs hidden)
alter table public.comments enable row level security;
revoke all on public.comments from anon, authenticated;

-- 3. A public, read-only list of comments (no device IDs)
create or replace view public.comment_list as
  select id, event_id, author, body, created_at from public.comments;
revoke all on public.comment_list from anon, authenticated;
grant select on public.comment_list to anon, authenticated;

-- 4. Post, delete or rename your own comments (at most 30 comments per phone per day)
create or replace function public.add_comment(p_event text, p_device uuid, p_name text, p_body text)
returns bigint language plpgsql security definer set search_path = public as $$
declare new_id bigint;
begin
  if (select count(*) from public.comments where device_id = p_device and created_at > now() - interval '1 day') >= 30 then
    raise exception 'Too many comments today' using errcode = 'P0001';
  end if;
  insert into public.comments (event_id, device_id, author, body)
  values (p_event, p_device, left(trim(p_name), 30), left(trim(p_body), 280))
  returning id into new_id;
  return new_id;
end $$;

create or replace function public.delete_comment(p_id bigint, p_device uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.comments where id = p_id and device_id = p_device;
$$;

create or replace function public.my_comment_ids(p_device uuid)
returns table (id bigint) language sql security definer set search_path = public as $$
  select c.id from public.comments c where c.device_id = p_device;
$$;

create or replace function public.rename_my_comments(p_device uuid, p_name text)
returns void language sql security definer set search_path = public as $$
  update public.comments set author = left(trim(p_name), 30) where device_id = p_device;
$$;

-- 5. Remove anyone's comment (needs the private review key from the suggestions setup)
create table if not exists public.review_keys (key text primary key);
alter table public.review_keys enable row level security;
revoke all on public.review_keys from anon, authenticated;

create or replace function public.remove_comment(p_key text, p_id bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_key = 'PUT-YOUR-REVIEW-KEY-HERE' or not exists (select 1 from public.review_keys k where k.key = p_key) then raise exception 'Not allowed'; end if;
  delete from public.comments where id = p_id;
end $$;

revoke all on function public.add_comment(text, uuid, text, text) from public;
revoke all on function public.delete_comment(bigint, uuid) from public;
revoke all on function public.my_comment_ids(uuid) from public;
revoke all on function public.rename_my_comments(uuid, text) from public;
revoke all on function public.remove_comment(text, bigint) from public;
grant execute on function public.add_comment(text, uuid, text, text) to anon, authenticated;
grant execute on function public.delete_comment(bigint, uuid) to anon, authenticated;
grant execute on function public.my_comment_ids(uuid) to anon, authenticated;
grant execute on function public.rename_my_comments(uuid, text) to anon, authenticated;
grant execute on function public.remove_comment(text, bigint) to anon, authenticated;
