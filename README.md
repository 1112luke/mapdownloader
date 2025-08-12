## Usage

        sudo docker run --rm -v $(pwd):/data 1112luke/mapdownloader \
        "https://api.maptiler.com/maps/streets-v2-dark/{z}/{x}/{y}.png?key=<YOUR_API_KEY>" \
        "-84.117039,39.769393,-84.091919,39.788237" \
        "12,13,14,15" \
        "/data/outputdockernew.mbtiles"

    where chords are minlon, minlat, maxlon, maxlat. specify zoom levels and output file, always in the data directory. Use z,x,y as placeholders for api zoom level
