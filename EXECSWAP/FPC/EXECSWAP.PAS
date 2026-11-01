{
Free Pascal (i8086-msdos) port of ExecSwap

Based on ExecSwap
  Copyright (c) 1988 TurboPower Software
  May be used freely as long as due credit is given

Same interface as the Turbo Pascal unit in ..\EXECSWAP.PAS. The swapping core
is SWAPCORE.ASM (NASM), linked into the same code segment as Free Pascal's
startup code, so only a small stub stays in memory while a program runs.
The EMS and swap file handling below was moved from assembler to Pascal.

Assemble SWAPCORE.OBJ first: nasm -f obj -o SWAPCORE.OBJ SWAPCORE.ASM
}

{$mode tp}

unit ExecSwap;
  {-Memory-efficient DOS EXEC call}
interface

const
  UseEmsIfAvailable : Boolean = True;     {True to use EMS if available}
  BytesSwapped : LongInt = 0;             {Bytes to swap to EMS/disk}
  EmsAllocated : Boolean = False;         {True when EMS allocated for swap}
  FileAllocated : Boolean = False;        {True when file allocated for swap}

function ExecWithSwap(Path, CmdLine : String) : Word;
  {-DOS EXEC supporting swap to EMS or disk}

function InitExecSwap(LastToSave : Pointer; SwapFileName : String) : Boolean;
  {-Initialize for swapping, returning TRUE if successful}

procedure ShutdownExecSwap;
  {-Deallocate swap area}

implementation

uses
  Dos;

type
  { Must match the Info offsets in SWAPCORE.ASM }
  { Segment and offset of a far pointer }
  TFarRec = record
    O, S : Word;
  end;

  TSwapInfo = packed record
    BytesSwapped : LongInt;
    EmsAllocated : Byte;
    FileAllocated : Byte;
    EmsHandle : Word;
    FrameSeg : Word;
    FileHandle : Word;
    PrefixSeg : Word;
  end;

var
  Info : TSwapInfo;
  SwapName : String[80];          {ASCIIZ name of swap file}
  SaveExit : CodePointer;         {Exit chain pointer}

{$L SWAPCORE.OBJ}
function ExecSwapCore(Path, CmdLine, SwapInfo : Pointer) : Word; far; pascal; external name 'ExecSwapCore';
procedure FirstToSave; far; external name 'FirstToSave';

{ Linear address of a segment:offset pointer }
function Linear(P : Pointer) : LongInt;
begin
  Linear := (LongInt(TFarRec(P).S) shl 4) + TFarRec(P).O;
end;

function EmsInstalled : Boolean;
const
  EmsDevice : array[0..7] of Char = 'EMMXXXX0';
var
  Vector : FarPointer;
  I : Byte;
begin
  { The EMS driver's device header holds its name at offset 0Ah of the INT 67h segment }
  GetIntVec($67, Vector);
  EmsInstalled := False;
  if Vector = nil then
    Exit;
  for I := 0 to 7 do
    if Mem[TFarRec(Vector).S:$0A + I] <> Ord(EmsDevice[I]) then
      Exit;
  EmsInstalled := True;
end;

function EmsPageFrame : Word;
var
  Regs : Registers;
begin
  Regs.AH := $41;
  Intr($67, Regs);
  if Regs.AH = 0 then
    EmsPageFrame := Regs.BX
  else
    EmsPageFrame := 0;
end;

function AllocateEmsPages(NumPages : Word) : Word;
var
  Regs : Registers;
begin
  Regs.AH := $43;
  Regs.BX := NumPages;
  Intr($67, Regs);
  if Regs.AH = 0 then
    AllocateEmsPages := Regs.DX
  else
    AllocateEmsPages := $FFFF;
end;

procedure DeallocateEmsHandle(Handle : Word);
var
  Regs : Registers;
begin
  Regs.AH := $45;
  Regs.DX := Handle;
  Intr($67, Regs);
end;

function AllocateSwapFile : Boolean;
var
  Regs : Registers;
begin
  Regs.AH := $3C;                 {Create file}
  Regs.CX := 6;                   {Hidden+system}
  Regs.DS := Seg(SwapName[1]);
  Regs.DX := Ofs(SwapName[1]);
  MsDos(Regs);
  AllocateSwapFile := (Regs.Flags and FCarry) = 0;
  Info.FileHandle := Regs.AX;
end;

procedure DeallocateSwapFile;
var
  Regs : Registers;
begin
  Regs.AH := $3E;                 {Close file}
  Regs.BX := Info.FileHandle;
  MsDos(Regs);
  Regs.AX := $4301;               {Set normal attribute}
  Regs.CX := 0;
  Regs.DS := Seg(SwapName[1]);
  Regs.DX := Ofs(SwapName[1]);
  MsDos(Regs);
  Regs.AH := $41;                 {Delete file}
  Regs.DS := Seg(SwapName[1]);
  Regs.DX := Ofs(SwapName[1]);
  MsDos(Regs);
end;

function ExecWithSwap(Path, CmdLine : String) : Word;
begin
  Info.BytesSwapped := BytesSwapped;
  Info.EmsAllocated := Ord(EmsAllocated);
  Info.FileAllocated := Ord(FileAllocated);
  Info.PrefixSeg := PrefixSeg;
  ExecWithSwap := ExecSwapCore(@Path, @CmdLine, @Info);
end;

procedure ShutdownExecSwap;
begin
  if EmsAllocated then begin
    DeallocateEmsHandle(Info.EmsHandle);
    EmsAllocated := False;
  end else if FileAllocated then begin
    DeallocateSwapFile;
    FileAllocated := False;
  end;
end;

procedure ExecSwapExit;
begin
  ExitProc := SaveExit;
  ShutdownExecSwap;
end;

function InitExecSwap(LastToSave : Pointer; SwapFileName : String) : Boolean;
const
  EmsPageSize = 16384;            {Bytes in a standard EMS page}
var
  PagesInEms : Word;              {Pages needed in EMS}
  BytesFree : LongInt;            {Bytes free on swap file drive}
  Drive : Byte;                   {Drive number for swap file, 0 = default}
begin
  InitExecSwap := False;

  if EmsAllocated or FileAllocated then
    Exit;
  BytesSwapped := Linear(LastToSave) - Linear(Pointer(@FirstToSave));
  if BytesSwapped <= 0 then
    Exit;

  if UseEmsIfAvailable and EmsInstalled then begin
    PagesInEms := (BytesSwapped+EmsPageSize-1) div EmsPageSize;
    Info.EmsHandle := AllocateEmsPages(PagesInEms);
    if Info.EmsHandle <> $FFFF then begin
      EmsAllocated := True;
      Info.FrameSeg := EmsPageFrame;
      if Info.FrameSeg <> 0 then begin
        InitExecSwap := True;
        Exit;
      end;
    end;
  end;
  if Length(SwapFileName) <> 0 then begin
    SwapName := SwapFileName+#0;
    if Pos(':', SwapFileName) = 2 then
      Drive := Ord(Upcase(SwapFileName[1]))-$40
    else
      Drive := 0;
    BytesFree := DiskFree(Drive);
    FileAllocated := (BytesFree > BytesSwapped) and AllocateSwapFile;
    if FileAllocated then
      InitExecSwap := True;
  end;
end;

begin
  SaveExit := ExitProc;
  ExitProc := @ExecSwapExit;
end.
