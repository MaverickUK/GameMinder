Unit MemMap;
{-----------------------------
Memory map - what's loaded in conventional and upper memory

Walks DOS's chain of memory control blocks (MCBs), the same way MEM /C does.
Each MCB is a 16 byte header before a block of memory:

  0     'M', or 'Z' for the last block
  1-2   Owner: the PSP segment of the program it belongs to,
        0 if free, 8 if it belongs to DOS
  3-4   Size in paragraphs (16 bytes), not counting the header
  8-15  Program name (DOS 4 and later), padded with zeros

Device drivers loaded from CONFIG.SYS sit inside DOS's 'SD' (system data)
block, each with a sub-header in the same format. Upper memory blocks are
only in the chain while they're linked in, so they're linked while walking.
------------------------------}

{ --------- interface -------- }
{ --------- interface -------- }
interface

const
  MaxMemEntries = 40;
  MaxMemRegions = 80;
  LowEndSeg = $A000;  { End of conventional memory, 640KB }
  MapFree = 0;        { MapCellEntry for free memory }
  MapNone = -1;       { MapCellEntry for no usable memory, e.g. video or ROM }

type
  TMemKind = (mkSystem, mkProgram, mkEms);

  { A named owner of memory - DOS, a driver or a program - with its total
    in conventional (low) and upper (high) memory }
  TMemEntry = record
    Name:string[12];
    Kind:TMemKind;
    LowBytes, HighBytes:longint;
  end;

  { A block of memory in address order, for drawing a map }
  TMemRegion = record
    StartSeg:longint;
    Paragraphs:longint;
    Entry:integer; { Index into MemEntries, or MapFree / MapNone }
  end;

