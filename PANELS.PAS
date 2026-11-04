Unit Panels;
{-----------------------------
Right hand panel - help, game info and system status
------------------------------}

{ --------- interface -------- }
interface

procedure drawPanel;

{ --------- implementation --------- }
implementation
{$IFDEF FPC}
{$ASMMODE INTEL}
{$ENDIF}
uses
    Crt,
    Dos,
    Utility,
    Prefs,
    Games,
    Screen,
    ListView,
    Runner,
    MemMap;

const
  PanelTextWidth = columns div 2 - 2; { Panel width, less the space lines start with }

procedure drawHelpPanel;
begin
  resetLineDrawing(ColorBackground);

  writeLine(' Help: ' + ApplicationName, ColorHeadingText, ColorHeadingBackground );
  writeLine(' Enter  Execute current action', ColorText, ColorBackground);
  writeLine(' Esc    Clear filter, back or exit', ColorText, ColorBackground);
  writeLine(' ' + #26 + ' ' + #27 + '    Highlight next/previous command', ColorText, ColorBackground);
  writeLine(' ' + #24 + ' ' + #25 + '    Highlight previous/next game', ColorText, ColorBackground);
  writeLine(' PgUp   Move games list up one page', ColorText, ColorBackground);
  writeLine(' PgDn   Move games list down one page', ColorText, ColorBackground);
  writeLine(' Home   Move to top of games list', ColorText, ColorBackground);
  writeLine(' End    Move to bottom of games list', ColorText, ColorBackground);
  writeLine(' A-Z    Type to filter by name or type', ColorText, ColorBackground);
  writeLine(' Ins    Add game     Del  Remove game', ColorText, ColorBackground);
  blankLine;
  writeLine(' F1 Help            F2 Game info', ColorText, ColorBackground);
  writeLine(' F3 Status          F4 Memory map', ColorText, ColorBackground);
  writeLine(' Press F1-F4 again for full screen', ColorText, ColorBackground);
  blankLine;
  writeLine(' F5 Sort by name    F6 Sort by dev', ColorText, ColorBackground);
  writeLine(' F7 Sort by year    F8 Sort by genre', ColorText, ColorBackground);
  writeLine(' F9 Most played     F10 Most playtime', ColorText, ColorBackground);
  blankLine;
  writeLine(' github.com/MaverickUK/GameMinder', ColorText, ColorBackground);

  blankRemainingLines;
end;

{ Volume label of a drive e.g. 'C', blank if none }
function VolumeLabel(drive:char):string;
var
  S:SearchRec;
  name:string;
begin
  VolumeLabel := '';
  FindFirst(drive + ':\*.*', VolumeID, S);
  if ( DosError = 0 ) then begin
    name := S.Name;
    { Labels over 8 characters are returned in 8.3 form }
    if ( pos('.', name) > 0 ) then delete(name, pos('.', name), 1);
    VolumeLabel := name;
  end;
end;

{ Conventional memory installed, from the BIOS }
function ConventionalMemoryKB:word;
var
  regs:Registers;
begin
  Intr($12, regs);
  ConventionalMemoryKB := regs.AX;
end;

{ Free extended (XMS) memory in KB, 0 if there's no XMS driver }
function XmsFreeKB:longint;
var
  regs:Registers;
  entry:pointer;
  freeKB:word;
begin
  XmsFreeKB := 0;

  regs.AX := $4300; { Is an XMS driver such as HIMEM.SYS installed? }
  Intr($2F, regs);
  if ( regs.AL <> $80 ) then exit;

  regs.AX := $4310; { Get the driver's entry point }
  Intr($2F, regs);
  entry := Ptr(regs.ES, regs.BX);

  { XMS functions are a far call to the entry point, not an interrupt }
  freeKB := 0;
  asm
    mov ah, $08 { Query free extended memory, DX = total free KB }
    call dword ptr [entry]
    mov freeKB, dx
  end;
  XmsFreeKB := freeKB;
end;

{ Bar of free (solid) and used (shaded) memory }
function MemoryBar(freeKB, totalKB:longint; width:byte):string;
var
  bar:string;
  filled, i:integer;
begin
  if ( totalKB < 1 ) then totalKB := 1;
  if ( freeKB < 0 ) then freeKB := 0;
  filled := freeKB * width div totalKB;
  if ( filled > width ) then filled := width;

  bar[0] := chr(width);
  for i := 1 to width do
    if ( i <= filled ) then bar[i] := #219 else bar[i] := #176;
  MemoryBar := bar;
end;

{ Free memory line for EMS or XMS }
function FreeMemoryText(name:string; freeKB:longint):string;
begin
  if ( freeKB > 0 ) then
    FreeMemoryText := ' ' + name + ' free: ' + ConvertToString(freeKB) + ' KB'
  else
    FreeMemoryText := ' ' + name + ': not available';
end;

procedure drawSystemStatus;
var
  drive:char;
  driveNumber:byte;
  total,free:longint;
  conventionalKB,availableKB:longint;
  currentDir,firstPath:string;
begin
  { Show the drive games are scanned from, the first one if there are several }
  firstPath := ScanPathItem(ScanPath, 1);
  if ( length(firstPath) >= 2 ) and ( firstPath[2] = ':' ) then
    drive := UpCase(firstPath[1])
  else begin
    GetDir(0, currentDir);
    drive := UpCase(currentDir[1]);
  end;
  driveNumber := ord(drive) - ord('A') + 1;
  total := DiskSize(driveNumber);
  free := DiskFree(driveNumber);

  resetLineDrawing(ColorBackground);

  writeLine(' System Status', ColorHeadingText, ColorHeadingBackground );
  writeLine(' ' + GetFormattedDate + '  ' + GetFormattedTime, ColorText, ColorBackground);
  blankLine;
  writeLine(' Drive ' + drive + ' Status', ColorHeadingText, ColorHeadingBackground );
  writeLine(' Volume label: ' + VolumeLabel(drive), ColorText, ColorBackground );
  writeLine(' Storage total: ' + FormatBytes(total), ColorText, ColorBackground );
  if ( total >= 0 ) and ( free >= 0 ) then
    writeLine(' Storage used: ' + FormatBytes(total - free), ColorText, ColorBackground );
  writeLine(' Storage free: ' + FormatBytes(free), ColorText, ColorBackground );
  blankLine;
  writeLine(' Memory Status', ColorHeadingText, ColorHeadingBackground );
  conventionalKB := ConventionalMemoryKB;
  availableKB := AvailableMemoryKB;
  writeLine(' Conventional: ' + ConvertToString(availableKB) + ' of '
            + ConvertToString(conventionalKB) + ' KB free', ColorText, ColorBackground );
  writeLine(' ' + MemoryBar(availableKB, conventionalKB, PanelTextWidth - 1), ColorText, ColorBackground );
  writeLine(FreeMemoryText('EMS', EmsFreeKB), ColorText, ColorBackground );
  writeLine(FreeMemoryText('XMS', XmsFreeKB), ColorText, ColorBackground );
  blankLine;
  writeLine(' Games', ColorHeadingText, ColorHeadingBackground );
  writeLine(' Found: ' + ConvertToString(GameCount) + '  Showing: ' + ConvertToString(ViewCount),
            ColorText, ColorBackground );
  if ( GameCapReached ) then
    writeLine(' Limit reached - raise MaxGames', ColorText, ColorBackground );

  blankRemainingLines;
end;

{ Memory in KB for the memory map, blank if none. Used memory is rounded up
  so small drivers show, free memory down to match the Status panel }
function MapKB(bytes:longint; width:byte; roundUp:boolean):string;
var
  text:string;
begin
  if ( bytes = 0 ) then text := ''
  else if ( roundUp ) then text := ConvertToString(( bytes + 1023 ) div 1024)
  else text := ConvertToString(bytes div 1024);
  while ( length(text) < width ) do text := ' ' + text;
  MapKB := text;
end;

{ Colours for the memory map, one per program or driver. Dark ones last }
const
  MapPaletteSize = 13;
  MapPalette: array[1..MapPaletteSize] of byte =
    (Yellow, LightGreen, LightMagenta, LightCyan, LightRed, White, Brown,
     Green, Magenta, Cyan, Red, LightBlue, LightGray);
  MapCellKB = 5;          { Low memory map: 5KB a cell, 32 cells a row, 4 rows }
  MapCells = 32;
  MapLowRows = 4;

var
  MapColours: array[0..MaxMemEntries] of byte;

{ Give each program and driver its own colour, avoiding the panel's colours }
procedure AssignMapColours;
var
  i, next, tries:integer;
  colour:byte;
begin
  next := 0;
  MapColours[0] := ColorText;
  for i := 1 to MemEntryCount do begin
    if ( MemEntries[i].Kind = mkSystem ) then
      MapColours[i] := ColorText
    else begin
      tries := 0;
      repeat
        colour := MapPalette[next mod MapPaletteSize + 1];
        inc(next);
        inc(tries);
      until ( ( ( colour and 7 ) <> ( ColorBackground and 7 ) ) and ( colour <> ColorText ) )
            or ( tries > MapPaletteSize );
      MapColours[i] := colour;
    end;
  end;
end;

{ Character and colour for an entry in the map and list }
function MapChar(entry:integer):char;
begin
  if ( entry = MapFree ) then MapChar := #176         { Light shade }
  else if ( entry = MapNone ) then MapChar := #250    { Small dot }
  else if ( MemEntries[entry].Kind = mkSystem ) then MapChar := #178 { Dark shade }
  else MapChar := #219;                               { Solid block }
end;

function MapColour(entry:integer):byte;
begin
  if ( entry > 0 ) then MapColour := MapColours[entry] else MapColour := ColorText;
end;

{ One row of the map, from fromSeg in steps of cellParagraphs, after a label }
procedure drawMapRow(rowLabel:string; fromSeg, cellParagraphs:longint);
var
  text, colours:string;
  cell, entry:integer;
  cellStart:longint;
begin
  while ( length(rowLabel) < 5 ) do rowLabel := ' ' + rowLabel;
  text := rowLabel + ' ';
  colours := '';
  while ( length(colours) < length(text) ) do colours := colours + chr(ColorText);

  for cell := 0 to MapCells - 1 do begin
    cellStart := fromSeg + cell * cellParagraphs;
    entry := MapCellEntry(cellStart, cellStart + cellParagraphs);
    text := text + MapChar(entry);
    colours := colours + chr(MapColour(entry));
  end;
  writeColouredLine(text, colours, ColorBackground);
end;

{ A row of the list: coloured key, name, then KB in low and high memory }
procedure drawMapListRow(entry:integer; name:string; lowBytes, highBytes:longint; textColour:byte);
var
  text, colours:string;
begin
  text := ' ' + MapChar(entry) + ' ' + PadRight(name, 12)
          + MapKB(lowBytes, 7, entry <> MapFree) + MapKB(highBytes, 9, entry <> MapFree);
  colours := chr(textColour) + chr(MapColour(entry));
  while ( length(colours) < length(text) ) do colours := colours + chr(textColour);
  writeColouredLine(text, colours, ColorBackground);
end;

{ What's loaded in conventional (low) and upper (high) memory, as it will be
  while a game runs - GameMinder is counted as just the stub it leaves }
procedure drawMemoryPanel;
const
  LinesBeforeList = 7;
var
  i, row, listRows, shown:integer;
begin
  ScanMemory(ResidentKB);
  AssignMapColours;
  resetLineDrawing(ColorBackground);

  writeLine(' Memory Map - while a game runs', ColorHeadingText, ColorHeadingBackground );

  { Low memory, 160KB a row }
  for row := 0 to MapLowRows - 1 do
    drawMapRow(ConvertToString(row * MapCells * MapCellKB) + 'K',
               longint(row) * MapCells * MapCellKB * 64, MapCellKB * 64);

  { Upper memory, 640KB to 1MB on one row }
  if ( HasUpperMemory ) then
    drawMapRow('UMB', LowEndSeg, ( $10000 - LowEndSeg ) div MapCells)
  else
    writeLine('   UMB none', ColorText, ColorBackground );

  writeLine('   ' + PadRight('Name', 12) + ' Low KB  High KB', ColorHeadingText, ColorBackground );

  { Leave a row for free memory, and one to say if some didn't fit }
  listRows := FrameBottom - panelTop - LinesBeforeList - 1;
  shown := MemEntryCount;
  if ( shown > listRows ) then shown := listRows - 1;

  for i := 1 to shown do
    drawMapListRow(i, MemEntries[i].Name, MemEntries[i].LowBytes, MemEntries[i].HighBytes, ColorText);
  if ( shown < MemEntryCount ) then
    writeLine('   ...and ' + ConvertToString(MemEntryCount - shown) + ' more', ColorText, ColorBackground );

  drawMapListRow(MapFree, 'Free', FreeLowBytes, FreeHighBytes, ColorHeadingText);

  blankRemainingLines;
end;

procedure drawInfoPanel;
var
  game:PGame;
  available:longint;
  notes:string;
begin
  game := HighlightedGame;
  resetLineDrawing(ColorBackground);

  if ( game = nil ) then begin
    writeLine(' No games found', ColorHeadingText, ColorHeadingBackground );
    writeLine(' Nothing matches "' + CurrentFilter + '"', ColorText, ColorBackground );
    writeLine(' Press Esc to clear the filter', ColorText, ColorBackground );
    blankRemainingLines;
    exit;
  end;

  writeLine(' ' + PStr(game^.Name), ColorHeadingText, ColorHeadingBackground );
  writeLine(' Developer: ' + PStr(game^.Developer), ColorText, ColorBackground );
  writeLine(' Genre: ' + PStr(game^.Genre), ColorText, ColorBackground );
  writeLine(' Year: ' + PStr(game^.Year), ColorText, ColorBackground );
  writeLine(' Type: ' + PStr(game^.GameType), ColorText, ColorBackground );
  if ( game^.Notes <> nil ) then begin
    notes := 'Notes: ' + PStr(game^.Notes);
    while ( length(notes) > 0 ) do
      writeLine(' ' + WrapText(notes, PanelTextWidth), ColorHeadingText, ColorBackground );
  end;
  blankLine;
  writeLine(' Video: ' + PStr(game^.Video), ColorText, ColorBackground );
  writeLine(' Sound: ' + PStr(game^.Sound), ColorText, ColorBackground );
  if ( game^.MemoryKB > 0 ) then begin
    available := AvailableMemoryKB;
    if ( game^.MemoryKB > available ) then
      writeLine(' Memory: ' + ConvertToString(game^.MemoryKB) + 'KB - only '
                + ConvertToString(available) + 'KB free', ColorHeadingText, ColorBackground )
    else
      writeLine(' Memory: ' + ConvertToString(game^.MemoryKB) + 'KB', ColorText, ColorBackground );
  end;
  blankLine;
  writeLine(' Path: ' + PStr(game^.Path), ColorText, ColorBackground );
  writeLine(' Exec: ' + PStr(game^.Exec), ColorText, ColorBackground );
  if ( game^.Setup <> nil ) then
    writeLine(' Setup: ' + PStr(game^.Setup), ColorText, ColorBackground );
  if ( game^.Before <> nil ) then
    writeLine(' Before: ' + PStr(game^.Before), ColorText, ColorBackground );
  if ( game^.After <> nil ) then
    writeLine(' After: ' + PStr(game^.After), ColorText, ColorBackground );
  blankLine;

  if ( EnablePlayStats ) then begin
    writeLine(' Play stats', ColorHeadingText, ColorHeadingBackground );
    writeLine(' Played: ' + ConvertToString(game^.TimesPlayed), ColorText, ColorBackground );
    if ( game^.LastPlayed = nil ) then
      writeLine(' Last played: N/A', ColorText, ColorBackground )
    else
      writeLine(' Last played: ' + PStr(game^.LastPlayed), ColorText, ColorBackground );
    writeLine(' Time playing: ' + MinutesToFriendlyTime(game^.MinutesPlayed), ColorText, ColorBackground );
  end;

  blankRemainingLines;
end;

{ Redraw the right hand panel for the current mode }
procedure drawPanel;
begin
  case( Mode ) of
    ModeHelp: drawHelpPanel;
    ModeInfo: drawInfoPanel;
    ModeStatus: drawSystemStatus;
    ModeMemory: drawMemoryPanel;
    { ModeFullScreen: games list uses whole screen }
  end;
end;

end.
