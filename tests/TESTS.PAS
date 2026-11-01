Program Tests;
{-----------------------------
GameMinder unit tests

Covers the pure logic units (no screen or ExecSwap) so they
can run on GitHub Actions with Free Pascal, or in DOS with TP7:

  fpc -Mtp -Fu. -FUbuild -obuild/tests tests/TESTS.PAS
  build/tests

Run from the repository root, or pass the fixtures directory
as the first parameter e.g. TESTS C:\GM\TESTS\FIXTURES\
------------------------------}
{$IFDEF MSDOS}
  {$M 16384,0,393216}
{$ENDIF}
uses
    Objects,
    Utility,
    Config,
    Games,
    Launch,
    Prefs,
    Themes;

var
  Passes,Failures:integer;
  Fixtures:string;

{ ////////////////// Assertions ////////////////// }

procedure Pass;
begin
  inc(Passes);
end;

procedure Fail(name:string; expected:string; actual:string);
begin
  inc(Failures);
  writeln('FAIL: ', name);
  writeln('  expected: "', expected, '"');
  writeln('  actual:   "', actual, '"');
end;

procedure CheckStr(name:string; expected:string; actual:string);
begin
  if ( expected = actual ) then Pass else Fail(name, expected, actual);
end;

procedure CheckInt(name:string; expected:longint; actual:longint);
begin
  if ( expected = actual ) then Pass else Fail(name, ConvertToString(expected), ConvertToString(actual));
end;

procedure CheckBool(name:string; expected:boolean; actual:boolean);
const
  BoolStr: array[boolean] of string[5] = ('false', 'true');
begin
  if ( expected = actual ) then Pass else Fail(name, BoolStr[expected], BoolStr[actual]);
end;

{ ////////////////// Helpers ////////////////// }

function MakeGame(name:string; developer:string; year:string; timesPlayed:word; minutes:longint):PGame;
var
  game:PGame;
begin
  game := NewGame;
  game^.Name := NewStr(name);
  game^.Developer := NewStr(developer);
  game^.Year := NewStr(year);
  game^.Path := NewStr('C:\GAMES\' + name + '\');
  game^.TimesPlayed := timesPlayed;
  game^.MinutesPlayed := minutes;
  MakeGame := game;
end;

{ Names of games in the view joined with | }
function ViewNames:string;
var
  i:integer;
  output:string;
begin
  output := '';
  for i := 0 to ViewCount - 1 do begin
    if ( i > 0 ) then output := output + '|';
    output := output + PStr(ViewGame(i)^.Name);
  end;
  ViewNames := output;
end;

{ ////////////////// Utility ////////////////// }

procedure TestTimes;
begin
  CheckInt('MinutesBetweenTimes same hour', 25, MinutesBetweenTimes('10:05', '10:30'));
  CheckInt('MinutesBetweenTimes no time', 0, MinutesBetweenTimes('10:05', '10:05'));
  { v0.1.x returned 2860 here }
  CheckInt('MinutesBetweenTimes across midnight', 20, MinutesBetweenTimes('23:50', '00:10'));

  CheckInt('DayNumber next day', 1, DayNumber(2022, 9, 5) - DayNumber(2022, 9, 4));
  CheckInt('DayNumber leap year', 2, DayNumber(2024, 3, 1) - DayNumber(2024, 2, 28));
  CheckInt('DayNumber non leap year', 1, DayNumber(2023, 3, 1) - DayNumber(2023, 2, 28));
  CheckInt('DayNumber new year', 1, DayNumber(2023, 1, 1) - DayNumber(2022, 12, 31));

  CheckInt('ElapsedMinutes across midnight', 20,
    ElapsedMinutes(DayNumber(2022, 12, 31), 23 * 60 + 50, DayNumber(2023, 1, 1), 10));
  CheckInt('ElapsedMinutes over a day', MinutesInDay + 5,
    ElapsedMinutes(DayNumber(2022, 9, 4), 600, DayNumber(2022, 9, 5), 605));
  CheckInt('ElapsedMinutes clock went backwards', 0,
    ElapsedMinutes(DayNumber(2022, 9, 5), 600, DayNumber(2022, 9, 4), 600));

  CheckStr('MinutesToFriendlyTime 0', 'N/A', MinutesToFriendlyTime(0));
  CheckStr('MinutesToFriendlyTime 1', '1 min', MinutesToFriendlyTime(1));
  CheckStr('MinutesToFriendlyTime 59', '59 mins', MinutesToFriendlyTime(59));
  CheckStr('MinutesToFriendlyTime 60', '1 hour', MinutesToFriendlyTime(60));
  CheckStr('MinutesToFriendlyTime 61', '1 hour 1 min', MinutesToFriendlyTime(61));
  CheckStr('MinutesToFriendlyTime 125', '2 hours 5 mins', MinutesToFriendlyTime(125));
  CheckStr('MinutesToFriendlyTime large', '1000 hours', MinutesToFriendlyTime(60000));

  CheckStr('FormatBytes small', '512 bytes', FormatBytes(512));
  CheckStr('FormatBytes KB', '640 KB', FormatBytes(655360));
  CheckStr('FormatBytes MB', '500 MB', FormatBytes(524288000));
  CheckStr('FormatBytes invalid', 'N/A', FormatBytes(-1));

  CheckStr('DosErrorText known', 'File not found', DosErrorText(2));
  CheckStr('DosErrorText unknown', 'DOS error 99', DosErrorText(99));

  CheckInt('ParseMemoryKB number', 580, ParseMemoryKB('580'));
  CheckInt('ParseMemoryKB K', 580, ParseMemoryKB(' 580K '));
  CheckInt('ParseMemoryKB KB', 580, ParseMemoryKB('580kb'));
  CheckInt('ParseMemoryKB invalid', 0, ParseMemoryKB('lots'));
  CheckInt('ParseMemoryKB too big', 0, ParseMemoryKB('4096'));
  CheckInt('ParseMemoryKB blank', 0, ParseMemoryKB(''));
end;

procedure TestStrings;
var
  key,value:string;
begin
  CheckStr('Trim', 'Keen', Trim('  Keen '#9#13));
  CheckStr('Trim blank', '', Trim('   '));
  CheckStr('UpStr', 'KEEN 4', UpStr('Keen 4'));
  CheckStr('LowerStr', 'keen 4', LowerStr('KEEN 4'));
  CheckStr('TitleCase', 'Monkey Island 2', TitleCase('MONKEY ISLAND 2'));
  CheckStr('TitleCase underscores', 'Doom_Ii', TitleCase('DOOM_II'));
  CheckStr('PadRight pads', 'Doom  ', PadRight('Doom', 6));
  CheckStr('PadRight truncates', 'Monkey', PadRight('Monkey Island', 6));
  CheckStr('PadRight zero', '', PadRight('Doom', 0));
  CheckStr('PadColumn pads', 'Doom  ', PadColumn('Doom', 6));
  CheckStr('PadColumn keeps a gap', 'Simulatio ', PadColumn('Simulation', 10));
  CheckStr('PadColumn zero', '', PadColumn('Doom', 0));
  CheckBool('CompareText equal ignoring case', true, CompareText('doom', 'DOOM') = 0);
  CheckBool('CompareText case-insensitive order', true, CompareText('doom', 'Zork') < 0);
  CheckBool('CompareText prefix shorter first', true, CompareText('Doom', 'Doom II') < 0);
  CheckBool('ContainsText match', true, ContainsText('Commander Keen 4', 'KEEN'));
  CheckBool('ContainsText no match', false, ContainsText('Doom', 'keen'));
  CheckBool('ContainsText empty filter', true, ContainsText('Doom', ''));

  CheckBool('SplitKeyValue valid', true, SplitKeyValue('Name: Commander Keen 1 ', key, value));
  CheckStr('SplitKeyValue key upper cased', 'NAME', key);
  CheckStr('SplitKeyValue value trimmed', 'Commander Keen 1', value);
  CheckBool('SplitKeyValue keeps later colons', true, SplitKeyValue('ScanPath:C:\GAMES', key, value));
  CheckStr('SplitKeyValue value with colon', 'C:\GAMES', value);
  CheckBool('SplitKeyValue comment', false, SplitKeyValue('; name:Keen', key, value));
  CheckBool('SplitKeyValue blank', false, SplitKeyValue('', key, value));
  CheckBool('SplitKeyValue no colon', false, SplitKeyValue('just text', key, value));
  CheckBool('SplitKeyValue empty value', true, SplitKeyValue('BlankLineFilter:', key, value));
  CheckStr('SplitKeyValue empty value', '', value);
  { v0.1.x truncated info lines at 50 characters }
  CheckBool('SplitKeyValue long line', true,
    SplitKeyValue('name:The Secret of Monkey Island Special Edition Collectors Box', key, value));
  CheckStr('SplitKeyValue long value', 'The Secret of Monkey Island Special Edition Collectors Box', value);
end;

procedure TestPaths;
begin
  CheckStr('NormalizeDir adds separator', 'C:\GAMES' + PathSep, NormalizeDir('C:\GAMES'));
  CheckStr('NormalizeDir keeps separator', 'C:\GAMES\', NormalizeDir('C:\GAMES\'));
  CheckStr('NormalizeDir trims', 'C:\GAMES\', NormalizeDir(' C:\GAMES\ '));
  CheckStr('NormalizeDir blank', '', NormalizeDir(''));
  CheckStr('StripTrailingSlash', 'E:\DOOM', StripTrailingSlash('E:\DOOM\'));
  CheckStr('StripTrailingSlash none', 'E:\DOOM', StripTrailingSlash('E:\DOOM'));
  CheckStr('StripTrailingSlash keeps drive root', 'E:\', StripTrailingSlash('E:\'));
  CheckStr('StripTrailingSlash keeps root', '\', StripTrailingSlash('\'));
  CheckStr('DirOfPath', 'C:\GMIND\', DirOfPath('C:\GMIND\GAMEMIND.EXE'));
  CheckStr('DirOfPath drive only', 'C:', DirOfPath('C:GAMEMIND.EXE'));
  CheckStr('DirOfPath no dir', '', DirOfPath('GAMEMIND.EXE'));
  CheckStr('FileExtension', 'BAT', FileExtension('dune.bat'));
  CheckStr('FileExtension none', '', FileExtension('C:\GAMES.DIR\RUN'));
end;

{ ////////////////// Config ////////////////// }

procedure TestConfig;
begin
  CheckBool('LoadConfigFile missing file', false, LoadConfigFile(Fixtures + 'NOSUCH.TXT'));
  CheckStr('GetConfigString default when no file', 'C:\GAMES\', GetConfigString('ScanPath', 'C:\GAMES\'));

  CheckBool('LoadConfigFile', true, LoadConfigFile(Fixtures + 'SETTINGS.TXT'));
  CheckStr('GetConfigString', 'D:\GAMES', GetConfigString('ScanPath', ''));
  CheckStr('GetConfigString key case-insensitive', 'D:\GAMES', GetConfigString('SCANPATH', ''));
  CheckStr('GetConfigString missing key', 'fallback', GetConfigString('Missing', 'fallback'));
  CheckStr('GetConfigString blank value uses default', '-----', GetConfigString('BlankLineFilter', '-----'));
  CheckBool('GetConfigBool lower case key', true, GetConfigBool('VerboseOutput', false));
  CheckBool('GetConfigBool no', false, GetConfigBool('EnablePlayStats', true));
  CheckBool('GetConfigBool missing', true, GetConfigBool('Missing', true));
  CheckInt('GetConfigInt later line wins', 500, GetConfigInt('DelayOnStartup', 0));
  CheckInt('GetConfigInt not a number', 7, GetConfigInt('ScanPath', 7));
  CheckInt('GetConfigColor name', 9, GetConfigColor('ColorBackground', 1));
  CheckInt('GetConfigColor number', 14, GetConfigColor('ColorText', 1));
  CheckInt('GetConfigColor unknown', 15, GetConfigColor('ColorFrame', 15));
  CheckInt('ParseColor mixed case', 13, ParseColor('LightMagenta', 0));
  CheckInt('ParseColor out of range', 3, ParseColor('16', 3));
  ClearConfig;
end;

procedure TestSaveConfig;
const
  TestFile = 'TESTSET.TXT';
var
  f:Text;
  line:string;
  lines:integer;
begin
  { New file }
  CheckBool('SaveConfigValue creates file', true, SaveConfigValue(TestFile, 'Theme', 'Turbo'));
  CheckBool('SaveConfigValue reload', true, LoadConfigFile(TestFile));
  CheckStr('SaveConfigValue value', 'Turbo', GetConfigString('Theme', ''));

  { Replace, keeping comments and other settings }
  Assign(f, TestFile);
  Rewrite(f);
  writeln(f, '; My settings');
  writeln(f, 'ScanPath:D:\GAMES');
  writeln(f, 'theme:Classic');
  writeln(f, '; Theme:Commented');
  Close(f);
  CheckBool('SaveConfigValue replace', true, SaveConfigValue(TestFile, 'Theme', 'Amber'));
  CheckStr('SaveConfigValue updates loaded settings', 'Amber', GetConfigString('Theme', ''));

  Reset(f);
  lines := 0;
  while not Eof(f) do begin
    readln(f, line);
    inc(lines);
    case lines of
      1: CheckStr('SaveConfigValue keeps comment', '; My settings', line);
      2: CheckStr('SaveConfigValue keeps setting', 'ScanPath:D:\GAMES', line);
      3: CheckStr('SaveConfigValue replaces line', 'Theme:Amber', line);
      4: CheckStr('SaveConfigValue ignores commented key', '; Theme:Commented', line);
    end;
  end;
  Close(f);
  CheckInt('SaveConfigValue line count', 4, lines);

  Erase(f);
  ClearConfig;
end;

procedure TestThemes;
var
  theme:TTheme;
begin
  CheckBool('ParseThemeLine', true, ParseThemeLine('Turbo: Background=Blue Text=Yellow', theme));
  CheckStr('ParseThemeLine name', 'Turbo', theme.Name);
  CheckInt('ParseThemeLine colour', 14, theme.Colors[teText]);
  CheckInt('ParseThemeLine default for missing element', 2, theme.Colors[teHighlightBack]);
  CheckBool('ParseThemeLine comment', false, ParseThemeLine('; Turbo: Text=Yellow', theme));
  CheckBool('ParseThemeLine blank', false, ParseThemeLine('  ', theme));
  CheckBool('ParseThemeLine no name', false, ParseThemeLine(':Text=Yellow', theme));

  CheckInt('LoadThemes missing file', 0, LoadThemes(Fixtures + 'NOSUCH.TXT'));
  CheckInt('LoadThemes', 3, LoadThemes(Fixtures + 'THEMES.TXT'));
  CheckInt('FindTheme', 2, FindTheme('green screen'));
  CheckInt('FindTheme missing', 0, FindTheme('Turbo'));
  CheckStr('ThemeName with spaces', 'Green Screen', ThemeName(2));
  CheckStr('ThemeName out of range', '', ThemeName(9));

  GetTheme(2, theme);
  CheckInt('Theme lower case element', 0, theme.Colors[teBackground]);
  CheckInt('Theme upper case element', 10, theme.Colors[teText]);
  CheckInt('Theme numeric colour', 2, theme.Colors[teHighlightBack]);
  CheckInt('Theme unknown colour keeps default', 15, theme.Colors[teFrame]);

  ApplyTheme(2);
  CheckInt('ApplyTheme current', 2, CurrentTheme);
  CheckInt('ApplyTheme background', 0, ColorBackground);
  CheckInt('ApplyTheme text', 10, ColorText);
  CheckInt('ApplyTheme heading default', 4, ColorHeadingBackground);

  ApplyTheme(0);
  CheckInt('ApplyTheme out of range ignored', 2, CurrentTheme);

  GetTheme(3, theme);
  CheckStr('Theme with no colours', 'Empty', theme.Name);
  CheckInt('Theme with no colours uses Classic', 1, theme.Colors[teBackground]);
end;

{ ////////////////// Games ////////////////// }

procedure TestInfoAndStats;
var
  game:PGame;
begin
  game := LoadInfoFile(Fixtures + 'GAMES' + PathSep + 'KEEN1' + PathSep, '!GM_INFO.TXT');
  CheckBool('LoadInfoFile found', true, game <> nil);
  if ( game = nil ) then exit;

  CheckStr('LoadInfoFile name trimmed', 'Commander Keen 1', PStr(game^.Name));
  CheckStr('LoadInfoFile exec', 'keen1.exe', PStr(game^.Exec));
  CheckStr('LoadInfoFile mixed case key', 'id software', PStr(game^.Developer));
  CheckStr('LoadInfoFile sound', 'PC Speaker', PStr(game^.Sound));
  CheckStr('LoadInfoFile type', 'Shareware', PStr(game^.GameType));
  CheckInt('LoadInfoFile memory', 512, game^.MemoryKB);
  CheckBool('LoadInfoFile no before', true, game^.Before = nil);

  LoadPlayStats(game);
  CheckInt('LoadPlayStats times played', 3, game^.TimesPlayed);
  CheckInt('LoadPlayStats minutes', 65, game^.MinutesPlayed);
  CheckStr('LoadPlayStats last played', '2022/09/06 23:50', PStr(game^.LastPlayed));

  { Reloading doesn't double count }
  LoadPlayStats(game);
  CheckInt('LoadPlayStats reload', 3, game^.TimesPlayed);

  ApplyPlayStatsLine(game, '');
  ApplyPlayStatsLine(game, 'garbage');
  ApplyPlayStatsLine(game, '<abc');
  CheckInt('ApplyPlayStatsLine ignores bad lines', 65, game^.MinutesPlayed);

  CheckBool('LoadInfoFile missing', true,
    LoadInfoFile(Fixtures + 'GAMES' + PathSep + 'NOSUCH' + PathSep, '!GM_INFO.TXT') = nil);

  game := LoadInfoFile(Fixtures + 'GAMES' + PathSep + 'ACTION' + PathSep + 'DUNE' + PathSep, '!GM_INFO.TXT');
  CheckBool('LoadInfoFile Dune', true, game <> nil);
  if ( game <> nil ) then begin
    CheckStr('LoadInfoFile before', 'C:\MOUSE\MOUSE.COM', PStr(game^.Before));
    CheckStr('LoadInfoFile after', 'C:\MOUSE\MOUSE OFF', PStr(game^.After));
  end;

  game := LoadInfoFile(Fixtures + 'GAMES' + PathSep + 'NONAME', '!GM_INFO.TXT');
  CheckBool('LoadInfoFile without name', true, game <> nil);
  if ( game <> nil ) then
    CheckStr('LoadInfoFile name falls back to directory', 'NONAME', PStr(game^.Name));
end;

procedure TestPlayLog;
var
  game:PGame;
  f:Text;
begin
  game := NewGame;
  game^.Path := NewStr('');
  CheckBool('AppendPlayLog creates file', true, AppendPlayLog(game, '>2022/09/04 05:34'));
  CheckBool('AppendPlayLog appends', true, AppendPlayLog(game, '<15'));
  LoadPlayStats(game);
  CheckInt('AppendPlayLog round trip times', 1, game^.TimesPlayed);
  CheckInt('AppendPlayLog round trip minutes', 15, game^.MinutesPlayed);

  Assign(f, PlayStatsFileName);
  Erase(f);

  { e.g. a game on CD-ROM - mustn't crash }
  game^.Path := NewStr(Fixtures + 'NOSUCH' + PathSep);
  CheckBool('AppendPlayLog unwritable', false, AppendPlayLog(game, '<15'));
end;

procedure TestScan;
begin
  InitGames(DefaultMaxGames);
  PlayStatsEnabled := true;
  ScanForInfoFiles(Fixtures + 'GAMES', '!GM_INFO.TXT');
  CheckInt('Scan finds nested games without trailing separator', 4, GameCount);

  SortGames(smName);
  CheckStr('Sort by name is case-insensitive', 'Commander Keen 1|doom|Dune|NONAME', ViewNames);

  SortGames(smYear);
  CheckStr('Sort by year, missing year first', 'NONAME|Commander Keen 1|Dune|doom', ViewNames);

  SortGames(smTimesPlayed);
  CheckStr('Sort by times played, most first', 'Commander Keen 1|doom|Dune|NONAME', ViewNames);

  SortGames(smType);
  CheckStr('Sort by type, missing type first', 'doom|NONAME|Dune|Commander Keen 1', ViewNames);

  SortGames(smName);
  ApplyFilter('keen');
  CheckStr('Filter by substring', 'Commander Keen 1', ViewNames);
  ApplyFilter('D');
  CheckStr('Filter keeps sort order', 'Commander Keen 1|doom|Dune', ViewNames);
  ApplyFilter('SHAREWARE');
  CheckStr('Filter matches type', 'Commander Keen 1', ViewNames);
  ApplyFilter('zzz');
  CheckInt('Filter with no matches', 0, ViewCount);
  CheckBool('ViewGame out of range', true, ViewGame(0) = nil);
  SortGames(smDeveloper);
  CheckInt('Filter survives sort', 0, ViewCount);
  ApplyFilter('');
  CheckInt('Clear filter', 4, ViewCount);

  { Single game - v0.1.x sort overran the stack here (Tiny Llama crash) }
  InitGames(DefaultMaxGames);
  ScanForInfoFiles(Fixtures + 'SINGLE' + PathSep, '!GM_INFO.TXT');
  CheckInt('Scan single game', 1, GameCount);
  SortGames(smName);
  CheckStr('Sort single game', 'Commander Keen 4', ViewNames);

  { No games }
  InitGames(DefaultMaxGames);
  ScanForInfoFiles(Fixtures + 'NOSUCH', '!GM_INFO.TXT');
  CheckInt('Scan missing directory', 0, GameCount);
  SortGames(smName);
  CheckInt('Sort no games', 0, ViewCount);

  { Cap }
  InitGames(2);
  ScanForInfoFiles(Fixtures + 'GAMES', '!GM_INFO.TXT');
  CheckInt('Scan stops at cap', 2, GameCount);
  CheckBool('Scan reports cap reached', true, GameCapReached);
end;

procedure TestSortMany;
const
  Total = 1500;
var
  i:integer;
  sorted:boolean;
  game:PGame;
begin
  InitGames(2000);
  { Reverse order names: Game 1499 .. Game 0000 }
  for i := Total - 1 downto 0 do
    AddGame(MakeGame('Game ' + FormatDatePart(i, 4), '', '', i mod 7, i));

  CheckInt('Add more than 255 games', Total, GameCount);
  SortGames(smName);
  CheckInt('View holds all games', Total, ViewCount);

  sorted := true;
  for i := 1 to ViewCount - 1 do
    if CompareGames(ViewGame(i - 1), ViewGame(i), smName) > 0 then sorted := false;
  CheckBool('Large sort ordered', true, sorted);
  CheckStr('Large sort first', 'Game 0000', PStr(ViewGame(0)^.Name));
  CheckStr('Large sort last', 'Game 1499', PStr(ViewGame(Total - 1)^.Name));

  SortGames(smTimePlayed);
  CheckStr('Sort by time played, most first', 'Game 1499', PStr(ViewGame(0)^.Name));

  game := ViewGame(10);
  CheckInt('IndexInView', 10, IndexInView(game));
  ApplyFilter('Game 0001');
  CheckInt('IndexInView filtered out', -1, IndexInView(game));

  DoneGames;
  CheckInt('DoneGames', 0, GameCount);
end;

procedure TestSortModes;
begin
  CheckBool('ParseSortMode', true, ParseSortMode('year', smName) = smYear);
  CheckBool('ParseSortMode played', true, ParseSortMode('TimesPlayed', smName) = smTimesPlayed);
  CheckBool('ParseSortMode unknown', true, ParseSortMode('rating', smGenre) = smGenre);
  CheckStr('SortModeName', 'developer', SortModeName(smDeveloper));
end;

procedure TestCache;
const
  CacheFile = 'TESTCACH.TXT';
var
  game:PGame;
  scanPath:string;
  f:Text;
begin
  scanPath := Fixtures + 'GAMES';

  InitGames(DefaultMaxGames);
  CheckBool('LoadGameCache missing file', false, LoadGameCache(CacheFile, scanPath, '!GM_INFO.TXT'));

  PlayStatsEnabled := true;
  ScanForInfoFiles(scanPath, '!GM_INFO.TXT');
  CheckBool('SaveGameCache', true, SaveGameCache(CacheFile, scanPath, '!GM_INFO.TXT'));

  InitGames(DefaultMaxGames);
  CheckBool('LoadGameCache', true, LoadGameCache(CacheFile, scanPath, '!GM_INFO.TXT'));
  CheckInt('LoadGameCache count', 4, GameCount);

  SortGames(smName);
  CheckStr('LoadGameCache names', 'Commander Keen 1|doom|Dune|NONAME', ViewNames);
  game := ViewGame(0);
  CheckStr('LoadGameCache path', NormalizeDir(scanPath) + 'KEEN1' + PathSep, PStr(game^.Path));
  CheckStr('LoadGameCache exec', 'keen1.exe', PStr(game^.Exec));
  CheckStr('LoadGameCache type', 'Shareware', PStr(game^.GameType));
  CheckInt('LoadGameCache memory', 512, game^.MemoryKB);
  CheckInt('LoadGameCache times played', 3, game^.TimesPlayed);
  CheckInt('LoadGameCache minutes played', 65, game^.MinutesPlayed);
  CheckStr('LoadGameCache last played', '2022/09/06 23:50', PStr(game^.LastPlayed));
  game := ViewGame(1);
  CheckStr('LoadGameCache arguments', 'DOOM.EXE -nomonsters', PStr(game^.Exec));
  game := ViewGame(2);
  CheckStr('LoadGameCache before', 'C:\MOUSE\MOUSE.COM', PStr(game^.Before));

  InitGames(DefaultMaxGames);
  CheckBool('LoadGameCache different scan path', false, LoadGameCache(CacheFile, Fixtures + 'SINGLE', '!GM_INFO.TXT'));
  CheckInt('LoadGameCache different scan path is empty', 0, GameCount);
  CheckBool('LoadGameCache different info file', false, LoadGameCache(CacheFile, scanPath, 'GAME.TXT'));
  CheckBool('LoadGameCache scan path case-insensitive', true, LoadGameCache(CacheFile, UpStr(scanPath), '!gm_info.txt'));

  Assign(f, CacheFile);
  Erase(f);
  DoneGames;
end;

procedure TestEditGames;
const
  Dir = 'TESTGAME';
var
  game:PGame;
  f:Text;
  line:string;
  lines:integer;
  path:string;
begin
  path := Dir + PathSep;
  {$I-} MkDir(Dir); {$I+}
  if ( IOResult <> 0 ) then ;

  Assign(f, path + '!GM_INFO.TXT');
  Rewrite(f);
  writeln(f, '; Keen notes');
  writeln(f, 'name:Keen');
  writeln(f, 'rating:5');
  writeln(f, 'exec:KEEN.EXE');
  writeln(f, 'genre:Platform');
  writeln(f, 'name:Duplicate');
  Close(f);

  game := LoadInfoFile(path, '!GM_INFO.TXT');
  CheckStr('GameFieldValue', 'KEEN.EXE', GameFieldValue(game, 'EXEC'));
  CheckStr('GameFieldValue blank memory', '', GameFieldValue(game, 'MEMORY'));

  SetGameField(game, 'NAME', 'Commander Keen');
  SetGameField(game, 'GENRE', '');
  SetGameField(game, 'YEAR', '1991');
  SetGameField(game, 'MEMORY', '520');
  CheckStr('GameFieldValue memory', '520', GameFieldValue(game, 'MEMORY'));
  CheckBool('SaveInfoFile', true, SaveInfoFile(game, '!GM_INFO.TXT'));

  Reset(f);
  lines := 0;
  while not Eof(f) do begin
    readln(f, line);
    inc(lines);
    case lines of
      1: CheckStr('SaveInfoFile keeps comment', '; Keen notes', line);
      2: CheckStr('SaveInfoFile replaces in place', 'name:Commander Keen', line);
      3: CheckStr('SaveInfoFile keeps unknown key', 'rating:5', line);
      4: CheckStr('SaveInfoFile keeps exec', 'exec:KEEN.EXE', line);
      5: CheckStr('SaveInfoFile adds new field', 'year:1991', line);
      6: CheckStr('SaveInfoFile adds memory', 'memory:520', line);
    end;
  end;
  Close(f);
  CheckInt('SaveInfoFile drops blank and duplicate fields', 6, lines);

  game := LoadInfoFile(path, '!GM_INFO.TXT');
  CheckStr('SaveInfoFile round trip', 'Commander Keen', PStr(game^.Name));

  { New game with no info file yet }
  Erase(f);
  CheckBool('SaveInfoFile new file', true, SaveInfoFile(game, '!GM_INFO.TXT'));
  game := LoadInfoFile(path, '!GM_INFO.TXT');
  CheckStr('SaveInfoFile new file round trip', '1991', PStr(game^.Year));

  CheckBool('DeleteInfoFile', true, DeleteInfoFile(game, '!GM_INFO.TXT'));
  CheckBool('DeleteInfoFile removed it', true, LoadInfoFile(path, '!GM_INFO.TXT') = nil);
  CheckBool('DeleteInfoFile missing', false, DeleteInfoFile(game, '!GM_INFO.TXT'));
  RmDir(Dir);

  { Removing from the list }
  InitGames(10);
  AddGame(MakeGame('Doom', '', '', 0, 0));
  game := MakeGame('Keen', '', '', 0, 0);
  AddGame(game);
  AddGame(MakeGame('Dune', '', '', 0, 0));
  SortGames(smName);
  RemoveGame(game);
  CheckInt('RemoveGame count', 2, GameCount);
  CheckStr('RemoveGame view', 'Doom|Dune', ViewNames);
  DoneGames;
end;

procedure TestFindGames;
var
  list:PStringCollection;
  root:string;
begin
  CheckInt('ExecScore exe', 3, ExecScore('doom.exe'));
  CheckInt('ExecScore bat', 2, ExecScore('START.BAT'));
  CheckInt('ExecScore com', 1, ExecScore('RUN.COM'));
  CheckInt('ExecScore setup', -1, ExecScore('SETUP.EXE'));
  CheckInt('ExecScore install', -1, ExecScore('INSTALL.BAT'));
  CheckInt('ExecScore not a program', -1, ExecScore('README.TXT'));

  root := Fixtures + 'UNLISTED' + PathSep;
  CheckBool('FileExists', true, FileExists(root + 'NEWGAME' + PathSep + 'START.BAT'));
  CheckBool('FileExists missing', false, FileExists(root + 'NEWGAME' + PathSep + 'NOSUCH.EXE'));
  CheckStr('SuggestExec prefers exe, skips setup', 'NEWGAME.EXE', SuggestExec(root + 'NEWGAME'));
  CheckStr('SuggestExec batch file', 'RUN.BAT', SuggestExec(root + 'BATONLY'));
  CheckStr('SuggestExec only setup', '', SuggestExec(root + 'SETUPONLY'));
  CheckStr('SuggestExec no programs', '', SuggestExec(root + 'NOPROG'));

  list := New(PStringCollection, Init(10, 10));
  FindUnlistedDirs(root, '!GM_INFO.TXT', list);
  CheckInt('FindUnlistedDirs count', 4, list^.Count);
  if ( list^.Count = 4 ) then begin
    CheckStr('FindUnlistedDirs 1', root + 'BATONLY' + PathSep, PString(list^.At(0))^);
    CheckStr('FindUnlistedDirs nested', root + 'GROUP' + PathSep + 'INNER' + PathSep, PString(list^.At(1))^);
    CheckStr('FindUnlistedDirs 3', root + 'NEWGAME' + PathSep, PString(list^.At(2))^);
    CheckStr('FindUnlistedDirs setup only', root + 'SETUPONLY' + PathSep, PString(list^.At(3))^);
  end;
  Dispose(list, Done);
end;

{ ////////////////// Launch ////////////////// }

procedure TestLaunch;
var
  prog,args:string;
  script:TLaunchScript;
begin
  BuildLaunchCommand('E:\GAMES\DOOM\', 'DOOM.EXE', 'C:\COMMAND.COM', prog, args);
  CheckStr('Launch exe on another drive', 'E:\GAMES\DOOM\DOOM.EXE', prog);
  CheckStr('Launch exe args', '', args);

  BuildLaunchCommand('E:\GAMES\DOOM\', 'DOOM.EXE -nomonsters', '', prog, args);
  CheckStr('Launch exe with args prog', 'E:\GAMES\DOOM\DOOM.EXE', prog);
  CheckStr('Launch exe with args', '-nomonsters', args);

  BuildLaunchCommand('C:\GAMES\DUNE\', 'dune.bat', 'C:\DOS\COMMAND.COM', prog, args);
  CheckStr('Launch bat uses COMSPEC', 'C:\DOS\COMMAND.COM', prog);
  CheckStr('Launch bat args', '/C C:\GAMES\DUNE\dune.bat', args);

  BuildLaunchCommand('C:\GAMES\BIO\', 'EPISODE.BAT 2', '', prog, args);
  CheckStr('Launch bat without COMSPEC', DefaultComSpec, prog);
  CheckStr('Launch bat with args', '/C C:\GAMES\BIO\EPISODE.BAT 2', args);

  BuildLaunchCommand('C:\GAMES\X\', 'D:\TOOLS\RUN.COM', '', prog, args);
  CheckStr('Launch full path exec', 'D:\TOOLS\RUN.COM', prog);

  CheckStr('GameProgram', 'C:\GAMES\DOOM\DOOM.EXE', GameProgram('C:\GAMES\DOOM\', 'DOOM.EXE -nomonsters'));
  CheckStr('GameProgram batch file', 'C:\GAMES\DUNE\dune.bat', GameProgram('C:\GAMES\DUNE\', 'dune.bat'));
  CheckStr('GameProgram full path', 'D:\TOOLS\RUN.COM', GameProgram('C:\GAMES\X\', 'D:\TOOLS\RUN.COM /X'));
  CheckBool('NeedsLaunchScript none', false, NeedsLaunchScript('', ' '));
  CheckBool('NeedsLaunchScript before', true, NeedsLaunchScript('MOUSE', ''));
  CheckBool('NeedsLaunchScript after', true, NeedsLaunchScript('', 'MOUSE OFF'));

  BuildLaunchScript('C:\GAMES\DOOM\', 'DOOM.EXE -nomonsters', ' C:\MOUSE\MOUSE.COM ', 'C:\MOUSE\MOUSE OFF', script);
  CheckInt('Launch script lines', 4, script.Count);
  CheckStr('Launch script echo off', '@ECHO OFF', script.Lines[1]);
  CheckStr('Launch script before', 'C:\MOUSE\MOUSE.COM', script.Lines[2]);
  CheckStr('Launch script game', 'C:\GAMES\DOOM\DOOM.EXE -nomonsters', script.Lines[3]);
  CheckStr('Launch script after', 'C:\MOUSE\MOUSE OFF', script.Lines[4]);

  BuildLaunchScript('C:\GAMES\DUNE\', 'dune.bat', '', 'MOUSE OFF', script);
  CheckInt('Launch script without before', 3, script.Count);
  CheckStr('Launch script calls batch file', 'CALL C:\GAMES\DUNE\dune.bat', script.Lines[2]);
end;

begin
  Passes := 0;
  Failures := 0;

  if ( ParamCount > 0 ) then
    Fixtures := NormalizeDir(ParamStr(1))
  else
    Fixtures := 'tests' + PathSep + 'fixtures' + PathSep;

  TestTimes;
  TestStrings;
  TestPaths;
  TestConfig;
  TestSaveConfig;
  TestThemes;
  TestInfoAndStats;
  TestPlayLog;
  TestScan;
  TestSortMany;
  TestSortModes;
  TestCache;
  TestEditGames;
  TestFindGames;
  TestLaunch;

  writeln(Passes, ' passed, ', Failures, ' failed');
  if ( Failures > 0 ) then Halt(1);
end.
