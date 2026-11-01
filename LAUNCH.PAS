Unit Launch;
{-----------------------------
Work out how to launch a game

Batch files can't be EXEC'd directly by DOS (doing so can crash or
reboot the machine), so they're run through the command interpreter.

Games with before: or after: commands are run from a small batch file,
so all three run in one command interpreter.
------------------------------}

{ --------- interface -------- }
interface

const
  DefaultComSpec = 'C:\COMMAND.COM';
  MaxScriptLines = 4;

type
  { Batch file to run a game with its before/after commands }
  TLaunchScript = record
    Count: byte;
    Lines: array[1..MaxScriptLines] of string;
  end;

procedure BuildLaunchCommand(path:string; exec:string; comSpec:string; var prog:string; var args:string);
procedure BuildLaunchScript(path:string; exec:string; before:string; after:string; var script:TLaunchScript);
function NeedsLaunchScript(before:string; after:string):boolean;

{ --------- implementation --------- }
implementation
uses
    Utility;

{ Split exec: into the full path of the program and its arguments }
procedure ResolveProgram(path:string; exec:string; var program_:string; var extraArgs:string);
var
  space:byte;
begin
  exec := Trim(exec);
  space := pos(' ', exec);

  if ( space > 0 ) then begin
    program_ := copy(exec, 1, space - 1);
    extraArgs := Trim(copy(exec, space + 1, 255));
  end else begin
    program_ := exec;
    extraArgs := '';
  end;

  { Allow exec to be a full path, otherwise it's relative to the game directory }
  if ( pos(':', program_) = 0 ) and ( pos('\', program_) <> 1 ) then
    program_ := NormalizeDir(path) + program_;
end;

{ path    - game directory e.g. C:\GAMES\DUNE\
  exec    - exec: value from !GM_INFO.TXT, may include arguments e.g. KEEN4.EXE /NOJOY
  comSpec - COMSPEC environment variable
  prog    - full path of program to EXEC
  args    - command line to pass it }
procedure BuildLaunchCommand(path:string; exec:string; comSpec:string; var prog:string; var args:string);
var
  program_,extraArgs:string;
begin
  ResolveProgram(path, exec, program_, extraArgs);

  if ( FileExtension(program_) = 'BAT' ) then begin
    comSpec := Trim(comSpec);
    if ( length(comSpec) = 0 ) then comSpec := DefaultComSpec;
    prog := comSpec;
    args := '/C ' + program_;
    if ( length(extraArgs) > 0 ) then args := args + ' ' + extraArgs;
  end else begin
    prog := program_;
    args := extraArgs;
  end;
end;

function NeedsLaunchScript(before:string; after:string):boolean;
begin
  NeedsLaunchScript := ( length(Trim(before)) > 0 ) or ( length(Trim(after)) > 0 );
end;

{ Lines of a batch file running before, the game, then after }
procedure BuildLaunchScript(path:string; exec:string; before:string; after:string; var script:TLaunchScript);
var
  program_,extraArgs,gameLine:string;

  procedure AddLine(line:string);
  begin
    inc(script.Count);
    script.Lines[script.Count] := line;
  end;

begin
  script.Count := 0;
  AddLine('@ECHO OFF');

  if ( length(Trim(before)) > 0 ) then AddLine(Trim(before));

  ResolveProgram(path, exec, program_, extraArgs);
  gameLine := program_;
  if ( length(extraArgs) > 0 ) then gameLine := gameLine + ' ' + extraArgs;
  { Without CALL, running a batch file wouldn't come back to run after }
  if ( FileExtension(program_) = 'BAT' ) then gameLine := 'CALL ' + gameLine;
  AddLine(gameLine);

  if ( length(Trim(after)) > 0 ) then AddLine(Trim(after));
end;

end.
