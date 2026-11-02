# Changelog

All notable changes to GameMinder are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and GameMinder uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
While below 1.0.0, MINOR versions add features or change file formats and PATCH versions only fix bugs.

## [0.5.0] - 2026-11-02

### Added
- **Add** (or Ins) lists directories under `ScanPath` with a program in but no `!GM_INFO.TXT`, then opens a form to fill in the game's details. The name and program to run are suggested, skipping SETUP and INSTALL programs
- **Edit** opens a form with all of the highlighted game's details. Saving updates its `!GM_INFO.TXT`, keeping comments and anything GameMinder doesn't use. Name and Exec, which are needed, are marked with `*`
- **Delete** (or Del) removes the highlighted game from GameMinder after asking, by deleting its `!GM_INFO.TXT`. The game's files and play log are kept
- `scripts/testbed.sh` builds GameMinder with Turbo Pascal 7 in DOSBox-X and runs it on a test drive of games, including edge cases - see [Building & testing](BUILD.md#testbed)

### Changed
- **Theme** lists all the themes under the menu, like Sort. Left and right try each theme out, Enter keeps it and Esc goes back to the theme you had

### Fixed
- Building with Turbo Pascal 7: `EXECSWAP.TPU` was a Turbo Pascal 6 unit ("Error 72: Unit file format error"). It's now the Turbo Pascal 7 unit, which was in `TPU\`

## [0.4.0] - 2026-11-01

### Added
- Colour themes, defined one per line in `THEMES.TXT` next to `GAMEMIND.EXE`. Choose one with **Theme** in the menu - the choice is remembered in `SETTINGS.TXT`
- Seven themes to start with: Classic, Turbo, Commander, Mono, Amber, Phosphor and Hot Dog Stand
- README demo shows themes and the type field

### Fixed
- A game that fails to start because its program is missing is no longer counted as played

## [0.3.0] - 2026-11-01

### Added
- Games are remembered in `GMCACHE.TXT`, so startup no longer scans every directory. **Rescan** in the menu, or `GAMEMIND /SCAN`, looks for new or changed games. `CacheGames:false` turns this off
- `before:` and `after:` commands in `!GM_INFO.TXT`, run either side of a game e.g. to load and unload a mouse driver
- `type:` in `!GM_INFO.TXT` for Full, Demo, Shareware, Freeware etc. Shown in game info, sortable, and matched when filtering
- `memory:` in `!GM_INFO.TXT` (KB of conventional memory a game needs). Game info shows if it won't fit, and GameMinder asks before running it
- `GAMEMIND /50` starts in 50 line mode (43 on EGA), showing twice as many games
- System status shows the memory free for games
- If a program is left loaded in memory after a game (e.g. a TSR), GameMinder explains why it can't continue instead of exiting silently

### Changed
- `GAMEMIND.PAS` split into units for settings, screen layout, games list, panels, menu and running games
- `HighlightedRow` defaults to the middle of the list, whatever the screen size

## [0.2.1] - 2026-11-01

### Fixed
- The 0.2.0 download kept GameMinder in memory while a game ran, leaving games less conventional memory. GameMinder now swaps itself out to EMS or disk again, leaving only a ~2KB stub - games get within a few KB of the memory free at the DOS prompt

### Added
- `/RUN name` command line switch to run a game directly, e.g. `GAMEMIND /RUN keen`
- ExecSwap ported to Free Pascal (`EXECSWAP/FPC`), so builds from GitHub Actions swap the same way as Turbo Pascal builds
- CI measures the memory a game gets when run through GameMinder, swapping to EMS and to disk, against the DOS prompt

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
- Demo video in the README, recorded in DOSBox-X by `scripts/record-demo.sh`

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

[0.5.0]: https://github.com/MaverickUK/GameMinder/releases/tag/v0.5.0
[0.4.0]: https://github.com/MaverickUK/GameMinder/releases/tag/v0.4.0
[0.3.0]: https://github.com/MaverickUK/GameMinder/releases/tag/v0.3.0
[0.2.1]: https://github.com/MaverickUK/GameMinder/releases/tag/v0.2.1
[0.2.0]: https://github.com/MaverickUK/GameMinder/releases/tag/v0.2.0
[0.1.0]: https://github.com/MaverickUK/GameMinder/releases/tag/0.1.0