var
  MemEntries:array[1..MaxMemEntries] of TMemEntry;
  MemEntryCount:integer;
  MemRegions:array[1..MaxMemRegions] of TMemRegion;
  MemRegionCount:integer;
  FreeLowBytes, FreeHighBytes:longint;
  HasUpperMemory:boolean;  { True when upper memory blocks were found }
  SelfBytes:longint;       { Memory GameMinder is using now, before it's swapped out }
  EmsFrameEntry:integer;   { Entry for the EMS page frame in upper memory, 0 if none }

procedure ScanMemory(selfResidentKB:word);
function MapCellEntry(cellStart, cellEnd:longint):integer;

{ --------- implementation --------- }
implementation
uses
    Dos;

const
  OwnerFree = 0;
  OwnerDos = 8;
  MaxBlocks = 1000; { Stop walking a damaged chain }
  EmsFramePages = 4; { 16KB pages, so 64KB }

{ Name stored in an MCB, blank if it isn't readable text }
function McbName(mcbSeg:word):string;
var
  name:string;
  i:integer;
  c:char;
begin
  name := '';
  for i := 0 to 7 do begin
    c := Chr(Mem[mcbSeg:8 + i]);
    if ( c = #0 ) then break;
    if ( c < '!' ) or ( c > '~' ) then begin
      McbName := '';
      exit;
    end;
    name := name + c;
  end;
  McbName := name;
end;

{ Program name from the end of its environment block, for DOS 3 }
function EnvironmentProgramName(psp:word):string;
var
  env, ofs:word;
  path:string;
  i:integer;
begin
  EnvironmentProgramName := '';
  env := MemW[psp:$2C];
  if ( env = 0 ) then exit;

  { Variables end with two zeros, then a count word, then the program's path }
  ofs := 0;
  while ( ofs < 32000 ) and not ( ( Mem[env:ofs] = 0 ) and ( Mem[env:ofs + 1] = 0 ) ) do
    inc(ofs);
  if ( ofs >= 32000 ) then exit;
  inc(ofs, 4);

  path := '';
  while ( Mem[env:ofs] <> 0 ) and ( length(path) < 80 ) do begin
    path := path + Chr(Mem[env:ofs]);
    inc(ofs);
  end;

  { Just the file name, without its extension }
  for i := length(path) downto 1 do
    if ( path[i] = '\' ) or ( path[i] = ':' ) then begin
      delete(path, 1, i);
      break;
    end;
  if ( pos('.', path) > 0 ) then path[0] := chr(pos('.', path) - 1);
  EnvironmentProgramName := path;
end;

function HexWord(value:word):string;
const
  Digits:string[16] = '0123456789ABCDEF';
begin
  HexWord := Digits[value shr 12 + 1] + Digits[( value shr 8 ) and 15 + 1]
             + Digits[( value shr 4 ) and 15 + 1] + Digits[value and 15 + 1];
end;

{ Segment of the EMS page frame, 0 if there's no EMS driver }
function EmsPageFrame:word;
const
  DriverName: string[8] = 'EMMXXXX0';
var
  regs:Registers;
  driverSeg:word;
  i:integer;
begin
  EmsPageFrame := 0;
  { The driver's name is 10 bytes into the segment its interrupt 67h handler is in }
  driverSeg := MemW[0:$67 * 4 + 2];
  for i := 1 to length(DriverName) do
    if ( Chr(Mem[driverSeg:$0A + i - 1]) <> DriverName[i] ) then exit;

  regs.AH := $41; { Get page frame segment }
  Intr($67, regs);
  if ( regs.AH = 0 ) then EmsPageFrame := regs.BX;
end;

{ Name of the program owning a block of memory }
function OwnerName(owner:word):string;
var
  name:string;
begin
  if ( owner = PrefixSeg ) then begin
    OwnerName := 'GameMinder';
    exit;
  end;

  name := '';
  { The program's own MCB is just before its PSP }
  if ( Lo(DosVersion) >= 4 ) and ( Chr(Mem[owner - 1:0]) in ['M', 'Z'] )
     and ( MemW[owner - 1:1] = owner ) then
    name := McbName(owner - 1);
  if ( name = '' ) then name := EnvironmentProgramName(owner);
  { The command shell is its own parent }
  if ( name = '' ) and ( MemW[owner:$16] = owner ) then name := 'COMMAND';
  { Keep programs we can't name apart, by their segment }
  if ( name = '' ) then name := 'Prog ' + HexWord(owner);
  OwnerName := name;
end;

procedure AddRegion(startSeg, paragraphs:longint; entry:integer);
begin
  if ( paragraphs <= 0 ) or ( MemRegionCount >= MaxMemRegions ) then exit;
  inc(MemRegionCount);
  MemRegions[MemRegionCount].StartSeg := startSeg;
  MemRegions[MemRegionCount].Paragraphs := paragraphs;
  MemRegions[MemRegionCount].Entry := entry;
end;

{ Add memory to a named entry, combining blocks with the same name, and map it }
procedure AddEntry(name:string; kind:TMemKind; startSeg, paragraphs:longint);
var
  i, found:integer;
begin
  if ( paragraphs <= 0 ) then exit;
  found := 0;
  for i := 1 to MemEntryCount do
    if ( MemEntries[i].Name = name ) and ( MemEntries[i].Kind = kind ) then found := i;

  if ( found = 0 ) then begin
    if ( MemEntryCount >= MaxMemEntries ) then exit;
    inc(MemEntryCount);
    found := MemEntryCount;
    MemEntries[found].Name := name;
    MemEntries[found].Kind := kind;
    MemEntries[found].LowBytes := 0;
    MemEntries[found].HighBytes := 0;
  end;

  if ( startSeg < LowEndSeg ) then
    inc(MemEntries[found].LowBytes, paragraphs * 16)
  else
    inc(MemEntries[found].HighBytes, paragraphs * 16);
  AddRegion(startSeg, paragraphs, found);
end;

procedure AddFree(startSeg, paragraphs:longint);
begin
  if ( paragraphs <= 0 ) then exit;
  if ( startSeg < LowEndSeg ) then
    inc(FreeLowBytes, paragraphs * 16)
  else
    inc(FreeHighBytes, paragraphs * 16);
  AddRegion(startSeg, paragraphs, MapFree);
end;

{ Device drivers and DOS data inside DOS's system data block }
procedure ScanSystemData(blockSeg, paragraphs:longint);
var
  sub, blockEnd, size:longint;
  subType:char;
  lastDriver:string;
begin
  sub := blockSeg + 1;
  blockEnd := blockSeg + 1 + paragraphs;
  lastDriver := '';

  while ( sub < blockEnd ) do begin
    subType := Chr(Mem[word(sub):0]);
    if not ( subType in ['D', 'E', 'I', 'F', 'X', 'C', 'B', 'L', 'S', 'T'] ) then break;
    size := longint(MemW[word(sub):3]) + 1;
    if ( sub + size > blockEnd ) then break;

    case subType of
      'D', 'I': begin { Device driver or installable file system }
          lastDriver := McbName(word(sub));
          if ( lastDriver = '' ) then lastDriver := 'Driver';
          AddEntry(lastDriver, mkProgram, sub, size);
        end;
      'E': { More memory belonging to the driver before it }
          if ( lastDriver <> '' ) then
            AddEntry(lastDriver, mkProgram, sub, size)
          else
            AddEntry('DOS', mkSystem, sub, size);
    else
      AddEntry('DOS', mkSystem, sub, size); { FILES, BUFFERS, STACKS etc. }
    end;

    inc(sub, size);
  end;

  { Anything left over, e.g. a sub-block we don't recognise }
  if ( sub < blockEnd ) then AddEntry('DOS', mkSystem, sub, blockEnd - sub);
end;

{ selfResidentKB is how much of GameMinder stays in memory while a game runs.
  The rest of GameMinder's own block is counted as free, as games get it. }
procedure ScanMemory(selfResidentKB:word);
var
  regs:Registers;
  mcb, owner, paragraphs, firstMcb, resident:longint;
  signature:char;
  linkState:byte;
  linkChanged:boolean;
  name:string;
  blocks:integer;
  frame:longint;
begin
  MemEntryCount := 0;
  MemRegionCount := 0;
  FreeLowBytes := 0;
  FreeHighBytes := 0;
  HasUpperMemory := false;
  SelfBytes := 0;
  EmsFrameEntry := 0;

  { Link upper memory into the chain (DOS 5 and later), remembering the setting }
  linkChanged := false;
  regs.AX := $5802;
  MsDos(regs);
  if ( regs.Flags and FCarry = 0 ) then begin
    linkState := regs.AL;
    regs.AX := $5803;
    regs.BX := 1;
    MsDos(regs);
    linkChanged := ( regs.Flags and FCarry = 0 );
  end;

  { DOS's List of Lists has the first MCB's segment just before it }
  regs.AH := $52;
  MsDos(regs);
  firstMcb := MemW[regs.ES:regs.BX - 2];

  { Interrupt vectors, BIOS data and the DOS kernel come before the first MCB }
  AddEntry('DOS', mkSystem, 0, firstMcb);

  mcb := firstMcb;
  blocks := 0;
  repeat
    signature := Chr(Mem[word(mcb):0]);
    if not ( signature in ['M', 'Z'] ) then break;
    owner := MemW[word(mcb):1];
    paragraphs := MemW[word(mcb):3];

    if ( owner = OwnerFree ) then
      AddFree(mcb, paragraphs + 1)
    else if ( owner = OwnerDos ) then begin
      name := McbName(word(mcb));
      if ( ( mcb < LowEndSeg ) and ( mcb + paragraphs + 1 > LowEndSeg ) )
         or ( ( mcb >= LowEndSeg ) and ( name = 'SC' ) ) then
        { Video memory and ROMs, skipped over to reach or between upper memory blocks }
        AddRegion(mcb, paragraphs + 1, MapNone)
      else if ( name = 'SD' ) then begin
        AddEntry('DOS', mkSystem, mcb, 1);
        ScanSystemData(mcb, paragraphs);
      end
      else
        AddEntry('DOS', mkSystem, mcb, paragraphs + 1);
    end
    else if ( owner = 6 ) or ( owner = 7 ) or ( owner >= $FFF0 ) then
      { Upper memory excluded or reserved by the memory manager }
      AddRegion(mcb, paragraphs + 1, MapNone)
    else if ( Mem[word(owner):0] <> $CD ) then
      { Owner isn't a program - every PSP starts with INT 20h (CD 20) }
      AddEntry('DOS', mkSystem, mcb, paragraphs + 1)
    else if ( owner = PrefixSeg ) and ( owner = mcb + 1 ) then begin
      { GameMinder itself: only its stub stays while a game runs }
      resident := longint(selfResidentKB) * 64;
      if ( resident > paragraphs + 1 ) then resident := paragraphs + 1;
      AddEntry('GameMinder', mkProgram, mcb, resident);
      AddFree(mcb + resident, paragraphs + 1 - resident);
    end
    else
      AddEntry(OwnerName(word(owner)), mkProgram, mcb, paragraphs + 1);

    if ( mcb >= LowEndSeg ) and ( owner <> 6 ) and ( owner <> 7 ) then
      HasUpperMemory := true;

    if ( owner = PrefixSeg ) then inc(SelfBytes, ( paragraphs + 1 ) * 16);

    mcb := mcb + paragraphs + 1;
    inc(blocks);
  until ( signature = 'Z' ) or ( blocks >= MaxBlocks ) or ( mcb > $FFFF );

  if ( linkChanged ) then begin
    regs.AX := $5803;
    regs.BX := linkState;
    MsDos(regs);
  end;

  { The EMS page frame: 64KB of upper memory a memory manager keeps for EMS.
    It isn't in the chain, so it would otherwise look like video memory or ROM }
  frame := EmsPageFrame;
  if ( frame >= LowEndSeg ) and ( frame <= $F000 ) then begin
    AddEntry('EMS window', mkEms, frame, EmsFramePages * 1024);
    EmsFrameEntry := MemEntryCount;
    HasUpperMemory := true;
  end;
end;

{ What to show for a cell of the memory map covering cellStart to cellEnd
  (segments). Programs and drivers win over DOS, DOS over free memory, so
  even a small TSR gets a cell. Returns an entry, MapFree or MapNone. }
function MapCellEntry(cellStart, cellEnd:longint):integer;
var
  i, entry, bestProgram, dos:integer;
  overlapStart, overlapEnd, size, bestSize:longint;
  free:boolean;
begin
  bestProgram := 0;
  bestSize := 0;
  dos := 0;
  free := false;

  for i := 1 to MemRegionCount do begin
    overlapStart := MemRegions[i].StartSeg;
    overlapEnd := overlapStart + MemRegions[i].Paragraphs;
    if ( overlapStart < cellStart ) then overlapStart := cellStart;
    if ( overlapEnd > cellEnd ) then overlapEnd := cellEnd;
    size := overlapEnd - overlapStart;
    if ( size > 0 ) then begin
      entry := MemRegions[i].Entry;
      if ( entry = MapFree ) then
        free := true
      else if ( entry > 0 ) then begin
        if ( MemEntries[entry].Kind <> mkProgram ) then
          dos := entry { DOS or the EMS page frame }
        else if ( size > bestSize ) then begin
          bestProgram := entry;
          bestSize := size;
        end;
      end;
    end;
  end;

  if ( bestProgram > 0 ) then MapCellEntry := bestProgram
  else if ( dos > 0 ) then MapCellEntry := dos
  else if ( free ) then MapCellEntry := MapFree
  else MapCellEntry := MapNone;
end;

end.
