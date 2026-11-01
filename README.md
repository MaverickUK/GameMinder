# GameMinder
## :video_game: A lightweight DOS games launcher to let you easily find and launch your games

[![CI](https://github.com/MaverickUK/GameMinder/actions/workflows/ci.yml/badge.svg)](https://github.com/MaverickUK/GameMinder/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/MaverickUK/GameMinder?include_prereleases&sort=semver)](https://github.com/MaverickUK/GameMinder/releases)

[![GameMinder UI](GameMinder_v0-1-0.jpg)](https://www.youtube.com/playlist?list=PL10dNdIzl6W1UniVHwAFTED-wT_Ckrucw)

[Watch demo of GameMinder running on a 386 on YouTube](https://www.youtube.com/watch?v=UGUtVTo1mUQ&list=PL10dNdIzl6W1UniVHwAFTED-wT_Ckrucw&index=7)

GameMinder was created after I took a holiday in Summer 2022 with my [Toshiba Libretto 100CT](https://www.strifestreams.com/search/libretto) and found navigating through DOS and attempting to identify all my names purely through 8 character file and directory names a little tricky. I also had issues remembering which of my games were just demos, weren't setup or ran with issues.

Through these frustrations I decided to scratch this specific itch by creating a lightweight DOS games launcher which could store meta data about each of the games. This allows for games to be grouped by genre, released date or to just check if a particular game has been setup on your system.

The UI is a tribute to [PathMinder](https://en.wikipedia.org/wiki/PathMinder) which is an DOS explorer utility I've fond memories of using whilst growing up.

GameMinder also keeps track on when you've played a specific game and for how long. This is used to provide you with statistics and allow sorting of your games by popularity.

[A series of videos showing the development are available on YouTube](https://www.youtube.com/playlist?list=PL10dNdIzl6W1UniVHwAFTED-wT_Ckrucw)

## :rocket: Getting started

1. Download the latest zip from [Releases](https://github.com/MaverickUK/GameMinder/releases) and copy `GAMEMIND.EXE` and `SETTINGS.TXT` to a directory on your DOS machine (real or virtual)
2. Edit `SETTINGS.TXT` and set `ScanPath` to the directory holding your games. It's searched recursively on startup
3. Add a `!GM_INFO.TXT` file to the directory of each game you want GameMinder to list
4. Run `GAMEMIND`

### !GM_INFO.TXT format

A series of `key:value` lines. Lines starting with `;` are comments.

| Key | |
|---|---|
| `name` | Name of the game (falls back to the directory name) |
| `exec` | File to run: `.EXE`, `.COM` or `.BAT`, optionally followed by arguments **(required)** |
| `developer` | Name of developer |
| `genre` | Genre of game |
| `year` | Year game was released |
| `video` | VGA, EGA, CGA etc. |
| `sound` | PC Speaker, Sound Blaster etc. |

```
name:Commander Keen 1
exec:keen1.exe
developer:id software
genre:Platform
year:1991
video:EGA
sound:PC Speaker
```

More examples are in [examples](examples). Every option in `SETTINGS.TXT` is documented in the [file itself](SETTINGS.TXT).

### Controls

| Key | |
|---|---|
| Up / Down, PgUp / PgDn, Home / End | Move through the games list |
| Left / Right | Change the menu option |
| Enter | Run the highlighted game (or the selected menu option) |
| Type letters | Filter games by name, Backspace to edit |
| Esc | Clear the filter, leave a sub-menu, or exit |
| F1 / F2 / F3 / F4 | Help / game info / system status / full screen list |
| F5 / F6 / F7 / F8 | Sort by name / developer / year / genre |
| F9 / F10 | Sort by times played / time played |

Command line: `GAMEMIND /V` shows the version, `GAMEMIND /LIST` prints the games found.

## 📑 [Changelog](CHANGELOG.md)
## 🗺️ [Roadmap](https://github.com/MaverickUK/GameMinder/wiki/Roadmap)
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
