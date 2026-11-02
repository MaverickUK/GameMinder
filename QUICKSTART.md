# Quick start

## Getting started

1. Download the latest zip from [Releases](https://github.com/MaverickUK/GameMinder/releases)
2. Unzip `GAMEMIND.EXE` and `SETTINGS.TXT` to a directory of your choice on a DOS machine (real or virtual), e.g. `C:\GMIND`
3. Edit `SETTINGS.TXT` and set **ScanPath** to the directory your games are in, e.g. `ScanPath:C:\GAMES`. It's searched recursively on startup, on any drive
4. Add your games: run GameMinder and choose **Add** (or press Ins) to pick a game directory and fill in its details. Or create a **!GM_INFO.TXT** file in each game's directory yourself (see below)
5. Run `GAMEMIND`. You can run it from any directory, e.g. `C:\GMIND\GAMEMIND`

If no games are found, GameMinder lists the directory it searched and exits. Check `ScanPath`, and that each game has a `!GM_INFO.TXT`.

## !GM_INFO.TXT format

This file holds the details GameMinder uses to list and run each game. It's made up of simple `key:value` lines. Lines starting with `;` are comments.

| Key | |
|---|---|
| **exec** | File to run: `.EXE`, `.COM` or `.BAT`, optionally followed by arguments **(required)** |
| **name** | Name of the game. If left out, the directory name is used |
| **developer** | Name of developer |
| **genre** | Genre of game |
| **year** | Year game was released |
| **video** | VGA, EGA, CGA etc. |
| **sound** | PC Speaker, Sound Blaster etc. |
| **type** | Full, Demo, Shareware, Freeware... |
| **memory** | Conventional memory the game needs in KB, e.g. `580`. GameMinder warns if it won't fit |
| **before** | Command run before the game, e.g. `C:\MOUSE\MOUSE.COM` |
| **after** | Command run after the game, e.g. `C:\MOUSE\MOUSE OFF` |

For example:

```
name:Commander Keen 1
exec:keen1.exe
developer:id software
genre:Platform
year:1991
video:EGA
sound:PC Speaker
```

Batch files are useful for games with several episodes or a setup step, e.g. `exec:start.bat`. Arguments can follow the file name, e.g. `exec:DOOM.EXE -nomonsters`.

`before:` and `after:` run either side of the game, in the game's directory. If `before:` loads something that stays in memory (a TSR such as a mouse driver), unload it with `after:` (e.g. `MOUSE OFF`), otherwise GameMinder can't get its memory back when the game exits. Drivers you always need are best loaded before starting GameMinder.

More examples are in the `EXAMPLES` directory of the zip.

## Controls

Up and down scroll the list of games. Left and right change the menu option at the top of the screen.

Page Up, Page Down, Home and End also scroll the games list.

Enter launches the highlighted game, unless a different menu option is selected. For example, if **Exit** is selected, Enter quits GameMinder.

Start typing to filter the list. For example, `KEEN` shows every game with Keen in its name, and `DEMO` every demo. Backspace edits the filter.

Esc clears the filter, or leaves a sub-menu (Sort or Filter). Otherwise it exits GameMinder.

| Key | |
|---|---|
| F1 | Show help |
| F2 | Show game information and play stats |
| F3 | Show system status (date, drive space, memory) |
| F4 | Full screen games list, with developer, genre and year |
| F5 | Sort games by name |
| F6 | Sort games by developer |
| F7 | Sort games by year |
| F8 | Sort games by genre |
| F9 | Sort games by times played |
| F10 | Sort games by total time played |
| Ins | Add a game |
| Del | Remove the highlighted game from GameMinder |

## Adding, editing and removing games

- **Add** (or Ins) lists the directories under `ScanPath` that have a program in them but no `!GM_INFO.TXT`. Choose one and GameMinder suggests a name and the program to run, then opens the game's details to check and fill in
- **Edit** opens the highlighted game's details
- In the details form, Up/Down move between fields, and **F10** (or Ctrl+S) saves. Esc cancels
- **Delete** (or Del) removes the highlighted game from GameMinder by deleting its `!GM_INFO.TXT`. The game's own files, and its play stats, are left alone - add it again to bring it back

GameMinder only changes the lines it uses in `!GM_INFO.TXT`, so your own comments stay put.

## Finding games

The first time GameMinder runs it searches `ScanPath` for games, then remembers them in `GMCACHE.TXT` next to `GAMEMIND.EXE`, so later startups are quick. After adding, removing or editing games, choose **Rescan** from the menu, or start GameMinder with `GAMEMIND /SCAN`.

## Play stats

While a game runs, GameMinder swaps itself out to EMS (or to a `SWAP.$$$` file on disk if there's no EMS), leaving only a ~2KB stub in memory, so games get almost all of your conventional memory. `UseEmsForSwapFile:false` always swaps to disk.

Each time you run a game, GameMinder records when you played it and for how long in a `!GM_LOG.TXT` file in the game's directory. F2 shows how many times you've played it, when you last played it, and your total play time. Games on read-only media such as CD-ROMs still run, but their stats aren't recorded.

To turn this off, set `EnablePlayStats:false`.

## Themes

Choose **Theme** in the menu and press Enter to list the themes under the menu. Left and right try each one out. Enter keeps the highlighted theme, and GameMinder remembers it in `SETTINGS.TXT`. Esc goes back to the theme you had.

Themes are in `THEMES.TXT`, next to `GAMEMIND.EXE`, one per line - a name, a colon, then the colour of each part of the screen:

```
Turbo: Background=Blue Text=Yellow Frame=LightGray HeadingText=White HeadingBack=Cyan HighlightText=Black HighlightBack=Green MenuText=White MenuHighlightText=Black MenuHighlightBack=Green
```

| Element | |
|---|---|
| `Background`, `Text`, `Frame` | Main screen |
| `HeadingText`, `HeadingBack` | Column and panel headings |
| `HighlightText`, `HighlightBack` | Highlighted game |
| `MenuText`, `MenuHighlightText`, `MenuHighlightBack` | Menu across the top |

Colours are names (Black, Blue, Green, Cyan, Red, Magenta, Brown, LightGray, DarkGray, LightBlue, LightGreen, LightCyan, LightRed, LightMagenta, Yellow, White) or numbers 0-15. Backgrounds can only be the first eight, Black to LightGray. Anything a theme leaves out uses the Classic colours, so add your own themes by adding a line.

## SETTINGS.TXT

All configurable options are in this file, with a comment explaining each one, so please have a poke and play. Highlights:

| Setting | |
|---|---|
| `ScanPath` | Directory to search for games |
| `CacheGames` | `false` to scan for games every time GameMinder starts |
| `MaxGames` | Most games to load (default 1,000, up to 16,000) |
| `DefaultSort` | Sort order on startup: `Name`, `Developer`, `Year`, `Genre`, `Type`, `TimesPlayed` or `TimePlayed` |
| `DefaultView` | Right hand panel on startup: `Help`, `Info`, `Status` or `Full` |
| `WaitForKeyAfterGame` | Pause after a game exits, to read any messages it left |
| `ExitScreen` | `false` to exit with a one-line message rather than the end screen showing what you played |
| `Theme` | Theme from `THEMES.TXT`, set by the Theme menu option |
| `Color...` | Individual colours, used when `Theme` is blank |

If `SETTINGS.TXT` is missing, GameMinder uses the defaults. It must be in the same directory as `GAMEMIND.EXE`.

## Command line

| | |
|---|---|
| `GAMEMIND /50` | Show 50 lines on VGA (43 on EGA), for more games on screen. Combine with other switches, e.g. `GAMEMIND /50 /SCAN` |
| `GAMEMIND /SCAN` | Scan for games rather than using the saved list, can be used with `/LIST` and `/RUN` |
| `GAMEMIND /V` | Show the version |
| `GAMEMIND /LIST` | Print the games found and exit, e.g. `GAMEMIND /LIST > GAMES.TXT` |
| `GAMEMIND /RUN name` | Run the first game whose name contains *name*, e.g. `GAMEMIND /RUN keen`, then exit |
| `GAMEMIND /?` | Show help |

## Current limitations

- Games can't yet be added, edited or deleted within GameMinder. Edit the `!GM_INFO.TXT` files directly
- See the [Roadmap](ROADMAP.md) for what's planned

## Reporting bugs and asking for features

Feel free to report bugs or ask for features on [GitHub issues](https://github.com/MaverickUK/GameMinder/issues) or in the [Vogons thread](https://www.vogons.org/viewtopic.php?t=89718).
