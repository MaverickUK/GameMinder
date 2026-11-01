#!/usr/bin/env bash
# Record the README demo video of GameMinder running in DOSBox-X.
#
# Builds a demo C: drive with ~25 games (metadata only, plus a stand-in batch file
# for the one game that's launched), types a scripted sequence of keys with
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

python3 - "$work/c" <<'EOF'
import os, sys, random
c = sys.argv[1]

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'w', newline='\r\n').write(text)

write(f'{c}/GMIND/SETTINGS.TXT', 'ScanPath:C:\\GAMES\nDelayOnStartup:1200\n')

games = [
    # dir, name, exec, developer, year, genre, video, sound, times played, minutes played
    ('KEEN1', 'Commander Keen 1: Marooned on Mars', 'KEEN1.EXE', 'id Software', '1990', 'Platform', 'EGA', 'PC Speaker', 3, 95),
    ('KEEN4', 'Commander Keen 4: Secret of the Oracle', 'START.BAT', 'id Software', '1991', 'Platform', 'EGA', 'Sound Blaster', 7, 410),
    ('DOOM', 'Doom', 'DOOM.EXE', 'id Software', '1993', 'FPS', 'VGA', 'Sound Blaster', 24, 1630),
    ('DOOM2', 'Doom II', 'DOOM2.EXE', 'id Software', '1994', 'FPS', 'VGA', 'Sound Blaster', 11, 720),
    ('WOLF3D', 'Wolfenstein 3D', 'WOLF3D.EXE', 'id Software', '1992', 'FPS', 'VGA', 'Sound Blaster', 5, 180),
    ('HERETIC', 'Heretic', 'HERETIC.EXE', 'Raven Software', '1994', 'FPS', 'VGA', 'Sound Blaster', 2, 75),
    ('DUKE3D', 'Duke Nukem 3D', 'DUKE3D.EXE', '3D Realms', '1996', 'FPS', 'SVGA', 'Sound Blaster', 9, 540),
    ('MONKEY1', 'The Secret of Monkey Island', 'MONKEY.EXE', 'Lucasfilm Games', '1990', 'Adventure', 'VGA', 'Roland MT-32', 4, 600),
    ('MONKEY2', "Monkey Island 2: LeChuck's Revenge", 'MONKEY2.EXE', 'LucasArts', '1991', 'Adventure', 'VGA', 'Sound Blaster', 3, 480),
    ('DOTT', 'Day of the Tentacle', 'TENTACLE.EXE', 'LucasArts', '1993', 'Adventure', 'VGA', 'Sound Blaster', 2, 300),
    ('DUNE', 'Dune', 'DUNE.BAT', 'Cryo Interactive', '1992', 'Strategy', 'VGA', 'Sound Blaster', 1, 90),
    ('DUNE2', 'Dune II', 'DUNE2.EXE', 'Westwood Studios', '1992', 'Strategy', 'VGA', 'Sound Blaster', 6, 880),
    ('XCOM', 'X-COM: UFO Defense', 'UFO.EXE', 'MicroProse', '1994', 'Strategy', 'VGA', 'Sound Blaster', 8, 2210),
    ('CIV', 'Civilization', 'CIV.EXE', 'MicroProse', '1991', 'Strategy', 'VGA', 'Roland MT-32', 12, 3125),
    ('POP', 'Prince of Persia', 'PRINCE.EXE', 'Broderbund', '1989', 'Platform', 'VGA', 'PC Speaker', 2, 40),
    ('LEMMINGS', 'Lemmings', 'LEMMINGS.BAT', 'DMA Design', '1991', 'Puzzle', 'VGA', 'Sound Blaster', 4, 150),
    ('TIM', 'The Incredible Machine', 'TIM.EXE', 'Dynamix', '1993', 'Puzzle', 'VGA', 'Sound Blaster', 1, 25),
    ('CANNON', 'Cannon Fodder', 'CANNON.EXE', 'Sensible Software', '1993', 'Action', 'VGA', 'Sound Blaster', 3, 130),
    ('AITD', 'Alone in the Dark', 'INDARK.EXE', 'Infogrames', '1992', 'Adventure', 'VGA', 'AdLib', 0, 0),
    ('BLACKTH', 'Blackthorne', 'BLACK.EXE', 'Blizzard', '1994', 'Platform', 'VGA', 'Sound Blaster', 1, 35),
    ('JAZZ', 'Jazz Jackrabbit', 'JAZZ.EXE', 'Epic MegaGames', '1994', 'Platform', 'VGA', 'Sound Blaster', 5, 210),
    ('OMF', 'One Must Fall 2097', 'OMF.EXE', 'Diversions Entertainment', '1994', 'Fighting', 'VGA', 'Sound Blaster', 6, 190),
    ('TYRIAN', 'Tyrian', 'TYRIAN.EXE', 'Eclipse Productions', '1995', 'Shooter', 'VGA', 'Sound Blaster', 3, 160),
    ('THEMEPK', 'Theme Park', 'MAIN.EXE', 'Bullfrog', '1994', 'Simulation', 'VGA', 'Sound Blaster', 2, 260),
    ('SC2000', 'SimCity 2000', 'SC2000.EXE', 'Maxis', '1993', 'Simulation', 'SVGA', 'Sound Blaster', 5, 940),
]

random.seed(7)
for d, name, exe, dev, year, genre, video, sound, plays, minutes in games:
    write(f'{c}/GAMES/{d}/!GM_INFO.TXT',
          f'name:{name}\nexec:{exe}\ndeveloper:{dev}\nyear:{year}\ngenre:{genre}\nvideo:{video}\nsound:{sound}\n')
    # Made up play history, so the stats and play sorts have something to show
    if plays:
        lines, left = [], minutes
        for i in range(plays):
            m = left if i == plays - 1 else random.randint(0, max(0, left // (plays - i)))
            left -= m
            lines += [f'>2026/{9 + i * 2 // plays:02d}/{1 + i * 3 % 28:02d} {19 + i % 4}:{(i * 13) % 60:02d}', f'<{m}']
        write(f'{c}/GAMES/{d}/!GM_LOG.TXT', '\n'.join(lines) + '\n')

# Stand-in for the game launched in the demo - waits for a key, like quitting a game
write(f'{c}/GAMES/KEEN4/START.BAT', '''@echo off
cls
echo.
echo.
echo.
echo           ******************************************************
echo           *                                                    *
echo           *     Commander Keen 4 would be running now...       *
echo           *                                                    *
echo           *     (a stand-in batch file for this demo)          *
echo           *                                                    *
echo           ******************************************************
echo.
echo           Quit the game to return to GameMinder
choice /c:yn /n >nul
''')
EOF

cp "$exe" "$work/c/GMIND/GAMEMIND.EXE"
mkdir -p "$work/capture"

# Each key is pressed 1.1s apart, "," adds an extra pause:
#   browse, help (F1), status (F3), info (F2), full screen (F4), sort by year/played/name,
#   type "keen" to filter, run Commander Keen 4 (a .BAT), quit it ("y"), check play stats,
#   Esc clears the filter, Sort menu > Developer, Esc back, Esc exits
keys="down down down pagedown home f1 , f3 , f2 f4 , f7 , f9 , f5 f2 k e e n , down , enter , , , y , f2 , , esc , right right enter , right enter , , esc esc"

SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox-x -fastlaunch -nomenu -exit -time-limit 150 \
  -set "dosbox captures=$work/capture" \
  -c "mount c $work/c" -c "c:" -c "cls" -c "cd \\GMIND" \
  -c "autotype -w 4 -p 1.1 $keys" \
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
