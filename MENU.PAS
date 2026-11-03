Unit Menu;
{-----------------------------
Horizontal menu across the top of the screen

Each menu is a table of options, so adding an option is
a line in the table plus handling its action in GAMEMIND.PAS
------------------------------}

{ --------- interface -------- }
interface

const
  { Horizontal menus }
  MenuPrimary = 0;
  MenuSort = 1;
  MenuFilter = 2;
  MenuTheme = 3; { Themes from THEMES.TXT, listed on the second row }
  MenuRun = 4;   { Game or setup program, for games with a setup program }
  { Position of options in the primary menu, to return to from a sub-menu }
  PrimaryRunIndex = 0;
  PrimaryFilterIndex = 1;
  PrimarySortIndex = 2;
  PrimaryThemeIndex = 7;

type
  { What a horizontal menu option does when Enter is pressed }
  TMenuAction = (maRun, maFilterMenu, maSortMenu, maAdd, maEdit, maDelete, maRescan, maTheme, maExit,
                 maSortName, maSortDeveloper, maSortYear, maSortGenre, maSortType,
                 maSortTimesPlayed, maSortTimePlayed,
                 maFilterType, maFilterClear,
                 maThemeChoose,
                 maRunGame, maRunSetup);

  TMenuItem = record
    Caption: string[10];
    Hint: string[78];
    Action: TMenuAction;
  end;

var
  hMenu:byte;   { Which horizontal menu is shown }
  hIndex:byte;  { Highlighted option within that menu }

procedure GetMenuItem(menu:byte; index:byte; var item:TMenuItem);
procedure renderHorizonalMenu;
procedure changeHorizonalMenu(movement:shortint);
procedure showMenu(menu:byte; index:byte);

{ --------- implementation --------- }
implementation
uses
    Crt,
    Utility,
    Prefs,
    Screen,
    Themes,
    Games,
    ListView;

const
  PrimaryMenu: array[0..8] of TMenuItem = (
    (Caption:'Run'; Hint:'Run highlighted game'; Action:maRun),
    (Caption:'Filter'; Hint:'Filter games by name or type - or just start typing'; Action:maFilterMenu),
    (Caption:'Sort'; Hint:'Name, Developer, Year, Genre, Type, Played, Playtime'; Action:maSortMenu),
    (Caption:'Add'; Hint:'Add a game from a directory GameMinder doesn''t list yet (Ins)'; Action:maAdd),
    (Caption:'Edit'; Hint:'Edit the highlighted game''s details'; Action:maEdit),
    (Caption:'Delete'; Hint:'Remove the highlighted game from GameMinder - its files are kept (Del)'; Action:maDelete),
    (Caption:'Rescan'; Hint:'Scan for games again, to pick up new or changed games'; Action:maRescan),
    (Caption:'Theme'; Hint:''; Action:maTheme), { Hint shows the current theme }
    (Caption:'Exit'; Hint:'Exit to DOS'; Action:maExit));

  { Same order as TSortMode, so the current sort can be highlighted }
  SortMenu: array[0..6] of TMenuItem = (
    (Caption:'Name'; Hint:'Sort by name ascending'; Action:maSortName),
    (Caption:'Developer'; Hint:'Sort by developer ascending'; Action:maSortDeveloper),
    (Caption:'Year'; Hint:'Sort by year ascending'; Action:maSortYear),
    (Caption:'Genre'; Hint:'Sort by genre ascending'; Action:maSortGenre),
    (Caption:'Type'; Hint:'Sort by type e.g. Demo, Full, Shareware'; Action:maSortType),
    (Caption:'Played'; Hint:'Sort by times played, most played first'; Action:maSortTimesPlayed),
    (Caption:'Playtime'; Hint:'Sort by total time played, longest first'; Action:maSortTimePlayed));

  FilterMenu: array[0..1] of TMenuItem = (
    (Caption:'Filter'; Hint:'Type to filter games by name or type, Backspace to edit'; Action:maFilterType),
    (Caption:'Clear'; Hint:'Clear current filter'; Action:maFilterClear));

  RunMenu: array[0..1] of TMenuItem = (
    (Caption:'Game'; Hint:'Run highlighted game'; Action:maRunGame),
    (Caption:'Setup'; Hint:''; Action:maRunSetup)); { Hint shows the setup program }

