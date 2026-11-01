Unit ListView;
{-----------------------------
Scrolling games list on the left of the screen,
or across the whole screen in full screen mode
------------------------------}

{ --------- interface -------- }
interface
uses
    Games;

const
  MaxFilterLength = 30;

var
  offset:integer; { Highlighted game - index into the filtered view }

function HighlightedGame:PGame;
function PageSize:integer;
procedure scrollTo(index:integer);
procedure scrollingList;
procedure SortBy(sortMode:TSortMode);
procedure SetFilter(filter:string);

{ --------- implementation --------- }
implementation
uses
    Crt,
    Utility,
    Prefs,
    Screen;

const
  listStartColumn = 3;
  listMinRow = 5;
  listHeaderRow = 4;
  developerColumn = 40;
  genreColumn = 60;
  yearColumn = 70;

{ Rows below the last game row }
function listMaxRow:byte;
begin
  listMaxRow := FrameBottom;
end;

{ Row the highlighted game is always shown on - HighlightedRow setting, or the middle of the list }
function HighlightRow:integer;
begin
  if ( HighlightedRow >= listMinRow ) and ( HighlightedRow < listMaxRow ) then
    HighlightRow := HighlightedRow
  else
    HighlightRow := ( listMinRow + listMaxRow - 1 ) div 2;
end;

{ Currently highlighted game, nil if the filter matches nothing }
function HighlightedGame:PGame;
begin
  HighlightedGame := ViewGame(offset);
end;

{ Games moved by Page Up/Down }
function PageSize:integer;
begin
  PageSize := listMaxRow - listMinRow;
end;

procedure scrollTo(index:integer);
begin
  if ( index > ViewCount - 1 ) then index := ViewCount - 1;
  if ( index < 0 ) then index := 0;
  offset := index;
end;

procedure scrollingList;
var
  game:PGame;
  gameIndex:integer;
  row:byte;
  nameWidth:byte;
begin
  nameWidth := columns div 2 - 4; { 3 columns + 1 left padding = 4}
  if ( Mode = ModeFullScreen ) then
    nameWidth := developerColumn - listStartColumn - 1;

  { Heading }
  gotoxy(listStartColumn,listHeaderRow);
  TextBackground(ColorHeadingBackground);
  TextColor(ColorHeadingText);
  if ( Mode = ModeFullScreen ) then
    write(PadColumn('Name', developerColumn - listStartColumn),
          PadColumn('Developer', genreColumn - developerColumn),
          PadColumn('Genre', yearColumn - genreColumn),
          PadRight('Year', columns - yearColumn))
  else
    write(PadRight('Name', nameWidth + 1));

  for row := listMinRow to listMaxRow - 1 do begin
    { Game to display - the highlighted game is always on HighlightRow }
    gameIndex := integer(row) - HighlightRow + offset;
    game := ViewGame(gameIndex);

    gotoxy(listStartColumn, row);

    if ( row = HighlightRow ) and ( game <> nil ) then begin
      TextBackground(ColorHighlightBackground);
      TextColor(ColorHighlightText);
    end else begin
      TextBackground(ColorBackground);
      TextColor(ColorText);
    end;

    if ( game = nil ) then begin
      { No game - show blank row }
      if ( Mode = ModeFullScreen ) then
        write(PadRight(BlankLineFilter, columns - listStartColumn))
      else
        write(PadRight(BlankLineFilter, nameWidth + 1));
    end
    else if ( Mode = ModeFullScreen ) then
      write(PadColumn(PStr(game^.Name), developerColumn - listStartColumn),
            PadColumn(PStr(game^.Developer), genreColumn - developerColumn),
            PadColumn(PStr(game^.Genre), yearColumn - genreColumn),
            PadRight(PStr(game^.Year), columns - yearColumn))
    else
      write(PadRight(PStr(game^.Name), nameWidth + 1));
  end;
end;

{ ////////////////// Sorting & filtering ////////////////// }

{ Change the current games sort order, keeping the highlighted game }
procedure SortBy(sortMode:TSortMode);
var
  game:PGame;
begin
  game := HighlightedGame;
  SortGames(sortMode);
  scrollTo(IndexInView(game));
  SetupScreen(OnlyBottom);
end;

{ Change the filter, keeping the highlighted game if it still matches }
procedure SetFilter(filter:string);
var
  game:PGame;
  index:integer;
begin
  game := HighlightedGame;
  ApplyFilter(filter);

  index := IndexInView(game);
  if ( index < 0 ) then index := 0;
  scrollTo(index);

  SetupScreen(OnlyBottom);
end;

begin
  offset := 0;
end.
