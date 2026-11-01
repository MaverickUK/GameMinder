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
    Launch;

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
end;

procedure TestStrings;
var
  key,value:string;
begin
  CheckStr('Trim', 'Keen', Trim('  Keen '#9#13));
  CheckStr('Trim blank', '', Trim('   '));
  CheckStr('UpStr', 'KEEN 4', UpStr('Keen 4'));
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

  SortGames(smName);
  ApplyFilter('keen');
  CheckStr('Filter by substring', 'Commander Keen 1', ViewNames);
  ApplyFilter('D');
  CheckStr('Filter keeps sort order', 'Commander Keen 1|doom|Dune', ViewNames);
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

{ ////////////////// Launch ////////////////// }

procedure TestLaunch;
var
  prog,args:string;
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
  TestInfoAndStats;
  TestPlayLog;
  TestScan;
  TestSortMany;
  TestSortModes;
  TestLaunch;

  writeln(Passes, ' passed, ', Failures, ' failed');
  if ( Failures > 0 ) then Halt(1);
end.
