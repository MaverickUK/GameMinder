# Quick start

## Getting started

1. Download the latest zip from [Releases](https://github.com/MaverickUK/GameMinder/releases)
2. Unzip `GAMEMIND.EXE` and `SETTINGS.TXT` to a directory of your choice on a DOS machine (real or virtual), e.g. `C:\GMIND`
3. Edit `SETTINGS.TXT` and set **ScanPath** to the directory your games are in, e.g. `ScanPath:C:\GAMES`. It's searched recursively on startup, on any drive
4. For each game you want GameMinder to list, create a **!GM_INFO.TXT** file in the game's directory (see below)
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

More examples are in the `EXAMPLES` directory of the zip.

## Controls

Up and down scroll the list of games. Left and right change the menu option at the top of the screen.

Page Up, Page Down, Home and End also scroll the games list.

Enter launches the highlighted game, unless a different menu option is selected. For example, if **Exit** is selected, Enter quits GameMinder.

Start typing to filter the list. For example, `KEEN` shows every game with Keen in its name. Backspace edits the filter.

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

## Play stats

Each time you run a game, GameMinder records when you played it and for how long in a `!GM_LOG.TXT` file in the game's directory. F2 shows how many times you've played it, when you last played it, and your total play time. Games on read-only media such as CD-ROMs still run, but their stats aren't recorded.

To turn this off, set `EnablePlayStats:false`.

## SETTINGS.TXT

All configurable options are in this file, with a comment explaining each one, so please have a poke and play. Highlights:

| Setting | |
|---|---|
| `ScanPath` | Directory to search for games |
| `MaxGames` | Most games to load (default 1,000, up to 16,000) |
| `DefaultSort` | Sort order on startup: `Name`, `Developer`, `Year`, `Genre`, `TimesPlayed` or `TimePlayed` |
| `DefaultView` | Right hand panel on startup: `Help`, `Info`, `Status` or `Full` |
| `WaitForKeyAfterGame` | Pause after a game exits, to read any messages it left |
| `Color...` | Colour theme |

If `SETTINGS.TXT` is missing, GameMinder uses the defaults. It must be in the same directory as `GAMEMIND.EXE`.

## Command line

| | |
|---|---|
| `GAMEMIND /V` | Show the version |
| `GAMEMIND /LIST` | Print the games found and exit, e.g. `GAMEMIND /LIST > GAMES.TXT` |
| `GAMEMIND /?` | Show help |

## Current limitations

- Games can't yet be added, edited or deleted within GameMinder. Edit the `!GM_INFO.TXT` files directly
- See the [Roadmap](ROADMAP.md) for what's planned

## Reporting bugs and asking for features

Feel free to report bugs or ask for features on [GitHub issues](https://github.com/MaverickUK/GameMinder/issues) or in the [Vogons thread](https://www.vogons.org/viewtopic.php?t=89718).
