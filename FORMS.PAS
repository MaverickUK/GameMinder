Unit Forms;
{-----------------------------
Full screen forms - editing a game's details, picking from
a list - and questions/messages on the hint line
------------------------------}

{ --------- interface -------- }
interface
uses
    Objects,
    Games;

function EditGameForm(game:PGame; title:string):boolean;
function PickFromList(title:string; hint:string; list:PStringCollection):integer;
function Confirm(question:string):boolean;
procedure ShowMessage(text:string);
procedure ShowStatus(text:string);

{ --------- implementation --------- }
implementation
uses
    Crt,
    Utility,
    Prefs,
    Screen,
    Launch;

const
  MaxFieldLength = 70;
  labelColumn = 3;
  valueColumn = 15;
  valueWidth = columns - valueColumn - 2; { Up to the right frame }
  firstFieldRow = 7;
  listFirstRow = 5;

  FieldLabels: array[1..InfoFieldCount] of string[10] = (
    'Name', 'Exec', 'Developer', 'Year', 'Genre', 'Type',
    'Video', 'Sound', 'Memory KB', 'Before', 'After');

  FieldHints: array[1..InfoFieldCount] of string[70] = (
    'Name shown in the games list (needed)',
    'Program to run, and any arguments e.g. KEEN4.EXE /NOJOY (needed)',
    'Who made the game',
    'Year it was released e.g. 1991',
    'e.g. Platform, Adventure, Strategy',
    'e.g. Full, Demo, Shareware, Freeware',
    'e.g. CGA, EGA, VGA',
    'e.g. PC Speaker, AdLib, Sound Blaster',
    'Conventional memory the game needs in KB e.g. 580',
    'Command run before the game e.g. C:\MOUSE\MOUSE.COM',
    'Command run after the game e.g. C:\MOUSE\MOUSE OFF');

type
  TFieldValues = array[1..InfoFieldCount] of string[MaxFieldLength];

