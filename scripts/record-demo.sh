#!/usr/bin/env bash
# Record the README demo video of GameMinder running in DOSBox-X.
#
# Builds a demo C: drive with 25 games (metadata plus stand-in programs, made by
# scripts/make-testdata.py), types a scripted sequence of keys with
# DOSBox-X's AUTOTYPE and captures it with DX-CAPTURE. No window is shown.
#
# Usage:   scripts/record-demo.sh path/to/GAMEMIND.EXE
# Needs:   dosbox-x, ffmpeg, python3
# Output:  docs/gameminder-demo.gif and docs/gameminder-demo.mp4
#
# Get GAMEMIND.EXE from a CI run: gh run download <run-id> -n gamemind-dos
set -euo pipefail

exe=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

python3 "$repo/scripts/make-testdata.py" "$work/c"

cp "$exe" "$work/c/GMIND/GAMEMIND.EXE"
cp "$repo/THEMES.TXT" "$work/c/GMIND/THEMES.TXT"
mkdir -p "$work/capture"

# Each key is pressed 1.2s apart, "," adds an extra pause. Keep the autotype command
# under 255 characters, or DOSBox-X ignores the end of it:
#   browse, help (F1), status (F3), info (F2), full screen (F4), sort by year/played/name,
#   type "keen" to filter, run Commander Keen 4 (a .BAT), quit it ("y"), check play stats,
#   Esc clears the filter, Sort menu > Developer, Esc back, Theme x4 (Classic, Turbo,
#   Commander, Mono), Esc exits
keys="down down down f1 , f3 , f2 f4 , f7 , f9 , f5 f2 k e e n , down , enter , , , y , f2 , esc right right enter right enter , esc right right right right right enter , enter , enter , enter , esc"

SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox-x -fastlaunch -nomenu -exit -time-limit 180 \
  -set "dosbox captures=$work/capture" \
  -c "mount c $work/c" -c "c:" -c "cls" -c "cd \\GMIND" \
  -c "autotype -w 4 -p 1.2 $keys" \
  -c "dx-capture /v GAMEMIND.EXE" > "$work/dosbox.log" 2>&1

avi=$(ls "$work"/capture/*.avi)
mkdir -p "$repo/docs"

# VGA text mode is captured at 720x400 but displayed at 4:3
ffmpeg -v error -y -i "$avi" -an -vf "scale=960:720:flags=neighbor" \
  -c:v libx264 -preset slow -crf 18 -tune animation -pix_fmt yuv420p -movflags +faststart \
  "$repo/docs/gameminder-demo.mp4"
ffmpeg -v error -y -i "$avi" \
  -vf "fps=8,scale=720:540:flags=neighbor,split[a][b];[a]palettegen=max_colors=32:stats_mode=full[p];[b][p]paletteuse=dither=none" \
  "$repo/docs/gameminder-demo.gif"

ls -lh "$repo/docs/gameminder-demo".*
