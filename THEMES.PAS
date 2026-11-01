Unit Themes;
{-----------------------------
Colour themes, loaded from THEMES.TXT next to GAMEMIND.EXE

One theme per line - its name, a colon, then element=colour pairs:

  Turbo: Background=Blue Text=Yellow HighlightBack=Cyan

Elements left out use the Classic colours. Colours are names
(e.g. LightBlue) or numbers 0-15.
------------------------------}

{ --------- interface -------- }
interface

const
  ThemesFileName = 'THEMES.TXT';
  MaxThemes = 30;

type
  TThemeElement = (teBackground, teText, teFrame, teHeadingText, teHeadingBack,
                   teHighlightText, teHighlightBack, teMenuText,
                   teMenuHighlightText, teMenuHighlightBack);

  TTheme = record
    Name: string[20];
    Colors: array[TThemeElement] of byte;
  end;

var
  ThemeCount:integer;
  CurrentTheme:integer; { Index of the theme in use, 0 if none }

function ParseThemeLine(line:string; var theme:TTheme):boolean;
function LoadThemes(fileName:string):integer;
function FindTheme(name:string):integer;
function ThemeName(index:integer):string;
procedure GetTheme(index:integer; var theme:TTheme);
procedure ApplyTheme(index:integer);

{ --------- implementation --------- }
implementation
uses
    Utility,
    Config,
    Prefs;

const
  ElementNames: array[TThemeElement] of string[17] = (
    'BACKGROUND', 'TEXT', 'FRAME', 'HEADINGTEXT', 'HEADINGBACK',
    'HIGHLIGHTTEXT', 'HIGHLIGHTBACK', 'MENUTEXT',
    'MENUHIGHLIGHTTEXT', 'MENUHIGHLIGHTBACK');

  { GameMinder's original colours, used for anything a theme leaves out }
  ClassicColors: array[TThemeElement] of byte = (
    ColBlue, ColWhite, ColWhite, ColYellow, ColRed,
    ColYellow, ColGreen, ColWhite,
    ColBlue, ColWhite);

var
  ThemeList: array[1..MaxThemes] of TTheme;

{ Parse "Name: element=colour element=colour ...", returns false if it isn't a theme }
function ParseThemeLine(line:string; var theme:TTheme):boolean;
var
  colon,space,equals:byte;
  pair,key:string;
  element:TThemeElement;
begin
  ParseThemeLine := false;

  line := Trim(line);
  if ( length(line) = 0 ) or ( line[1] = ';' ) then exit;
  colon := pos(':', line);
  if ( colon <= 1 ) then exit;

  theme.Name := Trim(copy(line, 1, colon - 1));
  for element := teBackground to teMenuHighlightBack do
    theme.Colors[element] := ClassicColors[element];

  line := Trim(copy(line, colon + 1, 255));
  while ( length(line) > 0 ) do begin
    { Next element=colour pair }
    space := pos(' ', line);
    if ( space = 0 ) then space := length(line) + 1;
    pair := copy(line, 1, space - 1);
    line := Trim(copy(line, space + 1, 255));

    equals := pos('=', pair);
    if ( equals > 1 ) then begin
      key := UpStr(copy(pair, 1, equals - 1));
      for element := teBackground to teMenuHighlightBack do
        if ( ElementNames[element] = key ) then
          theme.Colors[element] := ParseColor(copy(pair, equals + 1, 255), theme.Colors[element]);
    end;
  end;

  ParseThemeLine := true;
end;

{ Load themes from a file, returns how many were loaded }
function LoadThemes(fileName:string):integer;
var
  f:Text;
  line:string;
  theme:TTheme;
begin
  ThemeCount := 0;
  CurrentTheme := 0;
  LoadThemes := 0;

  Assign(f, fileName);
  {$I-}
  Reset(f);
  {$I+}
  if ( IOResult <> 0 ) then exit;

  while not Eof(f) and ( ThemeCount < MaxThemes ) do begin
    readln(f, line);
    if ParseThemeLine(line, theme) then begin
      inc(ThemeCount);
      ThemeList[ThemeCount] := theme;
    end;
  end;

  Close(f);
  LoadThemes := ThemeCount;
end;

{ Index of a theme by name, ignoring case, 0 if not found }
function FindTheme(name:string):integer;
var
  i:integer;
begin
  FindTheme := 0;
  for i := 1 to ThemeCount do
    if ( CompareText(ThemeList[i].Name, Trim(name)) = 0 ) then begin
      FindTheme := i;
      exit;
    end;
end;

function ThemeName(index:integer):string;
begin
  if ( index >= 1 ) and ( index <= ThemeCount ) then
    ThemeName := ThemeList[index].Name
  else
    ThemeName := '';
end;

procedure GetTheme(index:integer; var theme:TTheme);
begin
  theme := ThemeList[index];
end;

{ Use a theme's colours for the screen }
procedure ApplyTheme(index:integer);
begin
  if ( index < 1 ) or ( index > ThemeCount ) then exit;
  CurrentTheme := index;

  with ThemeList[index] do begin
    ColorBackground := Colors[teBackground];
    ColorText := Colors[teText];
    ColorFrame := Colors[teFrame];
    ColorHeadingText := Colors[teHeadingText];
    ColorHeadingBackground := Colors[teHeadingBack];
    ColorHighlightText := Colors[teHighlightText];
    ColorHighlightBackground := Colors[teHighlightBack];
    ColorHorizontalMenuPrimaryText := Colors[teMenuText];
    ColorHorizonalMenuHighlightText := Colors[teMenuHighlightText];
    ColorHorizonalMenuHighlightBackground := Colors[teMenuHighlightBack];
  end;
end;

begin
  ThemeCount := 0;
  CurrentTheme := 0;
end.
