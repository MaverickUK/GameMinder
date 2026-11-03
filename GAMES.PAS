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
  { Games remembered for the exit screen }
  MaxSessionGames = 8;
  { !GM_INFO.TXT keys, in the order they're written }
  InfoFieldCount = 13;
  InfoFieldKeys: array[1..InfoFieldCount] of string[9] = (
    'NAME', 'EXEC', 'SETUP', 'DEVELOPER', 'YEAR', 'GENRE', 'TYPE',
    'VIDEO', 'SOUND', 'MEMORY', 'BEFORE', 'AFTER', 'NOTES');
  { Popularity levels, from never played to most played }
  MaxPopularity = 4;

type
  { Games sorting modes }
  TSortMode = (smName, smDeveloper, smYear, smGenre, smType, smTimesPlayed, smTimePlayed);

  { Individual game record - strings held on heap, nil when blank }
  PGame = ^TGame;
  TGame = record
    Name: PString;      { Keen 1 }
    Path: PString;      { C:\games\keen1\ }
    Exec: PString;      { keen1.exe }
    Setup: PString;     { Setup program e.g. SETUP.EXE, to choose sound and video settings }
    Developer: PString; { id software }
    Year: PString;      { 1991 }
    Genre: PString;     { Platform }
    Video: PString;     { EGA }
    Sound: PString;     { Sound Blaster }
    GameType: PString;  { Full, Demo, Shareware, Freeware... }
    MemoryKB: word;     { Conventional memory needed, 0 if not known }
    Before: PString;    { Command run before the game e.g. MOUSE.COM }
    After: PString;     { Command run after the game e.g. MOUSE OFF }
    Notes: PString;     { Anything to remember e.g. Needs the CD in the drive }
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
  { This session, for the exit screen }
  SessionCount: integer; { Different games played }
  SessionNames: array[1..MaxSessionGames] of string[40];
  SessionMinutes: array[1..MaxSessionGames] of longint;
  SessionEdits: integer; { Games added or edited }
  MostMinutesPlayed: longint; { Longest any game has been played, set by UpdatePopularity }

{ Setup & teardown }
procedure InitGames(maxCount:integer);
procedure DoneGames;
function GameCount:integer;
{ Individual games }
function PStr(p:PString):string;
function NewGame:PGame;
procedure DisposeGame(game:PGame);
function GameFieldValue(game:PGame; key:string):string;
procedure SetGameField(game:PGame; key:string; value:string);
function InfoFieldIndex(key:string):integer;
function HasSetup(game:PGame):boolean;
procedure ApplyPlayStatsLine(game:PGame; line:string);
function LoadInfoFile(path:string; infoFileName:string):PGame;
procedure LoadPlayStats(game:PGame);
function AppendPlayLog(game:PGame; line:string):boolean;
function AddGame(game:PGame):boolean;
procedure ScanForInfoFiles(path:string; infoFileName:string);
procedure ScanForGames(scanPaths:string; infoFileName:string);
{ Adding, editing and removing games }
function SaveInfoFile(game:PGame; infoFileName:string):boolean;
function DeleteInfoFile(game:PGame; infoFileName:string):boolean;
procedure RemoveGame(game:PGame);
function ExecScore(fileName:string):integer;
function SuggestExec(dir:string):string;
function SuggestSetup(dir:string):string;
procedure FindUnlistedDirs(scanPath:string; infoFileName:string; list:PStringCollection);
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
{ Stats }
procedure GetLibraryStats(var plays:longint; var minutes:longint; var mostPlayed:PGame);
procedure RecordSessionPlay(name:string; minutes:longint);
procedure UpdatePopularity;
function PopularityLevel(game:PGame):byte;

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
  DisposeStr(game^.Setup);
  DisposeStr(game^.Developer);
  DisposeStr(game^.Year);
  DisposeStr(game^.Genre);
  DisposeStr(game^.Video);
  DisposeStr(game^.Sound);
  DisposeStr(game^.GameType);
  DisposeStr(game^.Before);
  DisposeStr(game^.After);
  DisposeStr(game^.Notes);
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

{ Value of a !GM_INFO.TXT field - key must be upper case }
function GameFieldValue(game:PGame; key:string):string;
begin
  GameFieldValue := '';
  if ( key = 'NAME' ) then GameFieldValue := PStr(game^.Name)
  else if ( key = 'EXEC' ) then GameFieldValue := PStr(game^.Exec)
  else if ( key = 'SETUP' ) then GameFieldValue := PStr(game^.Setup)
  else if ( key = 'DEVELOPER' ) then GameFieldValue := PStr(game^.Developer)
  else if ( key = 'YEAR' ) then GameFieldValue := PStr(game^.Year)
  else if ( key = 'GENRE' ) then GameFieldValue := PStr(game^.Genre)
  else if ( key = 'TYPE' ) then GameFieldValue := PStr(game^.GameType)
  else if ( key = 'VIDEO' ) then GameFieldValue := PStr(game^.Video)
  else if ( key = 'SOUND' ) then GameFieldValue := PStr(game^.Sound)
  else if ( key = 'MEMORY' ) then begin
    if ( game^.MemoryKB > 0 ) then GameFieldValue := ConvertToString(game^.MemoryKB);
  end
  else if ( key = 'BEFORE' ) then GameFieldValue := PStr(game^.Before)
  else if ( key = 'AFTER' ) then GameFieldValue := PStr(game^.After)
  else if ( key = 'NOTES' ) then GameFieldValue := PStr(game^.Notes);
end;

{ Set a game field from a !GM_INFO.TXT key - key must be upper case }
procedure SetGameField(game:PGame; key:string; value:string);
begin
  if ( key = 'NAME' ) then ReplaceStr(game^.Name, value)
  else if ( key = 'EXEC' ) then ReplaceStr(game^.Exec, value)
  else if ( key = 'SETUP' ) then ReplaceStr(game^.Setup, value)
  else if ( key = 'DEVELOPER' ) then ReplaceStr(game^.Developer, value)
  else if ( key = 'YEAR' ) then ReplaceStr(game^.Year, value)
  else if ( key = 'GENRE' ) then ReplaceStr(game^.Genre, value)
  else if ( key = 'VIDEO' ) then ReplaceStr(game^.Video, value)
  else if ( key = 'SOUND' ) then ReplaceStr(game^.Sound, value)
  else if ( key = 'TYPE' ) then ReplaceStr(game^.GameType, value)
  else if ( key = 'MEMORY' ) then game^.MemoryKB := ParseMemoryKB(value)
  else if ( key = 'BEFORE' ) then ReplaceStr(game^.Before, value)
  else if ( key = 'AFTER' ) then ReplaceStr(game^.After, value)
  else if ( key = 'NOTES' ) then ReplaceStr(game^.Notes, value);
end;

{ Index of an info file key in InfoFieldKeys, 0 if GameMinder doesn't use it }
function InfoFieldIndex(key:string):integer;
var
  i:integer;
begin
  InfoFieldIndex := 0;
  for i := 1 to InfoFieldCount do
    if ( InfoFieldKeys[i] = key ) then InfoFieldIndex := i;
end;

{ Whether a game has a setup program to run }
function HasSetup(game:PGame):boolean;
begin
  HasSetup := ( game <> nil ) and ( length(Trim(PStr(game^.Setup))) > 0 );
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

{ Search each directory in a ; separated ScanPath list for game info files }
procedure ScanForGames(scanPaths:string; infoFileName:string);
var
  i:integer;
begin
  for i := 1 to ScanPathCount(scanPaths) do
    ScanForInfoFiles(ScanPathItem(scanPaths, i), infoFileName);
end;

{ ////////////////// Adding, editing and removing games ////////////////// }

{ Write a game's details to its info file. Lines GameMinder doesn't use,
  such as comments, are kept. Returns false if it couldn't be written }
function SaveInfoFile(game:PGame; infoFileName:string):boolean;
var
  source,dest:Text;
  dir,line,key,value:string;
  written:array[1..InfoFieldCount] of boolean;
  i,index:integer;
  sourceFound:boolean;

  procedure WriteField(index:integer);
  var
    fieldValue:string;
  begin
    fieldValue := GameFieldValue(game, InfoFieldKeys[index]);
    if ( length(fieldValue) > 0 ) then
      writeln(dest, LowerStr(InfoFieldKeys[index]), ':', fieldValue);
    written[index] := true;
  end;

begin
  SaveInfoFile := false;
  dir := PStr(game^.Path);
  for i := 1 to InfoFieldCount do written[i] := false;

  Assign(dest, dir + '!GM_INFO.$$$');
  {$I-}
  Rewrite(dest);
  {$I+}
  if ( IOResult <> 0 ) then exit;

  Assign(source, dir + infoFileName);
  {$I-}
  Reset(source);
  {$I+}
  sourceFound := ( IOResult = 0 );

  {$I-}
  if ( sourceFound ) then begin
    while not Eof(source) do begin
      readln(source, line);
      index := 0;
      if SplitKeyValue(line, key, value) then index := InfoFieldIndex(key);

      if ( index = 0 ) then
        writeln(dest, line) { Comment or a key GameMinder doesn't use }
      else if not written[index] then
        WriteField(index);  { Replace in place, dropping it if now blank }
    end;
    Close(source);
  end;

  for i := 1 to InfoFieldCount do
    if not written[i] then WriteField(i);
  Close(dest);
  {$I+}
  if ( IOResult <> 0 ) then exit;

  {$I-}
  if ( sourceFound ) then Erase(source);
  Rename(dest, dir + infoFileName);
  {$I+}
  SaveInfoFile := ( IOResult = 0 );
end;

{ Delete a game's info file - the game itself and its play log are left alone }
function DeleteInfoFile(game:PGame; infoFileName:string):boolean;
var
  f:Text;
begin
  Assign(f, PStr(game^.Path) + infoFileName);
  {$I-}
  Erase(f);
  {$I+}
  DeleteInfoFile := ( IOResult = 0 );
end;

{ Remove a game from the list }
procedure RemoveGame(game:PGame);
begin
  GameList^.Free(game);
  ApplyFilter(CurrentFilter);
end;

{ How likely a file is to be the program that starts a game:
  -1 if it isn't a program or is a setup/install program,
  otherwise 3 for EXE, 2 for BAT, 1 for COM }
function ExecScore(fileName:string):integer;
const
  SetupNames: array[1..10] of string[8] = (
    'SETUP', 'INSTALL', 'INSTAL', 'UNINST', 'CONFIG', 'SETSOUND', 'SOUND', 'SETMAIN', 'CATALOG', 'ORDER');
var
  ext,name:string;
  i:integer;
begin
  ExecScore := -1;
  fileName := UpStr(fileName);
  ext := FileExtension(fileName);
  name := copy(fileName, 1, length(fileName) - length(ext) - 1);

  for i := 1 to 10 do
    if ( pos(SetupNames[i], name) = 1 ) then exit;

  if ( ext = 'EXE' ) then ExecScore := 3
  else if ( ext = 'BAT' ) then ExecScore := 2
  else if ( ext = 'COM' ) then ExecScore := 1;
end;

{ Best guess at the program that starts the game in a directory, blank if none }
function SuggestExec(dir:string):string;
var
  S:SearchRec;
  best:string;
  bestScore,score:integer;
begin
  best := '';
  bestScore := -1;

  FindFirst(NormalizeDir(dir) + AllFilesMask, ReadOnly + Hidden + Archive, S);
  while ( DosError = 0 ) do begin
    score := ExecScore(S.Name);
    if ( score > bestScore ) or ( ( score = bestScore ) and ( score >= 0 ) and ( CompareText(S.Name, best) < 0 ) ) then begin
      best := S.Name;
      bestScore := score;
    end;
    FindNext(S);
  end;
  {$IFDEF FPC}
  FindClose(S);
  {$ENDIF}

  if ( bestScore < 0 ) then best := '';
  SuggestExec := best;
end;

{ Best guess at a game's setup program, blank if none. INSTALL isn't suggested,
  as in an installed game it usually installs it again }
function SuggestSetup(dir:string):string;
const
  SetupCount = 5;
  SetupNames: array[1..SetupCount] of string[8] = (
    'SETUP', 'SETSOUND', 'SOUND', 'SETMAIN', 'CONFIG');
var
  S:SearchRec;
  best,ext,name:string;
  bestRank,i:integer;
begin
  best := '';
  bestRank := SetupCount + 1;

  FindFirst(NormalizeDir(dir) + AllFilesMask, ReadOnly + Hidden + Archive, S);
  while ( DosError = 0 ) do begin
    ext := FileExtension(S.Name);
    name := UpStr(copy(S.Name, 1, length(S.Name) - length(ext) - 1));
    if ( ext = 'EXE' ) or ( ext = 'COM' ) or ( ext = 'BAT' ) then
      for i := 1 to SetupCount do
        if ( pos(SetupNames[i], name) = 1 ) then
          if ( i < bestRank ) or ( ( i = bestRank ) and ( CompareText(S.Name, best) < 0 ) ) then begin
            best := S.Name;
            bestRank := i;
          end;
    FindNext(S);
  end;
  {$IFDEF FPC}
  FindClose(S);
  {$ENDIF}

  SuggestSetup := best;
end;

{ Directories under scanPath (a ; separated list) with a program in but no info file -
  games that could be added. Directories inside a game, or inside a found directory, are skipped }
procedure FindUnlistedDirs(scanPath:string; infoFileName:string; list:PStringCollection);

  procedure Walk(path:string; isRoot:boolean);
  var
    S:SearchRec;
    hasInfo,hasProgram:boolean;
  begin
    path := NormalizeDir(path);
    hasInfo := false;
    hasProgram := false;

    { Files }
    FindFirst(path + AllFilesMask, ReadOnly + Hidden + Archive, S);
    while ( DosError = 0 ) do begin
      if ( UpStr(S.Name) = UpStr(infoFileName) ) then hasInfo := true
      else if ( ExecScore(S.Name) >= 0 ) or ( FileExtension(S.Name) = 'EXE' ) then hasProgram := true;
      FindNext(S);
    end;
    {$IFDEF FPC}
    FindClose(S);
    {$ENDIF}

    if ( hasInfo ) then exit; { Already a game }
    if ( hasProgram ) and not isRoot then begin
      list^.Insert(NewStr(path));
      exit;
    end;

    { Sub-directories }
    FindFirst(path + AllFilesMask, Directory, S);
    while ( DosError = 0 ) do begin
      if ( ( S.Attr and Directory ) <> 0 ) and ( S.Name[1] <> '.' ) then
        Walk(path + S.Name, false);
      FindNext(S);
    end;
    {$IFDEF FPC}
    FindClose(S);
    {$ENDIF}
  end;

var
  i:integer;
begin
  for i := 1 to ScanPathCount(scanPath) do
    Walk(ScanPathItem(scanPath, i), true);
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
  writeln(f, 'scanpath:', UpStr(NormalizeScanPaths(scanPath)));
  writeln(f, 'infofile:', UpStr(infoFileName));

  for i := 0 to GameList^.Count - 1 do begin
    game := GameList^.At(i);
    writeln(f);
    WriteField('path', game^.Path);
    WriteField('name', game^.Name);
    WriteField('exec', game^.Exec);
    WriteField('setup', game^.Setup);
    WriteField('developer', game^.Developer);
    WriteField('year', game^.Year);
    WriteField('genre', game^.Genre);
    WriteField('video', game^.Video);
    WriteField('sound', game^.Sound);
    WriteField('type', game^.GameType);
    if ( game^.MemoryKB > 0 ) then writeln(f, 'memory:', game^.MemoryKB);
    WriteField('before', game^.Before);
    WriteField('after', game^.After);
    WriteField('notes', game^.Notes);
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
        else if ( key = 'SCANPATH' ) then valid := valid and ( value = UpStr(NormalizeScanPaths(scanPath)) )
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

{ ////////////////// Stats ////////////////// }

{ Total plays and minutes played across all games, and the game played longest (nil if none) }
procedure GetLibraryStats(var plays:longint; var minutes:longint; var mostPlayed:PGame);
var
  i:integer;
  game:PGame;
begin
  plays := 0;
  minutes := 0;
  mostPlayed := nil;
  if ( GameList = nil ) then exit;

  for i := 0 to GameList^.Count - 1 do begin
    game := GameList^.At(i);
    inc(plays, game^.TimesPlayed);
    inc(minutes, game^.MinutesPlayed);
    if ( game^.MinutesPlayed > 0 ) then
      if ( mostPlayed = nil ) or ( game^.MinutesPlayed > mostPlayed^.MinutesPlayed ) then
        mostPlayed := game;
  end;
end;

{ Remember a game played this session. Playing a game again adds to its minutes }
procedure RecordSessionPlay(name:string; minutes:longint);
var
  i:integer;
begin
  for i := 1 to SessionCount do
    if ( SessionNames[i] = copy(name, 1, 40) ) then begin
      inc(SessionMinutes[i], minutes);
      exit;
    end;

  if ( SessionCount >= MaxSessionGames ) then exit;
  inc(SessionCount);
  SessionNames[SessionCount] := name;
  SessionMinutes[SessionCount] := minutes;
end;

{ Find the longest any game has been played, for PopularityLevel. Call after
  loading games and when play stats change }
procedure UpdatePopularity;
var
  i:integer;
  game:PGame;
begin
  MostMinutesPlayed := 0;
  if ( GameList = nil ) then exit;

  for i := 0 to GameList^.Count - 1 do begin
    game := GameList^.At(i);
    if ( game^.MinutesPlayed > MostMinutesPlayed ) then
      MostMinutesPlayed := game^.MinutesPlayed;
  end;
end;

{ How much a game has been played compared to the most played game:
  0 never played, 1 played, then 2, 3 and 4 (MaxPopularity) for at least a
  32nd, an 8th and a half of the most played game's time }
function PopularityLevel(game:PGame):byte;
var
  minutes:longint;
begin
  PopularityLevel := 0;
  if ( game^.TimesPlayed = 0 ) and ( game^.MinutesPlayed = 0 ) then exit;

  minutes := game^.MinutesPlayed;
  if ( minutes = 0 ) or ( MostMinutesPlayed = 0 ) then PopularityLevel := 1
  else if ( minutes * 2 >= MostMinutesPlayed ) then PopularityLevel := 4
  else if ( minutes * 8 >= MostMinutesPlayed ) then PopularityLevel := 3
  else if ( minutes * 32 >= MostMinutesPlayed ) then PopularityLevel := 2
  else PopularityLevel := 1;
end;

begin
  GameList := nil;
  View := nil;
  ViewCount := 0;
  MaxGames := DefaultMaxGames;
  CurrentFilter := '';
  PlayStatsEnabled := true;
  ShowScanProgress := false;
  SessionCount := 0;
  SessionEdits := 0;
  MostMinutesPlayed := 0;
end.
