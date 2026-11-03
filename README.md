<p align="center">
  <img src="docs/gameminder-logo.png" alt="GameMinder logo: the name in yellow script across a white grid on DOS blue, above &quot;The games launcher for DOS&quot;" width="400">
</p>

# GameMinder
## :video_game: A lightweight DOS games launcher to let you easily find and launch your games

[![CI](https://github.com/MaverickUK/GameMinder/actions/workflows/ci.yml/badge.svg)](https://github.com/MaverickUK/GameMinder/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/MaverickUK/GameMinder?include_prereleases&sort=semver)](https://github.com/MaverickUK/GameMinder/releases)

[![GameMinder demo: browsing, sorting, filtering and launching games](docs/gameminder-demo.gif)](docs/gameminder-demo.mp4)

*GameMinder v0.7.0 in DOSBox-X: the startup screen, help, system status, full screen view with how much each game has been played, sorting, a game's notes, type-to-filter, launching a game from a batch file with play stats updated on return, adding a new game with its setup program suggested, choosing a colour theme, and the end screen on exit. [Watch as MP4](docs/gameminder-demo.mp4).*

[Watch demo of GameMinder running on a 386 on YouTube](https://www.youtube.com/watch?v=UGUtVTo1mUQ&list=PL10dNdIzl6W1UniVHwAFTED-wT_Ckrucw&index=7)

GameMinder was created after I took a holiday in Summer 2022 with my [Toshiba Libretto 100CT](https://www.strifestreams.com/search/libretto) and found navigating through DOS and attempting to identify all my names purely through 8 character file and directory names a little tricky. I also had issues remembering which of my games were just demos, weren't setup or ran with issues.

Through these frustrations I decided to scratch this specific itch by creating a lightweight DOS games launcher which could store meta data about each of the games. This allows for games to be grouped by genre, released date or to just check if a particular game has been setup on your system.

The UI is a tribute to [PathMinder](https://en.wikipedia.org/wiki/PathMinder) which is an DOS explorer utility I've fond memories of using whilst growing up. The logo is a nod to the grid and script lettering on the cover of PathMinder's manual, in the colours of GameMinder's Classic theme.

GameMinder also keeps track on when you've played a specific game and for how long. This is used to provide you with statistics and allow sorting of your games by popularity.

[A series of videos showing the development are available on YouTube](https://www.youtube.com/playlist?list=PL10dNdIzl6W1UniVHwAFTED-wT_Ckrucw)

## :rocket: [Quick start](QUICKSTART.md)

1. Download the latest zip from [Releases](https://github.com/MaverickUK/GameMinder/releases) and copy `GAMEMIND.EXE` and `SETTINGS.TXT` to your DOS machine
2. Copy `THEMES.TXT` too if you'd like colour themes, then set `ScanPath` in `SETTINGS.TXT` to your games directory (or several, separated by `;`)
3. Add a `!GM_INFO.TXT` file to each game's directory, e.g. `name:Commander Keen 1` and `exec:keen1.exe`
4. Run `GAMEMIND`

The [quick start guide](QUICKSTART.md) covers the `!GM_INFO.TXT` format, controls, play stats and settings.

## 📑 [Changelog](CHANGELOG.md)
## 🗺️ [Roadmap](ROADMAP.md)
## :computer: [Design](https://github.com/MaverickUK/GameMinder/wiki/Design)
## :hammer: [Building & testing](BUILD.md)

GameMinder follows [Semantic Versioning](https://semver.org).

## :clap: Credits
Helpful resources used in the creation of GameMinder
* [ExecWithSwap](https://www.pcorner.com/list/PASCAL/EXECSW13.ZIP/INFO/) by TurboPower Software - Allows execution of external program whilst leaving only a small 2K memory stub
* [Vogons](https://www.vogons.org/viewtopic.php?t=89718) for motivation support and testing

### Useful resources
* [ASCII codes lookup](https://www.ascii-codes.com/)
* [Keyboard scan codes](https://www.freepascal.org/docs-html/rtl/keyboard/kbdscancode.html)
* [Pascal programming](https://www.tutorialspoint.com/pascal/)
* [Pascal runtime error codes](https://there10han.wordpress.com/programming/pascal/free-pascal-exitcoderuntime-error-code/)

---

<p align="center">
  <img src="docs/gameminder-banner.png" alt="GameMinder banner: the name in yellow script across a white grid on DOS blue, beside &quot;The games launcher for DOS&quot;" width="100%">
</p>
