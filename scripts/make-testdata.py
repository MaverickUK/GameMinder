#!/usr/bin/env python3
"""Create a DOS C: drive of test games for GameMinder.

Usage:  make-testdata.py DRIVE_DIR [--edge-cases] [--bulk N]

Writes DRIVE_DIR/GMIND/SETTINGS.TXT and DRIVE_DIR/GAMES/... with:
  - 25 well known games, with metadata, setup programs, notes and a made up play history
  - --edge-cases: games that exercise awkward info files, missing programs,
    before/after commands, memory warnings, long names and so on (in GAMES/TESTS),
    plus a second scan directory, EXTRA
  - --bulk N: N generated games (in GAMES/BULK), for scrolling and large lists

Every game's program is a tiny stand-in (.COM image or .BAT) that shows the game's
name and waits for a key, so games can be launched and play stats recorded.
Used by scripts/record-demo.sh and scripts/testbed.sh.
"""
import argparse
import os
import random

parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
parser.add_argument('drive', help='directory to use as the C: drive')
parser.add_argument('--edge-cases', action='store_true', help='add edge case games in GAMES\\TESTS')
parser.add_argument('--bulk', type=int, default=0, metavar='N', help='add N generated games in GAMES\\BULK')
args = parser.parse_args()
c = args.drive


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', newline='\r\n', encoding='cp437') as f:
        f.write(text)


def stand_in_com(name):
    """A .COM program that prints a message, waits for a key and exits.
    DOS runs it whatever its extension, as it has no MZ header."""
    msg = (f'\r\n\r\n  {name} would be running now...\r\n\r\n'
           '  (a stand-in for testing GameMinder)\r\n\r\n'
           '  Press a key to quit the game and return to GameMinder\r\n')
    msg = msg.replace('$', 'S').encode('cp437', 'replace') + b'$'
    code = bytes([
        0xBA, 0x10, 0x01,  # mov dx, 0110h  (message follows the 16 bytes of code)
        0xB4, 0x09,        # mov ah, 09h    print $-terminated string
        0xCD, 0x21,        # int 21h
        0xB4, 0x00,        # mov ah, 00h    wait for a key
        0xCD, 0x16,        # int 16h
        0xB8, 0x00, 0x4C,  # mov ax, 4C00h  exit
        0xCD, 0x21,        # int 21h
    ])
    return code + msg


def stand_in_bat(name):
    return f'''@echo off
cls
echo.
echo.
echo.
echo           ******************************************************
echo           *
echo           *     {name} would be running now...
echo           *
echo           *     (a stand-in batch file for testing GameMinder)
echo           *
echo           ******************************************************
echo.
echo           Press a key to quit the game and return to GameMinder
pause >nul
'''


def add_stand_in(game_dir, name, exec_line):
    """Create the program named by an exec: line, unless it's on another path"""
    program = exec_line.split()[0] if exec_line.strip() else ''
    if not program or ':' in program or '\\' in program:
        return
    path = f'{game_dir}/{program.upper()}'
    if program.upper().endswith('.BAT'):
        write(path, stand_in_bat(name))
    else:
        os.makedirs(game_dir, exist_ok=True)
        with open(path, 'wb') as f:
            f.write(stand_in_com(name))


def add_game(rel_dir, info, name, exec_line, log=None, stand_in=True):
    game_dir = f'{c}/GAMES/{rel_dir}'
    write(f'{game_dir}/!GM_INFO.TXT', info)
    if log:
        write(f'{game_dir}/!GM_LOG.TXT', log)
    if stand_in:
        add_stand_in(game_dir, name, exec_line)


