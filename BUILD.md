# Building GameMinder

GameMinder builds with either **Turbo Pascal 7** (used for releases) or **Free Pascal** (used by GitHub Actions).

| | Turbo Pascal 7 | Free Pascal (i8086-msdos) |
|---|---|---|
| Launching games | ExecSwap: GameMinder swaps to EMS/disk, leaving a ~2KB stub | Plain DOS `Exec`: GameMinder stays in memory (heap capped at 192KB) |
| Use for | Releases, real hardware | CI builds and smoke tests |

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
2. Compile:
   ```
   ppcross8086 -Tmsdos -WmLarge -Mtp -Fu. -Fu$HOME/fpc-msdos/lib/fpc/3.2.2/units/i8086-msdos/* -obuild/dos/GAMEMIND.EXE GAMEMIND.PAS
   ```

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

The [release workflow](.github/workflows/release.yml) runs CI, then creates a **draft** GitHub release with a zip of the Free Pascal build and the changelog section as notes. Before publishing it, you can swap in a Turbo Pascal 7 build of `GAMEMIND.EXE` (recommended, so games get the memory ExecSwap frees). Versions with a pre-release suffix (e.g. `-beta.1`) are marked as pre-releases.
