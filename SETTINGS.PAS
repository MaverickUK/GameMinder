Unit Settings;
{-----------------------------
Allow settings to be read from
the external SETTINGS.TXT file
------------------------------}

{ --------- interface -------- }
interface

function GetConfigBool(key:string; default:boolean):boolean;
function GetConfigString(key:string; default:string):string;
function GetConfigInt(key:string; default:integer):integer;
function GetConfigColor(key:string; default:byte):byte;

{ --------- implementation --------- }
implementation 
uses
    Crt,
    Dos;
const
  SettingsFileName = 'SETTINGS.TXT'; 

function UpString(var s : string):string;
var k : word;
begin
    for k := 1 to length(s) do
        s[k] := UpCase(s[k]);

    UpString := s;
end;

{ Retrieve the value from a key/pair line }
function GetKeyPairValue(line:string;key:string):string;
begin
    GetKeyPairValue := copy(line, length(key) + 1, length(line) - length(key));
end;

{ Read a string based config value }
function GetConfigString(key:string; default:string):string;
const
    comment = ';';
var
    SettingsFile:Text;
    line:string[100];
    path:string;
    settingsFilePath:string;
    found:boolean;
begin
    GetDir(0,path); { TODO: Make a global variable }

    settingsFilePath := path + '\' + SettingsFileName;

    Assign(SettingsFile, settingsFilePath);
    Reset(SettingsFile);

    GetConfigString := default;
    found := false;

    while not Eof(SettingsFile) do begin
        readln(SettingsFile, line);

        if ( length(line) > 0) and (line[1] = ';') then begin
        { Commented line, skip }
        end else begin
        if ( pos(key + ':', line) = 1 ) then begin
            GetConfigString := GetKeyPairValue(line, key + ':');
            found := true;
        end;
        end;
    end;

    if ( found ) then write('.') else write(',');

    Close(SettingsFile);
end;

{ Read an integer based config value }
function GetConfigInt(key:string; default:integer):integer;
var
    temp:string;
    code:integer;
    parsedInt:integer;
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
    code:integer;
    parsedInt:integer;
begin
    GetConfigBool := default;

    temp := GetConfigString(key,'');

    { If string returned, attempt to parse }
    if ( length(temp) > 0) then begin
        GetConfigBool := (UpString(temp) = 'TRUE');
    end;
    end;  

{ Read a color based config value }
function GetConfigColor(key:string; default:byte):byte;
var
    temp,color:string;
begin
    GetConfigColor := default;

    temp := GetConfigString(key,'');

    { If string returned, attempt to parse }
    if ( length(temp) > 0 ) then begin
        color := UpString(temp);
        
        if ( color = 'BLACK' ) then GetConfigColor := Black;
        if ( color = 'BLUE' ) then GetConfigColor := Blue;
        if ( color = 'BROWN' ) then GetConfigColor := Brown;
        if ( color = 'CYAN' ) then GetConfigColor := Cyan;
        if ( color = 'DARKGRAY' ) then GetConfigColor := DarkGray;
        if ( color = 'GREEN' ) then GetConfigColor := Green;
        if ( color = 'LIGHTBLUE' ) then GetConfigColor := LightBlue;
        if ( color = 'LIGHTCYAN' ) then GetConfigColor := LightCyan;
        if ( color = 'LIGHTGRAY' ) then GetConfigColor := LightGray;
        if ( color = 'LIGHTGREEN' ) then GetConfigColor := LightGreen;
        if ( color = 'LIGHTMAGENTA' ) then GetConfigColor := LightMagenta;
        if ( color = 'LIGHTRED' ) then GetConfigColor := LightRed;
        if ( color = 'MAGENTA' ) then GetConfigColor := Magenta;
        if ( color = 'RED' ) then GetConfigColor := Red;
        if ( color = 'WHITE' ) then GetConfigColor := White;
        if ( color = 'YELLOW' ) then GetConfigColor := Yellow;
    end;
end;

end.