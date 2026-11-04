# Changelog

All notable changes to GameMinder are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and GameMinder uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
While below 1.0.0, MINOR versions add features or change file formats and PATCH versions only fix bugs.

## [Unreleased]

### Added
- Memory map (F4): what's loaded in memory while a game runs, like `MEM /C`. A map of conventional memory in 5KB blocks, with upper memory below it, shows each driver and program in its own colour, DOS shaded dark and free memory light. Below it a list of DOS, device drivers such as HIMEM and EMM386, TSRs such as MOUSE and MSCDEX, and GameMinder, with how much each uses in low and high memory. GameMinder is shown as the few KB it leaves behind when a game runs, so free memory matches the Status panel, with a note of what it uses until it's swapped out. If the highlighted game has `memory:` set, it says whether the game fits and by how much. EMM386's 64KB EMS page frame shows in upper memory. When there are more programs than fit, the list scrolls slowly. On DOS 3, which doesn't record program names, names come from each program's environment. `DefaultView:Memory` in `SETTINGS.TXT` opens it on startup

### Changed
- Full screen is no longer on F4. Press the key for the panel that's showing (F1-F4) again to switch to the full screen games list, and once more to go back
- System status (F3) shows conventional memory as a bar, solid for what's free for games and shaded for what DOS and drivers use, with free EMS and XMS memory below it. The GameMinder heap line is gone

## [0.7.0] - 2026-11-03

### Added
- `setup:` in `!GM_INFO.TXT` for a game's setup program, e.g. `setup:SETUP.EXE`. For these games **Run** opens a second menu, **Game** or **Setup**, so sound, video and controls can be set up from GameMinder. Running setup isn't counted as a play. **Add** suggests a setup program it finds (SETUP, SETSOUND, SOUND, SETMAIN or CONFIG)
- `notes:` in `!GM_INFO.TXT` for anything to remember about a game, e.g. that it needs the CD in the drive. Notes are shown under the game's details (F2), and both fields are in the Add and Edit form
- Popularity indicator: a shaded block after each game in the list showing how much it's been played compared to your most played game, from blank (never played) through ░ ▒ ▓ to █. `PopularityIndicator:false` in `SETTINGS.TXT` hides it
- `ScanPath` can list several directories separated by `;`, e.g. `ScanPath:C:\GAMES;D:\GAMES`. Directories inside another listed directory are only searched once

## [0.6.1] - 2026-11-02

### Fixed
- GameMinder hung at startup, before showing anything, on PCs without a maths coprocessor, such as many 386s. This affected every release built with Free Pascal (v0.2.0 onwards)

## [0.6.0] - 2026-11-02

### Added
- End screen on exit, like the ones DOS games left behind: the GameMinder logo, the games you played this session and for how long, your library's totals and most played game. It stays above the DOS prompt, with no key to press. `ExitScreen:false` in `SETTINGS.TXT` turns it off

### Changed
- Startup screen in the style of Doom's, showing what GameMinder is doing: settings, themes, memory free for games (including EMS), the games scan with a progress bar, and play stats logged

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

[0.6.1]: https://github.com/MaverickUK/GameMinder/releases/tag/v0.6.1
[0.6.0]: https://github.com/MaverickUK/GameMinder/releases/tag/v0.6.0
[0.5.0]: https://github.com/MaverickUK/GameMinder/releases/tag/v0.5.0
[0.4.0]: https://github.com/MaverickUK/GameMinder/releases/tag/v0.4.0
[0.3.0]: https://github.com/MaverickUK/GameMinder/releases/tag/v0.3.0
[0.2.1]: https://github.com/MaverickUK/GameMinder/releases/tag/v0.2.1
[0.2.0]: https://github.com/MaverickUK/GameMinder/releases/tag/v0.2.0
[0.1.0]: https://github.com/MaverickUK/GameMinder/releases/tag/0.1.0
