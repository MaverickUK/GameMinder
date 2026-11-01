Unit Launch;
{-----------------------------
Work out how to launch a game

Batch files can't be EXEC'd directly by DOS (doing so can crash or
reboot the machine), so they're run through the command interpreter
------------------------------}

{ --------- interface -------- }
interface

const
  DefaultComSpec = 'C:\COMMAND.COM';

procedure BuildLaunchCommand(path:string; exec:string; comSpec:string; var prog:string; var args:string);

{ --------- implementation --------- }
implementation
uses
    Utility;

{ path    - game directory e.g. C:\GAMES\DUNE\
  exec    - exec: value from !GM_INFO.TXT, may include arguments e.g. KEEN4.EXE /NOJOY
  comSpec - COMSPEC environment variable
  prog    - full path of program to EXEC
  args    - command line to pass it }
procedure BuildLaunchCommand(path:string; exec:string; comSpec:string; var prog:string; var args:string);
var
  space:byte;
  program_,extraArgs:string;
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

end.