def play_log(plays, minutes, rng):
    """Made up play history, so the stats and play sorts have something to show"""
    lines, left = [], minutes
    for i in range(plays):
        m = left if i == plays - 1 else rng.randint(0, max(0, left // (plays - i)))
        left -= m
        lines += [f'>2026/{9 + i * 2 // plays:02d}/{1 + i * 3 % 28:02d} {19 + i % 4}:{(i * 13) % 60:02d}', f'<{m}']
    return '\n'.join(lines) + '\n'


scan_path = 'C:\\GAMES;C:\\EXTRA' if args.edge_cases else 'C:\\GAMES'
write(f'{c}/GMIND/SETTINGS.TXT', f'ScanPath:{scan_path}\nDelayOnStartup:1200\n')

# ---- Well known games (also used for the README demo) ----

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

shareware = {'KEEN1', 'KEEN4', 'DOOM', 'WOLF3D', 'JAZZ', 'TYRIAN', 'OMF'}
memory = {'KEEN4': 520, 'DOOM': 560, 'XCOM': 590}
setup = {'DOOM': 'SETUP.EXE', 'DOOM2': 'SETUP.EXE', 'DUKE3D': 'SETUP.EXE', 'HERETIC': 'SETUP.EXE',
         'MONKEY2': 'SETSOUND.EXE', 'XCOM': 'SETSOUND.EXE', 'DUNE2': 'SETUP.EXE'}
notes = {'MONKEY1': 'Set the Roland MT-32 up in SETSOUND first',
         'CIV': 'Copy protection: look up the answers in the manual',
         'AITD': 'Bought on holiday - still need to try it'}

rng = random.Random(7)
for d, name, exe, dev, year, genre, video, sound, plays, minutes in games:
    info = f'name:{name}\nexec:{exe}\ndeveloper:{dev}\nyear:{year}\ngenre:{genre}\nvideo:{video}\nsound:{sound}\n'
    info += 'type:Shareware\n' if d in shareware else 'type:Full\n'
    if d in memory:
        info += f'memory:{memory[d]}\n'
    if d in setup:
        info += f'setup:{setup[d]}\n'
        add_stand_in(f'{c}/GAMES/{d}', f'{name} setup', setup[d])
    if d in notes:
        info += f'notes:{notes[d]}\n'
    add_game(d, info, name, exe, play_log(plays, minutes, rng) if plays else None)

# A game with no !GM_INFO.TXT yet, for Add to find - it should suggest RAP.EXE, not SETUP.EXE
for program in ('RAP.EXE', 'SETUP.EXE'):
    add_stand_in(f'{c}/GAMES/RAPTOR', 'Raptor', program)

# ---- Edge cases ----

if args.edge_cases:
    t = 'TESTS'
    # No name: the directory name is shown
    add_game(f'{t}/NONAME', 'exec:RUN.EXE\n', 'NONAME', 'RUN.EXE')
    # Longer than any column or panel
    long_name = 'The Extraordinarily Long Named Adventure of the Overly Verbose Developer, Special Edition'
    add_game(f'{t}/LONGNAME',
             f'name:{long_name}\nexec:LONG.EXE\ndeveloper:A Developer With A Remarkably Long Company Name Ltd\n'
             'year:1995\ngenre:Interactive Movie Adventure Role Playing\nvideo:VGA 320x200 256 colours\n'
             'sound:Sound Blaster 16 / Gravis Ultrasound / Roland\ntype:Full\n', long_name, 'LONG.EXE')
    # Program isn't there: "File not found", not counted as played
    add_game(f'{t}/MISSING', 'name:Missing Program\nexec:NOSUCH.EXE\ngenre:Test\ntype:Test\n',
             'Missing Program', 'NOSUCH.EXE', stand_in=False)
    # No exec line at all
    add_game(f'{t}/NOEXEC', 'name:No Exec Line\ngenre:Test\ntype:Test\n', 'No Exec Line', '')
    # before:/after: commands write C:\BEFORE.TXT and C:\AFTER.TXT
    add_game(f'{t}/SCRIPTS',
             'name:Before and After Commands\nexec:SCRIPTS.EXE\ngenre:Test\ntype:Test\n'
             'before:echo before > C:\\BEFORE.TXT\nafter:echo after > C:\\AFTER.TXT\n',
             'Before and After Commands', 'SCRIPTS.EXE')
    # Needs more memory than there is: warning before launching
    add_game(f'{t}/BIGMEM', 'name:Needs Too Much Memory\nexec:BIGMEM.EXE\nmemory:900\ngenre:Test\ntype:Test\n',
             'Needs Too Much Memory', 'BIGMEM.EXE')
    # Arguments after the program
    add_game(f'{t}/ARGS', 'name:Program With Arguments\nexec:ARGS.BAT one two\ngenre:Test\ntype:Test\n',
             'Program With Arguments', 'ARGS.BAT one two', stand_in=False)
    write(f'{c}/GAMES/{t}/ARGS/ARGS.BAT',
          '@echo off\necho.\necho Arguments received: [%1] [%2]\necho.\necho Press a key to return to GameMinder\npause >nul\n')
    # Untidy info file: comments, blank lines, mixed case keys, spaces, unknown keys, units
    add_game(f'{t}/MESSY',
             '; A comment\n\n  NAME :   Messy Info File   \nExec:messy.exe\nDEVELOPER:lower case dev\n'
             'Year:1990\nunknown:ignored\nnot a key value line\nmemory:512K\ntype:Freeware\ngenre:Test\n',
             'Messy Info File', 'messy.exe')
    # Play log with an unfinished session (crashed mid-game) and junk lines
    add_game(f'{t}/BADLOG', 'name:Odd Play Log\nexec:BADLOG.EXE\ngenre:Test\ntype:Demo\n', 'Odd Play Log', 'BADLOG.EXE',
             log='>2025/01/02 10:00\n<30\n>2025/01/03 11:00\njunk\n\n<abc\n>2025/01/04 12:00\n<15\n')
    # Deeply nested
    add_game(f'{t}/DEEP/ER/AND/DEEPER', 'name:Deeply Nested Game\nexec:DEEP.EXE\ngenre:Test\ntype:Demo\n',
             'Deeply Nested Game', 'DEEP.EXE')
    # Characters from the DOS code page
    add_game(f'{t}/ACCENTS', 'name:Über Café Señor\nexec:ACCENTS.EXE\ndeveloper:Ñandú Ölf\ngenre:Test\ntype:Demo\n',
             'Uber Cafe Senor', 'ACCENTS.EXE')
    # Setup program that isn't there
    add_game(f'{t}/NOSETUP', 'name:Missing Setup Program\nexec:NOSETUP.EXE\nsetup:NOSUCH.EXE\ngenre:Test\ntype:Test\n',
             'Missing Setup Program', 'NOSETUP.EXE')
    # Notes too long for one line of the info panel
    add_game(f'{t}/LONGNOTE',
             'name:Long Notes\nexec:NOTES.EXE\ngenre:Test\ntype:Test\n'
             'notes:Needs SETUP run for Sound Blaster on IRQ 5, then crashes on level 3 unless EMS is off\n',
             'Long Notes', 'NOTES.EXE')
    # In the second scan directory, C:\EXTRA
    write(f'{c}/EXTRA/STARGUN/!GM_INFO.TXT', 'name:Stargunner\nexec:STARGUN.EXE\ngenre:Shooter\ntype:Freeware\n')
    add_stand_in(f'{c}/EXTRA/STARGUN', 'Stargunner', 'STARGUN.EXE')
    # Program given with a full path, run from elsewhere
    add_game(f'{t}/FULLPATH', 'name:Program On Another Path\nexec:C:\\GAMES\\DOOM\\DOOM.EXE\ngenre:Test\ntype:Test\n',
             'Program On Another Path', 'C:\\GAMES\\DOOM\\DOOM.EXE')

# ---- Lots of games ----

if args.bulk:
    words = ['Space', 'Quest', 'Dungeon', 'Star', 'Night', 'Castle', 'Racer', 'Tank', 'Ninja', 'Galaxy',
             'Pirate', 'Robot', 'Dragon', 'Lost', 'Hyper', 'Mega', 'Super', 'Secret', 'Island', 'Fury']
    devs = ['Apogee', 'Sierra', 'Epic MegaGames', 'Origin', 'SSI', 'Psygnosis', 'Interplay', 'Accolade']
    genres = ['Platform', 'FPS', 'Adventure', 'Strategy', 'Puzzle', 'RPG', 'Racing', 'Sports', 'Shooter']
    types = ['Full', 'Shareware', 'Demo', 'Freeware']
    rng = random.Random(42)
    for i in range(1, args.bulk + 1):
        name = f'{rng.choice(words)} {rng.choice(words)} {i}'
        info = (f'name:{name}\nexec:GAME.EXE\ndeveloper:{rng.choice(devs)}\nyear:{rng.randint(1981, 1999)}\n'
                f'genre:{rng.choice(genres)}\ntype:{rng.choice(types)}\n')
        plays = rng.choice([0, 0, 0, 1, 2, 5, 12])
        add_game(f'BULK/G{i // 100:02d}/G{i:05d}', info, name, 'GAME.EXE',
                 play_log(plays, plays * rng.randint(5, 60), rng) if plays else None)
