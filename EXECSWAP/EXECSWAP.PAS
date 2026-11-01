{
Copyright (c) 1988 TurboPower Software
May be used freely as long as due credit is given

Version 1.1 - 3/15/89
  save and restore EMS page map
Version 1.2 - 3/29/89
  add more compiler directives (far calls off, boolean short-circuiting)
  add UseEmsIfAvailable to disable EMS usage when desired
Version 1.3 - 5/02/89
  fix problem with exit chain when InitExecSwap/ShutdownExecSwap called
    more than once in a program
  flush swap file before execing
}

{$A+,B-,E+,F+,I-,L-,N-,O-,R-,S-,V-}

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

var
  EmsHandle : Word;               {Handle of EMS allocation block}
  FrameSeg : Word;                {Segment of EMS page frame}
  FileHandle : Word;              {DOS handle of swap file}
  SwapName : String[80];          {ASCIIZ name of swap file}
  SaveExit : Pointer;             {Exit chain pointer}

  {$L EXECSWAP}
  function ExecWithSwap(Path, CmdLine : String) : Word; external;
  procedure FirstToSave; external;
  function AllocateSwapFile : Boolean; external;
  procedure DeallocateSwapFile; external;

  {$F+}     {These routines could be interfaced for general use}
  function EmsInstalled : Boolean; external;
  function EmsPageFrame : Word; external;
  function AllocateEmsPages(NumPages : Word) : Word; external;
  procedure DeallocateEmsHandle(Handle : Word); external;
  function DefaultDrive : Char; external;
  function DiskFree(Drive : Byte) : LongInt; external;

  procedure ExecSwapExit;
  begin
    ExitProc := SaveExit;
    ShutdownExecSwap;
  end;
  {$F-}

  procedure ShutdownExecSwap;
  begin
    if EmsAllocated then begin
      DeallocateEmsHandle(EmsHandle);
      EmsAllocated := False;
    end else if FileAllocated then begin
      DeallocateSwapFile;
      FileAllocated := False;
    end;
  end;

  function PtrDiff(H, L : Pointer) : LongInt;
  type
    OS = record O, S : Word; end;   {Convenient typecast}
  begin
    PtrDiff := (LongInt(OS(H).S) shl 4+OS(H).O)-
               (LongInt(OS(L).S) shl 4+OS(L).O);
  end;

  function InitExecSwap(LastToSave : Pointer;
                        SwapFileName : String) : Boolean;
  const
    EmsPageSize = 16384;            {Bytes in a standard EMS page}
  var
    PagesInEms : Word;              {Pages needed in EMS}
    BytesFree : LongInt;            {Bytes free on swap file drive}
    DriveChar : Char;               {Drive letter for swap file}
  begin
    InitExecSwap := False;

    if EmsAllocated or FileAllocated then
      Exit;
    BytesSwapped := PtrDiff(LastToSave, @FirstToSave);
    if BytesSwapped <= 0 then
      Exit;

    if UseEmsIfAvailable and EmsInstalled then begin
      PagesInEms := (BytesSwapped+EmsPageSize-1) div EmsPageSize;
      EmsHandle := AllocateEmsPages(PagesInEms);
      if EmsHandle <> $FFFF then begin
        EmsAllocated := True;
        FrameSeg := EmsPageFrame;
        if FrameSeg <> 0 then begin
          InitExecSwap := True;
          Exit;
        end;
      end;
    end;
    if Length(SwapFileName) <> 0 then begin
      SwapName := SwapFileName+#0;
      if Pos(':', SwapFileName) = 2 then
        DriveChar := Upcase(SwapFileName[1])
      else
        DriveChar := DefaultDrive;
      BytesFree := DiskFree(Byte(DriveChar)-$40);
      FileAllocated := (BytesFree > BytesSwapped) and AllocateSwapFile;
      if FileAllocated then
        InitExecSwap := True;
    end;
  end;

begin
  SaveExit := ExitProc;
  ExitProc := @ExecSwapExit;
end.
