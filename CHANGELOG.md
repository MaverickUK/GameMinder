# Changelog

All notable changes to GameMinder are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and GameMinder uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
While below 1.0.0, MINOR versions add features or change file formats and PATCH versions only fix bugs.

## [0.2.0] - 2026-11-01

### Added
- Type to filter the games list by name (e.g. `KEEN` shows every Commander Keen game). Backspace edits, Esc clears
- Support for well over 1,000 games, set with `MaxGames` in `SETTINGS.TXT` (previously 100)
- Sort by times played (F9) and total time played (F10)
- `DefaultSort`, `DefaultView`, `WaitForKeyAfterGame` and `MaxGames` settings
- F3 System Status now shows real drive, memory and game counts
- `exec:` can include arguments, e.g. `exec:DOOM.EXE -nomonsters`
- `/V`, `/LIST` and `/?` command line switches
- Version number follows SemVer, shown in the menu bar and with `/V`
- Sample `SETTINGS.TXT` documenting every option, and example `!GM_INFO.TXT` files
- Unit tests that run on Linux with Free Pascal and as a 16-bit DOS program
- GitHub Actions: unit tests, a Free Pascal DOS build, a DOSBox smoke test and a packaged release zip on every change; tags create a draft release
- Builds with Free Pascal (i8086-msdos) as well as Turbo Pascal 7 - see [BUILD.md](BUILD.md)
- ExecSwap v1.3 source (in `EXECSWAP/`) alongside the prebuilt unit
- [QUICKSTART.md](QUICKSTART.md) guide, also included in the release zip
- [ROADMAP.md](ROADMAP.md), replacing the wiki roadmap

### Changed
- Esc now exits straight away from the main menu (clears the filter or leaves a sub-menu first)
- Sorting is case-insensitive
- `SETTINGS.TXT` is read once at startup, which speeds up starting on slow disks
- `!GM_INFO.TXT` keys are case-insensitive, values are trimmed and lines are no longer cut off at 50 characters
- A game without a `name:` uses its directory name
- Logic split into `CONFIG` (was `SETTINGS`), `GAMES` and `LAUNCH` units, separate from the screen code
- Horizontal menus are defined as tables, making new options easier to add

### Fixed
- Batch files (`.BAT`) can be used as `exec:`. Previously they failed or rebooted the PC ([#1](https://github.com/MaverickUK/GameMinder/issues/1))
- Games on drives other than C: fail to launch with runtime error 003
- Running GameMinder from another directory (e.g. `C:\GMIND\GAMEMIND`) fails with runtime error 005
- `ScanPath` must end with a backslash
- Crash at startup when only one game is found (reported on a Tiny Llama 2 with QEMM)
- Missing `SETTINGS.TXT`, or games on read-only media such as CD-ROMs, crash GameMinder
- Play time is wrong for sessions that run past midnight
- Page Up near the top of the list jumps to the wrong game
- Highlighted game ignores the `ColorHighlight*` settings
- Directories with the archive or read-only attribute are skipped while scanning
- Screen is left in graphics mode after some games exit
- Cursor hiding doesn't work on monochrome (MDA/Hercules) displays
- Long names, developers and genres run into the next column in full screen view

## [0.1.0] - 2022-09-09

Initial preview release.

### Added
- Scrollable games list
- Launch games, leaving a 2KB memory stub while they run
- Scan for games on startup
- Game details loaded from `!GM_INFO.TXT` files
- Sort games list by name, developer, genre or release year
- Splash screen on startup
- Date, time and length of play recorded in `!GM_LOG.TXT` files
- Settings loaded from `SETTINGS.TXT`
- Help message if no games are found on startup
- Colour theme settings
- Setting to turn off play stats

[0.2.0]: https://github.com/MaverickUK/GameMinder/releases/tag/v0.2.0
[0.1.0]: https://github.com/MaverickUK/GameMinder/releases/tag/0.1.0
