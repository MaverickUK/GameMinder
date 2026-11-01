Unit Games;
{-----------------------------
Games list - loading, sorting and filtering

Games are held on the heap rather than in static arrays, so the
number of games isn't limited by the 64K data segment. The heap is
swapped out to EMS/disk with the rest of GameMinder when a game runs,
so it doesn't reduce the memory available to games.
------------------------------}

{ --------- interface -------- }
interface
uses
    Objects;

const
  PlayStatsFileName = '!GM_LOG.TXT';
  MaxGamesLimit = 16000; { Upper limit of a TCollection is 16380 }
  DefaultMaxGames = 1000;
  { Play stats }
  PlayStatsFile_StartMarker = '>'; { Indicate start date/time of game in file }
  PlayStatsFile_MinutesPlayedMarker = '<'; { Indicate minutes played game for }

type
  { Games sorting modes }
  TSortMode = (smName, smDeveloper, smYear, smGenre, smType, smTimesPlayed, smTimePlayed);

  { Individual game record - strings held on heap, nil when blank }
  PGame = ^TGame;
  TGame = record
    Name: PString;      { Keen 1 }
    Path: PString;      { C:\games\keen1\ }
    Exec: PString;      { keen1.exe }
    Developer: PString; { id software }
    Year: PString;      { 1991 }
    Genre: PString;     { Platform }
    Video: PString;     { EGA }
    Sound: PString;     { Sound Blaster }
    GameType: PString;  { Full, Demo, Shareware, Freeware... }
    MemoryKB: word;     { Conventional memory needed, 0 if not known }
    Before: PString;    { Command run before the game e.g. MOUSE.COM }
    After: PString;     { Command run after the game e.g. MOUSE OFF }
    { Play stats }
    LastPlayed: PString; { yyyy/mm/dd HH:MM }
    TimesPlayed: word;
    MinutesPlayed: longint;
  end;

  PGameCollection = ^TGameCollection;
  TGameCollection = object(TCollection)
    procedure FreeItem(Item: Pointer); virtual;
  end;

  { Games currently shown in the list, after the filter is applied }
  PGameView = ^TGameView;
  TGameView = array[0..MaxGamesLimit - 1] of PGame;

var
  GameList: PGameCollection; { All games found, in current sort order }
  View: PGameView;
  ViewCount: integer;
  MaxGames: integer;
  GameCapReached: boolean;
  CurrentSort: TSortMode;
  CurrentFilter: string[30];
  PlayStatsEnabled: boolean;
  ShowScanProgress: boolean;

{ Setup & teardown }
procedure InitGames(maxCount:integer);
procedure DoneGames;
function GameCount:integer;
{ Individual games }
function PStr(p:PString):string;
function NewGame:PGame;
procedure SetGameField(game:PGame; key:string; value:string);
procedure ApplyPlayStatsLine(game:PGame; line:string);
function LoadInfoFile(path:string; infoFileName:string):PGame;
procedure LoadPlayStats(game:PGame);
function AppendPlayLog(game:PGame; line:string):boolean;
function AddGame(game:PGame):boolean;
procedure ScanForInfoFiles(path:string; infoFileName:string);
{ Cache }
function SaveGameCache(fileName:string; scanPath:string; infoFileName:string):boolean;
function LoadGameCache(fileName:string; scanPath:string; infoFileName:string):boolean;
{ Sorting & filtering }
function CompareGames(a,b:PGame; mode:TSortMode):integer;
procedure SortGames(mode:TSortMode);
procedure ApplyFilter(filter:string);
function ViewGame(index:integer):PGame;
function IndexInView(game:PGame):integer;
function SortModeName(mode:TSortMode):string;
function ParseSortMode(name:string; default:TSortMode):TSortMode;

{ --------- implementation --------- }
implementation
uses
    Dos,
    Utility;

