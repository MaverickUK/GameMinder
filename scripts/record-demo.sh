#!/usr/bin/env bash
# Record the README demo video of GameMinder running in DOSBox-X.
#
# Builds a demo C: drive with 25 games (metadata plus stand-in programs, made by
# scripts/make-testdata.py), types a scripted sequence of keys with
# DOSBox-X's AUTOTYPE and captures it with DX-CAPTURE. No window is shown.
#
# Usage:   scripts/record-demo.sh path/to/GAMEMIND.EXE
# Needs:   DOSBox-X (on PATH, or set DOSBOX_X), ffmpeg, Python 3
# Output:  docs/gameminder-demo.gif and docs/gameminder-demo.mp4
#
# Get GAMEMIND.EXE from a CI run: gh run download <run-id> -n gamemind-dos
set -euo pipefail

exe=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Windows paths for DOSBox-X when running in Git Bash, otherwise unchanged
native() { if command -v cygpath > /dev/null; then cygpath -w "$1"; else echo "$1"; fi; }

dosbox=${DOSBOX_X:-$(command -v dosbox-x || true)}
for guess in "$HOME/scoop/apps/dosbox-x/current/dosbox-x.exe" "/c/Program Files/DOSBox-X/dosbox-x.exe"; do
  if [ -z "$dosbox" ] && [ -x "$guess" ]; then dosbox=$guess; fi
done
[ -n "$dosbox" ] || { echo "DOSBox-X not found - install it or set DOSBOX_X" >&2; exit 1; }

python=
for p in python3 python py; do
  if "$p" -c 'import sys; sys.exit(sys.version_info < (3, 6))' 2> /dev/null; then python=$p; break; fi
done
[ -n "$python" ] || { echo "Python 3 not found" >&2; exit 1; }

make_drive() {
  rm -rf "$work/c" "$work/capture"
  "$python" "$repo/scripts/make-testdata.py" "$work/c"
  cp "$exe" "$work/c/GMIND/GAMEMIND.EXE"
  cp "$repo/THEMES.TXT" "$work/c/GMIND/THEMES.TXT"
  # Long enough to read the startup screen
  printf 'ScanPath:C:\\GAMES\r\nDelayOnStartup:3500\r\n' > "$work/c/GMIND/SETTINGS.TXT"
  mkdir -p "$work/capture"
}

# Each key is pressed 1.2s apart, "," adds an extra pause. Keep the autotype command
# under 255 characters, or DOSBox-X ignores the end of it:
#   browse, help (F1), status (F3), memory map (F4), info (F2), full screen (F2 again),
#   sort by played/name,
#   type "keen" to filter, run Commander Keen 4 (a .BAT), quit it ("y"), check play stats,
#   Esc clears the filter, Sort menu > Developer, Esc back, Add (Ins) Raptor, type its
#   developer and save (F10), Theme > Turbo, Commander, Mono and keep it, Esc exits
#   to the end screen, which DX-CAPTURE keeps recording for 3 seconds
keys="down down f1 , f3 , f4 , , f2 f2 , f9 , f5 f2 k e e n , down enter , , y , f2 , esc right right enter right enter , esc insert , enter , down down down a p o g e e , f10 left left left left enter , right , right , right , enter , esc"

# DOSBox-X closes at the time limit, after the recording has finished. It sometimes crashes
# while recording once a game has run (and always with -exit), so try a few times
for attempt in 1 2 3; do
  make_drive
  SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy "$dosbox" -fastlaunch -nomenu -time-limit 180 \
    -set "dosbox captures=$(native "$work/capture")" \
    -c "mount c \"$(native "$work/c")\"" -c "c:" -c "cls" -c "cd \\GMIND" \
    -c "autotype -w 6 -p 1.2 $keys" \
    -c "dx-capture /v GAMEMIND.EXE" > "$work/dosbox.log" 2>&1 || true
  if grep -q "Stopped capturing video" "$work/dosbox.log"; then break; fi
  echo "DOSBox-X stopped before the recording finished (attempt $attempt)" >&2
  [ "$attempt" -lt 3 ] || exit 1
done

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
