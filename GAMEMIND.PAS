Program GameMind;
{$IFDEF FPC}
  { Free Pascal DOS builds use plain Exec rather than ExecSwap, so the heap
    must be capped to leave memory free for games }
  {$M 16384,0,196608}
{$ENDIF}
uses
    Objects,
    Dos,
    Crt, { https://theasciicode.com.ar/extended-ascii-code/graphic-character-high-density-dotted-ascii-code-178.html }
    { GameMinder modules }
    Utility,
    Config,
    Games,
    Launch,
    Screen
    {$IFNDEF FPC}
    { Launch external executable - Must keep ExecSwap last }
    , ExecSwap
    {$ENDIF}
    ;

{$I VERSION.INC}

const
  SettingsFileName = 'SETTINGS.TXT';
  SwapFileName = 'SWAP.$$$';
  MaxFilterLength = 30;
  { Screen }
  rows = 24;
  columns = 80;
  { Games list }
  listStartColumn = 3;
  listMinRow = 5;
  listMaxRow = 24;
  listHeaderRow = 4;
  developerColumn = 40;
  genreColumn = 60;
  yearColumn = 70;
  pageSize = listMaxRow - listMinRow;
  { Horizontal menus }
  MenuPrimary = 0;
  MenuSort = 1;
  MenuFilter = 2;

type
  { What a horizontal menu option does when Enter is pressed }
  TMenuAction = (maRun, maFilterMenu, maSortMenu, maAdd, maEdit, maDelete, maExit,
                 maSortName, maSortDeveloper, maSortYear, maSortGenre, maSortTimesPlayed, maSortTimePlayed,
                 maFilterType, maFilterClear);

  TMenuItem = record
    Caption: string[10];
    Hint: string[60];
    Action: TMenuAction;
  end;

const
  PrimaryMenu: array[0..6] of TMenuItem = (
    (Caption:'Run'; Hint:'Run highlighted game'; Action:maRun),
    (Caption:'Filter'; Hint:'Filter games by name - or just start typing'; Action:maFilterMenu),
    (Caption:'Sort'; Hint:'Name, Developer, Year, Genre, Played, Playtime'; Action:maSortMenu),
    (Caption:'Add'; Hint:'Not yet implemented: Add game to GameMinder'; Action:maAdd),
    (Caption:'Edit'; Hint:'Not yet implemented: Edit game in GameMinder'; Action:maEdit),
    (Caption:'Delete'; Hint:'Not yet implemented: Delete game from GameMinder'; Action:maDelete),
    (Caption:'Exit'; Hint:'Exit to DOS'; Action:maExit));

  SortMenu: array[0..5] of TMenuItem = (
    (Caption:'Name'; Hint:'Sort by name ascending'; Action:maSortName),
    (Caption:'Developer'; Hint:'Sort by developer ascending'; Action:maSortDeveloper),
    (Caption:'Year'; Hint:'Sort by year ascending'; Action:maSortYear),
    (Caption:'Genre'; Hint:'Sort by genre ascending'; Action:maSortGenre),
    (Caption:'Played'; Hint:'Sort by times played, most played first'; Action:maSortTimesPlayed),
    (Caption:'Playtime'; Hint:'Sort by total time played, longest first'; Action:maSortTimePlayed));

  FilterMenu: array[0..1] of TMenuItem = (
    (Caption:'Filter'; Hint:'Type to filter games by name, Backspace to edit'; Action:maFilterType),
    (Caption:'Clear'; Hint:'Clear current filter'; Action:maFilterClear));

var
  ApplicationName:string[30];
  ExeDir:string;
  ListOnly:boolean; { /LIST - print games and exit }
  StartupVideoMode:word;

  { User configurable settings }
  ScanPath:string[70];
  InfoFileName:string[12];
  HighlightedRow:word;
  DelayAfterGameExit:word;
  DelayOnStartup:word;
  BlankLineFilter:string[30];
  UseEmsForSwapFile:boolean;
  EnablePlayStats:boolean;
  WaitForKeyAfterGame:boolean;
  DefaultSort:TSortMode;
  DefaultView:byte;

  { /// Colour theme /// }
  { Available colours: https://www.freepascal.org/docs-html/rtl/crt/index-2.html }
  ColorBackground:byte;
  ColorText:byte;
  ColorFrame:byte;
  { Heading }
  ColorHeadingBackground:byte;
  ColorHeadingText:byte;
  { Hihghlight }
  ColorHighlightBackground:byte;
  ColorHighlightText:byte;
  { Horizontal menu }
  ColorHorizontalMenuPrimaryText:byte;
  ColorHorizonalMenuHighlightText:byte;
  ColorHorizonalMenuHighlightBackground:byte;

  { Drawing to screen }
  mode:byte;
  hMenu:byte;   { Which horizontal menu is shown }
  hIndex:byte;  { Highlighted option within that menu }

  { Highlighted game - index into the filtered view }
  offset:integer;

{ Parse a DefaultView setting }
function ParseView(name:string; default:byte):byte;
begin
  name := UpStr(name);
  if ( name = 'HELP' ) then ParseView := ModeHelp
  else if ( name = 'INFO' ) then ParseView := ModeInfo
  else if ( name = 'STATUS' ) then ParseView := ModeStatus
  else if ( name = 'FULL' ) or ( name = 'FULLSCREEN' ) then ParseView := ModeFullScreen
  else ParseView := default;
end;

{ Load user configurable settings, with defaults as fallback }
procedure LoadSettings;
begin
  VerboseOutput := GetConfigBool('VerboseOutput', false);
  ScanPath := NormalizeDir(GetConfigString('ScanPath', 'C:\GAMES\'));
  InfoFileName := GetConfigString('InfoFileName', '!GM_INFO.TXT');
  HighlightedRow := GetConfigInt('HighlightedRow', 14);
  if ( HighlightedRow < listMinRow ) or ( HighlightedRow >= listMaxRow ) then HighlightedRow := 14;
  DelayAfterGameExit := GetConfigInt('DelayAfterGameExit', 0);
  DelayOnStartup := GetConfigInt('DelayOnStartup', 0);
  BlankLineFilter := GetConfigString('BlankLineFilter', '');
  UseEmsForSwapFile := GetConfigBool('UseEmsForSwapFile', true);
  EnablePlayStats := GetConfigBool('EnablePlayStats', true);
  WaitForKeyAfterGame := GetConfigBool('WaitForKeyAfterGame', false);
  DefaultSort := ParseSortMode(GetConfigString('DefaultSort', ''), smName);
  DefaultView := ParseView(GetConfigString('DefaultView', ''), ModeInfo);
  MaxGames := GetConfigInt('MaxGames', DefaultMaxGames);

  { Theme colours }
  ColorBackground := GetConfigColor('ColorBackground',Blue);
  ColorText := GetConfigColor('ColorText',White);
  ColorFrame := GetConfigColor('ColorFrame',White);
  { Heading }
  ColorHeadingBackground := GetConfigColor('ColorHeadingBackground',Red);
  ColorHeadingText := GetConfigColor('ColorHeadingText',Yellow);
  { Hihghlight }
  ColorHighlightBackground := GetConfigColor('ColorHighlightBackground',Green);
  ColorHighlightText := GetConfigColor('ColorHighlightText',Yellow);
  { Horizontal menu }
  ColorHorizontalMenuPrimaryText := GetConfigColor('ColorHorizontalMenuPrimaryText',White);
  ColorHorizonalMenuHighlightText := GetConfigColor('ColorHorizonalMenuHighlightText',Blue);
  ColorHorizonalMenuHighlightBackground := GetConfigColor('ColorHorizonalMenuHighlightBackground',White);
end;

{ Currently highlighted game, nil if the filter matches nothing }
function HighlightedGame:PGame;
begin
  HighlightedGame := ViewGame(offset);
end;

{ ////////////////// Games list ////////////////// }
procedure scrollTo(index:integer);
begin
  if ( index > ViewCount - 1 ) then index := ViewCount - 1;
  if ( index < 0 ) then index := 0;
  offset := index;
end;

procedure scrollingList;
var
  game:PGame;
  gameIndex:integer;
  row:byte;
  nameWidth:byte;
begin
  nameWidth := columns div 2 - 4; { 3 columns + 1 left padding = 4}
  if ( Mode = ModeFullScreen ) then
    nameWidth := developerColumn - listStartColumn - 1;

  { Heading }
  gotoxy(listStartColumn,listHeaderRow);
  TextBackground(ColorHeadingBackground);
  TextColor(ColorHeadingText);
  if ( Mode = ModeFullScreen ) then
    write(PadColumn('Name', developerColumn - listStartColumn),
          PadColumn('Developer', genreColumn - developerColumn),
          PadColumn('Genre', yearColumn - genreColumn),
          PadRight('Year', columns - yearColumn))
  else
    write(PadRight('Name', nameWidth + 1));

  for row := listMinRow to listMaxRow - 1 do begin
    { Game to display - the highlighted game is always on HighlightedRow }
    gameIndex := integer(row) - integer(HighlightedRow) + offset;
    game := ViewGame(gameIndex);

    gotoxy(listStartColumn, row);

    if ( row = HighlightedRow ) and ( game <> nil ) then begin
      TextBackground(ColorHighlightBackground);
      TextColor(ColorHighlightText);
    end else begin
      TextBackground(ColorBackground);
      TextColor(ColorText);
    end;

    if ( game = nil ) then begin
      { No game - show blank row }
      if ( Mode = ModeFullScreen ) then
        write(PadRight(BlankLineFilter, columns - listStartColumn))
      else
        write(PadRight(BlankLineFilter, nameWidth + 1));
    end
    else if ( Mode = ModeFullScreen ) then
      write(PadColumn(PStr(game^.Name), developerColumn - listStartColumn),
            PadColumn(PStr(game^.Developer), genreColumn - developerColumn),
            PadColumn(PStr(game^.Genre), yearColumn - genreColumn),
            PadRight(PStr(game^.Year), columns - yearColumn))
    else
      write(PadRight(PStr(game^.Name), nameWidth + 1));
  end;
end;

{ Draw text in centre of screen}
procedure DrawCenter(text:string);
var
  padding:byte;
begin
  padding := (columns - length(text)) div 2;

  drawBlanks(padding);
  write(text);
  drawBlanks(columns - length(text) - padding);
end;

procedure drawHelpPanel;
begin
  resetLineDrawing(ColorBackground);

  writeLine(' Help: ' + ApplicationName, ColorHeadingText, ColorHeadingBackground );
  writeLine(' Enter  Execute current action', ColorText, ColorBackground);
  writeLine(' Esc    Clear filter, back or exit', ColorText, ColorBackground);
  writeLine(' ' + #26 + ' ' + #27 + '    Highlight next/previous command', ColorText, ColorBackground);
  writeLine(' ' + #24 + ' ' + #25 + '    Highlight previous/next game', ColorText, ColorBackground);
  writeLine(' PgUp   Move games list up one page', ColorText, ColorBackground);
  writeLine(' PgDn   Move games list down one page', ColorText, ColorBackground);
  writeLine(' Home   Move to top of games list', ColorText, ColorBackground);
  writeLine(' End    Move to bottom of games list', ColorText, ColorBackground);
  writeLine(' A-Z    Type to filter games by name', ColorText, ColorBackground);
  blankLine;
  writeLine(' F1 Help            F2 Game info', ColorText, ColorBackground);
  writeLine(' F3 Status          F4 Full screen', ColorText, ColorBackground);
  blankLine;
  writeLine(' F5 Sort by name    F6 Sort by dev', ColorText, ColorBackground);
  writeLine(' F7 Sort by year    F8 Sort by genre', ColorText, ColorBackground);
  writeLine(' F9 Most played     F10 Most playtime', ColorText, ColorBackground);
  blankLine;
  writeLine(' github.com/MaverickUK/GameMinder', ColorText, ColorBackground);

  blankRemainingLines;
end;

{ Volume label of a drive e.g. 'C', blank if none }
function VolumeLabel(drive:char):string;
var
  S:SearchRec;
  name:string;
begin
  VolumeLabel := '';
  FindFirst(drive + ':\*.*', VolumeID, S);
  if ( DosError = 0 ) then begin
    name := S.Name;
    { Labels over 8 characters are returned in 8.3 form }
    if ( pos('.', name) > 0 ) then delete(name, pos('.', name), 1);
    VolumeLabel := name;
  end;
end;

{ Conventional memory installed, from the BIOS }
function ConventionalMemoryKB:word;
var
  regs:Registers;
begin
  Intr($12, regs);
  ConventionalMemoryKB := regs.AX;
end;

{ Free memory in GameMinder's heap }
function HeapFree:longint;
begin
  {$IFDEF FPC}
  HeapFree := GetHeapStatus.TotalFree;
  {$ELSE}
  HeapFree := MemAvail;
  {$ENDIF}
end;

procedure drawSystemStatus;
var
  drive:char;
  driveNumber:byte;
  total,free:longint;
  currentDir:string;
begin
  { Show the drive games are scanned from }
  if ( length(ScanPath) >= 2 ) and ( ScanPath[2] = ':' ) then
    drive := UpCase(ScanPath[1])
  else begin
    GetDir(0, currentDir);
    drive := UpCase(currentDir[1]);
  end;
  driveNumber := ord(drive) - ord('A') + 1;
  total := DiskSize(driveNumber);
  free := DiskFree(driveNumber);

  resetLineDrawing(ColorBackground);

  writeLine(' System Status', ColorHeadingText, ColorHeadingBackground );
  writeLine(' ' + GetFormattedDate + '  ' + GetFormattedTime, ColorText, ColorBackground);
  blankLine;
  writeLine(' Drive ' + drive + ' Status', ColorHeadingText, ColorHeadingBackground );
  writeLine(' Volume label: ' + VolumeLabel(drive), ColorText, ColorBackground );
  writeLine(' Storage total: ' + FormatBytes(total), ColorText, ColorBackground );
  if ( total >= 0 ) and ( free >= 0 ) then
    writeLine(' Storage used: ' + FormatBytes(total - free), ColorText, ColorBackground );
  writeLine(' Storage free: ' + FormatBytes(free), ColorText, ColorBackground );
  blankLine;
  writeLine(' Memory Status', ColorHeadingText, ColorHeadingBackground );
  writeLine(' Conventional RAM: ' + ConvertToString(ConventionalMemoryKB) + ' KB', ColorText, ColorBackground );
  writeLine(' GameMinder heap free: ' + FormatBytes(HeapFree), ColorText, ColorBackground );
  blankLine;
  writeLine(' Games', ColorHeadingText, ColorHeadingBackground );
  writeLine(' Found: ' + ConvertToString(GameCount) + '  Showing: ' + ConvertToString(ViewCount),
            ColorText, ColorBackground );
  if ( GameCapReached ) then
    writeLine(' Limit reached - raise MaxGames', ColorText, ColorBackground );

  blankRemainingLines;
end;

procedure drawInfoPanel;
var
  game:PGame;
begin
  game := HighlightedGame;
  resetLineDrawing(ColorBackground);

  if ( game = nil ) then begin
    writeLine(' No games found', ColorHeadingText, ColorHeadingBackground );
    writeLine(' Nothing matches "' + CurrentFilter + '"', ColorText, ColorBackground );
    writeLine(' Press Esc to clear the filter', ColorText, ColorBackground );
    blankRemainingLines;
    exit;
  end;

  writeLine(' ' + PStr(game^.Name), ColorHeadingText, ColorHeadingBackground );
  writeLine(' Developer: ' + PStr(game^.Developer), ColorText, ColorBackground );
  writeLine(' Genre: ' + PStr(game^.Genre), ColorText, ColorBackground );
  writeLine(' Year: ' + PStr(game^.Year), ColorText, ColorBackground );
  blankLine;
  writeLine(' Video: ' + PStr(game^.Video), ColorText, ColorBackground );
  writeLine(' Sound: ' + PStr(game^.Sound), ColorText, ColorBackground );
  blankLine;
  writeLine(' Path: ' + PStr(game^.Path), ColorText, ColorBackground );
  writeLine(' Exec: ' + PStr(game^.Exec), ColorText, ColorBackground );
  blankLine;

  if ( EnablePlayStats ) then begin
    writeLine(' Play stats', ColorHeadingText, ColorHeadingBackground );
    writeLine(' Played: ' + ConvertToString(game^.TimesPlayed), ColorText, ColorBackground );
    if ( game^.LastPlayed = nil ) then
      writeLine(' Last played: N/A', ColorText, ColorBackground )
    else
      writeLine(' Last played: ' + PStr(game^.LastPlayed), ColorText, ColorBackground );
    writeLine(' Time playing: ' + MinutesToFriendlyTime(game^.MinutesPlayed), ColorText, ColorBackground );
  end;

  blankRemainingLines;
end;

{ Redraw the right hand panel for the current mode }
procedure drawPanel;
begin
  case( Mode ) of
    ModeHelp: drawHelpPanel;
    ModeInfo: drawInfoPanel;
    ModeStatus: drawSystemStatus;
    { ModeFullScreen: games list uses whole screen }
  end;
end;

{ ////////////////// Horizontal menu ////////////////// }

function MenuCount(menu:byte):byte;
begin
  case menu of
    MenuSort: MenuCount := 6;
    MenuFilter: MenuCount := 2;
  else
    MenuCount := 7;
  end;
end;

procedure GetMenuItem(menu:byte; index:byte; var item:TMenuItem);
begin
  case menu of
    MenuSort: item := SortMenu[index];
    MenuFilter: item := FilterMenu[index];
  else
    item := PrimaryMenu[index];
  end;
end;

{ Render the horizonal menu that appears at the top of the scren }
procedure renderHorizonalMenu;
var
  i:byte;
  item:TMenuItem;
begin
  { Clear }
  gotoxy(1,1);
  TextColor(ColorHorizontalMenuPrimaryText);
  TextBackground(ColorBackground);
  drawBlanks(columns);

  { Primary nav }
  gotoxy(1,1);

  for i := 0 to MenuCount(hMenu) - 1 do begin
    GetMenuItem(hMenu, i, item);

    if ( i = hIndex ) then begin
      TextColor(ColorHorizonalMenuHighlightText);
      TextBackground(ColorHorizonalMenuHighlightBackground);
    end
    else begin
      TextColor(ColorHorizontalMenuPrimaryText);
      TextBackground(ColorBackground);
    end;

    write(item.Caption);

    TextColor(ColorText);
    TextBackground(ColorBackground);
    write('  '); { Spacer }
  end;

  { Secondary nav - describe highlighted option }
  GetMenuItem(hMenu, hIndex, item);
  gotoxy(1,2);
  write(PadRight(item.Hint, columns));

  { Application name }
  gotoxy(columns - length(ApplicationName) + 1, 1);
  TextColor(ColorHorizonalMenuHighlightText);
  TextBackground(ColorHorizonalMenuHighlightBackground);
  write(ApplicationName);
end;

{ Change selected horizonal menu option, looping round }
procedure changeHorizonalMenu(movement:shortint);
var
  desired:integer;
begin
  desired := hIndex + movement;
  if ( desired < 0 ) then desired := MenuCount(hMenu) - 1;
  if ( desired >= MenuCount(hMenu) ) then desired := 0;
  hIndex := desired;
end;

procedure showMenu(menu:byte; index:byte);
begin
  hMenu := menu;
  hIndex := index;
end;

{ ////////////////// Frame overlays ////////////////// }

procedure RenderSortBy;
begin
  gotoxy(5,rows);
  write(#185, ' Sorted by ', SortModeName(CurrentSort), ' ', #204);
end;

procedure RenderFilter;
begin
  if ( length(CurrentFilter) = 0 ) then exit;
  gotoxy(columns div 2 + 3, rows);
  write(#185, ' Filter: ', CurrentFilter, ' ', #204);
end;

{ Draw screen facade }
procedure SetupScreen(drawMode:TDrawScreenMode);
begin
    {https://putka-upm.acm.si/langref/turboPascal/0511.html}
    TextColor(ColorFrame);
    TextBackground(ColorBackground);

    if ( drawMode = All ) then clrscr;

    drawFrame(mode, drawMode,1,3,columns,rows);

  { Overlays }
  if (drawMode = All) or (drawMode = OnlyFrame) or (drawMode = OnlyBottom ) then begin
    RenderSortBy;
    RenderFilter;
  end;
end;

{ Redraw everything }
procedure RedrawAll;
begin
  SetupScreen(All);
  renderHorizonalMenu;
  scrollingList;
  drawPanel;
end;

{ ////////////////// Sorting & filtering ////////////////// }

{ Change the current games sort order, keeping the highlighted game }
procedure SortBy(sortMode:TSortMode);
var
  game:PGame;
begin
  game := HighlightedGame;
  SortGames(sortMode);
  scrollTo(IndexInView(game));
  SetupScreen(OnlyBottom);
end;

{ Change the filter, keeping the highlighted game if it still matches }
procedure SetFilter(filter:string);
var
  game:PGame;
  index:integer;
begin
  game := HighlightedGame;
  ApplyFilter(filter);

  index := IndexInView(game);
  if ( index < 0 ) then index := 0;
  scrollTo(index);

  SetupScreen(OnlyBottom);
end;

{ ////////////////// Running games ////////////////// }

{ Where to put the swap file - %TEMP% if set, otherwise next to GAMEMIND.EXE }
function SwapFilePath:string;
var
  temp:string;
begin
  temp := GetEnv('TEMP');
  if ( length(temp) = 0 ) then temp := ExeDir;
  SwapFilePath := NormalizeDir(temp) + SwapFileName;
end;

{ Launch an external executable, returning 0 on success or a DOS error code }
function Execute(prog:string; args:string; gameDir:string):word;
var
  Status : Word;
  OriginalDir: String;
begin
  Status := 0;

  { Change to game's drive and directory - ChDir also changes drive }
  GetDir(0,OriginalDir);
  VerboseWriteln('GameMinder directory is ' + OriginalDir);
  VerboseWriteln('Changing directory to ' + StripTrailingSlash(gameDir));
  {$I-}
  ChDir(StripTrailingSlash(gameDir));
  {$I+}
  Status := IOResult;
  if ( Status <> 0 ) then begin
    Execute := Status;
    exit;
  end;

  VerboseWriteln('Executing ' + prog + ' ' + args);

  {$IFDEF FPC}
  SwapVectors;
  Exec(prog, args);
  SwapVectors;
  Status := DosError;
  {$ELSE}
  UseEmsIfAvailable := UseEmsForSwapFile;

  {function InitExecSwap(LastToSave : Pointer; SwapFileName : String) : Boolean;
  -Initialize for swapping, returning TRUE if successful}
  if not InitExecSwap(HeapPtr, SwapFilePath) then begin
    WriteLn('Error: Unable to allocate swap space');
    Status := 8; { Not enough memory }
  end
  else begin
    VerboseWriteln('GameMinder swapped ' + ConvertToString(BytesSwapped) + ' bytes to ' + SwapFilePath);
    writeln('');
    SwapVectors;
    Status := ExecWithSwap(prog, args);
    SwapVectors;
    ShutdownExecSwap;
  end;
  {$ENDIF}

  VerboseWriteln('Changing directory back to ' + OriginalDir);
  {$I-}
  ChDir(OriginalDir);
  {$I+}
  if ( IOResult <> 0 ) then ; { Clear error - nothing else we can do }

  Execute := Status;
end;

{ Start the currently selected game }
procedure ExecuteGame;
var
  game:PGame;
  prog,args:string;
  status:word;
  y,m,d,dow,h,min,s,hund:word;
  startDay:longint;
  startMinute:word;
  playTimeMinutes:longint;
begin
  game := HighlightedGame;
  if ( game = nil ) then exit;

  BuildLaunchCommand(PStr(game^.Path), PStr(game^.Exec), GetEnv('COMSPEC'), prog, args);

  TextBackground(Black);
  clrscr;

  TextColor(White);
  TextBackground(Blue);
  DrawCenter('GameMinder');

  TextColor(White);
  TextBackground(Black);
  ShowCursor;

  writeln('Starting ', PStr(game^.Name));

  GetDate(y,m,d,dow);
  GetTime(h,min,s,hund);
  startDay := DayNumber(y,m,d);
  startMinute := h * 60 + min;

  if ( EnablePlayStats ) then
    AppendPlayLog(game, PlayStatsFile_StartMarker + GetFormattedDate + ' ' + GetFormattedTime);

  status := Execute(prog, args, PStr(game^.Path));

  { Games can leave the screen in a graphics mode }
  TextMode(StartupVideoMode);

  if ( status <> 0 ) then begin
    TextColor(LightRed);
    writeln('');
    writeln('Unable to run ', prog, ' ', args);
    writeln(DosErrorText(status));
    TextColor(White);
    writeln('');
    writeln('Press any key to return to GameMinder');
    ReadKey;
  end
  else begin
    if ( EnablePlayStats ) then begin
      GetDate(y,m,d,dow);
      GetTime(h,min,s,hund);
      playTimeMinutes := ElapsedMinutes(startDay, startMinute, DayNumber(y,m,d), h * 60 + min);
      VerboseWriteln('Logging play time of ' + ConvertToString(playTimeMinutes) + ' minute(s)');
      AppendPlayLog(game, PlayStatsFile_MinutesPlayedMarker + ConvertToString(playTimeMinutes));
    end;

    if ( WaitForKeyAfterGame ) then begin
      writeln('');
      writeln('Press any key to return to GameMinder');
      ReadKey;
    end;

    Delay(DelayAfterGameExit);
  end;

  { Reload game details, to include updated play stats }
  if ( EnablePlayStats ) then LoadPlayStats(game);

  { Restart Gameminder UI }
  HideCursor;
  RedrawAll;
end;

{ ////////////////// Startup ////////////////// }

{ Read settings from SETTINGS.TXT next to GAMEMIND.EXE, wherever it's run from }
function LoadSettingsFile:boolean;
var
  found:boolean;
begin
  found := LoadConfigFile(ExeDir + SettingsFileName);
  LoadSettings;
  LoadSettingsFile := found;
end;

procedure ShowUsage;
begin
  writeln(ApplicationName, ' - DOS games launcher');
  writeln('');
  writeln('GAMEMIND [/LIST] [/V] [/?]');
  writeln('');
  writeln('  /LIST  Print the games found and exit');
  writeln('  /V     Show version');
  writeln('  /?     Show this help');
end;

{ Handle command line switches }
procedure ParseCommandLine;
var
  i:integer;
  param:string;
begin
  ListOnly := false;

  { Switches only produce text, so use DOS output rather than Crt,
    allowing it to be redirected e.g. GAMEMIND /LIST > GAMES.TXT }
  if ( ParamCount > 0 ) then begin
    Assign(Output, '');
    Rewrite(Output);
  end;

  for i := 1 to ParamCount do begin
    param := UpStr(ParamStr(i));
    if ( param = '/V' ) or ( param = '-V' ) or ( param = '/VERSION' ) then begin
      writeln(ApplicationName);
      Halt(0);
    end
    else if ( param = '/LIST' ) or ( param = '-LIST' ) then
      ListOnly := true
    else begin
      ShowUsage;
      if ( param = '/?' ) or ( param = '-?' ) or ( param = '/H' ) then Halt(0) else Halt(1);
    end;
  end;
end;

{ /LIST - print games to standard output so it can be redirected to a file }
procedure ListGames;
var
  i,found:integer;
  game:PGame;
begin
  LoadSettingsFile;
  InitGames(MaxGames);
  PlayStatsEnabled := EnablePlayStats;
  ScanForInfoFiles(ScanPath, InfoFileName);
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

procedure Startup;
begin
  { init }
  offset := 0;
  showMenu(MenuPrimary, 0);

  TextColor(White);
  TextBackground(Black);
  clrscr;

  TextColor(White);
  TextBackground(Blue);
  DrawCenter(ApplicationName);

  TextColor(White);
  TextBackground(Black);

  writeln('Using setup file ', ExeDir, SettingsFileName);
  if not LoadSettingsFile then begin
    TextColor(Yellow);
    writeln('Setup file not found, using default settings');
    TextColor(White);
  end;
  writeln('');

  InitGames(MaxGames);
  PlayStatsEnabled := EnablePlayStats;
  ShowScanProgress := true;

  writeln('Scanning ', ScanPath, ' for ', InfoFileName, ' files');
  ScanForInfoFiles(ScanPath, InfoFileName);

  if ( GameCount > 0 ) then begin
    writeln('');
    writeln('Scan complete, ', GameCount, ' game(s) found');
    if ( GameCapReached ) then begin
      TextColor(Yellow);
      writeln('Only the first ', MaxGames, ' games were loaded - increase MaxGames in ', SettingsFileName);
      TextColor(White);
    end;
  end
  else begin
    TextColor(Red);
    writeln('');
    writeln('No ', InfoFileName, ' files found under any directories in ', ScanPath );
    writeln('');
    writeln('Each game needs to have a ', InfoFileName, ' file added which contains');
    writeln('details about the game GameMinder needs in order to detect it.');
    writeln('');
    writeln('Please read the README.md file for instructions on to create these files');
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
  ApplicationName := 'GameMinder v' + AppVersion;
  ExeDir := DirOfPath(ParamStr(0));
  StartupVideoMode := LastMode;

  ParseCommandLine;

  if ( ListOnly ) then begin
    ListGames;
    Halt(0);
  end;

  runMainLoop := true; { When false, GameMinder will exit }

  Startup;

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
             #73 : scrollTo(offset - pageSize); { Page up - jump up a page }
             #81 : scrollTo(offset + pageSize); { Page down - jump down a page }
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
              maExit: runMainLoop := false; { Exit GameMinder }
              { --- Sort --- }
              maSortName: SortBy(smName);
              maSortDeveloper: SortBy(smDeveloper);
              maSortYear: SortBy(smYear);
              maSortGenre: SortBy(smGenre);
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
          showMenu(MenuPrimary, 2)
        else if ( hMenu = MenuFilter ) then
          showMenu(MenuPrimary, 1)
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
  NormVideo;
  clrscr;
  DoneGames;
  writeln('Thanks for using GameMinder');
  { TODO: Fancy ASCII exit screen like an Apogee game }
end.
