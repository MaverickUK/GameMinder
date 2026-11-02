Unit EndScrn;
{-----------------------------
End screen shown when exiting GameMinder, like the ENDOOM screen
DOS games of the era left behind - a logo and what was played this
session. It stays above the DOS prompt, so there's no key to press
------------------------------}

{ --------- interface -------- }
interface

procedure ShowEndScreen;

{ --------- implementation --------- }
implementation
uses
    Crt,
    Utility,
    Games,
    Prefs;

const
  { Block letters, 66 columns wide: # full block, ^ upper half, _ lower half }
  LogoRows = 3;
  Logo: array[1..LogoRows] of string[66] = (
    '_^^^^  _^^^_  #_ _#  #^^^^  #_ _#  ^#^  #_  #  #^^^_  #^^^^  #^^^_',
    '# ^^#  #___#  # ^ #  #^^^   # ^ #   #   # ^_#  #   #  #^^^   #___^',
    '^___^  #   #  #   #  #____  #   #  _#_  #   #  #___^  #____  #  ^_');
  LogoColors: array[1..LogoRows] of byte = (Yellow, LightRed, Red);
  LogoTop = 2;

  LabelColumn = 3;
  ValueColumn = 18;
  RuleWidth = 76;
  SessionLines = 4; { Most games listed under This session }

  SignOffCount = 6;
  SignOffs: array[1..SignOffCount] of string[30] = (
    'Thanks for playing!',
    'One more turn...',
    'See you next session',
    'Happy gaming!',
    'Don''t forget to save',
    'Until next time');

function LogoChar(c:char):char;
begin
  case c of
    '#': LogoChar := #219;
    '^': LogoChar := #223;
    '_': LogoChar := #220;
  else
    LogoChar := ' ';
  end;
end;

{ Draw the logo, skipping spaces so a shadow drawn first shows through }
procedure DrawLogo(x,y:byte; shadow:boolean);
var
  row,i:byte;
begin
  for row := 1 to LogoRows do begin
    if shadow then TextColor(DarkGray) else TextColor(LogoColors[row]);
    for i := 1 to length(Logo[row]) do
      if ( Logo[row][i] <> ' ' ) then begin
        gotoxy(x + i - 1, y + row - 1);
        write(LogoChar(Logo[row][i]));
      end;
  end;
end;

procedure DrawRule(row:byte);
var
  i:byte;
begin
  gotoxy(LabelColumn, row);
  TextColor(Blue);
  for i := 1 to RuleWidth do write(#205);
end;

{ A label and its value on one row }
procedure DrawItem(row:byte; caption:string; value:string);
begin
  gotoxy(LabelColumn, row);
  TextColor(LightCyan);
  write(caption);
  gotoxy(ValueColumn, row);
  TextColor(White);
  write(copy(value, 1, RuleWidth - ValueColumn + LabelColumn));
end;

function PlayTime(minutes:longint):string;
begin
  if ( minutes = 0 ) then PlayTime := 'under a minute'
  else PlayTime := MinutesToFriendlyTime(minutes);
end;

function Plural(count:longint; singular:string):string;
begin
  if ( count = 1 ) then Plural := '1 ' + singular
  else Plural := ConvertToString(count) + ' ' + singular + 's';
end;

procedure ShowEndScreen;
var
  row,i,shown:byte;
  plays,minutes:longint;
  mostPlayed:PGame;
  caption,libraryText:string;
begin
  TextBackground(Black);
  clrscr;

  { Logo with a shadow to the right }
  DrawLogo(8, LogoTop, true);
  DrawLogo(7, LogoTop, false);

  row := LogoTop + LogoRows + 2;
  DrawRule(row);
  inc(row);

  { This session }
  caption := 'This session';
  if ( SessionCount = 0 ) then begin
    if ( SessionEdits > 0 ) then
      DrawItem(row, caption, 'No games played, ' + Plural(SessionEdits, 'game') + ' added or edited')
    else
      DrawItem(row, caption, 'Just browsing');
    inc(row);
  end
  else begin
    shown := SessionCount;
    if ( shown > SessionLines ) then shown := SessionLines - 1;
    for i := 1 to shown do begin
      DrawItem(row, caption, SessionNames[i] + ' - ' + PlayTime(SessionMinutes[i]));
      caption := '';
      inc(row);
    end;
    if ( shown < SessionCount ) then begin
      DrawItem(row, '', '+' + ConvertToString(SessionCount - shown) + ' more');
      inc(row);
    end;
  end;

  { Your library }
  GetLibraryStats(plays, minutes, mostPlayed);
  libraryText := Plural(GameCount, 'game');
  if ( EnablePlayStats ) then
    libraryText := libraryText + ', ' + Plural(plays, 'play') + ', ' + PlayTime(minutes) + ' played';
  DrawItem(row, 'Your library', libraryText);
  inc(row);

  if ( EnablePlayStats ) and ( mostPlayed <> nil ) then begin
    DrawItem(row, 'Most played', PStr(mostPlayed^.Name) + ' - ' + PlayTime(mostPlayed^.MinutesPlayed));
    inc(row);
  end;

  DrawRule(row);
  inc(row, 2);

  { Sign off }
  gotoxy(LabelColumn, row);
  TextColor(Yellow);
  write(SignOffs[Random(SignOffCount) + 1]);
  gotoxy(LabelColumn + RuleWidth - length(ApplicationName), row);
  TextColor(DarkGray);
  write(ApplicationName);
  inc(row);

  gotoxy(LabelColumn, row);
  TextColor(LightBlue);
  write('github.com/MaverickUK/GameMinder');

  { Leave the DOS prompt below }
  TextColor(LightGray);
  gotoxy(1, row + 2);
end;

end.
