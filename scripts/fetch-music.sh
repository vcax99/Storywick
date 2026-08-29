#!/bin/sh
# Rebuilds MoodMusic/ — 14 Kevin MacLeod tracks (CC-BY 4.0, incompetech.com),
# downloaded from archive.org and transcoded to 48 kbps mono AAC.
# Requires: curl, afconvert (built into macOS).
set -e
cd "$(dirname "$0")/.."
mkdir -p MoodMusic .music-tmp

dl() { # name  archive-identifier  path-in-item
  curl -sL -o ".music-tmp/$1.mp3" \
    "https://archive.org/download/$2/$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$3")"
  afconvert -f m4af -d aac -b 48000 --mix -c 1 ".music-tmp/$1.mp3" "MoodMusic/$1.m4a"
  echo "  $1"
}

dl calm          Kevin-MacLeod_Calming_2014_FullAlbum         "Calming/Kevin MacLeod - 12 - Meditation Impromptu 01.mp3"
dl meditative    Kevin-MacLeod_Vadodara_2014_FullAlbum        "Vadodara/Kevin MacLeod - 14 - Himalayan Atmosphere.mp3"
dl sad           Kevin-MacLeod_Sadness_2014_FullAlbum         "Sadness/Kevin MacLeod - 02 - Anguish.mp3"
dl romance       Kevin-MacLeod_Touching-Moments_2014_FullAlbum "Touching Moments/Kevin MacLeod - 02 - Melody.mp3"
dl dreamy        Kevin-MacLeod_Calming_2014_FullAlbum         "Calming/Kevin MacLeod - 07 - Dream Culture.mp3"
dl mystery       Kevin-MacLeod_Mystery_2014_FullAlbum         "Mystery/Kevin MacLeod - 04 - Myst.mp3"
dl suspense      Kevin-MacLeod_Ossuary_2015_FullAlbum         "Ossuary/Kevin MacLeod - 06 - Ossuary 6 - Air.mp3"
dl thriller      Kevin-MacLeod_Mystery_2014_FullAlbum         "Mystery/Kevin MacLeod - 12 - Spider Eyes.mp3"
dl horror        Kevin-MacLeod_Ghostpocalypse_2014_FullAlbum  "Ghostpocalypse/Kevin MacLeod - 07 - Master.mp3"
dl epic          Kevin-MacLeod_Impact_2014_FullAlbum          "Impact/Kevin MacLeod - 06 - Prelude.mp3"
dl inspirational Kevin-MacLeod_Impact_2014_FullAlbum          "Impact/Kevin MacLeod - 02 - Andante.mp3"
dl fantasy       Kevin-MacLeod_Vadodara_2014_FullAlbum        "Vadodara/Kevin MacLeod - 15 - Ibn Al-Noor.mp3"
dl scifi         Kevin-MacLeod_Light-Electronic_2014_FullAlbum "Light Electronic/Kevin MacLeod - 18 - Cipher.mp3"
dl comedy        Kevin-MacLeod_Mystery_2014_FullAlbum         "Mystery/Kevin MacLeod - 11 - Sneaky Snitch.mp3"

rm -rf .music-tmp
echo "MoodMusic/ rebuilt."