function MenuCount(menu:byte):byte;
begin
  case menu of
    MenuSort: MenuCount := 7;
    MenuFilter: MenuCount := 2;
    MenuTheme: MenuCount := ThemeCount;
    MenuRun: MenuCount := 2;
  else
    MenuCount := 9;
  end;
end;

procedure GetMenuItem(menu:byte; index:byte; var item:TMenuItem);
begin
  case menu of
    MenuSort: item := SortMenu[index];
    MenuFilter: item := FilterMenu[index];
    MenuRun: item := RunMenu[index];
    MenuTheme: begin { Names are drawn by renderThemeRow }
      item.Caption := '';
      item.Hint := '';
      item.Action := maThemeChoose;
    end;
  else
    item := PrimaryMenu[index];
  end;
end;

procedure setMenuColours(highlighted:boolean);
begin
  if highlighted then begin
    TextColor(ColorHorizonalMenuHighlightText);
    TextBackground(ColorHorizonalMenuHighlightBackground);
  end
  else begin
    TextColor(ColorHorizontalMenuPrimaryText);
    TextBackground(ColorBackground);
  end;
end;

{ Theme names across the second row, scrolled so the highlighted one is shown }
procedure renderThemeRow;
var
  first,i,width:integer;
begin
  gotoxy(1,2);
  setMenuColours(false);
  drawBlanks(columns);

  { Width of the themes from first to the highlighted one, with 2 space spacers }
  first := 0;
  width := 0;
  for i := 0 to hIndex do
    inc(width, length(ThemeName(i + 1)) + 2);
  while ( width > columns ) and ( first < hIndex ) do begin
    dec(width, length(ThemeName(first + 1)) + 2);
    inc(first);
  end;

  gotoxy(1,2);
  width := 0;
  i := first;
  while ( i < ThemeCount ) and ( width + length(ThemeName(i + 1)) <= columns ) do begin
    setMenuColours(i = hIndex);
    write(ThemeName(i + 1));
    inc(width, length(ThemeName(i + 1)));
    if ( width + 2 <= columns ) then begin
      setMenuColours(false);
      write('  '); { Spacer }
      inc(width, 2);
    end;
    inc(i);
  end;
end;

{ Render the horizonal menu that appears at the top of the scren }
procedure renderHorizonalMenu;
var
  i,menu,index:byte;
  item:TMenuItem;
begin
  { The theme menu keeps the primary menu on the first row }
  menu := hMenu;
  index := hIndex;
  if ( hMenu = MenuTheme ) then begin
    menu := MenuPrimary;
    index := PrimaryThemeIndex;
  end;

  { Clear }
  gotoxy(1,1);
  TextColor(ColorHorizontalMenuPrimaryText);
  TextBackground(ColorBackground);
  drawBlanks(columns);

  { Primary nav }
  gotoxy(1,1);

  for i := 0 to MenuCount(menu) - 1 do begin
    GetMenuItem(menu, i, item);
    setMenuColours(i = index);
    write(item.Caption);

    TextColor(ColorText);
    TextBackground(ColorBackground);
    write('  '); { Spacer }
  end;

  { Secondary nav - describe highlighted option, or list the themes }
  if ( hMenu = MenuTheme ) then
    renderThemeRow
  else begin
    GetMenuItem(hMenu, hIndex, item);
    if ( item.Action = maTheme ) then begin
      if ( ThemeCount = 0 ) then
        item.Hint := 'No themes found - add them to ' + ThemesFileName
      else if ( CurrentTheme = 0 ) then
        item.Hint := 'Using Color settings - Enter to choose a theme'
      else
        item.Hint := 'Theme: ' + ThemeName(CurrentTheme) + ' - Enter to choose a theme';
    end
    else if ( item.Action = maRun ) and HasSetup(HighlightedGame) then
      item.Hint := 'Run highlighted game, or its setup program'
    else if ( item.Action = maRunSetup ) and HasSetup(HighlightedGame) then
      item.Hint := 'Run ' + PStr(HighlightedGame^.Setup) + ' to choose sound, video and controls';
    gotoxy(1,2);
    write(PadRight(item.Hint, columns));
  end;

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

begin
  showMenu(MenuPrimary, 0);
end.
