# Adult Fun Finder

A mobile-friendly map and list of things to do over the next few weekends within about 2 hours of West Orange, NJ: food festivals, shows, comedy, breweries and wineries, active outings, obstacle races, hikes, street fairs, and seasonal events.

**Live site:** https://tehdean.github.io/AdultFunFinder/

Events are refreshed every Thursday evening. Listings come from web searches, so confirm times and prices before you go.

## Files

- `index.html` – the public website.
- `build_public.py` – rebuilds `index.html` from the Claude-hosted dashboard page, swapping in a live street map.
- `supabase_setup.sql` – one-time database setup for shared votes (run in the Supabase SQL Editor).
