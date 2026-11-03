Program GameMind;
{-----------------------------
GameMinder - a lightweight DOS games launcher
https://github.com/MaverickUK/GameMinder

Startup, command line and the main input loop. The rest lives in units:
  PREFS     settings          LISTVIEW  games list       RUNNER   running games
  SCREEN    layout & frame    PANELS    right hand panel GAMES    games data
  MENU      horizontal menu   LAUNCH    launch commands  CONFIG   SETTINGS.TXT
  THEMES    colour themes     FORMS     edit game, pick from list
  ENDSCRN   exit screen       FPUFIX    PCs without an FPU
------------------------------}
uses
    FpuFix, { Must be first - see FPUFIX.PAS }
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
    Config,
    Themes,
    Forms,
    EndScrn,
    Objects,
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
  Returns true if the games came from the cache. A scan shows its progress
  as [....] when ShowScanProgress is set }
function LoadGames(scan:boolean):boolean;
var
  cached:boolean;
begin
  InitGames(MaxGames);
  PlayStatsEnabled := EnablePlayStats;

  cached := false;
  if not scan and CacheGames then
    cached := LoadGameCache(ExeDir + CacheFileName, ScanPath, InfoFileName) and ( GameCount > 0 );

  if not cached then begin
    InitGames(MaxGames);
    if ( ShowScanProgress ) then write('Scanning ', ScanPath, ' [');
    ScanForGames(ScanPath, InfoFileName);
    if ( ShowScanProgress ) then writeln(']');
    if ( GameCount > 0 ) then SaveCache;
  end;

  UpdatePopularity;
  LoadGames := cached;
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

