Unit Panels;
{-----------------------------
Right hand panel - help, game info and system status
------------------------------}

{ --------- interface -------- }
interface

procedure drawPanel;

{ --------- implementation --------- }
implementation
uses
    Crt,
    Dos,
    Utility,
    Prefs,
    Games,
    Screen,
    ListView,
    Runner;

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
  blankLine;
  writeLine(' F1 Help            F2 Game info', ColorText, ColorBackground);
  writeLine(' F3 Status          F4 Full screen', ColorText, ColorBackground);
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

{ Free memory in GameMinder's heap }
function HeapFree:longint;
begin
  {$IFDEF FPC}
  HeapFree := GetHeapStatus.TotalFree;
  {$ELSE}
  HeapFree := MemAvail;
  {$ENDIF}
end;

procedure drawSystemStatus;
var
  drive:char;
  driveNumber:byte;
  total,free:longint;
  currentDir:string;
begin
  { Show the drive games are scanned from }
  if ( length(ScanPath) >= 2 ) and ( ScanPath[2] = ':' ) then
    drive := UpCase(ScanPath[1])
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
  writeLine(' Conventional RAM: ' + ConvertToString(ConventionalMemoryKB) + ' KB', ColorText, ColorBackground );
  writeLine(' GameMinder heap free: ' + FormatBytes(HeapFree), ColorText, ColorBackground );
  writeLine(' Free for games: ' + ConvertToString(AvailableMemoryKB) + ' KB', ColorText, ColorBackground );
  blankLine;
  writeLine(' Games', ColorHeadingText, ColorHeadingBackground );
  writeLine(' Found: ' + ConvertToString(GameCount) + '  Showing: ' + ConvertToString(ViewCount),
            ColorText, ColorBackground );
  if ( GameCapReached ) then
    writeLine(' Limit reached - raise MaxGames', ColorText, ColorBackground );

  blankRemainingLines;
end;

procedure drawInfoPanel;
var
  game:PGame;
  available:longint;
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
    { ModeFullScreen: games list uses whole screen }
  end;
end;

end.
