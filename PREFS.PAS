Unit Prefs;
{-----------------------------
GameMinder's settings, loaded from SETTINGS.TXT

No screen code in here, so the unit can be unit tested
------------------------------}

{ --------- interface -------- }
interface
uses
    Games;

{$I VERSION.INC}

const
  SettingsFileName = 'SETTINGS.TXT';
  CacheFileName = 'GMCACHE.TXT';
  { Right hand panel / view modes - TODO: Change to enum }
  ModeHelp = 0;
  ModeInfo = 1;
  ModeStatus = 2;
  ModeFullScreen = 3;
  ModeMemory = 4;
  { Colours, matching the Crt unit's constants }
  ColBlack = 0;
  ColBlue = 1;
  ColGreen = 2;
  ColRed = 4;
  ColYellow = 14;
  ColWhite = 15;

var
  ApplicationName:string[30];
  ExeDir:string; { Directory GAMEMIND.EXE was run from, with trailing separator }

  { User configurable settings }
  ScanPath:string; { One or more directories separated by ; e.g. C:\GAMES;D:\GAMES }
  InfoFileName:string[12];
  HighlightedRow:word; { 0 = middle of the list }
  ScreenLines:word;    { 25, or 50 (43 on EGA) with GAMEMIND /50 }
  DelayAfterGameExit:word;
  DelayOnStartup:word;
  BlankLineFilter:string[30];
  UseEmsForSwapFile:boolean;
  EnablePlayStats:boolean;
  ShowPopularity:boolean; { Shaded block by each game showing how much it's been played }
  WaitForKeyAfterGame:boolean;
  CacheGames:boolean;
  ExitScreen:boolean; { Show the end screen with session stats on exit }
  ThemeSetting:string[20]; { Theme from THEMES.TXT, blank to use the Color settings }
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

function ParseView(name:string; default:byte):byte;
procedure LoadSettings;
function LoadSettingsFile:boolean;

{ --------- implementation --------- }
implementation
uses
    Utility,
    Config;

{ Parse a DefaultView setting }
function ParseView(name:string; default:byte):byte;
begin
  name := UpStr(name);
  if ( name = 'HELP' ) then ParseView := ModeHelp
  else if ( name = 'INFO' ) then ParseView := ModeInfo
  else if ( name = 'STATUS' ) then ParseView := ModeStatus
  else if ( name = 'MEMORY' ) then ParseView := ModeMemory
  else if ( name = 'FULL' ) or ( name = 'FULLSCREEN' ) then ParseView := ModeFullScreen
  else ParseView := default;
end;

{ Load user configurable settings, with defaults as fallback }
procedure LoadSettings;
begin
  VerboseOutput := GetConfigBool('VerboseOutput', false);
  ScanPath := NormalizeScanPaths(GetConfigString('ScanPath', 'C:\GAMES\'));
  InfoFileName := GetConfigString('InfoFileName', '!GM_INFO.TXT');
  HighlightedRow := GetConfigInt('HighlightedRow', 0);
  DelayAfterGameExit := GetConfigInt('DelayAfterGameExit', 0);
  DelayOnStartup := GetConfigInt('DelayOnStartup', 0);
  BlankLineFilter := GetConfigString('BlankLineFilter', '');
  UseEmsForSwapFile := GetConfigBool('UseEmsForSwapFile', true);
  EnablePlayStats := GetConfigBool('EnablePlayStats', true);
  ShowPopularity := GetConfigBool('PopularityIndicator', true);
  WaitForKeyAfterGame := GetConfigBool('WaitForKeyAfterGame', false);
  CacheGames := GetConfigBool('CacheGames', true);
  ExitScreen := GetConfigBool('ExitScreen', true);
  ThemeSetting := GetConfigString('Theme', '');
  DefaultSort := ParseSortMode(GetConfigString('DefaultSort', ''), smName);
  DefaultView := ParseView(GetConfigString('DefaultView', ''), ModeInfo);
  MaxGames := GetConfigInt('MaxGames', DefaultMaxGames);

  { Theme colours }
  ColorBackground := GetConfigColor('ColorBackground',ColBlue);
  ColorText := GetConfigColor('ColorText',ColWhite);
  ColorFrame := GetConfigColor('ColorFrame',ColWhite);
  { Heading }
  ColorHeadingBackground := GetConfigColor('ColorHeadingBackground',ColRed);
  ColorHeadingText := GetConfigColor('ColorHeadingText',ColYellow);
  { Hihghlight }
  ColorHighlightBackground := GetConfigColor('ColorHighlightBackground',ColGreen);
  ColorHighlightText := GetConfigColor('ColorHighlightText',ColYellow);
  { Horizontal menu }
  ColorHorizontalMenuPrimaryText := GetConfigColor('ColorHorizontalMenuPrimaryText',ColWhite);
  ColorHorizonalMenuHighlightText := GetConfigColor('ColorHorizonalMenuHighlightText',ColBlue);
  ColorHorizonalMenuHighlightBackground := GetConfigColor('ColorHorizonalMenuHighlightBackground',ColWhite);
end;

{ Read settings from SETTINGS.TXT next to GAMEMIND.EXE, wherever it's run from }
function LoadSettingsFile:boolean;
var
  found:boolean;
begin
  found := LoadConfigFile(ExeDir + SettingsFileName);
  LoadSettings;
  LoadSettingsFile := found;
end;

begin
  ApplicationName := 'GameMinder v' + AppVersion;
  ExeDir := DirOfPath(ParamStr(0));
  ScreenLines := 25; { Set by the /50 command line switch }
  LoadSettings; { Defaults until LoadSettingsFile is called }
end.
