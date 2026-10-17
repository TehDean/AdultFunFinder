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
sys.stdout.write(out)
