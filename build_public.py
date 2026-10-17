"""Build the public website (index.html) from the Claude dashboard page.

The Claude-hosted dashboard stores its street map inside the page because
Claude's shared pages block outside map images. A normal public website has
no such limit, so this script swaps in a live street map instead.

Usage:  python3 build_public.py <claude_dashboard.html> > index.html
"""
import sys

src = open(sys.argv[1], encoding="utf-8").read()

START = "  // Each piece of the map loads only when that area is on screen."
END = "  map.setMinZoom(7);"
LIVE_MAP = '''  // Live street map (works on a normal public website).
  const townLayer = L.layerGroup([]);
  const streets = L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}", {
    maxZoom: 19, attribution: "Tiles &copy; Esri &mdash; Esri, HERE, Garmin, USGS, NGA"
  }).addTo(map);
  let fellBack = false, tileErrors = 0;
  streets.on("tileerror", () => {
    if (++tileErrors === 6 && !fellBack) {
      fellBack = true; map.removeLayer(streets);
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19, attribution: "&copy; OpenStreetMap contributors"
      }).addTo(map);
    }
  });
'''

i, j = src.find(START), src.find(END)
if i < 0 or j < 0 or j < i:
    sys.exit("build_public.py: could not find the map block in the dashboard page")
out = src[:i] + LIVE_MAP + src[j:]
out = out.replace('<!-- Index of the street-map pieces stored with this page -->\n<script src="tile-index.js"></script>\n', "")
out = out.replace('<script src="tile-index.js"></script>', "")

# Public website extras: switch on public-only features and make it installable as a home-screen app
flag_old = "const IS_PUBLIC_SITE = false;"
if flag_old not in out:
    sys.exit("build_public.py: could not find the IS_PUBLIC_SITE switch")
out = out.replace(flag_old, "const IS_PUBLIC_SITE = true;")
APP_TAGS = """<link rel="apple-touch-icon" href="icon-180.png">
<link rel="manifest" href="manifest.webmanifest">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="Fun Finder">
<meta name="apple-mobile-web-app-status-bar-style" content="black">"""
if '<link rel="apple-touch-icon" href="icon-180.png">' not in out:
    sys.exit("build_public.py: could not find the app icon tag")
out = out.replace('<link rel="apple-touch-icon" href="icon-180.png">', APP_TAGS, 1)
sys.stdout.write(out)
