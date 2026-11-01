# Roadmap

What's being worked on for the next version and beyond. Completed items are crossed out with the version that delivered them. See [CHANGELOG.md](CHANGELOG.md) for full details of each release.

Ideas and bug reports are welcome on [GitHub issues](https://github.com/MaverickUK/GameMinder/issues) or the [Vogons thread](https://www.vogons.org/viewtopic.php?t=89718).

## Now (MVP)

- ~~Split code into separate files~~ (0.2.0)
- ~~Fix: launching GameMinder by its full path fails~~ (0.2.0)
- ~~Fix: scan path must end with a backslash~~ (0.2.0)
- ~~Fix: only the C: drive works~~ (0.2.0)
- ~~Fix: batch files can't be used to launch games, only .exe files~~ (0.2.0, [#1](https://github.com/MaverickUK/GameMinder/issues/1))
- ~~Fix: crash at startup with a single game (Tiny Llama 2)~~ (0.2.0)
- ~~Filter the games list by typing~~ (0.2.0, matches anywhere in the name e.g. `KEEN`)
- ~~Esc to exit instantly~~ (0.2.0)
- ~~F3 System Status~~ (0.2.0)
- ~~More extendable horizontal menu~~ (0.2.0)
- ~~Semantic versioning, unit tests and GitHub Actions builds~~ (0.2.0)
- ~~Release builds swap GameMinder out of memory while games run~~ (0.2.1, ExecSwap ported to Free Pascal)
- ~~Run a game from the command line~~ (0.2.1, `GAMEMIND /RUN name`)
- ~~Split GAMEMIND.PAS into units~~ (0.3.0)
- ~~Remember games between runs, with a rescan option~~ (0.3.0, `GMCACHE.TXT`, Rescan menu option and `/SCAN`)
- ~~Type of game: full, demo, shareware, freeware~~ (0.3.0, `type:`)
- ~~More rows on screen~~ (0.3.0, `GAMEMIND /50`)
- ~~Warn when a game needs more memory than is free~~ (0.3.0, `memory:`)
- Configure which columns are shown in half and full screen mode, and their widths, in `SETTINGS.TXT`
- ASCII splash screen on exit

## Next (planned)

- ~~Raise the 100 game limit~~ (0.2.0, games held on the heap; default 1,000, up to 16,000 with `MaxGames`)
- ~~Sort by play stats: times played and total time played~~ (0.2.0)
- ~~Config options: default sort mode and default display mode on startup~~ (0.2.0, `DefaultSort` and `DefaultView`)
- ~~Config option: wait for a key press after a game exits~~ (0.2.0, `WaitForKeyAfterGame`)
- Popularity indicator in the games list (a single shaded ASCII character, can be turned off in `SETTINGS.TXT`)
- ~~Automatically load the mouse driver for games that need a mouse~~ (0.3.0, `before:` and `after:` commands)
- Config option: custom date/time formatting
- Customise what the function keys (e.g. F5) do in `SETTINGS.TXT`
- Add, edit and delete games within GameMinder

## Later (undecided)

- Detect games automatically from a CSV database matching file names (and possibly sizes), perhaps a shared Google Sheet exported as CSV
- Integrate with the [IGDB](https://www.igdb.com/) website
- Optionally store game metadata centrally instead of in each game's directory