procedure DisposeGame(game:PGame);
begin
  if ( game = nil ) then exit;
  DisposeStr(game^.Name);
  DisposeStr(game^.Path);
  DisposeStr(game^.Exec);
  DisposeStr(game^.Developer);
  DisposeStr(game^.Year);
  DisposeStr(game^.Genre);
  DisposeStr(game^.Video);
  DisposeStr(game^.Sound);
  DisposeStr(game^.GameType);
  DisposeStr(game^.Before);
  DisposeStr(game^.After);
  DisposeStr(game^.LastPlayed);
  Dispose(game);
end;

procedure TGameCollection.FreeItem(Item: Pointer);
begin
  DisposeGame(PGame(Item));
end;

{ ////////////////// Setup & teardown ////////////////// }

procedure InitGames(maxCount:integer);
begin
  DoneGames;

  if ( maxCount < 1 ) then maxCount := 1;
  if ( maxCount > MaxGamesLimit ) then maxCount := MaxGamesLimit;
  MaxGames := maxCount;

  GameList := New(PGameCollection, Init(50, 50));
  GetMem(View, word(MaxGames) * SizeOf(PGame));
  ViewCount := 0;
  GameCapReached := false;
  CurrentSort := smName;
  CurrentFilter := '';
end;

procedure DoneGames;
begin
  if ( GameList <> nil ) then begin
    Dispose(GameList, Done);
    GameList := nil;
  end;
  if ( View <> nil ) then begin
    FreeMem(View, word(MaxGames) * SizeOf(PGame));
    View := nil;
  end;
  ViewCount := 0;
end;

function GameCount:integer;
begin
  if ( GameList = nil ) then
    GameCount := 0
  else
    GameCount := GameList^.Count;
end;

{ ////////////////// Individual games ////////////////// }

{ Safely read a heap string, blank if not set }
function PStr(p:PString):string;
begin
  if ( p = nil ) then PStr := '' else PStr := p^;
end;

function NewGame:PGame;
var
  game:PGame;
begin
  New(game);
  FillChar(game^, SizeOf(TGame), 0);
  NewGame := game;
end;

procedure ReplaceStr(var p:PString; value:string);
begin
  DisposeStr(p);
  p := NewStr(value);
end;

{ Set a game field from a !GM_INFO.TXT key - key must be upper case }
procedure SetGameField(game:PGame; key:string; value:string);
begin
  if ( key = 'NAME' ) then ReplaceStr(game^.Name, value)
  else if ( key = 'EXEC' ) then ReplaceStr(game^.Exec, value)
  else if ( key = 'DEVELOPER' ) then ReplaceStr(game^.Developer, value)
  else if ( key = 'YEAR' ) then ReplaceStr(game^.Year, value)
  else if ( key = 'GENRE' ) then ReplaceStr(game^.Genre, value)
  else if ( key = 'VIDEO' ) then ReplaceStr(game^.Video, value)
  else if ( key = 'SOUND' ) then ReplaceStr(game^.Sound, value)
  else if ( key = 'TYPE' ) then ReplaceStr(game^.GameType, value)
  else if ( key = 'MEMORY' ) then game^.MemoryKB := ParseMemoryKB(value)
  else if ( key = 'BEFORE' ) then ReplaceStr(game^.Before, value)
  else if ( key = 'AFTER' ) then ReplaceStr(game^.After, value);
end;

{ Apply a single line from a !GM_LOG.TXT file to a game's stats }
procedure ApplyPlayStatsLine(game:PGame; line:string);
begin
  line := Trim(line);
  if ( length(line) = 0 ) then exit;

  case line[1] of
    PlayStatsFile_StartMarker: begin
      ReplaceStr(game^.LastPlayed, Trim(copy(line, 2, 255)));
      inc(game^.TimesPlayed);
    end;
    PlayStatsFile_MinutesPlayedMarker:
      inc(game^.MinutesPlayed, ConvertToInteger(copy(line, 2, 255)));
  end;
end;

{ Load a game info file, returns nil if it can't be read }
function LoadInfoFile(path:string; infoFileName:string):PGame;
var
  InfoFile: Text;
  line,key,value:string;
  game:PGame;
begin
  LoadInfoFile := nil;
  path := NormalizeDir(path);

  Assign(InfoFile, path + infoFileName);
  {$I-}
  Reset(InfoFile);
  {$I+}
  if ( IOResult <> 0 ) then begin
    VerboseWriteln('Unable to read ' + path + infoFileName);
    exit;
  end;

  game := NewGame;
  game^.Path := NewStr(path);

  while not Eof(InfoFile) do begin
    readln(InfoFile, line);
    if SplitKeyValue(line, key, value) then
      SetGameField(game, key, value);
  end;

  Close(InfoFile);

  { Fall back to the directory name if the game has no name }
  if ( game^.Name = nil ) then begin
    line := StripTrailingSlash(path);
    game^.Name := NewStr(copy(line, length(DirOfPath(line)) + 1, 255));
  end;

  LoadInfoFile := game;
end;

{ Load and calculate play statistics from the game's !GM_LOG.TXT }
procedure LoadPlayStats(game:PGame);
var
  playStatsFile:Text;
  line:string;
begin
  DisposeStr(game^.LastPlayed);
  game^.LastPlayed := nil;
  game^.TimesPlayed := 0;
  game^.MinutesPlayed := 0;

  Assign(playStatsFile, PStr(game^.Path) + PlayStatsFileName);
  {$I-}
  Reset(playStatsFile);
  {$I+}
  if ( IOResult <> 0 ) then exit; { Never played }

  while not eof(playStatsFile) do begin
    readln(playStatsFile, line);
    ApplyPlayStatsLine(game, line);
  end;

  Close(playStatsFile);
end;

{ Append a line to the game's !GM_LOG.TXT, creating it if needed.
  Returns false if it can't be written e.g. game on a CD-ROM }
function AppendPlayLog(game:PGame; line:string):boolean;
var
  playStatsFile:Text;
  logPath:string;
begin
  AppendPlayLog := false;
  logPath := PStr(game^.Path) + PlayStatsFileName;

  Assign(playStatsFile, logPath);
  {$I-}
  Append(playStatsFile);
  if ( IOResult <> 0 ) then
    Rewrite(playStatsFile); { File doesn't already exist }
  {$I+}
  if ( IOResult <> 0 ) then begin
    VerboseWriteln('Unable to write play stats to ' + logPath);
    exit;
  end;

  {$I-}
  Writeln(playStatsFile, line);
  Close(playStatsFile);
  {$I+}
  AppendPlayLog := ( IOResult = 0 );
end;

{ Add a game to the list, returns false if the cap has been reached }
function AddGame(game:PGame):boolean;
begin
  if ( GameList^.Count >= MaxGames ) then begin
    GameCapReached := true;
    DisposeGame(game);
    AddGame := false;
    exit;
  end;

  GameList^.Insert(game);
  AddGame := true;
end;

{ Recursively search for game info files }
procedure ScanForInfoFiles(path:string; infoFileName:string);
var
  S: SearchRec;
  game: PGame;
begin
  path := NormalizeDir(path);
  infoFileName := UpStr(infoFileName);

  FindFirst(path + AllFilesMask, Directory, S);
  while ( DosError = 0 ) and not GameCapReached do begin
    if ( S.Name[1] <> '.' ) then begin
      if ( S.Attr and Directory ) <> 0 then
        ScanForInfoFiles(path + S.Name, infoFileName) { If directory found, recursively scan inside }
      else if ( UpStr(S.Name) = infoFileName ) then begin { GameMinder info file found }
        VerboseWriteln('Found ' + path + S.Name);
        game := LoadInfoFile(path, S.Name);
        if ( game <> nil ) then begin
          if ( PlayStatsEnabled ) then LoadPlayStats(game);
          if AddGame(game) and ShowScanProgress and not VerboseOutput then write('.');
        end;
      end;
    end;
    FindNext(S);
  end;
  {$IFDEF FPC}
  FindClose(S);
  {$ENDIF}
end;

{ ////////////////// Cache ////////////////// }

const
  CacheVersion = '1';

{ Save all games, including play stats, so the next startup doesn't need to scan }
function SaveGameCache(fileName:string; scanPath:string; infoFileName:string):boolean;
var
  f:Text;
  i:integer;
  game:PGame;

  procedure WriteField(key:string; value:PString);
  begin
    if ( value <> nil ) then writeln(f, key, ':', value^);
  end;

begin
  SaveGameCache := false;

  Assign(f, fileName);
  {$I-}
  Rewrite(f);
  {$I+}
  if ( IOResult <> 0 ) then begin
    VerboseWriteln('Unable to write game cache ' + fileName);
    exit;
  end;

  {$I-}
  writeln(f, '; GameMinder game cache - delete this file or use Rescan to rebuild it');
  writeln(f, 'cache:', CacheVersion);
  writeln(f, 'scanpath:', UpStr(NormalizeDir(scanPath)));
  writeln(f, 'infofile:', UpStr(infoFileName));

  for i := 0 to GameList^.Count - 1 do begin
    game := GameList^.At(i);
    writeln(f);
    WriteField('path', game^.Path);
    WriteField('name', game^.Name);
    WriteField('exec', game^.Exec);
    WriteField('developer', game^.Developer);
    WriteField('year', game^.Year);
    WriteField('genre', game^.Genre);
    WriteField('video', game^.Video);
    WriteField('sound', game^.Sound);
    WriteField('type', game^.GameType);
    if ( game^.MemoryKB > 0 ) then writeln(f, 'memory:', game^.MemoryKB);
    WriteField('before', game^.Before);
    WriteField('after', game^.After);
    WriteField('lastplayed', game^.LastPlayed);
    if ( game^.TimesPlayed > 0 ) then writeln(f, 'timesplayed:', game^.TimesPlayed);
    if ( game^.MinutesPlayed > 0 ) then writeln(f, 'minutesplayed:', game^.MinutesPlayed);
  end;

  Close(f);
  {$I+}
  SaveGameCache := ( IOResult = 0 );
end;

{ Load games from a cache made by SaveGameCache. Returns false, leaving the list empty,
  if there's no cache or it was made for a different ScanPath or InfoFileName }
function LoadGameCache(fileName:string; scanPath:string; infoFileName:string):boolean;
var
  f:Text;
  line,key,value:string;
  game:PGame;
  valid:boolean;
  code:integer;
begin
  LoadGameCache := false;

  Assign(f, fileName);
  {$I-}
  Reset(f);
  {$I+}
  if ( IOResult <> 0 ) then exit;

  valid := false;
  game := nil;

  while not Eof(f) do begin
    readln(f, line);
    if SplitKeyValue(line, key, value) then begin
      if ( game = nil ) and ( key <> 'PATH' ) then begin
        { Header }
        if ( key = 'CACHE' ) then valid := ( value = CacheVersion )
        else if ( key = 'SCANPATH' ) then valid := valid and ( value = UpStr(NormalizeDir(scanPath)) )
        else if ( key = 'INFOFILE' ) then valid := valid and ( value = UpStr(infoFileName) );
      end
      else if not valid then
        break
      else if ( key = 'PATH' ) then begin
        if ( game <> nil ) then AddGame(game);
        game := NewGame;
        game^.Path := NewStr(value);
      end
      else if ( key = 'LASTPLAYED' ) then ReplaceStr(game^.LastPlayed, value)
      else if ( key = 'TIMESPLAYED' ) then val(value, game^.TimesPlayed, code)
      else if ( key = 'MINUTESPLAYED' ) then val(value, game^.MinutesPlayed, code)
      else
        SetGameField(game, key, value);
    end;
  end;

  if ( game <> nil ) then begin
    if ( valid ) then AddGame(game) else DisposeGame(game);
  end;

  Close(f);

  { Discard anything read before the cache was found to be invalid }
  if not valid then GameList^.FreeAll;

  LoadGameCache := valid;
end;

{ ////////////////// Sorting & filtering ////////////////// }

{ Compare two games for the sort mode, ties broken by name then path }
function CompareGames(a,b:PGame; mode:TSortMode):integer;
var
  result_:longint;
begin
  case mode of
    smDeveloper: result_ := CompareText(PStr(a^.Developer), PStr(b^.Developer));
    smYear: result_ := CompareText(PStr(a^.Year), PStr(b^.Year));
    smGenre: result_ := CompareText(PStr(a^.Genre), PStr(b^.Genre));
    smType: result_ := CompareText(PStr(a^.GameType), PStr(b^.GameType));
    { Most played first }
    smTimesPlayed: result_ := longint(b^.TimesPlayed) - a^.TimesPlayed;
    smTimePlayed: result_ := b^.MinutesPlayed - a^.MinutesPlayed;
  else
    result_ := 0;
  end;

  if ( result_ = 0 ) then result_ := CompareText(PStr(a^.Name), PStr(b^.Name));
  if ( result_ = 0 ) then result_ := CompareText(PStr(a^.Path), PStr(b^.Path));

  if ( result_ < 0 ) then CompareGames := -1
  else if ( result_ > 0 ) then CompareGames := 1
  else CompareGames := 0;
end;

{ Sort the games list in place using a shell sort, then rebuild the view }
procedure SortGames(mode:TSortMode);
var
  gap,i,j:integer;
  temp:Pointer;
begin
  CurrentSort := mode;

  gap := GameList^.Count div 2;
  while ( gap > 0 ) do begin
    for i := gap to GameList^.Count - 1 do begin
      temp := GameList^.Items^[i];
      j := i;
      while ( j >= gap ) and ( CompareGames(GameList^.Items^[j - gap], temp, mode) > 0 ) do begin
        GameList^.Items^[j] := GameList^.Items^[j - gap];
        dec(j, gap);
      end;
      GameList^.Items^[j] := temp;
    end;
    gap := gap div 2;
  end;

  ApplyFilter(CurrentFilter);
end;

{ Rebuild the view with games whose name or type contains the filter text }
procedure ApplyFilter(filter:string);
var
  i:integer;
  game:PGame;
begin
  CurrentFilter := filter;
  ViewCount := 0;

  for i := 0 to GameList^.Count - 1 do begin
    game := GameList^.At(i);
    if ContainsText(PStr(game^.Name), CurrentFilter)
       or ContainsText(PStr(game^.GameType), CurrentFilter) then begin
      View^[ViewCount] := game;
      inc(ViewCount);
    end;
  end;
end;

{ Game at a position in the view, nil if out of range }
function ViewGame(index:integer):PGame;
begin
  if ( index >= 0 ) and ( index < ViewCount ) then
    ViewGame := View^[index]
  else
    ViewGame := nil;
end;

{ Position of a game in the view, -1 if not shown }
function IndexInView(game:PGame):integer;
var
  i:integer;
begin
  IndexInView := -1;
  for i := 0 to ViewCount - 1 do
    if ( View^[i] = game ) then begin
      IndexInView := i;
      exit;
    end;
end;

function SortModeName(mode:TSortMode):string;
begin
  case mode of
    smName: SortModeName := 'name';
    smDeveloper: SortModeName := 'developer';
    smYear: SortModeName := 'year';
    smGenre: SortModeName := 'genre';
    smType: SortModeName := 'type';
    smTimesPlayed: SortModeName := 'times played';
    smTimePlayed: SortModeName := 'time played';
  end;
end;

{ Sort mode from a SETTINGS.TXT value e.g. DefaultSort:Year }
function ParseSortMode(name:string; default:TSortMode):TSortMode;
begin
  name := UpStr(Trim(name));
  if ( name = 'NAME' ) then ParseSortMode := smName
  else if ( name = 'DEVELOPER' ) then ParseSortMode := smDeveloper
  else if ( name = 'YEAR' ) then ParseSortMode := smYear
  else if ( name = 'GENRE' ) then ParseSortMode := smGenre
  else if ( name = 'TYPE' ) then ParseSortMode := smType
  else if ( name = 'TIMESPLAYED' ) then ParseSortMode := smTimesPlayed
  else if ( name = 'TIMEPLAYED' ) then ParseSortMode := smTimePlayed
  else ParseSortMode := default;
end;

begin
  GameList := nil;
  View := nil;
  ViewCount := 0;
  MaxGames := DefaultMaxGames;
  CurrentFilter := '';
  PlayStatsEnabled := true;
  ShowScanProgress := false;
end.