{ ////////////////// Hint line questions & messages ////////////////// }

{ Show text on the hint line, under the menu }
procedure ShowStatus(text:string);
begin
  gotoxy(1, 2);
  TextColor(ColorHeadingText);
  TextBackground(ColorHeadingBackground);
  write(PadRight(text, columns));
end;

{ Wait for a key, discarding the second half of extended keys }
function WaitKey:char;
var
  ch:char;
begin
  ch := ReadKey;
  if ( ch = #0 ) then begin
    ReadKey;
    ch := #0;
  end;
  WaitKey := ch;
end;

{ Ask a yes/no question on the hint line }
function Confirm(question:string):boolean;
var
  key:char;
begin
  ShowStatus(question + ' (Y/N)');
  repeat
    key := UpCase(WaitKey);
  until key in ['Y', 'N', #27];
  Confirm := ( key = 'Y' );
end;

{ Show a message on the hint line until a key is pressed }
procedure ShowMessage(text:string);
begin
  ShowStatus(text + ' - press a key');
  WaitKey;
end;

{ ////////////////// Drawing ////////////////// }

{ Title, hint and frame for a full screen form }
procedure DrawFormScreen(title:string; hint:string; footer:string);
begin
  TextColor(ColorFrame);
  TextBackground(ColorBackground);
  clrscr;
  drawFrame(ModeFullScreen, All, 1, frameTop, columns, FrameBottom);

  gotoxy(1, 1);
  TextColor(ColorHorizonalMenuHighlightText);
  TextBackground(ColorHorizonalMenuHighlightBackground);
  write(PadRight(' ' + title, length(title) + 2));
  gotoxy(columns - length(ApplicationName) + 1, 1);
  write(ApplicationName);

  gotoxy(1, 2);
  TextColor(ColorText);
  TextBackground(ColorBackground);
  write(PadRight(hint, columns));

  gotoxy(5, FrameBottom);
  TextColor(ColorFrame);
  write(#185, ' ', footer, ' ', #204);
end;

procedure DrawHint(hint:string);
begin
  gotoxy(1, 2);
  TextColor(ColorText);
  TextBackground(ColorBackground);
  write(PadRight(hint, columns));
end;

{ First character of the value shown, so the cursor stays in view }
function ScrollStart(cursor:integer):integer;
begin
  if ( cursor > valueWidth ) then
    ScrollStart := cursor - valueWidth + 1
  else
    ScrollStart := 1;
end;

procedure DrawField(index:integer; var values:TFieldValues; current:integer; cursor:integer);
var
  start:integer;
begin
  gotoxy(labelColumn, firstFieldRow + index - 1);
  TextBackground(ColorBackground);
  if ( index = current ) then TextColor(ColorHeadingText) else TextColor(ColorText);
  write(PadRight(FieldLabels[index], valueColumn - labelColumn));

  if ( index = current ) then begin
    TextColor(ColorHighlightText);
    TextBackground(ColorHighlightBackground);
    start := ScrollStart(cursor);
  end else begin
    TextColor(ColorText);
    TextBackground(ColorBackground);
    start := 1;
  end;
  write(PadRight(copy(values[index], start, valueWidth), valueWidth));
end;

{ ////////////////// Edit game form ////////////////// }

{ Check the form can be saved, moving to the field with a problem if not }
function ValidForm(game:PGame; var values:TFieldValues; var current:integer):boolean;
var
  program_:string;
begin
  ValidForm := false;

  if ( length(Trim(values[1])) = 0 ) then begin
    current := 1;
    ShowMessage('The game needs a name');
    exit;
  end;

  if ( length(Trim(values[2])) = 0 ) then begin
    current := 2;
    ShowMessage('Exec needs the program that starts the game');
    exit;
  end;

  if ( length(Trim(values[9])) > 0 ) and ( ParseMemoryKB(values[9]) = 0 ) then begin
    current := 9;
    ShowMessage('Memory should be a number of KB e.g. 580');
    exit;
  end;

  program_ := GameProgram(PStr(game^.Path), values[2]);
  if not FileExists(program_) then begin
    current := 2;
    if not Confirm('Can''t find ' + program_ + ' - save anyway?') then exit;
  end;

  ValidForm := true;
end;

{ Edit a game's details. Returns true and updates the game if saved }
function EditGameForm(game:PGame; title:string):boolean;
var
  values:TFieldValues;
  current,cursor,i:integer;
  ch:char;
  done,saved:boolean;

  procedure MoveTo(index:integer);
  var
    previous:integer;
  begin
    if ( index < 1 ) then index := InfoFieldCount;
    if ( index > InfoFieldCount ) then index := 1;
    previous := current;
    current := index;
    cursor := length(values[current]) + 1;
    DrawField(previous, values, current, cursor);
  end;

begin
  for i := 1 to InfoFieldCount do
    values[i] := GameFieldValue(game, InfoFieldKeys[i]);

  DrawFormScreen(title, '', 'Up/Down move   F10 or Ctrl+S save   Esc cancel');
  gotoxy(labelColumn, 5);
  TextColor(ColorText);
  TextBackground(ColorBackground);
  write('Directory: ', PStr(game^.Path));

  current := 1;
  cursor := length(values[1]) + 1;
  for i := 1 to InfoFieldCount do
    DrawField(i, values, current, cursor);

  done := false;
  saved := false;
  ShowCursor;

  repeat
    DrawHint(FieldHints[current]);
    DrawField(current, values, current, cursor);
    gotoxy(valueColumn + cursor - ScrollStart(cursor), firstFieldRow + current - 1);

    ch := ReadKey;
    case ch of
      #0: begin
          ch := ReadKey;
          case ch of
            #72, #15: MoveTo(current - 1); { Up, Shift+Tab }
            #80: MoveTo(current + 1);      { Down }
            #75: if ( cursor > 1 ) then dec(cursor); { Left }
            #77: if ( cursor <= length(values[current]) ) then inc(cursor); { Right }
            #71: cursor := 1; { Home }
            #79: cursor := length(values[current]) + 1; { End }
            #83: delete(values[current], cursor, 1); { Del }
            #68: begin { F10 - save }
                HideCursor;
                if ValidForm(game, values, current) then begin
                  saved := true;
                  done := true;
                end;
                cursor := length(values[current]) + 1;
                for i := 1 to InfoFieldCount do DrawField(i, values, current, cursor);
                ShowCursor;
              end;
          end;
        end;
      #19: begin { Ctrl+S - save }
          HideCursor;
          if ValidForm(game, values, current) then begin
            saved := true;
            done := true;
          end;
          cursor := length(values[current]) + 1;
          for i := 1 to InfoFieldCount do DrawField(i, values, current, cursor);
          ShowCursor;
        end;
      #9, #13: MoveTo(current + 1); { Tab, Enter }
      #27: done := true; { Esc - cancel }
      #8: if ( cursor > 1 ) then begin { Backspace }
          delete(values[current], cursor - 1, 1);
          dec(cursor);
        end;
      #32..#126: if ( length(values[current]) < MaxFieldLength ) then begin
          insert(ch, values[current], cursor);
          inc(cursor);
        end;
    end;
  until done;

  HideCursor;

  if ( saved ) then
    for i := 1 to InfoFieldCount do
      SetGameField(game, InfoFieldKeys[i], Trim(values[i]));

  EditGameForm := saved;
end;

{ ////////////////// Pick from a list ////////////////// }

{ Choose an item from a list of strings. Returns its index, or -1 if cancelled }
function PickFromList(title:string; hint:string; list:PStringCollection):integer;
var
  current,top,rows,i:integer;
  ch:char;
  done:boolean;
begin
  PickFromList := -1;
  if ( list^.Count = 0 ) then exit;

  DrawFormScreen(title, hint, 'Enter choose   Esc cancel');
  rows := FrameBottom - listFirstRow;
  current := 0;
  top := 0;
  done := false;

  repeat
    { Keep the highlighted item on screen }
    if ( current < top ) then top := current;
    if ( current >= top + rows ) then top := current - rows + 1;

    for i := 0 to rows - 1 do begin
      gotoxy(labelColumn, listFirstRow + i);
      if ( top + i = current ) then begin
        TextColor(ColorHighlightText);
        TextBackground(ColorHighlightBackground);
      end else begin
        TextColor(ColorText);
        TextBackground(ColorBackground);
      end;
      if ( top + i < list^.Count ) then
        write(PadRight(PString(list^.At(top + i))^, columns - labelColumn - 1))
      else
        write(PadRight('', columns - labelColumn - 1));
    end;

    ch := ReadKey;
    case ch of
      #0: begin
          ch := ReadKey;
          case ch of
            #72: if ( current > 0 ) then dec(current); { Up }
            #80: if ( current < list^.Count - 1 ) then inc(current); { Down }
            #73: begin dec(current, rows); if ( current < 0 ) then current := 0; end; { PgUp }
            #81: begin inc(current, rows); if ( current > list^.Count - 1 ) then current := list^.Count - 1; end; { PgDn }
            #71: current := 0; { Home }
            #79: current := list^.Count - 1; { End }
          end;
        end;
      #13: begin
          PickFromList := current;
          done := true;
        end;
      #27: done := true;
    end;
  until done;
end;

end.
