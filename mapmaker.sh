#!/bin/bash

set -e

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 TILE_URL_TEMPLATE BBOX_ZOOM OUTPUT_MBTS"
    echo "Example:"
    echo "$0 'https://api.maptiler.com/maps/streets-v2-dark/{z}/{x}/{y}.png?key=APIKEY' '-84.117039,39.769393,-84.091919,39.788237' '12,13,14' output.mbtiles"
    exit 1
fi

TILE_URL_TEMPLATE=$1
BBOX=$2
ZOOMS=$3
OUTPUT_MBTS=$4

# Parse bounding box
IFS=',' read -r MIN_LON MIN_LAT MAX_LON MAX_LAT <<< "$BBOX"

# Convert zooms string to Python list format
ZOOM_LIST="["$(echo $ZOOMS | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')"]"
# But better is to make it a list of ints
ZOOM_LIST=$(echo $ZOOMS | sed 's/,/, /g')
ZOOM_LIST="[${ZOOM_LIST}]"

# Create a Python script on the fly to download tiles
PYTHON_SCRIPT=$(cat << EOF
import os
import requests
import mercantile
import sys

TILE_URL = "${TILE_URL_TEMPLATE}"
bbox = (${MIN_LON}, ${MIN_LAT}, ${MAX_LON}, ${MAX_LAT})
zoom_levels = ${ZOOM_LIST}
output_dir = "map_tiles"

def download_tile(z, x, y):
    url = TILE_URL.format(z=z, x=x, y=y)
    r = requests.get(url)
    if r.status_code == 200:
        tile_path = os.path.join(output_dir, str(z), str(x))
        os.makedirs(tile_path, exist_ok=True)
        filename = os.path.join(tile_path, f"{y}.png")
        with open(filename, "wb") as f:
            f.write(r.content)
        print(f"Downloaded tile z{z} x{x} y{y}")
    else:
        print(f"Failed to download tile z{z} x{x} y{y} - HTTP {r.status_code}")

def main():
    min_lon, min_lat, max_lon, max_lat = bbox

    for z in zoom_levels:
        ul_tile = mercantile.tile(min_lon, max_lat, z)
        lr_tile = mercantile.tile(max_lon, min_lat, z)

        for x in range(ul_tile.x, lr_tile.x + 1):
            for y in range(ul_tile.y, lr_tile.y + 1):
                download_tile(z, x, y)

if __name__ == "__main__":
    main()
EOF
)

echo "Downloading tiles..."
python3 -c "$PYTHON_SCRIPT"

echo "Creating MBTiles..."
mb-util --scheme=xyz map_tiles "$OUTPUT_MBTS"

echo "Updating metadata..."
MIN_ZOOM=$(echo $ZOOMS | cut -d, -f1)
MAX_ZOOM=$(echo $ZOOMS | awk -F, '{print $NF}')

sqlite3 "$OUTPUT_MBTS" <<SQL
CREATE TABLE IF NOT EXISTS metadata (name TEXT UNIQUE, value TEXT);
INSERT OR REPLACE INTO metadata (name, value) VALUES ('name', 'streets-v2-dark');
INSERT OR REPLACE INTO metadata (name, value) VALUES ('format', 'png');
INSERT OR REPLACE INTO metadata (name, value) VALUES ('bounds', '${MIN_LON},${MIN_LAT},${MAX_LON},${MAX_LAT}');
INSERT OR REPLACE INTO metadata (name, value) VALUES ('minzoom', '${MIN_ZOOM}');
INSERT OR REPLACE INTO metadata (name, value) VALUES ('maxzoom', '${MAX_ZOOM}');
INSERT OR REPLACE INTO metadata (name, value) VALUES ('tilejson', '{"tiles":["${TILE_URL_TEMPLATE}"],"bounds":[${MIN_LON},${MIN_LAT},${MAX_LON},${MAX_LAT}],"minzoom":${MIN_ZOOM},"maxzoom":${MAX_ZOOM} }');
SQL

echo "Done! Output MBTiles file: $OUTPUT_MBTS"