{ Plain text screen used at startup and while scanning, like Doom's }
procedure ShowTitleScreen;
begin
  TextColor(White);
  TextBackground(Black);
  clrscr;

  TextColor(White);
  TextBackground(Red);
  DrawCenter('GameMinder System Startup v' + AppVersion);

  TextColor(LightGray);
  TextBackground(Black);
  writeln('');
end;

{ A startup line, e.g. "W_Init: Loaded 37 games" - the part up to the colon is
  highlighted. Doesn't end the line, so progress can follow }
procedure StartupText(line:string);
var
  colon:byte;
begin
  colon := pos(':', line);
  TextColor(White);
  write(copy(line, 1, colon));
  TextColor(LightGray);
  write(copy(line, colon + 1, 255));
end;

procedure StartupLine(line:string);
begin
  StartupText(line);
  writeln;
end;

{ Something to read while GameMinder starts, chosen at random }
function FlavourLine:string;
const
  FlavourCount = 12;
  Flavours: array[1..FlavourCount] of string[50] = (
    'I_Init: Checking for IRQ conflicts... none',
    'I_Init: Calibrating joystick... centred',
    'I_Init: Parking hard disk heads',
    'I_Init: Counting floppy disks... too many',
    'I_Init: Blowing dust out of the disk drive',
    'I_Init: Reticulating splines',
    'Z_Init: Defragmenting upper memory... done',
    'Z_Init: Squeezing past the 640K barrier',
    'S_Init: Tuning the PC speaker',
    'S_Init: Setting BLASTER=A220 I5 D1',
    'V_Init: Degaussing monitor',
    'V_Init: Counting colours... all 16');
begin
  FlavourLine := Flavours[Random(FlavourCount) + 1];
end;

{ ////////////////// Actions ////////////////// }

{ Start the currently selected game }
procedure ExecuteGame;
var
  game:PGame;
begin
  game := HighlightedGame;
  if ( game = nil ) then exit;

  if ( LaunchGame(game, true) <> LaunchCancelled ) then begin
    UpdatePopularity;
    SaveCache; { Updated play stats }
  end;

  { Restart Gameminder UI }
  ApplyScreenMode;
  HideCursor;
  RedrawAll;
end;

{ Run the selected game's setup program }
procedure ExecuteSetup;
var
  game:PGame;
begin
  game := HighlightedGame;
  if not HasSetup(game) then exit;

  LaunchSetup(game, true);

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
  StartupText('W_Init: ');
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

{ Highlight a game, clearing the filter if it hides it }
procedure ShowGame(game:PGame);
begin
  if ( IndexInView(game) < 0 ) then ApplyFilter('');
  scrollTo(IndexInView(game));
end;

{ Edit the highlighted game's details, saving them to its info file }
procedure EditHighlightedGame;
var
  game:PGame;
begin
  game := HighlightedGame;
  if ( game = nil ) then exit;

  if EditGameForm(game, 'Edit ' + PStr(game^.Name)) then begin
    if not SaveInfoFile(game, InfoFileName) then
      ShowMessage('Unable to save ' + PStr(game^.Path) + InfoFileName);
    inc(SessionEdits);
    SortGames(CurrentSort);
    ShowGame(game);
    SaveCache;
  end;

  RedrawAll;
end;

{ Add a game from a directory with a program in but no info file }
procedure AddNewGame;
var
  dirs:PStringCollection;
  index:integer;
  dir:string;
  game:PGame;
begin
  ShowStatus('Looking for games in ' + ScanPath + ' that aren''t listed...');
  dirs := New(PStringCollection, Init(20, 20));
  FindUnlistedDirs(ScanPath, InfoFileName, dirs);

  if ( dirs^.Count = 0 ) then
    ShowMessage('No new games found in ' + ScanPath)
  else begin
    index := PickFromList('Add game', 'Choose the directory of the game to add', dirs);
    if ( index >= 0 ) then begin
      dir := PString(dirs^.At(index))^;

      { Suggest a name from the directory and the program to run }
      game := NewGame;
      game^.Path := NewStr(dir);
      game^.Name := NewStr(TitleCase(copy(StripTrailingSlash(dir),
                      length(DirOfPath(StripTrailingSlash(dir))) + 1, 255)));
      game^.Exec := NewStr(SuggestExec(dir));
      game^.Setup := NewStr(SuggestSetup(dir));

      if not EditGameForm(game, 'Add game') then
        DisposeGame(game)
      else if not SaveInfoFile(game, InfoFileName) then begin
        ShowMessage('Unable to save ' + dir + InfoFileName);
        DisposeGame(game);
      end
      else if not AddGame(game) then
        ShowMessage('Saved, but GameMinder already lists MaxGames games')
      else begin
        if ( PlayStatsEnabled ) then LoadPlayStats(game);
        UpdatePopularity;
        inc(SessionEdits);
        SortGames(CurrentSort);
        ShowGame(game);
        SaveCache;
      end;
    end;
  end;

  Dispose(dirs, Done);
  RedrawAll;
end;

{ Remove the highlighted game from GameMinder by deleting its info file }
procedure RemoveHighlightedGame;
var
  game:PGame;
begin
  game := HighlightedGame;
  if ( game = nil ) then exit;

  if Confirm('Remove ' + PStr(game^.Name) + ' from GameMinder? Its files are kept') then begin
    if DeleteInfoFile(game, InfoFileName) then begin
      RemoveGame(game);
      UpdatePopularity;
      scrollTo(offset);
      SaveCache;
    end else
      ShowMessage('Unable to delete ' + PStr(game^.Path) + InfoFileName);
  end;

  RedrawAll;
end;

var
  ThemeBefore:integer;   { Theme in use before the theme menu was opened }
  ColorsBefore:TTheme;   { ...and its colours, as it may be the Color settings }

{ Show the highlighted theme while choosing one }
procedure PreviewTheme;
begin
  if ( CurrentTheme = hIndex + 1 ) then exit;
  ApplyTheme(hIndex + 1);
  RedrawAll;
end;

{ List the themes in THEMES.TXT on the second row, to choose with left and right }
procedure ChooseTheme;
begin
  if ( ThemeCount = 0 ) then exit;

  ThemeBefore := CurrentTheme;
  GetColors(ColorsBefore);
  if ( CurrentTheme > 0 ) then
    showMenu(MenuTheme, CurrentTheme - 1)
  else
    showMenu(MenuTheme, 0);
  PreviewTheme;
end;

{ Use the highlighted theme, remembering it in SETTINGS.TXT }
procedure KeepTheme;
begin
  ThemeSetting := ThemeName(CurrentTheme);
  SaveConfigValue(ExeDir + SettingsFileName, 'Theme', ThemeSetting);
  showMenu(MenuPrimary, PrimaryThemeIndex);
end;

{ Leave the theme menu, going back to the theme in use before }
procedure CancelTheme;
begin
  showMenu(MenuPrimary, PrimaryThemeIndex);
  if ( CurrentTheme = ThemeBefore ) then exit;
  CurrentTheme := ThemeBefore;
  SetColors(ColorsBefore);
  RedrawAll;
end;

{ Load THEMES.TXT and use the theme chosen in SETTINGS.TXT }
procedure LoadTheme;
begin
  LoadThemes(ExeDir + ThemesFileName);
  if ( length(ThemeSetting) > 0 ) then
    ApplyTheme(FindTheme(ThemeSetting));
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

{ Load everything, showing what's happening like Doom's startup }
procedure Startup;
var
  plays,minutes,ems:longint;
  mostPlayed:PGame;
begin
  Randomize;
  ShowTitleScreen;

  StartupLine('M_LoadDefaults: ' + ExeDir + SettingsFileName);
  if not LoadSettingsFile then begin
    TextColor(Yellow);
    writeln('                Not found, using default settings');
  end;

  LoadTheme;
  if ( ThemeCount = 0 ) then
    StartupLine('T_Init: No themes in ' + ThemesFileName + ', using Color settings')
  else if ( CurrentTheme = 0 ) then
    StartupLine('T_Init: ' + ConvertToString(ThemeCount) + ' colour themes, using Color settings')
  else
    StartupLine('T_Init: ' + ConvertToString(ThemeCount) + ' colour themes, using ' + ThemeName(CurrentTheme));

  ems := EmsFreeKB;
  if ( ems > 0 ) then
    StartupLine('Z_Init: ' + ConvertToString(AvailableMemoryKB) + 'KB conventional, ' +
      ConvertToString(ems) + 'KB EMS free for games')
  else
    StartupLine('Z_Init: ' + ConvertToString(AvailableMemoryKB) + 'KB conventional memory free for games');

  StartupText('W_Init: ');
  ShowScanProgress := true;
  if LoadGames(ForceScan) then
    writeln('Loaded ', GameCount, ' games from ', CacheFileName)
  else if ( GameCount > 0 ) then
    writeln('        ', GameCount, ' games found');
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

  if ( EnablePlayStats ) then begin
    GetLibraryStats(plays, minutes, mostPlayed);
    if ( plays = 0 ) then
      StartupLine('P_Init: No plays logged yet')
    else if ( minutes = 0 ) then
      StartupLine('P_Init: ' + ConvertToString(plays) + ' plays logged')
    else
      StartupLine('P_Init: ' + ConvertToString(plays) + ' plays, ' +
        MinutesToFriendlyTime(minutes) + ' of play logged');
  end;

  StartupLine('L_Init: Sorting by ' + SortModeName(DefaultSort));
  SortGames(DefaultSort);
  Mode := DefaultView;

  StartupLine(FlavourLine);
  StartupLine('D_GameLoop: Ready');

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
             #82 : AddNewGame; { Insert }
             #83 : RemoveHighlightedGame; { Delete }

            {(( Horizonal menu ))}
            #75, #77 : begin { Left, Right }
                if ( ch = #75 ) then changeHorizonalMenu(-1) else changeHorizonalMenu(1);
                if ( hMenu = MenuTheme ) then PreviewTheme;
              end;

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
              maRun: if HasSetup(HighlightedGame) then
                       showMenu(MenuRun, 0)
                     else
                       ExecuteGame;
              maSortMenu: showMenu(MenuSort, ord(CurrentSort));
              maFilterMenu: showMenu(MenuFilter, 0);
              maAdd: AddNewGame;
              maEdit: EditHighlightedGame;
              maDelete: RemoveHighlightedGame;
              maRescan: RescanGames;
              maTheme: ChooseTheme;
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
              { --- Theme --- }
              maThemeChoose: KeepTheme;
              { --- Run --- }
              maRunGame: begin
                  showMenu(MenuPrimary, PrimaryRunIndex);
                  ExecuteGame;
                end;
              maRunSetup: begin
                  showMenu(MenuPrimary, PrimaryRunIndex);
                  ExecuteSetup;
                end;
            end;
        end;
    #27: begin { Esc - clear filter, then go up a menu, then exit }
        if ( length(CurrentFilter) > 0 ) then
          SetFilter('')
        else if ( hMenu = MenuSort ) then
          showMenu(MenuPrimary, PrimarySortIndex)
        else if ( hMenu = MenuFilter ) then
          showMenu(MenuPrimary, PrimaryFilterIndex)
        else if ( hMenu = MenuTheme ) then
          CancelTheme
        else if ( hMenu = MenuRun ) then
          showMenu(MenuPrimary, PrimaryRunIndex)
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

    { The Run menu is only for games with a setup program }
    if ( hMenu = MenuRun ) and not HasSetup(HighlightedGame) then
      showMenu(MenuPrimary, PrimaryRunIndex);

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
  if ( ExitScreen ) then
    ShowEndScreen
  else
    writeln('Thanks for using GameMinder');
  DoneGames;
end.
