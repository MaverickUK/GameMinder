Program GameMind;
uses 
    Objects,
    Dos,
    Crt, { https://theasciicode.com.ar/extended-ascii-code/graphic-character-high-density-dotted-ascii-code-178.html }
    { GameMinder modules }
    Settings, 
    Utility,
    Screen,
    { Launch external executable - Must keep ExecSwap last}
    ExecSwap; 
const
  ApplicationName = 'GameMinder (WIP v0.1.1)';
  MaxGames = 100; { Maximum games GameMinder can load }
  SettingsFileName = 'SETTINGS.TXT';
  PlayStatsFileName = '!GM_LOG.TXT'; { TODO: Add to config }
  endOfLine = #10;  
  { Info file keys }
  InfoFile_Name = 'name:';
  InfoFile_Exec = 'exec:';
  InfoFile_Developer = 'developer:';
  InfoFile_Year = 'year:';
  InfoFile_Genre = 'genre:';
  InfoFile_Video = 'video:';
  InfoFile_Sound = 'sound:';
  { Screen }
  rows = 24;
  columns = 80;  
  { Modes - Moved to SCREEN.PAS }
  {
  ModeHelp = 0;
  ModeInfo = 1;
  ModeStatus = 2;
  ModeFullScreen = 3;
  }
  { Horizonal }
  HMenu_Primary = 0;
  HMenu_Sort = 1;
  HMenu_Filter = 2;  
  HMenu_Filter_Apply = 3;  
  { Horizonal - Primary menu }
  HModeRun = 0;
  HModeFilter = 1;
  HModeSort = 2;  
  HModeAdd = 3;
  HModeEdit = 4;
  HModeDelete = 5;
  HModeExit = 6;
  { Horizonal - Sort menu }
  HModeSort_Name = 7;
  HModeSort_Developer = 8;
  HModeSort_Year = 9;
  HModeSort_Genre = 10;
  { Horizonal - Filter menu }
  HModeFilter_Filter = 11;
  HModeFilter_Clear = 12;
  { Play stats }
  PlayStatsFile_StartMarker = '>'; { Indicate start time of game in file }
  PlayStatsFile_SecondsPlayedMarker = '<'; { Indicate seconds played game for }
type
  { Individual game record }
  Game = record
      name: string[40]; { Keen 1 }  
      path: string[66]; { C:\games\keen1\ - max length in DOS }
      exec: string[12]; { keen1.exe }      
      developer: string[25]; { id software }
      year: string[4]; { 1991 }
      genre: string[15]; { Platform }
      video: string[15]; { EGA }
      sound: string[15]; { Sound Blaster }
      { Play stats }
      lastPlayed: string[16]; {yyyy/mm/dd HH:MM}
      timesPlayed: word;
      timeSpentPlaying: string[15];
  end;

  { Sortable game - references a single field in a game record}
  SortableGame = record
    id: word; { Index of original game array }
    value: string[40]; { Game field to sort on }
  end;

  { Games sorting modes }
  TSortMode = (Name, Developer, Year, Genre);

  { Screen redraw modes }
  { Moved to Screen.pas - TDrawScreenMode = (All, OnlyFrame, OnlyTop, OnlyBottom); }

  { Pointer to sortable game }
  { PSortableGame = ^SortableGame; }

var
  GamesTotal: word; { Total number of games found }
  Games: array[0..MaxGames] of Game;

  SortedGamesByName: array[0..MaxGames] of SortableGame;
  SortedGamesByDeveloper: array[0..MaxGames] of SortableGame;
  SortedGamesByYear: array[0..MaxGames] of SortableGame;
  SortedGamesByGenre: array[0..MaxGames] of SortableGame;

  CurrentSortMode:TSortMode;

  { User configurable settings }
  ScanPath:string[70];
  InfoFileName:string[12];
  HighlightedRow:word;
  DelayAfterGameExit:word;
  DelayOnStartup:word;
  VerboseOutput:boolean;
  BlankLineFilter:string[30];
  UseEmsForSwapFile:boolean;
  EnablePlayStats:boolean;

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
  hMode:byte;

  { Highlighted game }
  offset:byte;  

{ Load user configurable settings from file }
procedure LoadSettingsFile;
begin
  { Load configuration from file, with defaults as fallback }
  VerboseOutput := GetConfigBool('VerboseOutput', false);  
  ScanPath := GetConfigString('ScanPath', 'C:\GAMES\');
  InfoFileName := GetConfigString('InfoFileName', '!GM_INFO.TXT');
  HighlightedRow := GetConfigInt('HighlightedRow', 14);
  DelayAfterGameExit := GetConfigInt('DelayAfterGameExit', 0);
  DelayOnStartup := GetConfigInt('DelayOnStartup', 0);
  BlankLineFilter := GetConfigString('BlankLineFilter', '');
  UseEmsForSwapFile := GetConfigBool('UseEmsForSwapFile', true);
  EnablePlayStats := GetConfigBool('EnablePlayStats', true);

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

{ Currently highlighted game index - with sort applied }
function HighlightedGameIndex:byte;
var
  SortedGameIndex,gameIndex:byte;
begin
  gameIndex := offset;

  case CurrentSortMode of 
    Name: SortedGameIndex := SortedGamesByName[gameIndex].id;
    Developer: SortedGameIndex := SortedGamesByDeveloper[gameIndex].id;
    Year: SortedGameIndex := SortedGamesByYear[gameIndex].id;
    Genre: SortedGameIndex := SortedGamesByGenre[gameIndex].id;
  end;

  HighlightedGameIndex := SortedGameIndex;
end;  

{ Only output if VerboseOutput is enabled }
procedure VerboseWriteln(output:string);
begin
  if ( VerboseOutput )  then writeln(output);
end;

{ Log the start of a play session }
procedure LogPlayStart;
var
  path:string;
  playStatsFile:Text;
  line:string;
begin
  path := Games[HighlightedGameIndex].path + PlayStatsFileName;
  line := concat(PlayStatsFile_StartMarker, GetFormattedDate, ' ', GetFormattedTime);

  VerboseWriteln('Logging play start datetime to ' + path);

  Assign(playStatsFile, path);

  {$I-}
  Reset(playStatsFile);
  {$I+}

  { File doesn't already exist }
  if IOResult <> 0 then begin
    VerboseWriteln(path + ' not found, creating new file');
    Rewrite(playStatsFile); { Create new file }
  end;

  Append(playStatsFile);
  Writeln(playStatsFile,line);
  Close(playStatsFile);
end;

{ Log the end of a play session }
procedure LogPlayEnd(playTimeMinutes:word);
var 
  path:string;
  playStatsFile:Text;
  line:string;
begin
  path := Games[HighlightedGameIndex].path + PlayStatsFileName;

  VerboseWriteln('Logging play time of ' + ConvertToString(playTimeMinutes) + ' minute(s) to ' + path);

  line := concat( PlayStatsFile_SecondsPlayedMarker, ConvertToString(playTimeMinutes) );

  Assign(playStatsFile, path);
  Append(playStatsFile);
  Writeln(playStatsFile, line);

  Close(playStatsFile);
end;

{ Load a game info file into games array}
procedure LoadInfoFile(Path:string; GameIndex:byte);
const
  endOfLine = #10;
var
  InfoFile: Text;
  Ch: Char;
  line:string[50];  
  { Play stats - temp vars }
  lastPlayed: string[16]; {yyyy/mm/dd HH:MM}
  timesPlayed: word;
  timeSpentPlaying: string[15];

  { Retrieve the value from a key/pair line }
  function GetKeyPairValue(line:string;key:string):string;
  begin
    GetKeyPairValue := copy(line, length(key) + 1, length(line) - length(key));
  end;

  { Load and calculate play statistics }
  procedure GetPlayStats;
  var
    minutesPlayedTotal:integer;
    statsFilePath:string[70];
    playStatsFile:Text;
    Ch:Char;
    line:string;
    minutesPlayed:word;
    minutesPlayedStr:string[5];
    errorCode:byte;
    code:integer;
    endOfFile:boolean;
  begin
    { Defaults }
    lastPlayed := 'N/A';
    timesPlayed := 0;
    timeSpentPlaying := 'N/A';

    statsFilePath := Path + PlayStatsFileName;
    VerboseWriteln('Loading play stats for ' + statsFilePath);

    { Protect against missing file - https://www.tek-tips.com/viewthread.cfm?qid=484647 }
    Assign(playStatsFile, statsFilePath);
    {$I-}
    Reset(playStatsFile);
    {$I+}
    errorCode := IOResult;

    { If file not found}
    if errorCode <> 0 then begin
      VerboseWriteln(statsFilePath + ' not found');
      exit;
    end;

    minutesPlayedTotal := 0;

    while not eof(playStatsFile) do begin
      readln(playStatsFile, line);

      if length(line) > 0 then begin
        { Check marker character on line }
        case line[1] of
          PlayStatsFile_StartMarker: begin
            lastPlayed := copy(line,2, length(line) - 1);
            inc(timesPlayed);
          end;
          PlayStatsFile_SecondsPlayedMarker: begin
            minutesPlayedStr := copy(line, 2, length(line) - 1);

            { Increase total minutes played count }
            minutesPlayedTotal := minutesPlayedTotal + ConvertToInteger(minutesPlayedStr);            
          end;
        end;
      end;
    end;

    timeSpentPlaying := MinutesToFriendlyTime(minutesPlayedTotal);

    Close(playStatsFile);
  end;

begin
  if VerboseOutput then
    writeln('Found ', Path, InfoFileName, ' [', GameIndex, ']')
  else
    write('.');

  Games[GameIndex].path := Path;

  if ( EnablePlayStats ) then GetPlayStats;

  Games[GameIndex].lastPlayed := lastPlayed;
  Games[GameIndex].timesPlayed := timesPlayed;
  Games[GameIndex].timeSpentPlaying := timeSpentPlaying;

  Assign(InfoFile, Path + InfoFileName);
  Reset(InfoFile);

  line := ''; { init }
  
  while not Eof(InfoFile) do begin
    readln(InfoFile,line);

    { Determine key for line }
    if ( pos(InfoFile_Name, line) = 1 ) then begin
      Games[GameIndex].name :=  GetKeyPairValue(line, InfoFile_Name);
    end;

    if ( pos(InfoFile_Exec, line) = 1 ) then begin
      Games[GameIndex].exec :=  GetKeyPairValue(line, InfoFile_Exec);
    end;            

    if ( pos(InfoFile_Developer, line) = 1 ) then begin
      Games[GameIndex].developer := GetKeyPairValue(line, InfoFile_Developer);
    end;

    if ( pos(InfoFile_Year, line) = 1 ) then begin
      Games[GameIndex].year := GetKeyPairValue(line, InfoFile_Year);
    end;    

    if ( pos(InfoFile_Genre, line) = 1 ) then begin
      Games[GameIndex].genre := GetKeyPairValue(line, InfoFile_Genre);
    end;

    if ( pos(InfoFile_Video, line) = 1 ) then begin
      Games[GameIndex].video := GetKeyPairValue(line, InfoFile_Video);
    end;   

    if ( pos(InfoFile_Sound, line) = 1 ) then begin
      Games[GameIndex].sound := GetKeyPairValue(line, InfoFile_Sound);
    end;                 

  end;

  Close(InfoFile);
end;

procedure ScanForInfoFiles(Path:string);
  var
    S: SearchRec;
  begin
    FindFirst(Path+'*.*',Directory,S);
    while DosError=0 do
    begin
      if S.Name[1]<>'.' then
        if S.Attr=Directory
          then ScanForInfoFiles(Path+S.Name+'\') { If directory found, recursively scan inside}
          else begin
            if (S.Name = InfoFileName ) then begin { GameMinder info file found }
              LoadInfoFile(Path, GamesTotal);
              GamesTotal := GamesTotal + 1;
            end;
          end;
      FindNext(S);
    end;
  end;

{ ////////////////// Games list ////////////////// }
procedure scrollUp;
begin
  if ( offset > 0 ) then begin
    dec(offset);
  end;
end;

procedure scrollDown;
begin
  if ( offset < GamesTotal - 1) then begin
    inc(offset);
  end;
end;

procedure scrollPageUp;
const
  visibleRows = 9; { TODO Calculate this dynamically }
begin
  offset := offset - visibleRows;
  if ( offset < 0) then offset := 0;
end;

procedure scrollPageDown;
const
  visibleRows = 9; { TODO Calculate this dynamically }
begin
  offset := offset + visibleRows;
  if ( offset > GamesTotal - 1) then offset := GamesTotal - 1;
end;

procedure scrollToTop;
begin
  offset := 0;
end;

procedure scrollToBottom;
begin
  offset := GamesTotal - 1;
end;

procedure scrollingList(offset:byte);
    { Write game name - with blank spaces padding }
    procedure writeName(name:string);
    var
        rowLength,paddingLength:byte;
        i:byte;
    const
        columns = 80; { TODO - Make this global setting }
    begin
        rowLength := columns div 2 - 4; { 3 columns + 1 left padding = 4}

        if ( Mode = ModeFullScreen ) then 
          rowLength := columns - 4;

        paddingLength := rowLength - length(name);

        write(name);
        for i:=0 to paddingLength do write(' '); { Blanks }
    end;

var
    gameIndex:byte;
    row:byte;
    temp:string;
    SortedGames:array[0..MaxGames] of SortableGame;
    x:byte;
const
    startColumn = 3;
    minRow = 5;
    maxRow = 24;
    headerRow = 4;
    developerColumn = 40;
    genreColumn = 60;
    yearColumn = 70; 
begin
    row := minRow;

    { Heading }
    gotoxy(startColumn,headerRow);
    TextBackground(ColorHeadingBackground);
    TextColor(ColorHeadingText);
    writeName('Name');

    if ( Mode = ModeFullScreen ) then begin
      gotoxy(developerColumn,headerRow);
      write('Developer');

      gotoxy(genreColumn,headerRow);
      write('Genre');

      gotoxy(yearColumn,headerRow);
      write('Year');      
    end;

    { TODO: There must be a better way to do this! }
    case CurrentSortMode of 
      Name: for x := 0 to GamesTotal - 1 do  SortedGames[x] := SortedGamesByName[x];
      Developer: for x := 0 to GamesTotal - 1 do  SortedGames[x] := SortedGamesByDeveloper[x];
      Year: for x := 0 to GamesTotal - 1 do  SortedGames[x] := SortedGamesByYear[x];
      Genre: for x := 0 to GamesTotal - 1 do  SortedGames[x] := SortedGamesByGenre[x];
    end;

    while row < maxRow do
    begin
        { Game to display }
        { gameIndex := offset + row - minRow; }
        gameIndex := row - HighlightedRow + offset;

        { Defaults  }
        TextBackground(ColorBackground);
        TextColor(ColorText);

        { Game found to display}
        if (gameIndex >= 0) and (gameIndex < GamesTotal) then begin
            gotoxy(startColumn, row);

            { Highlight the selected game }
            if ( row = HighlightedRow ) then begin
                TextBackground(Green);
                TextColor(Yellow);
            end;

            { Use sorted games data }
            writeName(Games[ SortedGames[gameIndex].id ].name);

            if ( Mode = ModeFullScreen ) then begin
              gotoxy(developerColumn,row);
              write(Games[ SortedGames[gameIndex].id ].developer);

              gotoxy(genreColumn,row);
              write(Games[ SortedGames[gameIndex].id ].genre);

              gotoxy(yearColumn,row);
              write(Games[ SortedGames[gameIndex].id ].year);
            end;

            { writeName(Games[gameIndex].name); }
        end
        else { No game - show blank row }
        begin
            gotoxy(startColumn, row);
            writeName(BlankLineFilter);
        end;

        inc(row);
    end;

end;


{ Draw text in centre of screen}
procedure DrawCenter(text:string);
var
  padding,i:byte;
begin
  padding := (columns - length(text)) div 2;

  drawBlanks(padding);
  write(text);

  if not (columns - length(text)) mod 2 = 0 then inc(padding); { If text is an odd number }
  drawBlanks(padding);
end;

procedure drawFullScreen;
begin

end;

procedure drawHelpPanel;
begin
  resetLineDrawing;

  writeLine(' Help: GameMinder', ColorHeadingText, ColorHeadingBackground );       
  writeLine(' Enter  Execute current action', ColorText, ColorBackground);
  writeLine(' ' + #26 + '      Highlight next command', ColorText, ColorBackground);
  writeLine(' ' + #27 + '      Highlight previous command', ColorText, ColorBackground);  
  writeLine(' ' + #24 + '      Highlight previous game', ColorText, ColorBackground);
  writeLine(' ' + #25 + '      Highlight next game', ColorText, ColorBackground);
  writeLine(' PgUp   Move games list up one page', ColorText, ColorBackground);
  writeLine(' PgDn   Move games list down one page', ColorText, ColorBackground);
  writeLine(' Home   Move to top of games list', ColorText, ColorBackground);
  writeLine(' End    Move to bottom of games list', ColorText, ColorBackground);
  blankLine;
  writeLine(' F1 Help            F2 Game info', ColorText, ColorBackground);
  writeLine(' F3 Status          F4 Full screen', ColorText, ColorBackground);
  blankLine;
  writeLine(' F5 Sort by name    F6 Sort by dev', ColorText, ColorBackground);
  writeLine(' F7 Sort by year    F8 Sort by genre', ColorText, ColorBackground);
  blankLine;
  writeLine(' https://github.com/', ColorText, ColorBackground);
  writeLine(' MaverickUK/GameMinder', ColorText, ColorBackground);

  blankRemainingLines;
end;

procedure drawSystemStatus;
begin
  resetLineDrawing;

  writeLine(' System Status', ColorHeadingText, ColorHeadingBackground );       
  writeLine(' Sat 3 Sep 2022  12:03:11pm', ColorText, ColorBackground);
  blankLine;
  writeLine(' Drive C Status', ColorHeadingText, ColorHeadingBackground );
  writeLine(' Volume Label     ???', ColorText, ColorBackground );
  writeLine(' Bytes of Storage Total ?', ColorText, ColorBackground );
  writeLine(' Bytes of Storage Used ?', ColorText, ColorBackground );
  writeLine(' Bytes of Storage Free ?', ColorText, ColorBackground );
  blankLine;
  writeLine(' Memory Status', ColorHeadingText, ColorHeadingBackground );
  writeLine(' Bytes of RAM Total ?', ColorText, ColorBackground );
  writeLine(' Bytes of RAM Used ?', ColorText, ColorBackground );
  writeLine(' Bytes of RAM Free ?', ColorText, ColorBackground );
  blankLine;

  blankRemainingLines;
end;

procedure drawInfoPanel;
var 
  offset:byte;
  temp:string[5];
begin
    offset := HighlightedGameIndex;
    resetLineDrawing;

    writeLine(' ' + Games[offset].name, ColorHeadingText, ColorHeadingBackground );       
    writeLine(' Developer: ' + Games[offset].developer, ColorText, ColorBackground );        
    writeLine(' Genre: ' + Games[offset].genre, ColorText, ColorBackground );    
    writeLine(' Year: ' + Games[offset].year, ColorText, ColorBackground );
    blankLine;
    writeLine(' Video: ' +  Games[offset].video, ColorText, ColorBackground );
    writeLine(' Sound: ' +  Games[offset].sound, ColorText, ColorBackground );
    blankLine;

    if ( EnablePlayStats ) then begin
      writeLine(' Play stats', ColorHeadingText, ColorHeadingBackground );      
      writeLine(' Played: ' + ConvertToString(Games[offset].timesPlayed), ColorText, ColorBackground );
      writeLine(' Last played: ' + Games[offset].lastPlayed, ColorText, ColorBackground );            
      writeLine(' Time playing: ' + Games[offset].timeSpentPlaying, ColorText, ColorBackground );    
    end;

    blankRemainingLines;
end;

{ Which horizonal menu is currently displayed }
function getHorizonalMenuMode:byte;
begin
  if ( hMode >= HModeRun) and ( hMode <= HModeExit) then getHorizonalMenuMode := HMenu_Primary;
  if ( hMode >= HModeSort_Name) and ( hMode <= HModeSort_Genre) then getHorizonalMenuMode := HMenu_Sort;
  if ( hMode >= HModeFilter_Filter) and ( hMode <= HModeFilter_Clear) then getHorizonalMenuMode := HMenu_Filter;
end;

{ Render the horizonal menu that appears at the top of the scren }
procedure renderHorizonalMenu;
var
  Selected:boolean;  

  procedure renderPrimaryOption(option:byte; name:string);
  begin
    if ( option = hMode ) then begin
      TextColor(ColorHorizonalMenuHighlightText);
      TextBackground(ColorHorizonalMenuHighlightBackground);
    end
    else begin
      TextColor(ColorHorizontalMenuPrimaryText);
      TextBackground(ColorBackground); 
    end;

    write(name);

    TextColor(ColorText);
    TextBackground(ColorBackground);     
    write('  '); { Spacer }
  end;

  procedure renderSeconaryOption(text:string);
  begin
    write(text);
    drawBlanks(columns - length(text));
  end;

begin
  { Clear }
  gotoxy(1,1);
  TextColor(ColorHorizontalMenuPrimaryText);
  TextBackground(ColorBackground);   
  drawBlanks(columns); 

  { Primary nav }  
  gotoxy(1,1);

  case getHorizonalMenuMode of
    { ================================ }
    HMenu_Primary: begin 
      renderPrimaryOption(HModeRun, 'Run');
      renderPrimaryOption(HModeFilter, 'Filter');      
      renderPrimaryOption(HModeSort, 'Sort');
      renderPrimaryOption(HModeAdd, 'Add');
      renderPrimaryOption(HModeEdit, 'Edit');
      renderPrimaryOption(HModeDelete, 'Delete');
      renderPrimaryOption(HModeExit, 'Exit');

      { Secondry nav }
      gotoxy(1,2);
      
      case hMode of
        HModeRun: renderSeconaryOption('Run highlighted game');
        HModeFilter: renderSeconaryOption('Not yet implemented: Filter games');
        HModeSort: renderSeconaryOption('Name, Developer, Year, Genre');
        HModeAdd: renderSeconaryOption('Not yet implemented: Add game to GameMinder');
        HModeEdit: renderSeconaryOption('Not yet implemented: Edit game in GameMinder');
        HModeDelete: renderSeconaryOption('Not yet implemented: Delete game from GameMinder');
        HModeExit: renderSeconaryOption('Exit to DOS');
      end;      
    end;
    { ================================ }
    HMenu_Sort: begin
      renderPrimaryOption(HModeSort_Name, 'Name');
      renderPrimaryOption(HModeSort_Developer, 'Developer');
      renderPrimaryOption(HModeSort_Year, 'Year');
      renderPrimaryOption(HModeSort_Genre, 'Genre');

      { Secondry nav }
      gotoxy(1,2);     
      
      case hMode of
        HModeSort_Name: renderSeconaryOption('Sort by name ascending');
        HModeSort_Developer: renderSeconaryOption('Sort by developer ascending');
        HModeSort_Year: renderSeconaryOption('Sort by year ascending');
        HModeSort_Genre: renderSeconaryOption('Sort by genre ascending');
      end;          
    end;
    { ================================ }
    HMenu_Filter: begin
      renderPrimaryOption(HModeFilter_Filter, 'Filter');
      renderPrimaryOption(HModeFilter_Clear, 'Clear');

      { Secondry nav }
      gotoxy(1,2);     

      case hMode of
        HModeFilter_Filter: renderSeconaryOption('Filter games by name');
        HModeFilter_Clear: renderSeconaryOption('Clear current filter');
      end;              
    end;
  end;

  { Application name }
  gotoxy(columns - length(ApplicationName) + 1, 1);
  TextColor(ColorHorizonalMenuHighlightText);
  TextBackground(ColorHorizonalMenuHighlightBackground);
  write(ApplicationName);
end;

{ Change selected horizonal menu option }
procedure changeHorizonalMenu(movement:shortint);
var 
  desiredHMode:shortint;
begin
  desiredHMode := hMode + movement;

  { Loop round }
  case getHorizonalMenuMode of
    HMenu_Primary:  begin 
      if( desiredHMode < HModeRun ) then desiredHMode := HModeExit;
      if( desiredHMode > HModeExit) then desiredHMode := HModeRun; 
    end;
    HMenu_Sort: begin
      if( desiredHMode < HModeSort_Name ) then desiredHMode := HModeSort_Genre;
      if( desiredHMode > HModeSort_Genre) then desiredHMode := HModeSort_Name;
    end;
    HMenu_Filter: begin
      if( desiredHMode < HModeFilter_Filter ) then desiredHMode := HModeFilter_Clear;
      if( desiredHMode > HModeFilter_Clear) then desiredHMode := HModeFilter_Filter;    
    end;
  end;

  hMode := desiredHMode;

  { rerender the menu }
  renderHorizonalMenu;
end;

{ Toggle cursor visability }
procedure ToggleCursor;
var
  Num :word;
begin
   port[$03D4]:=$0A; Num:=port[$03D5];
   port[$03D4]:=$0A; port[$03D5]:=Num xor 32;
end;

{ Launch an external executable }
procedure Execute(path:string; executable:string);
const
  SwapLoc : array[Boolean] of String[7] = ('on disk', 'in EMS');
var
  Status : Word;
  OriginalDir: String;
  ShortPath,OriginalShortPath: string;
begin
  UseEmsIfAvailable := UseEmsForSwapFile;
  writeln('Starting ', path, executable);

 {function InitExecSwap(LastToSave : Pointer; SwapFileName : String) : Boolean;
-Initialize for swapping, returning TRUE if successful}
  if not InitExecSwap(HeapPtr,'SWAP.$$$') then begin
    WriteLn('Error: Unable to allocate swap space');
    Delay(5000); { TODO: Make configurable }
  end
  else begin
    WriteLn('GameMinder allocated ', BytesSwapped, ' bytes ', SwapLoc[EmsAllocated], ' to cache state');
    SwapVectors;

    {Must change directory}
    GetDir(0,OriginalDir);
    VerboseWriteln('GameMinder directory is ' + OriginalDir);    

    { Remove drive from path }
    ShortPath := Copy(path,3,length(path) - 3); 
    VerboseWriteln('Changing directory to ' + ShortPath);
    ChDir(ShortPath);

    {function ExecWithSwap(Path, CmdLine : String) : Word;
    -DOS Exec supporting swap to EMS or disk}

    VerboseWriteln('Executing ' + path + executable);
    writeln('');
    Status := ExecWithSwap(path + executable, '');

    SwapVectors;
    ShutdownExecSwap;

    VerboseWriteln('Changing directory back to ' + OriginalDir);
    ChDir(OriginalDir);

    Delay(DelayAfterGameExit);
  end;
end;

procedure RenderSortBy;
var
  sortName:string[15];
begin
  { TODO: Move this into own function }
  case CurrentSortMode of 
    Name: sortName := 'name';
    Developer: sortName := 'developer';
    Year: sortName := 'year';
    Genre: sortName := 'genre';
  end;

  gotoxy(5,rows);  
  write(#185, ' Sorted by ', sortName,' ', #204);  
end;

{ Draw screen facade }
procedure SetupScreen(drawMode:TDrawScreenMode);
begin
    {https://putka-upm.acm.si/langref/turboPascal/0511.html}

    if ( drawMode = All ) then begin
      TextColor(ColorFrame);
      TextBackground(ColorBackground);
      clrscr; 
    end; 

    drawFrame(mode, drawMode,1,3,columns,rows);

  { Overlays }
  if (drawMode = All) or (drawMode = OnlyFrame) or (drawMode = OnlyBottom ) then begin
    RenderSortBy;
  end;    
end;

{ Change the current games sort order }
procedure SortBy(sortMode:TSortMode);
begin
  CurrentSortMode := sortMode;
  SetupScreen(OnlyBottom);
end;

procedure SortGames;
var 
  x:byte;
  Sorted: array[0..MaxGames] of SortableGame;

  { Sort using bubble sort }
  { TODO: Implement quick sort }
  procedure Sort(ToSort: array of SortableGame);
  var
    i,j:byte;
    tmp:SortableGame;

    id:string;
  begin
    { From http://sandbox.mc.edu/~bennet/cs404/doc/sort_pas.html }
    FOR i := GamesTotal - 2 DOWNTO 0 DO
        FOR j := 0 TO i DO 
            IF ToSort[j].value > ToSort[j + 1].value THEN BEGIN
                tmp := ToSort[j];
                ToSort[j] := ToSort[j + 1];
                ToSort[j + 1] := tmp;
                write('.');
            END;

    { Remap to shared array variable - as function can't return an array }
    for i := 0 to GamesTotal - 1 do begin
      Sorted[i] := ToSort[i];
    end;
  end;

begin
  x := 0;

  while x < GamesTotal do begin
    SortedGamesByName[x].id := x;
    SortedGamesByDeveloper[x].id := x;
    SortedGamesByYear[x].id := x;
    SortedGamesByGenre[x].id := x;
   
    SortedGamesByName[x].value := Games[x].name; 
    SortedGamesByDeveloper[x].value := Games[x].developer;    
    SortedGamesByYear[x].value := Games[x].year;    
    SortedGamesByGenre[x].value := Games[x].genre;

    inc(x);
  end;  


  write('- Name');
  Sort(SortedGamesByName);

  { TODO: Is this approach really needed? Why doesn't direct assignment work?}
  for x := 0 to GamesTotal - 1 do begin  
    SortedGamesByName[x] := Sorted[x];
  end;
  writeln('');

  write('- Developer');
  Sort(SortedGamesByDeveloper);
  for x := 0 to GamesTotal - 1 do begin  
    SortedGamesByDeveloper[x] := Sorted[x];
  end;
  writeln('');

  write('- Year');
  Sort(SortedGamesByYear);
  for x := 0 to GamesTotal - 1 do begin  
    SortedGamesByYear[x] := Sorted[x];
  end;
  writeln('');    

  write('- Genre');
  Sort(SortedGamesByGenre);
  for x := 0 to GamesTotal - 1 do begin  
    SortedGamesByGenre[x] := Sorted[x];
  end;
  writeln('');  
end;

procedure Startup;
begin
  { init }
  GamesTotal := 0; 
  Mode := ModeInfo;
  hMode := ModeHelp;
  SortBy(Name);

  clrscr;

  TextColor(White);
  TextBackground(Blue);
  DrawCenter(ApplicationName);

  TextColor(White);
  TextBackground(Black);  

  writeln('Using setup file `', SettingsFileName, '`');
  LoadSettingsFile;
  writeln('');

  writeln('Scanning for game config files');
  ScanForInfoFiles(ScanPath);

  if ( GamesTotal > 0 ) then begin
    writeln('');
    writeln('Scan complete, ', GamesTotal, ' file(s) found');
  end
  else begin
    TextColor(Red);
    writeln('');
    writeln('No ', InfoFileName, ' files found under any directories in ', ScanPath );
    writeln('');
    writeln('Each game needs to have a ', InfoFileName, ' file added which contains');
    writeln('about the game GameMinder needs in order to detect it.');
    writeln('');
    writeln('Please read the README.md file for instructions on to create these files');
    writeln('or visit https://github.com/MaverickUK/GameMinder');
    TextColor(White);
    Halt;
  end;

  if ( GamesTotal > 0 ) then begin
    writeln('Precalculating sorted games');
    SortGames;
  end;

  { TODO: Pick random text on each startup }
  writeln('Reticulating splines');

  Delay(DelayOnStartup);
end;



{ Start the currently selected game }
procedure ExecuteGame;
var
  gameIndex:integer;
  startTime:string[5];
  playTimeMinutes:word;
begin
  gameIndex := HighlightedGameIndex;

  TextBackground(Black);  
  clrscr;

  TextColor(White);
  TextBackground(Blue);
  DrawCenter('GameMinder');

  TextColor(White);
  TextBackground(Black);  

  if ( EnablePlayStats ) then begin
    LogPlayStart;
    startTime := GetFormattedTime;
  end;

  Execute(Games[gameIndex].Path, Games[gameIndex].Exec);

  if ( EnablePlayStats ) then begin
    playTimeMinutes := MinutesBetweenTimes(startTime, GetFormattedTime);
    LogPlayEnd(playTimeMinutes);

    { Reload game details, to include updated play stats }
    LoadInfoFile(Games[gameIndex].path, gameIndex);
  end;

  { Restart Gameminder UI }
  SetupScreen(All);
  renderHorizonalMenu;
  scrollingList(offset);

   { TODO: Revert to correct mode }
  drawInfoPanel;
end;

{ ================== Main program loop ================== }
var
    i:byte;
    ch:char;
    previousMode:byte;
    runMainLoop:boolean;
begin
  runMainLoop := true; { When false, GameMinder will exit }

  Startup;

  ToggleCursor;
  SetupScreen(All);
  drawInfoPanel;
  SortBy(Name); 

  renderHorizonalMenu;

  { Start with first game }
  offset := 0;
  scrollingList(offset);

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
             #72 : scrollUp; { Up }
             #80 : scrollDown; { Down }
             #73 : scrollPageUp; { Page up - jump up a page }
             #81 : scrollPageDown; { Page down - jump down a page }
             #71 : scrollToTop; { Home - jump to top }
             #79 : scrollToBottom; { End - jump to bottom }

            {(( Horizonal menu ))}
            #75 : changeHorizonalMenu(-1); { Left }
            #77 : changeHorizonalMenu(1); { Right }

            {(( Mode ))}
             #59 : Mode := ModeHelp; { F1 - Help }
             #60 : Mode := ModeInfo; { F2 - Game info }
             #61 : Mode := ModeStatus; { F3 - System status }
             #62 : Mode := ModeFullScreen; { F4 - Full width }

            {(( Temp sort ))}
            #63: SortBy(Name); { F5 }
            #64: SortBy(Developer); { F6 }
            #65: SortBy(Year); { F7}
            #66: SortBy(Genre); { F8 }
            end;

          end;
    #13: begin  { Enter }
            { Horizonal menu mode based behaviour }
            case hMode of 
              { --- Primary --- }
              HModeRun: ExecuteGame;
              HModeSort: hMode := HModeSort_Name;
              HModeFilter: hMode := HModeFilter_Filter;
              HModeExit: runMainLoop := false; { Exit GameMinder }
              { --- Sort --- }
              HModeSort_Name: SortBy(Name);
              HModeSort_Developer: SortBy(Developer);
              HModeSort_Year: SortBy(Year);
              HModeSort_Genre: SortBy(Genre);
              { --- Filter --- }
              HModeFilter_Filter: hMode := HMenu_Filter_Apply;
            end;

            renderHorizonalMenu;
        end;
    #27: begin { Esc }
        if ( hMode = HModeExit ) then runMainLoop := false; { Quick exit }

        if ( hMode = HModeRun ) then
          hMode := HModeExit
        else
          hMode := HModeRun;

        renderHorizonalMenu; { TODO: Only go up a single level }
      end;        
    end;

    { Redraw routines after input }

    scrollingList(offset);

    { TODO: Implement this is a better way }
    { Redraw screen when exiting full screen mode }
    if not ( previousMode = Mode ) then begin
      if ( previousMode = ModeFullScreen ) then begin
        SetupScreen(OnlyFrame);
        renderHorizonalMenu;
        scrollingList(offset);
      end else begin
        { Leaving full screen, redraw frame }
        SetupScreen(OnlyFrame);
      end;
    end;
    
    { TODO: Only call these if they need to be redrawn }
    case( Mode ) of
      ModeHelp: drawHelpPanel;
      ModeInfo: drawInfoPanel;
      ModeStatus: drawSystemStatus;
      { ModeFullScreen: }
    end;

  until runMainLoop = false; (* ch=#27; {Esc} *)

  { Exit splash screen } 
  ToggleCursor;
  NormVideo;
  clrscr;
  writeln('Thanks for using GameMinder');
  { TODO: Fancy ASCII exit screen like an Apogee game }
end.