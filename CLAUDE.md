# Notes for Claude: Adult Fun Finder

Read this before changing anything. The owner is Dean (GitHub `TehDean`), West Orange, NJ.
This repo is PUBLIC: never write keys, passwords or the review key into any file here.

## What this is

A weekend-events site for Dean and his friends: a Leaflet map and a list of things to do
Friday evening through Sunday, for the next ~4 weekends. It has two area tabs:
- **New Jersey**: within ~2 hours of West Orange, NJ (HQ 40.7948, -74.2391).
- **Rochester, NY**: within ~1 hour of 651 Hinchey Rd, Rochester NY 14624 (HQ 43.1385787, -77.6890792).

There are two copies of the same page:

1. **The main copy (source of truth): a Claude artifact**
   https://claude.ai/artifact/SK7TqQ6xx118y2MYdzEVBp
   - Always edit THIS page, then derive the public site from it.
   - To get its current HTML, use the Artifact tool with `action: "read"` and that url.
   - To publish, ALWAYS pass `url: "https://claude.ai/artifact/SK7TqQ6xx118y2MYdzEVBp"`.
     Publishing without it creates a separate new artifact (this happened once; the stray was deleted).
   - Publish only the page. Do not pass `files`, `capabilities` or a new icon. The artifact also
     stores ~100 street-map tile files (`tile-index.js`, `t7.js` … `t12_*.js`) that are kept
     automatically; never touch, remove or re-upload them. They only cover New Jersey, so the
     Claude copy shows town names (no street detail) on the Rochester tab. The public site's live
     map covers both.

2. **The public copy: GitHub Pages**, https://tehdean.github.io/AdultFunFinder/
   - `index.html` here is GENERATED. Don't hand-edit it.
   - Build it: `python3 build_public.py <dashboard.html> > index.html`
     (swaps in a live Esri street map, sets `IS_PUBLIC_SITE = true`, adds manifest/app tags).
     Check the output contains `World_Street_Map`, `IS_PUBLIC_SITE = true`, `manifest.webmanifest`
     and no `tile-index.js`.
   - Commit and push to `main`. Pages redeploys in about a minute.

## Updating events

Events for both areas live in one array in the page: `const ALL_EVENTS = [ ... ];` (inside the
"EDIT HERE" block). `EVENTS` is the filtered list for the tab being shown; don't edit it.
Rochester events have `region: "roc"`; events without `region` are New Jersey. Area settings
(HQ, map box, towns, distance labels) are in `REGIONS`.

```js
{ id: "montclair-zombie-walk", url: "https://…", name: "…", weekends: ["2026-10-24"],
  type: "fall", day: "sat", free: true, far: false, outdoor: true,
  lat: 40.0, lng: -74.0, when: "Saturday, Oct 24, 2 to 6 PM", where: "Venue, address, town",
  cost: "Free.", about: "1–2 sentences, plus rough drive time from West Orange." }
```

- **`id` never changes.** Friends' votes, comments and shared links (`?e=<id>`) are keyed by it.
  If you change an event's details, keep its id. Never reuse an old id for a different event.
- `weekends`: Saturday dates (YYYY-MM-DD). A Friday-night event goes under the next day's Saturday.
- `day`: `fri` (evening only) | `sat` | `sun` | `both` (Sat+Sun) | `fri-sat` | `fri-sun`.
- `type`: race, hike, active, food, brew, show, comedy, movie, art, fair, fall, holiday.
  `race` is ONLY obstacle/mud races; ordinary 5Ks, half marathons, etc. are excluded.
- `outdoor`: optional override. By default race/hike/active/fair/fall/food count as outdoor.
- `far`: NJ: true if more than ~1 hour's drive from West Orange. Rochester: true if more than
  ~30 min from 651 Hinchey Rd (its distance chips are "Within 30 min" / "30–60 min").
  `free`: true only when a source says free.
- `when`: write times like "Saturday, Oct 24, 10 AM to 4 PM". The calendar button and the
  list's time sorting read this format.
- Same venue means the same exact lat/lng, so the map merges its events into one pin with a count.
- Rules: no New York City events (the five boroughs). Friday means evening (5 PM+).
- Stay inside the area's map box. NJ: lat 39.30–42.10, lng -76.00 to -72.80.
  Rochester: lat 42.45–43.45, lng -78.55 to -76.75.
- Rochester ids start with `roc-`. Share links with `?e=<id>` open the right tab automatically;
  `?r=roc` opens the Rochester tab.

## The Thursday update (scheduled task)

"Adult Fun Finder refresh", Thursdays 5:55 PM Eastern, runs on its own (no approval needed).
It drops past weekends, adds a new 4th weekend, refreshes the coming one, and checks Dean's
favorite spots:
- Recess Bar karaoke
- Montclair Brewery (via its public calendar feed)
- Dwell New Jersey's Friday/Saturday/Sunday roundups

It also reviews friends' suggestions, publishes the artifact and pushes `index.html`. Its full
instructions live in the task itself. If you change how events are stored or add a rule, update
the task's prompt too (claude-code-remote `update_trigger`; list it with `list_triggers`).

## Database (Supabase)

- Project "Adult Fun Finder", ref `bsdoccpgsoyixsmtsvsu`. Dean has another project ("Japan2026");
  don't touch it.
- The page uses only the publishable key. Never put a secret / service_role key in the page.
- Tables are locked (RLS on, no direct access). Everything goes through functions:
  - votes (⭐ Interested / ✅ Going): `set_interest(p_event, p_device, p_name, p_status, p_type, p_title)`,
    `remove_vote`, `my_interest`, and the `vote_list` view (with `status`, `event_type`, `event_name`).
    `cast_vote` (3 args) is only used to rename and keeps the level. `my_votes` is the old version.
  - `interest_by_type` view: interest per event type (score = interested + 2 × going). The Thursday
    update reads it to search harder for the kinds of events friends like.
  - suggestions: `suggest_event`, `my_suggestions`, plus `review_suggestions(p_key)` and
    `mark_suggestion(p_key, …)` for the Thursday task
  - comments: the `comment_list` view, `add_comment`, `delete_comment`, `my_comment_ids`,
    `rename_my_comments`, plus `remove_comment(p_key, id)` for moderation
- Moderation functions need the private review key. It lives only in the Thursday task's prompt.
  Never copy it into this repo, the page, a commit, or a chat summary.
- Setup SQL: `supabase_setup.sql`, `supabase_suggestions.sql`, `supabase_comments.sql`, `supabase_interest.sql`.
  - All four are applied already. Write new SQL files so they're safe to run more than once.
  - The Supabase connector may be connected. If it is, apply schema changes with it, but only
    when Dean asks for a change. If not, send Dean the SQL to paste into the SQL Editor.
- Don't delete or edit real votes or comments from friends.

## Testing before publishing

1. Extract the main inline `<script>` and run `node --check` on it.
2. Load the page in Playwright (Chromium is preinstalled), with Supabase and Open-Meteo requests
   mocked. Check:
   - filters, the list's day headings, opening events, combined venue pins, comments and sharing
   - no page errors
   - no horizontal overflow at 320 and 360px wide (phones zoomed out once because of this)
3. Leaflet loads from cdnjs. If the network blocks it, the page falls back to an SVG map, so test
   that fallback too.

## Working with Dean

- Keep replies plain and short. He's not a developer.
- Verify event details on the venue's or organizer's own page before adding them. Don't add events
  you can only find on Facebook.
- Commits: `git -c user.name=Claude -c user.email=noreply@anthropic.com commit …`, with the
  attribution lines the session's instructions give.
