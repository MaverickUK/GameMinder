# GameMinder
## :video_game: A lightweight DOS games launcher to let you easily find and launch your games

[![GameMinder WIP](https://img.youtube.com/vi/tkKVguKeelc/0.jpg)](https://www.youtube.com/watch?v=tkKVguKeelc)

GameMinder was created after I took a holiday in Summer 2022 with my [Toshiba Libretto 100CT](https://www.strifestreams.com/search/libretto) and found navigating through DOS and attempting to identify all my names purely through 8 character file and directory names a little tricky. I also had issues remembering which of my games were just demos, weren't setup or ran with issues.

Through these frustrations I decided to scratch this specific itch by creating a lightweight DOS games launcher which could store meta data about each of the games. This allows for games to be grouped by genre, released date or to just check if a particular game has been setup on your system.

The UI is a tribute to [PathMinder](https://en.wikipedia.org/wiki/PathMinder) which is an DOS explorer utility I've fond memories of using whilst growing up.

GameMinder also keeps track on when you've played a specific game and for how long. This is used to provide you with statistics and allow sorting of your games by popularity.

## :computer: Implementation
Written in Turbo Pascal 7 it makes use of a file named `!GM_INFO.TXT` existing within each of the game directories to hold the meta data about each game

```
name:Commander Keen 1
developer:id Software
year:1991
genre:Platform
video:EGA
sound:PC Speaker
```

On startup GameMinder recursively searches a specific directory (e.g. `C:\GAMES`) for these files in order to create the games listing. This approach was choosen to make it easy to manage the game meta data externally to GameMinder.

When is a game is launched GameMinder saves itself into EMS memory or to disk leaving only a 2K stub behind in order to relaunch GameMinder once the game has finished executing.

Statistics about the number and playtime length of each game is held in the `!GM_LOG.TXT` file in each game directory. Each line in the file represents a game launch with the date and time, following by the playtime in seconds (if successfully completed).

## TODO 
### :green_heart: Now (MVP)
* ✔️ ~Scrollable list of games~ 
* ✔️ ~Launch game by pressing `enter`~
* ✔️ ~Return to GameMinder when game exits~
* ✔️ ~Minimize memory footprint~ 
* ✔️ 2022/09/01 ~Automatically scan for games on startup~ 
* ✔️ 2022/09/05 ~ASCII modal on scanning ( `Scanning C:/games/...` )~
* ✔️ 2022/09/01 ~Load `!GM_INFO.TXT` files into in memory record~
* ✔️ 2022/09/07 ~Ordering of games list~
* ✔️ 2022/09/07 ~Show current sort order~
* ✔️ 2022/09/05 ~ASCII splash screen on start~
* ASCII splash screen on exit
* ✔️ 2022/09/09 ~Log each gameplay date time & length to `!GM_LOG.TXT` file~
* ✔️ 2022/09/07 ~Display game info & metrics in right panel~
* ✔️ 2022/09/05 ~Load configuration from external file~
* If no games found on startup, show help message and exit

### :blue_heart: Next
* Increase the max games limit from 100
* Automatically load mouse driver, for games that require a mouse
* Config option: Default sort mode on startup
* Config option: Disable play stats tracking
* Config option: Default display mode on startup
* Config option: Press key to continue, after game exists
* Config option: Specify datetime formatting
* ✔️ 2022/09/09 ~Config option: Specifiy colour themes~
* Filtering: Enter first X characters of game name to filter list
* Allow new games to be added in GameMinder
* Edit existing games in GameMinder
* Delete games from GameMinder

### :heart: Later
* Use CSV database with filename (& size?) to automatically detect games (Could this just be a shared Google Sheet which downloads as a CSV?)
* Tie into igdb.com website (how?)
* Optionally allow game meta data to stored centrally, rather than in individual game directories

## :clap: Credits
List the websites used to help build this
* [ExecWithSwap](https://www.pcorner.com/list/PASCAL/EXECSW13.ZIP/INFO/) - Allows execution of external program whilst leaving only a small 2K memory stub
* [ASCII codes lookup](https://www.ascii-codes.com/)
