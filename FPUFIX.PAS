Unit FpuFix;
{-----------------------------
Free Pascal only - lets GameMinder start on PCs without a maths coprocessor

At startup the Free Pascal runtime hooks interrupt 10h (the video BIOS) to
catch FPU errors, and only puts the original handler back once it has found
an FPU. Without one the hook stays, and the FPU instruction in it hangs a 386
without a 387 on the first video BIOS call. GameMinder doesn't use floating
point, so put the original handler back before anything uses the screen.

Must be the first unit in GAMEMIND.PAS's uses, so it starts before Crt.
------------------------------}

{ --------- interface -------- }
interface

{ --------- implementation --------- }
implementation
{$IFDEF FPC}
uses
    Dos;
{$ENDIF}

begin
{$IFDEF FPC}
  if ( Test8087 = 0 ) then
    SetIntVec($10, SaveInt10);
{$ENDIF}
end.
