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
interface

const
  MaxMemEntries = 40;
  MaxMemRegions = 80;
  LowEndSeg = $A000;  { End of conventional memory, 640KB }

type
  TMemKind = (mkSystem, mkProgram, mkFree, mkReserved);

  { A named owner of memory, with its total in conventional and upper memory }
  TMemEntry = record
    Name:string[12];
    Kind:TMemKind;
    LowBytes, HighBytes:longint;
  end;

  { A block of memory in address order, for drawing a map }
  TMemRegion = record
    StartSeg:longint;
    Paragraphs:longint;
    Kind:TMemKind;
  end;

var
  MemEntries:array[1..MaxMemEntries] of TMemEntry;
  MemEntryCount:integer;
  MemRegions:array[1..MaxMemRegions] of TMemRegion;
  MemRegionCount:integer;
  FreeLowBytes, FreeHighBytes:longint;
  HasUpperMemory:boolean;  { True when upper memory blocks were found }

procedure ScanMemory;
function MemoryMapBar(fromSeg, toSeg:longint; width:byte):string;

{ --------- implementation --------- }
implementation
uses
    Dos;

const
  OwnerFree = 0;
  OwnerDos = 8;
  MaxBlocks = 1000; { Stop walking a damaged chain }

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
  if ( name = '' ) then name := 'Unknown';
  OwnerName := name;
end;

procedure AddRegion(startSeg, paragraphs:longint; kind:TMemKind);
begin
  if ( MemRegionCount >= MaxMemRegions ) then exit;
  inc(MemRegionCount);
  MemRegions[MemRegionCount].StartSeg := startSeg;
  MemRegions[MemRegionCount].Paragraphs := paragraphs;
  MemRegions[MemRegionCount].Kind := kind;
end;

{ Add memory to a named entry, combining blocks with the same name }
procedure AddEntry(name:string; kind:TMemKind; startSeg, paragraphs:longint);
var
  i, found:integer;
begin
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
          AddEntry(lastDriver, mkSystem, sub, size);
        end;
      'E': { More memory belonging to the driver before it }
          if ( lastDriver <> '' ) then
            AddEntry(lastDriver, mkSystem, sub, size)
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

procedure ScanMemory;
var
  regs:Registers;
  mcb, owner, paragraphs, firstMcb:longint;
  signature:char;
  linkState:byte;
  linkChanged:boolean;
  name:string;
  blocks:integer;
begin
  MemEntryCount := 0;
  MemRegionCount := 0;
  FreeLowBytes := 0;
  FreeHighBytes := 0;
  HasUpperMemory := false;

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
  AddRegion(0, firstMcb, mkSystem);

  mcb := firstMcb;
  blocks := 0;
  repeat
    signature := Chr(Mem[word(mcb):0]);
    if not ( signature in ['M', 'Z'] ) then break;
    owner := MemW[word(mcb):1];
    paragraphs := MemW[word(mcb):3];

    if ( owner = OwnerFree ) then begin
      AddRegion(mcb, paragraphs + 1, mkFree);
      if ( mcb < LowEndSeg ) then
        inc(FreeLowBytes, paragraphs * 16)
      else
        inc(FreeHighBytes, paragraphs * 16);
    end
    else if ( owner = OwnerDos ) then begin
      name := McbName(word(mcb));
      if ( ( mcb < LowEndSeg ) and ( mcb + paragraphs + 1 > LowEndSeg ) )
         or ( ( mcb >= LowEndSeg ) and ( name = 'SC' ) ) then
        { Video memory and ROMs, skipped over to reach or between upper memory blocks }
        AddRegion(mcb, paragraphs + 1, mkReserved)
      else if ( name = 'SD' ) then begin
        AddEntry('DOS', mkSystem, mcb, 1);
        ScanSystemData(mcb, paragraphs);
        AddRegion(mcb, paragraphs + 1, mkSystem);
      end
      else begin
        AddEntry('DOS', mkSystem, mcb, paragraphs + 1);
        AddRegion(mcb, paragraphs + 1, mkSystem);
      end;
    end
    else if ( owner = 6 ) or ( owner = 7 ) or ( owner >= $FFF0 ) then
      { Upper memory excluded or reserved by the memory manager }
      AddRegion(mcb, paragraphs + 1, mkReserved)
    else if ( Mem[word(owner):0] <> $CD ) then begin
      { Owner isn't a program - every PSP starts with INT 20h (CD 20) }
      AddEntry('DOS', mkSystem, mcb, paragraphs + 1);
      AddRegion(mcb, paragraphs + 1, mkSystem);
    end
    else begin
      AddEntry(OwnerName(word(owner)), mkProgram, mcb, paragraphs + 1);
      AddRegion(mcb, paragraphs + 1, mkProgram);
    end;

    if ( mcb >= LowEndSeg ) and ( owner <> 6 ) and ( owner <> 7 ) then
      HasUpperMemory := true;

    mcb := mcb + paragraphs + 1;
    inc(blocks);
  until ( signature = 'Z' ) or ( blocks >= MaxBlocks ) or ( mcb > $FFFF );

  if ( linkChanged ) then begin
    regs.AX := $5803;
    regs.BX := linkState;
    MsDos(regs);
  end;
end;

{ A map of memory between two segments: DOS and drivers, programs, free,
  or a dot where there's no usable memory }
function MemoryMapBar(fromSeg, toSeg:longint; width:byte):string;
var
  bar:string;
  cell, i:integer;
  cellStart, cellEnd, overlapStart, overlapEnd:longint;
  amount:array[TMemKind] of longint;
  kind, best:TMemKind;
begin
  bar[0] := chr(width);
  for cell := 1 to width do begin
    cellStart := fromSeg + ( toSeg - fromSeg ) * ( cell - 1 ) div width;
    cellEnd := fromSeg + ( toSeg - fromSeg ) * cell div width;
    for kind := mkSystem to mkReserved do amount[kind] := 0;

    for i := 1 to MemRegionCount do begin
      overlapStart := MemRegions[i].StartSeg;
      overlapEnd := overlapStart + MemRegions[i].Paragraphs;
      if ( overlapStart < cellStart ) then overlapStart := cellStart;
      if ( overlapEnd > cellEnd ) then overlapEnd := cellEnd;
      if ( overlapEnd > overlapStart ) then
        inc(amount[MemRegions[i].Kind], overlapEnd - overlapStart);
    end;

    { Whatever fills most of the cell }
    best := mkReserved;
    for kind := mkSystem to mkFree do
      if ( amount[kind] > 0 ) and ( amount[kind] >= amount[best] ) then best := kind;

    case best of
      mkSystem: bar[cell] := #178;  { Dark shade }
      mkProgram: bar[cell] := #177; { Medium shade }
      mkFree: bar[cell] := #176;    { Light shade }
    else
      bar[cell] := #250;            { Small dot }
    end;
  end;
  MemoryMapBar := bar;
end;

end.
