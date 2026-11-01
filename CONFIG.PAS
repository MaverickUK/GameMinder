Unit Config;
{-----------------------------
Allow settings to be read from
the external SETTINGS.TXT file

The file is read once into memory by LoadConfigFile,
the GetConfig* functions then look values up from there
------------------------------}

{ --------- interface -------- }
interface

function LoadConfigFile(fileName:string):boolean;
procedure ClearConfig;
procedure SetConfigValue(key:string; value:string);
function GetConfigString(key:string; default:string):string;
function GetConfigInt(key:string; default:longint):longint;
function GetConfigBool(key:string; default:boolean):boolean;
function GetConfigColor(key:string; default:byte):byte;
function ParseColor(name:string; default:byte):byte;

{ --------- implementation --------- }
implementation
uses
    Objects,
    Utility;
const
  MaxConfigEntries = 64;
  { Index matches the Crt colour constant value }
  ColorNames: array[0..15] of string[12] = (
    'BLACK', 'BLUE', 'GREEN', 'CYAN', 'RED', 'MAGENTA', 'BROWN', 'LIGHTGRAY',
    'DARKGRAY', 'LIGHTBLUE', 'LIGHTGREEN', 'LIGHTCYAN', 'LIGHTRED', 'LIGHTMAGENTA', 'YELLOW', 'WHITE');
var
  ConfigCount:integer;
  ConfigKeys: array[1..MaxConfigEntries] of PString;
  ConfigValues: array[1..MaxConfigEntries] of PString;

{ Find the index of a key, 0 if not found }
function FindKey(key:string):integer;
var
  i:integer;
begin
  FindKey := 0;
  key := UpStr(key);
  for i := 1 to ConfigCount do
    if ( ConfigKeys[i]^ = key ) then begin
      FindKey := i;
      exit;
    end;
end;

procedure ClearConfig;
var
  i:integer;
begin
  for i := 1 to ConfigCount do begin
    DisposeStr(ConfigKeys[i]);
    DisposeStr(ConfigValues[i]);
  end;
  ConfigCount := 0;
end;

{ Add or replace a setting - a later line in the file wins }
procedure SetConfigValue(key:string; value:string);
var
  i:integer;
begin
  key := UpStr(key);
  i := FindKey(key);

  if ( i = 0 ) then begin
    if ( ConfigCount >= MaxConfigEntries ) then exit;
    inc(ConfigCount);
    i := ConfigCount;
    ConfigKeys[i] := NewStr(key);
  end else
    DisposeStr(ConfigValues[i]);

  ConfigValues[i] := NewStr(value); { nil when value is blank }
end;

{ Load settings file into memory, returns false if it couldn't be read }
function LoadConfigFile(fileName:string):boolean;
var
  SettingsFile:Text;
  line,key,value:string;
begin
  LoadConfigFile := false;
  ClearConfig;

  Assign(SettingsFile, fileName);
  {$I-}
  Reset(SettingsFile);
  {$I+}
  if ( IOResult <> 0 ) then exit;

  while not Eof(SettingsFile) do begin
    readln(SettingsFile, line);
    if SplitKeyValue(line, key, value) then
      SetConfigValue(key, value);
  end;

  Close(SettingsFile);
  LoadConfigFile := true;
end;

{ Read a string based config value }
function GetConfigString(key:string; default:string):string;
var
  i:integer;
begin
  i := FindKey(key);
  if ( i > 0 ) and ( ConfigValues[i] <> nil ) then
    GetConfigString := ConfigValues[i]^
  else
    GetConfigString := default;
end;

{ Read an integer based config value }
function GetConfigInt(key:string; default:longint):longint;
var
  temp:string;
  code:integer;
  parsedInt:longint;
begin
  GetConfigInt := default;

  temp := GetConfigString(key,'');

  { If string returned, attempt to parse to int }
  if ( length(temp) > 0) then begin
    val(temp, parsedInt, code);
    if (code = 0) then GetConfigInt := parsedInt;
  end;
end;

{ Read a boolean based config value }
function GetConfigBool(key:string; default:boolean):boolean;
var
  temp:string;
begin
  temp := UpStr(GetConfigString(key,''));

  if ( temp = 'TRUE' ) or ( temp = 'YES' ) or ( temp = '1' ) then
    GetConfigBool := true
  else if ( temp = 'FALSE' ) or ( temp = 'NO' ) or ( temp = '0' ) then
    GetConfigBool := false
  else
    GetConfigBool := default;
end;

{ Convert a colour name (e.g. LightBlue) or number (0-15) to a colour }
function ParseColor(name:string; default:byte):byte;
var
  i:byte;
  code:integer;
begin
  ParseColor := default;
  name := UpStr(Trim(name));

  for i := 0 to 15 do
    if ( ColorNames[i] = name ) then begin
      ParseColor := i;
      exit;
    end;

  val(name, i, code);
  if ( code = 0 ) and ( i <= 15 ) then ParseColor := i;
end;

{ Read a color based config value }
function GetConfigColor(key:string; default:byte):byte;
begin
  GetConfigColor := ParseColor(GetConfigString(key,''), default);
end;

begin
  ConfigCount := 0;
end.
