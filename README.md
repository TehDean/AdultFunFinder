# Adult Fun Finder

A mobile-friendly map and list of things to do over the next few weekends, with two area tabs: within about 2 hours of West Orange, NJ, and within about an hour of Rochester, NY. It covers food festivals, shows, comedy, breweries and wineries, active outings, obstacle races, hikes, street fairs, and seasonal events.

**Live site:** https://tehdean.github.io/AdultFunFinder/

Events are refreshed every Thursday evening. Listings come from web searches, so confirm times and prices before you go.

## Files

- `index.html` – the public website.
- `build_public.py` – rebuilds `index.html` from the Claude-hosted dashboard page, swapping in a live street map.
- `supabase_setup.sql` – one-time database setup for shared votes (run in the Supabase SQL Editor).
- `supabase_suggestions.sql` – one-time database setup for the "Suggest an event" form. Replace the placeholder review key before running it, and keep the real key private.
- `supabase_comments.sql` – one-time database setup for comments on events.
- `supabase_interest.sql` – adds the Interested / Going levels to votes and a summary of which kinds of events friends like.
- `og-image.jpg` – the preview picture shown when the site's link is shared in chats.
- `manifest.webmanifest`, `icon-*.png` – let people add the site to their phone's home screen like an app.

## Features

- Weekends run Friday evening to Sunday. Map and list with filters for weekend, category, day (Friday night, Saturday, Sunday), cost, indoor, distance and saved events, plus a search box.
- Each event has its web page (or a web search), a share link that opens the site on that event (`?e=event-id`), and an add-to-calendar button (Google Calendar or a calendar file).
- Weekend weather from Open-Meteo, with a ☔ tag on outdoor events when rain is likely.
- Shared "Interested" and "Going" buttons, a "Who's interested" sidebar, comments on each event, and a form for friends to suggest events.
