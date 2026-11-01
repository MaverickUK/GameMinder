Program MemFree;
{-----------------------------
Writes the conventional memory available to this program, in KB, to the
file named on the command line. CI runs it from the DOS prompt and through
GAMEMIND /RUN to check how much memory GameMinder leaves free for games.

  MEMFREE C:\BASE.TXT
------------------------------}
uses
    Dos;

var
  regs:Registers;
  paragraphs:longint;
  f:Text;
begin
  { Memory DOS gave this program, from its memory control block }
  paragraphs := MemW[PrefixSeg - 1:3];

  { Plus the largest block left free, in case the program wasn't given everything }
  regs.AH := $48;
  regs.BX := $FFFF;
  MsDos(regs);
  inc(paragraphs, regs.BX);

  Assign(f, ParamStr(1));
  Rewrite(f);
  writeln(f, paragraphs * 16 div 1024);
  Close(f);
end.
