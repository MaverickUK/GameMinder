Unit Runner;
{-----------------------------
Run games - swapping GameMinder out of memory with ExecSwap,
running before/after commands, checking memory and logging play stats.
Also runs games' setup programs
------------------------------}

{ --------- interface -------- }
interface
uses
    Games;

const
  LaunchCancelled = $FFFF; { Returned by LaunchGame if the player chose not to run it }
  ResidentKB = 3;          { ExecSwap's stub and memory control block, left while a game runs }

function AvailableMemoryKB:longint;
function GameFreeKB(game:PGame):longint;
function EmsFreeKB:longint;
function LaunchGame(game:PGame; interactive:boolean):word;
function LaunchSetup(game:PGame; interactive:boolean):word;

{ --------- implementation --------- }
implementation
uses
    Crt,
    Dos,
    Utility,
    Prefs,
    Launch,
    Screen,
    ExecSwap;

const
  SwapFileName = 'SWAP.$$$';
  ScriptFileName = 'GMRUN.BAT';
  ScriptOverheadKB = 5; { COMMAND.COM, when running before/after commands }

{ Conventional memory a game would get once GameMinder is swapped out, in KB }
function AvailableMemoryKB:longint;
var
  regs:Registers;
  paragraphs:longint;
begin
  { GameMinder's own memory, freed by swapping out }
  paragraphs := MemW[PrefixSeg - 1:3];

  { Plus the largest free block }
  regs.AH := $48;
  regs.BX := $FFFF;
  MsDos(regs);
  inc(paragraphs, regs.BX);

  AvailableMemoryKB := paragraphs * 16 div 1024 - ResidentKB;
end;

{ Conventional memory a game will get, allowing for COMMAND.COM when it has
  before/after commands - the same figure the warning before launching uses }
function GameFreeKB(game:PGame):longint;
begin
  if NeedsLaunchScript(PStr(game^.Before), PStr(game^.After)) then
    GameFreeKB := AvailableMemoryKB - ScriptOverheadKB
  else
    GameFreeKB := AvailableMemoryKB;
end;

{ Free expanded (EMS) memory in KB, 0 if there's no EMS driver }
function EmsFreeKB:longint;
const
  DriverName: string[8] = 'EMMXXXX0';
var
  regs:Registers;
  driverSeg:word;
  i:integer;
begin
  EmsFreeKB := 0;

  { The driver's name is 10 bytes into the segment its interrupt 67h handler is in }
  driverSeg := MemW[0:$67 * 4 + 2];
  for i := 1 to length(DriverName) do
    if ( Chr(Mem[driverSeg:$0A + i - 1]) <> DriverName[i] ) then exit;

  regs.AH := $42; { Get unallocated page count, 16KB pages }
  Intr($67, regs);
  if ( regs.AH = 0 ) then EmsFreeKB := longint(regs.BX) * 16;
end;

{ Directory for temporary files - %TEMP% if set, otherwise next to GAMEMIND.EXE }
function TempDir:string;
var
  temp:string;
begin
  temp := GetEnv('TEMP');
  if ( length(temp) = 0 ) then temp := ExeDir;
  TempDir := NormalizeDir(temp);
end;

function ComSpec:string;
var
  value:string;
begin
  value := Trim(GetEnv('COMSPEC'));
  if ( length(value) = 0 ) then value := DefaultComSpec;
  ComSpec := value;
end;

{ Write the batch file running a game's before/after commands }
function WriteScript(fileName:string; var script:TLaunchScript):boolean;
var
  f:Text;
  i:byte;
begin
  Assign(f, fileName);
  {$I-}
  Rewrite(f);
  for i := 1 to script.Count do
    writeln(f, script.Lines[i]);
  Close(f);
  {$I+}
  WriteScript := ( IOResult = 0 );
end;

procedure DeleteFile(fileName:string);
var
  f:File;
begin
  Assign(f, fileName);
  {$I-}
  Erase(f);
  {$I+}
  if ( IOResult <> 0 ) then ; { Clear error }
end;

{ Launch an external executable, returning 0 on success or a DOS error code }
function Execute(prog:string; args:string; gameDir:string):word;
var
  Status : Word;
  OriginalDir: String;
begin
  Status := 0;

  { Change to game's drive and directory - ChDir also changes drive }
  GetDir(0,OriginalDir);
  VerboseWriteln('GameMinder directory is ' + OriginalDir);
  VerboseWriteln('Changing directory to ' + StripTrailingSlash(gameDir));
  {$I-}
  ChDir(StripTrailingSlash(gameDir));
  {$I+}
  Status := IOResult;
  if ( Status <> 0 ) then begin
    Execute := Status;
    exit;
  end;

  VerboseWriteln('Executing ' + prog + ' ' + args);

  UseEmsIfAvailable := UseEmsForSwapFile;

  {function InitExecSwap(LastToSave : Pointer; SwapFileName : String) : Boolean;
  -Initialize for swapping, returning TRUE if successful}
  if not InitExecSwap(HeapPtr, TempDir + SwapFileName) then begin
    WriteLn('Error: Unable to allocate swap space');
    Status := 8; { Not enough memory }
  end
  else begin
    if ( EmsAllocated ) then
      VerboseWriteln('GameMinder swapped ' + ConvertToString(BytesSwapped) + ' bytes to EMS')
    else
      VerboseWriteln('GameMinder swapped ' + ConvertToString(BytesSwapped) + ' bytes to ' + TempDir + SwapFileName);
    writeln('');
    SwapVectors;
    Status := ExecWithSwap(prog, args);
    SwapVectors;
    ShutdownExecSwap;
  end;

  VerboseWriteln('Changing directory back to ' + OriginalDir);
  {$I-}
  ChDir(OriginalDir);
  {$I+}
  if ( IOResult <> 0 ) then ; { Clear error - nothing else we can do }

  Execute := Status;
end;

{ Warn if a game needs more memory than will be free.
  Returns false if the player chose not to run it }
function CheckMemory(game:PGame; overheadKB:integer; interactive:boolean):boolean;
var
  available:longint;
  key:char;
begin
  CheckMemory := true;
  if ( game^.MemoryKB = 0 ) then exit;

  available := AvailableMemoryKB - overheadKB;
  if ( game^.MemoryKB <= available ) then exit;

  TextColor(Yellow);
  writeln('');
  writeln(PStr(game^.Name), ' needs ', game^.MemoryKB, 'KB of conventional memory,');
  writeln('but only about ', available, 'KB will be free. It may not run.');
  TextColor(White);

  if ( interactive ) then begin
    writeln('');
    write('Run it anyway? (Y/N) ');
    key := UpCase(ReadKey);
    writeln(key);
    CheckMemory := ( key = 'Y' );
  end;
end;

{ Clear the screen for a game or setup program to start }
procedure ShowLaunchScreen;
begin
  TextBackground(Black);
  clrscr;

  TextColor(White);
  TextBackground(Blue);
  DrawCenter('GameMinder');

  TextColor(White);
  TextBackground(Black);
  ShowCursor;
end;

{ Report a program that couldn't be run, waiting for a key if interactive }
procedure ShowLaunchError(command:string; status:word; interactive:boolean);
begin
  TextColor(LightRed);
  writeln('');
  writeln('Unable to run ', command);
  writeln(DosErrorText(status));
  TextColor(White);
  if ( interactive ) then begin
    writeln('');
    writeln('Press any key to return to GameMinder');
    ReadKey;
  end;
end;

{ Run a game and record play stats. Interactive asks before running a game that
  may not fit in memory and waits for a key after errors.
  Returns 0 on success, a DOS error code, or LaunchCancelled }
function LaunchGame(game:PGame; interactive:boolean):word;
var
  prog,args,scriptPath:string;
  script:TLaunchScript;
  useScript:boolean;
  status:word;
  y,m,d,dow,h,min,s,hund:word;
  startDay:longint;
  startMinute:word;
  playTimeMinutes:longint;
begin
  useScript := NeedsLaunchScript(PStr(game^.Before), PStr(game^.After));

  if ( interactive ) then ShowLaunchScreen;

  writeln('Starting ', PStr(game^.Name));

  { Check the game is there first, so a failed launch isn't counted as a play }
  if not FileExists(GameProgram(PStr(game^.Path), PStr(game^.Exec))) then begin
    ShowLaunchError(GameProgram(PStr(game^.Path), PStr(game^.Exec)), 2, interactive);
    LaunchGame := 2; { File not found }
    exit;
  end;

  if ( useScript ) then begin
    if not CheckMemory(game, ScriptOverheadKB, interactive) then begin
      LaunchGame := LaunchCancelled;
      exit;
    end;

    { Run before, the game and after from one batch file }
    BuildLaunchScript(PStr(game^.Path), PStr(game^.Exec), PStr(game^.Before), PStr(game^.After), script);
    scriptPath := TempDir + ScriptFileName;
    if not WriteScript(scriptPath, script) then
      writeln('Unable to write ', scriptPath);
    prog := ComSpec;
    args := '/C ' + scriptPath;
  end
  else begin
    if not CheckMemory(game, 0, interactive) then begin
      LaunchGame := LaunchCancelled;
      exit;
    end;

    BuildLaunchCommand(PStr(game^.Path), PStr(game^.Exec), ComSpec, prog, args);
  end;

  GetDate(y,m,d,dow);
  GetTime(h,min,s,hund);
  startDay := DayNumber(y,m,d);
  startMinute := h * 60 + min;

  if ( EnablePlayStats ) then
    AppendPlayLog(game, PlayStatsFile_StartMarker + GetFormattedDate + ' ' + GetFormattedTime);

  status := Execute(prog, args, PStr(game^.Path));

  if ( useScript ) then DeleteFile(scriptPath);

  { Games can leave the screen in a graphics mode }
  if ( interactive ) then TextMode(StartupVideoMode);

  if ( status <> 0 ) then
    ShowLaunchError(prog + ' ' + args, status, interactive)
  else begin
    GetDate(y,m,d,dow);
    GetTime(h,min,s,hund);
    playTimeMinutes := ElapsedMinutes(startDay, startMinute, DayNumber(y,m,d), h * 60 + min);
    RecordSessionPlay(PStr(game^.Name), playTimeMinutes);

    if ( EnablePlayStats ) then begin
      VerboseWriteln('Logging play time of ' + ConvertToString(playTimeMinutes) + ' minute(s)');
      AppendPlayLog(game, PlayStatsFile_MinutesPlayedMarker + ConvertToString(playTimeMinutes));
    end;

    if ( WaitForKeyAfterGame ) and ( interactive ) then begin
      writeln('');
      writeln('Press any key to return to GameMinder');
      ReadKey;
    end;

    Delay(DelayAfterGameExit);
  end;

  { Reload game details, to include updated play stats }
  if ( EnablePlayStats ) then LoadPlayStats(game);

  LaunchGame := status;
end;

{ Run a game's setup program. It isn't counted as a play, and the game's
  before/after commands and memory check aren't used.
  Returns 0 on success or a DOS error code }
function LaunchSetup(game:PGame; interactive:boolean):word;
var
  prog,args:string;
  status:word;
begin
  if ( interactive ) then ShowLaunchScreen;

  writeln('Starting ', PStr(game^.Name), ' setup');

  if not FileExists(GameProgram(PStr(game^.Path), PStr(game^.Setup))) then begin
    ShowLaunchError(GameProgram(PStr(game^.Path), PStr(game^.Setup)), 2, interactive);
    LaunchSetup := 2; { File not found }
    exit;
  end;

  BuildLaunchCommand(PStr(game^.Path), PStr(game^.Setup), ComSpec, prog, args);
  status := Execute(prog, args, PStr(game^.Path));

  { Setup programs can leave the screen in a graphics mode too }
  if ( interactive ) then TextMode(StartupVideoMode);

  if ( status <> 0 ) then
    ShowLaunchError(prog + ' ' + args, status, interactive)
  else if ( WaitForKeyAfterGame ) and ( interactive ) then begin
    writeln('');
    writeln('Press any key to return to GameMinder');
    ReadKey;
  end;

  LaunchSetup := status;
end;

end.
