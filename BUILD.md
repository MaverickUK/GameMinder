# Building GameMinder

GameMinder builds with either **Turbo Pascal 7** or **Free Pascal**. Releases are built by GitHub Actions with Free Pascal.

Both use ExecSwap (TurboPower Software) to launch games: GameMinder swaps itself out to EMS or disk, leaving a ~2KB stub, so games get almost all conventional memory.

| | Turbo Pascal 7 | Free Pascal (i8086-msdos) |
|---|---|---|
| ExecSwap | `EXECSWAP.TPU`, source in [EXECSWAP](EXECSWAP) (TASM) | [EXECSWAP/FPC](EXECSWAP/FPC): Pascal unit plus `SWAPCORE.ASM` (NASM) |
| Use for | Local builds | Releases, CI builds and tests |

## Source layout

| File | |
|---|---|
| `GAMEMIND.PAS` | Startup, command line and main loop |
| `PREFS.PAS` | Settings from `SETTINGS.TXT` |
| `SCREEN.PAS` | Screen layout, frame and panel drawing |
| `LISTVIEW.PAS` | Games list, scrolling, sorting and filtering |
| `PANELS.PAS` | Help, game info and system status panels |
| `MENU.PAS` | Horizontal menu |
| `RUNNER.PAS` | Running games: swapping, before/after commands, memory check, play stats |
| `GAMES.PAS` | Games data: info files, play logs, cache, sorting, filtering |
| `LAUNCH.PAS` | Working out the command to run a game |
| `CONFIG.PAS` | Reading and updating `SETTINGS.TXT` |
| `THEMES.PAS` | Colour themes from `THEMES.TXT` |
| `UTILITY.PAS` | Strings, paths, dates |

`GAMES`, `LAUNCH`, `CONFIG`, `PREFS`, `THEMES` and `UTILITY` don't use the screen, so they're unit tested on any OS.

## Turbo Pascal 7

From the repository directory in DOS or DOSBox:

```
TPC /M GAMEMIND.PAS
```

This uses the prebuilt `EXECSWAP.TPU`. The ExecSwap source (TurboPower Software, v1.3) is in [EXECSWAP](EXECSWAP) if you want to rebuild it with TASM:

```
CD EXECSWAP
TASM EXECSWAP.ASM
TPC EXECSWAP.PAS
COPY EXECSWAP.TPU ..
```

Copy `GAMEMIND.EXE` and `SETTINGS.TXT` to a directory on the DOS machine.

## Free Pascal

The [CI workflow](.github/workflows/ci.yml) shows the full steps. In summary:

1. Build an FPC 3.2.2 i8086-msdos cross compiler (large memory model) from the FPC source:
   ```
   make crossall crossinstall CPU_TARGET=i8086 OS_TARGET=msdos CROSSOPT="-WmLarge -CX -XX" INSTALL_PREFIX=$HOME/fpc-msdos
   ```
2. Assemble the ExecSwap core with [NASM](https://www.nasm.us/):
   ```
   nasm -f obj -o EXECSWAP/FPC/SWAPCORE.OBJ EXECSWAP/FPC/SWAPCORE.ASM
   ```
3. Compile:
   ```
   ppcross8086 -Tmsdos -WmLarge -Mtp -Fu. -FuEXECSWAP/FPC -FoEXECSWAP/FPC -Fu$HOME/fpc-msdos/lib/fpc/3.2.2/units/msdos/* -obuild/dos/GAMEMIND.EXE GAMEMIND.PAS
   ```

The swap core is linked into the same code segment as Free Pascal's startup code, which comes first in memory, so only the startup code and the core (~2KB) stay resident while a game runs.

## Tests

The logic units (`UTILITY`, `CONFIG`, `GAMES`, `LAUNCH`) don't touch the screen, so they're tested natively with Free Pascal on Linux, macOS or Windows:

```
mkdir -p build
fpc -Mtp -Fu. -FUbuild -obuild/tests tests/TESTS.PAS
build/tests
```

The tests also compile with Turbo Pascal 7. Run them in DOS by passing the fixtures directory:

```
TPC /M TESTS\TESTS.PAS
TESTS\TESTS TESTS\FIXTURES\
```

CI also runs `TESTS.EXE` and `GAMEMIND /LIST` in DOSBox against the games in [tests/fixtures](tests/fixtures).

It checks how much memory GameMinder leaves for games too: [tests/MEMFREE.PAS](tests/MEMFREE.PAS) records the conventional memory it's given, run from the DOS prompt and through `GAMEMIND /RUN memory`, swapping to EMS and to disk. The build fails if a game gets more than 8KB less than at the DOS prompt.

## Demo video

The README demo is recorded in DOSBox-X from a scripted set of key presses. Nothing is shown on screen while it records. To re-record it with a new build (needs `dosbox-x` and `ffmpeg`):

```
gh run download <run-id> -n gamemind-dos -D build/dos
scripts/record-demo.sh build/dos/GAMEMIND.EXE
```

This writes `docs/gameminder-demo.gif` and `docs/gameminder-demo.mp4`. The key sequence is in the script.

## Releasing

GameMinder uses [Semantic Versioning](https://semver.org). While below 1.0.0, MINOR versions add features or change file formats and PATCH versions only fix bugs.

1. Update `AppVersion` in [VERSION.INC](VERSION.INC) (e.g. `0.2.0`, or `0.2.0-beta.1` for a test build).
2. Move the `Unreleased` changes in [CHANGELOG.md](CHANGELOG.md) under a heading with that version and date.
3. Check they match: `scripts/check-version.sh`
4. Commit, then tag and push: `git tag v0.2.0 && git push origin v0.2.0`

The [release workflow](.github/workflows/release.yml) runs CI, then creates a **draft** GitHub release with a zip of the Free Pascal build and the changelog section as notes. Review it on GitHub, then publish. Versions with a pre-release suffix (e.g. `-beta.1`) are marked as pre-releases.
