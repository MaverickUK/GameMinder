#!/usr/bin/env bash
# Try out GameMinder in DOSBox-X with a drive full of test games.
#
# Builds GAMEMIND.EXE from this repository with Turbo Pascal 7 inside DOSBox-X,
# creates a test C: drive in build/testbed (see scripts/make-testdata.py) and opens
# DOSBox-X with GameMinder running.
#
# In DOSBox-X:  C:  test drive, GameMinder in C:\GMIND, games in C:\GAMES
#               S:  this repository (read only)
#               T:  Turbo Pascal (read only)
#   B [args]    rebuild from the source on S: and run GAMEMIND [args], e.g. after
#               editing the source on the host: B, B /50, B /SCAN
#
# Usage:  scripts/testbed.sh [options]
#   --exe FILE    Use this GAMEMIND.EXE (e.g. from a CI run) rather than building
#   --bulk N      Add N generated games, for scrolling and large lists
#   --no-edge     Leave out the edge case games in C:\GAMES\TESTS
#   --keep        Keep the test drive from last time (play logs, settings, cache)
#   --build-only  Build GAMEMIND.EXE into build/testbed/c/GMIND and exit
#   -- ARGS       Arguments for GAMEMIND, e.g. -- /50
#
# Needs:  DOSBox-X (on PATH, or set DOSBOX_X), Python 3, and Turbo Pascal 7
#         (TP_DIR, default C:\TPWDB, containing BIN\TPC.EXE) unless --exe is given
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
bed=$repo/build/testbed
drive=$bed/c

exe= bulk=0 edge=--edge-cases keep= build_only= gm_args=
while [ $# -gt 0 ]; do
  case $1 in
    --exe) exe=$(cd "$(dirname "$2")" && pwd)/$(basename "$2"); shift 2 ;;
    --bulk) bulk=$2; shift 2 ;;
    --no-edge) edge=; shift ;;
    --keep) keep=1; shift ;;
    --build-only) build_only=1; shift ;;
    --) shift; gm_args="$*"; break ;;
    -h|--help) sed -n '2,/^set -e/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1 (see --help)" >&2; exit 1 ;;
  esac
done

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

tp_dir=${TP_DIR:-/c/TPWDB}
if [ -z "$exe" ] && [ ! -f "$tp_dir/BIN/TPC.EXE" ]; then
  echo "Turbo Pascal not found at $tp_dir/BIN/TPC.EXE - set TP_DIR, or use --exe" >&2; exit 1
fi

# ---- Test drive ----

if [ -z "$keep" ] || [ ! -d "$drive/GAMES" ]; then
  rm -rf "$drive"
  "$python" "$repo/scripts/make-testdata.py" "$drive" $edge --bulk "$bulk"
  cp "$repo/THEMES.TXT" "$drive/GMIND/THEMES.TXT"
  echo "Test drive created in $drive"
fi
mkdir -p "$drive/BUILD"

dos_bat() { printf '%s\r\n' "$@" > "$1.tmp" && mv "$1.tmp" "$1"; }
mounts=(
  "mount c \"$(native "$drive")\""
  "mount -ro s \"$(native "$repo")\""
)
[ -n "$exe" ] || mounts+=("mount -ro t \"$(native "$tp_dir")\"")

# Compiles everything (/B) so stale units are never used, into C:\BUILD
tpc='T:\BIN\TPC.EXE /B /Q /EC:\BUILD /US:\;T:\UNITS /IS:\ S:\GAMEMIND.PAS'

write_b_bat() {
  printf '%s\r\n' \
    '@echo off' \
    'rem Rebuild GameMinder from the source on S: and run it, e.g. B /50' \
    'rescan > nul' \
    'c:' 'cd \BUILD' \
    "$tpc" \
    'if errorlevel 1 goto failed' \
    'copy C:\BUILD\GAMEMIND.EXE C:\GMIND > nul' \
    'c:' 'cd \GMIND' \
    'GAMEMIND %1 %2 %3' \
    'goto end' \
    ':failed' \
    'c:' 'cd \GMIND' \
    'echo Build failed - GAMEMIND.EXE not updated' \
    ':end' > "$drive/GMIND/B.BAT"
}

run_dosbox() { # conf file, then any extra options
  local conf=$1; shift
  "$dosbox" -conf "$(native "$conf")" -fastlaunch -nomenu "$@"
}

write_conf() { # conf file, then autoexec lines
  local conf=$1; shift
  {
    printf '[sdl]\r\nautolock=false\r\n'
    printf '[dosbox]\r\ntitle=GameMinder testbed\r\nmemsize=16\r\n'
    printf '[dos]\r\nems=true\r\nxms=true\r\n'
    printf '[autoexec]\r\n'
    printf '%s\r\n' "${mounts[@]}" "$@"
  } > "$conf"
}

# ---- Build ----

if [ -n "$exe" ]; then
  cp "$exe" "$drive/GMIND/GAMEMIND.EXE"
else
  write_b_bat
  rm -f "$drive/BUILD/GAMEMIND.EXE" "$drive/BUILD/BUILD.LOG"
  write_conf "$bed/build.conf" 'c:' 'cd \BUILD' "$tpc > C:\\BUILD\\BUILD.LOG" 'exit'
  echo "Building GAMEMIND.EXE with Turbo Pascal..."
  SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy run_dosbox "$bed/build.conf" -exit -time-limit 120 \
    > "$bed/dosbox-build.log" 2>&1 || true
  tr -d '\r' < "$drive/BUILD/BUILD.LOG" 2> /dev/null | sed '/^$/d' || true
  if [ ! -f "$drive/BUILD/GAMEMIND.EXE" ] || grep -q "Error " "$drive/BUILD/BUILD.LOG" 2> /dev/null; then
    echo "Build failed" >&2; exit 1
  fi
  cp "$drive/BUILD/GAMEMIND.EXE" "$drive/GMIND/GAMEMIND.EXE"
fi

[ -z "$build_only" ] || { echo "Built $drive/GMIND/GAMEMIND.EXE"; exit 0; }

# ---- Run ----

write_conf "$bed/run.conf" 'c:' 'cd \GMIND' "GAMEMIND $gm_args"
echo "Starting DOSBox-X. Type EXIT to close it."
[ -n "$exe" ] || echo "After changing the source, type B in DOSBox-X to rebuild and run GameMinder."
run_dosbox "$bed/run.conf" > "$bed/dosbox-run.log" 2>&1 &
