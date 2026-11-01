Program GameMind;
{-----------------------------
GameMinder - a lightweight DOS games launcher
https://github.com/MaverickUK/GameMinder

Startup, command line and the main input loop. The rest lives in units:
  PREFS     settings          LISTVIEW  games list       RUNNER   running games
  SCREEN    layout & frame    PANELS    right hand panel GAMES    games data
  MENU      horizontal menu   LAUNCH    launch commands  CONFIG   SETTINGS.TXT
------------------------------}
uses
    Dos,
    Crt, { https://theasciicode.com.ar/extended-ascii-code/graphic-character-high-density-dotted-ascii-code-178.html }
    { GameMinder modules }
    Utility,
    Games,
    Prefs,
    Screen,
    ListView,
    Menu,
    Panels,
    Runner,
    { Launch external executable - Must keep ExecSwap last.
      Turbo Pascal uses EXECSWAP.TPU, Free Pascal uses EXECSWAP\FPC\EXECSWAP.PAS }
    ExecSwap;

var
  ListOnly:boolean;  { /LIST - print games and exit }
  RunName:string;    { /RUN - run the first game whose name contains this, then exit }
  ForceScan:boolean; { /SCAN - scan for games rather than using the cache }

{ ////////////////// Loading games ////////////////// }

procedure SaveCache;
begin
  if ( CacheGames ) then
    SaveGameCache(ExeDir + CacheFileName, ScanPath, InfoFileName);
end;

{ Load games from the cache, or scan for them if there's no cache or scan is true.
  Returns true if the games came from the cache }
function LoadGames(scan:boolean):boolean;
begin
  LoadGames := false;
  InitGames(MaxGames);
  PlayStatsEnabled := EnablePlayStats;

  if not scan and CacheGames then
    if LoadGameCache(ExeDir + CacheFileName, ScanPath, InfoFileName) and ( GameCount > 0 ) then begin
      LoadGames := true;
      exit;
    end;

  InitGames(MaxGames);
  ScanForInfoFiles(ScanPath, InfoFileName);
  if ( GameCount > 0 ) then SaveCache;
end;

{ ////////////////// Screen ////////////////// }

{ Redraw everything }
procedure RedrawAll;
begin
  SetupScreen(All);
  renderHorizonalMenu;
  scrollingList;
  drawPanel;
end;

{ Plain text screen used while scanning and running games }
procedure ShowTitleScreen;
begin
  TextColor(White);
  TextBackground(Black);
  clrscr;

  TextColor(White);
  TextBackground(Blue);
  DrawCenter(ApplicationName);

  TextColor(White);
  TextBackground(Black);
end;

{ ////////////////// Actions ////////////////// }

{ Start the currently selected game }
procedure ExecuteGame;
var
  game:PGame;
begin
  game := HighlightedGame;
  if ( game = nil ) then exit;

  if ( LaunchGame(game, true) <> LaunchCancelled ) then
    SaveCache; { Updated play stats }

  { Restart Gameminder UI }
  ApplyScreenMode;
  HideCursor;
  RedrawAll;
end;

{ Scan for games again, keeping the sort, filter and highlighted game }
procedure RescanGames;
var
  sortMode:TSortMode;
  filter:string;
  highlightedPath:string;
  i:integer;
begin
  sortMode := CurrentSort;
  filter := CurrentFilter;
  highlightedPath := '';
  if ( HighlightedGame <> nil ) then highlightedPath := PStr(HighlightedGame^.Path);

  ShowTitleScreen;
  writeln('Scanning ', ScanPath, ' for ', InfoFileName, ' files');
  ShowScanProgress := true;
  LoadGames(true);
  ShowScanProgress := false;

  CurrentFilter := filter;
  SortGames(sortMode);

  scrollTo(0);
  for i := 0 to ViewCount - 1 do
    if ( PStr(ViewGame(i)^.Path) = highlightedPath ) then scrollTo(i);

  RedrawAll;
end;

{ ////////////////// Command line ////////////////// }

procedure ShowUsage;
begin
  writeln(ApplicationName, ' - DOS games launcher');
  writeln('');
  writeln('GAMEMIND [/50] [/SCAN] [/LIST] [/RUN name] [/V] [/?]');
  writeln('');
  writeln('  /50        Show 50 lines on VGA (43 on EGA), for more games on screen');
  writeln('  /SCAN      Scan for games rather than using the saved list');
  writeln('  /LIST      Print the games found and exit');
  writeln('  /RUN name  Run the first game whose name contains name, then exit');
  writeln('  /V         Show version');
  writeln('  /?         Show this help');
end;

{ Handle command line switches }
procedure ParseCommandLine;
var
  i:integer;
  param:string;
begin
  ListOnly := false;
  RunName := '';
  ForceScan := false;

  i := 1;
  while ( i <= ParamCount ) do begin
    param := UpStr(ParamStr(i));
    if ( param = '/V' ) or ( param = '-V' ) or ( param = '/VERSION' ) then begin
      Assign(Output, '');
      Rewrite(Output);
      writeln(ApplicationName);
      Halt(0);
    end
    else if ( param = '/50' ) or ( param = '-50' ) or ( param = '/43' ) or ( param = '-43' ) then
      ScreenLines := 50
    else if ( param = '/SCAN' ) or ( param = '-SCAN' ) then
      ForceScan := true
    else if ( param = '/LIST' ) or ( param = '-LIST' ) then
      ListOnly := true
    else if ( ( param = '/RUN' ) or ( param = '-RUN' ) ) and ( i < ParamCount ) then begin
      inc(i);
      RunName := ParamStr(i);
    end
    else begin
      Assign(Output, '');
      Rewrite(Output);
      ShowUsage;
      if ( param = '/?' ) or ( param = '-?' ) or ( param = '/H' ) then Halt(0) else Halt(1);
    end;
    inc(i);
  end;

  { /LIST and /RUN only produce text, so use DOS output rather than Crt,
    allowing it to be redirected e.g. GAMEMIND /LIST > GAMES.TXT }
  if ( ListOnly ) or ( length(RunName) > 0 ) then begin
    Assign(Output, '');
    Rewrite(Output);
  end;
end;

{ /RUN - run a game by name without the UI, exit code is non-zero if it couldn't be run }
procedure RunGame;
var
  status:word;
begin
  LoadSettingsFile;
  LoadGames(ForceScan);
  SortGames(smName);
  ApplyFilter(RunName);

  if ( ViewCount = 0 ) then begin
    writeln('No game found matching "', RunName, '"');
    DoneGames;
    Halt(1);
  end;

  status := LaunchGame(ViewGame(0), false);
  SaveCache;
  DoneGames;
  if ( status <> 0 ) then Halt(2);
end;

{ /LIST - print games to standard output so it can be redirected to a file }
procedure ListGames;
var
  i,found:integer;
  game:PGame;
begin
  LoadSettingsFile;
  LoadGames(ForceScan);
  SortGames(smName);

  for i := 0 to ViewCount - 1 do begin
    game := ViewGame(i);
    writeln(PStr(game^.Name), '|', PStr(game^.Path), '|', PStr(game^.Exec));
  end;

  found := GameCount;
  writeln(found, ' game(s) found');
  DoneGames;
  if ( found = 0 ) then Halt(1);
end;

{ ////////////////// Startup ////////////////// }

procedure Startup;
begin
  ShowTitleScreen;

  writeln('Using setup file ', ExeDir, SettingsFileName);
  if not LoadSettingsFile then begin
    TextColor(Yellow);
    writeln('Setup file not found, using default settings');
    TextColor(White);
  end;
  writeln('');

  writeln('Looking for games in ', ScanPath);
  ShowScanProgress := true;
  if LoadGames(ForceScan) then
    writeln('Loaded ', GameCount, ' game(s) from ', CacheFileName, ' - use Rescan to look for new games')
  else if ( GameCount > 0 ) then begin
    writeln('');
    writeln('Scanned ', ScanPath, ', ', GameCount, ' game(s) found');
  end;
  ShowScanProgress := false;

  if ( GameCapReached ) then begin
    TextColor(Yellow);
    writeln('Only the first ', MaxGames, ' games were loaded - increase MaxGames in ', SettingsFileName);
    TextColor(White);
  end;

  if ( GameCount = 0 ) then begin
    TextColor(Red);
    writeln('');
    writeln('No ', InfoFileName, ' files found under any directories in ', ScanPath );
    writeln('');
    writeln('Each game needs to have a ', InfoFileName, ' file added which contains');
    writeln('details about the game GameMinder needs in order to detect it.');
    writeln('');
    writeln('Please read the QUICKSTART.md file for instructions on to create these files');
    writeln('or visit https://github.com/MaverickUK/GameMinder');
    TextColor(White);
    DoneGames;
    Halt(1);
  end;

  writeln('Sorting games');
  SortGames(DefaultSort);
  Mode := DefaultView;

  { TODO: Pick random text on each startup }
  writeln('Reticulating splines');

  Delay(DelayOnStartup);
end;

{ ================== Main program loop ================== }
var
    ch:char;
    previousMode:byte;
    runMainLoop:boolean;
    item:TMenuItem;
begin
  ParseCommandLine;

  if ( ListOnly ) then begin
    ListGames;
    Halt(0);
  end;

  if ( length(RunName) > 0 ) then begin
    RunGame;
    Halt(0);
  end;

  runMainLoop := true; { When false, GameMinder will exit }

  Startup;

  ApplyScreenMode;
  HideCursor;
  RedrawAll;

 { Main input loop }
  repeat
    ch:=ReadKey; { https://www.freepascal.org/docs-html/rtl/crt/readkey.html }
    previousMode := Mode;

    case ch of
     #0 : begin
            { https://www.freepascal.org/docs-html/rtl/keyboard/kbdscancode.html
             Remember to convert hex to dec e.g. 4B = 75 }
            ch:=ReadKey; {Read ScanCode}
            case ch of
            {(( Games ))}
             #72 : scrollTo(offset - 1); { Up }
             #80 : scrollTo(offset + 1); { Down }
             #73 : scrollTo(offset - PageSize); { Page up - jump up a page }
             #81 : scrollTo(offset + PageSize); { Page down - jump down a page }
             #71 : scrollTo(0); { Home - jump to top }
             #79 : scrollTo(ViewCount - 1); { End - jump to bottom }

            {(( Horizonal menu ))}
            #75 : changeHorizonalMenu(-1); { Left }
            #77 : changeHorizonalMenu(1); { Right }

            {(( Mode ))}
             #59 : Mode := ModeHelp; { F1 - Help }
             #60 : Mode := ModeInfo; { F2 - Game info }
             #61 : Mode := ModeStatus; { F3 - System status }
             #62 : Mode := ModeFullScreen; { F4 - Full width }

            {(( Sort ))}
            #63: SortBy(smName); { F5 }
            #64: SortBy(smDeveloper); { F6 }
            #65: SortBy(smYear); { F7}
            #66: SortBy(smGenre); { F8 }
            #67: SortBy(smTimesPlayed); { F9 }
            #68: SortBy(smTimePlayed); { F10 }
            end;

          end;
    #13: begin  { Enter }
            GetMenuItem(hMenu, hIndex, item);

            case item.Action of
              { --- Primary --- }
              maRun: ExecuteGame;
              maSortMenu: showMenu(MenuSort, ord(CurrentSort));
              maFilterMenu: showMenu(MenuFilter, 0);
              maRescan: RescanGames;
              maExit: runMainLoop := false; { Exit GameMinder }
              { --- Sort --- }
              maSortName: SortBy(smName);
              maSortDeveloper: SortBy(smDeveloper);
              maSortYear: SortBy(smYear);
              maSortGenre: SortBy(smGenre);
              maSortType: SortBy(smType);
              maSortTimesPlayed: SortBy(smTimesPlayed);
              maSortTimePlayed: SortBy(smTimePlayed);
              { --- Filter --- }
              maFilterClear: SetFilter('');
            end;
        end;
    #27: begin { Esc - clear filter, then go up a menu, then exit }
        if ( length(CurrentFilter) > 0 ) then
          SetFilter('')
        else if ( hMenu = MenuSort ) then
          showMenu(MenuPrimary, PrimarySortIndex)
        else if ( hMenu = MenuFilter ) then
          showMenu(MenuPrimary, PrimaryFilterIndex)
        else
          runMainLoop := false;
      end;
    #8: begin { Backspace - edit filter }
        if ( length(CurrentFilter) > 0 ) then
          SetFilter(copy(CurrentFilter, 1, length(CurrentFilter) - 1));
      end;
    #32..#126: begin { Type to filter }
        if ( length(CurrentFilter) < MaxFilterLength ) then
          SetFilter(CurrentFilter + ch);
      end;
    end;

    { Redraw routines after input }
    if not runMainLoop then break;

    { Entering or leaving full screen mode changes the frame }
    if ( previousMode <> Mode ) and
       ( ( previousMode = ModeFullScreen ) or ( Mode = ModeFullScreen ) ) then
      SetupScreen(OnlyFrame);

    renderHorizonalMenu;
    scrollingList;
    drawPanel;

  until runMainLoop = false;

  { Exit splash screen }
  ShowCursor;
  RestoreScreenMode;
  NormVideo;
  clrscr;
  DoneGames;
  writeln('Thanks for using GameMinder');
  { TODO: Fancy ASCII exit screen like an Apogee game }
end.
