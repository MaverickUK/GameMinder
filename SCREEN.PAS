Unit Screen;
{-----------------------------
Screen drawing routines
------------------------------}

{ --------- interface -------- }
interface

type
  { Screen redraw modes }
  TDrawScreenMode = (All, OnlyFrame, OnlyTop, OnlyBottom);
const
  { Modes - TODO: Change to enum }
  ModeHelp = 0;
  ModeInfo = 1;
  ModeStatus = 2;
  ModeFullScreen = 3;

procedure drawBlanks(amount:byte);
procedure resetLineDrawing(backColour:byte);
procedure blankLine;
procedure blankRemainingLines;
procedure writeLine(text:string; textColour:byte; backColour:byte);
procedure drawFrame(mode:byte; drawMode:TDrawScreenMode; x1,y1,x2,y2:byte);
procedure HideCursor;
procedure ShowCursor;

{ --------- implementation --------- }
implementation
uses
    Crt,
    Dos;
const
  rows = 24;
  columns = 80;
  panelColumn = columns div 2 + 1; { First column of the right hand panel }
  panelWidth = columns div 2 - 1;  { Up to, but not including, the right frame }
var
  drawRow:byte;
  panelBackground:byte;
  originalCursorShape:word;

{ --------- public --------- }

{ Draw blank characters to screen }
procedure drawBlanks(amount:byte);
var
  i:byte;
begin
  for i:=1 to amount do write(' '); { Blanks }
end;

{ Reset before drawing lines }
procedure resetLineDrawing(backColour:byte);
begin
  drawRow := 4; { Starting row to draw}
  panelBackground := backColour;
end;

{ Draw a blank line }
procedure blankLine;
begin
  gotoxy(panelColumn, drawRow);
  TextBackground(panelBackground);
  drawBlanks(panelWidth);
  inc(drawRow);
end;

{ Draw blank remaining lines }
procedure blankRemainingLines;
begin
  while drawRow < rows do
    blankLine;
end;

{ Draw a line, truncated to fit the panel }
procedure writeLine(text:string; textColour:byte; backColour:byte);
begin
  if ( length(text) > panelWidth ) then text[0] := chr(panelWidth);

  { Move to drawing position }
  gotoxy(panelColumn, drawRow);

  { Set colours }
  TextColor(textColour);
  TextBackground(backColour);

  write(text);
  drawBlanks(panelWidth - length(text));

  { next row for next  }
  inc(drawRow);
end;

procedure drawFrame(mode:byte; drawMode:TDrawScreenMode; x1,y1,x2,y2:byte);
const
  { ASCII characters for frame }
  charHorizonalFrame = #205;
  charVerticalFrame = #179;
  charTopLeftFrame = #213;
  charTopRightFrame = #184;
  charBottomLeftFrame = #212;
  charBottomRightFrame = #190;
  charTopMiddleCap = #209;
  charBottomMiddleCap = #207;

   (*local procedure line1 - horizonal *)
   procedure horizonalLine(a,b,c,e:byte);
   (*writes a - line to the screen*)
   (*a and b are the starting position*)
      begin
      gotoxy(a,b);
      while c <= e do begin
         inc(c,1);
         write(charHorizonalFrame);
      end;
   end;(*end of line1*)

   (*local procedure line2 - vertical *)
   (*this writes a | line to the screen*)
   procedure verticalLine(a,b,c,e:byte);
   begin
        while c <= e do begin
            gotoxy(a,b);
            write(charVerticalFrame);
            inc(c,1);
            inc(b);
        end;
   end;(*end of line2*)

begin

  { Top line }
  if ( drawMode = All ) or ( drawMode = OnlyFrame ) or ( drawMode = OnlyTop ) then begin
    gotoxy(x1,y1);(*upper left corner of the box*)
    write(charTopLeftFrame);
    gotoxy(x2,y1);(*upper right corner of the box*)
    write(charTopRightFrame);
    (*let's go back to the upper left corner*)
    (*and concatenate the upper corners...*)
    horizonalLine(x1+1,y1,x1,x2-2);
   end;

  { Bottom line }
  if ( drawMode = All ) or ( drawMode = OnlyFrame ) or ( drawMode = OnlyBottom ) then begin
   gotoxy(x2,y2);(*lower right corner of the box*)
   write(charBottomRightFrame);
   gotoxy(x1,y2);(*lower left corner of the box*)
   write(charBottomLeftFrame);
   horizonalLine(x1+1,y2,x1,x2-2);(*concat the lower corners*)
   { Keep the split's cap when only the bottom is redrawn }
   if not ( mode = ModeFullScreen ) then begin
     gotoxy(x2 div 2, y2);
     write(charBottomMiddleCap);
   end;
  end;

  { Left & Right sides }
  if ( drawMode = All ) or ( drawMode = OnlyFrame ) then begin
   verticalLine(x1,y1+1,y1,y2-2);(*concat the left sides of the box*)
   verticalLine(x2,y1+1,y1,y2-2);(*and last,concat the right sides too*)
  end;

  { Horizonal split - not shown in full screen mode }
  if ( ( drawMode = All ) or ( drawMode = OnlyFrame ) ) and not ( mode = ModeFullScreen ) then begin
   {Draw horizonal split}
   verticalLine(x2 div 2, y1, y1, y2);
   {Top cap}
   gotoxy(x2 div 2, y1);
   write(charTopMiddleCap);
   {Bottom cap}
   gotoxy(x2 div 2, y2);
   write(charBottomMiddleCap);
  end;

end;

{ Hide the text cursor using the video BIOS, works on CGA/EGA/VGA and MDA }
procedure HideCursor;
var
  regs:Registers;
begin
  regs.AH := $03; { Read cursor shape }
  regs.BH := 0;
  Intr($10, regs);
  { Don't overwrite the saved shape if the cursor is already hidden }
  if ( regs.CX and $2000 ) = 0 then originalCursorShape := regs.CX;

  regs.AH := $01; { Set cursor shape }
  regs.CX := $2000; { Bit 5 of start line hides the cursor }
  Intr($10, regs);
end;

{ Restore the cursor saved by HideCursor }
procedure ShowCursor;
var
  regs:Registers;
begin
  regs.AH := $01;
  regs.CX := originalCursorShape;
  Intr($10, regs);
end;

begin
  originalCursorShape := $0607; { Standard colour text mode underline cursor }
end.
