Unit Utility;
{-----------------------------
Misc utility routines
No screen or DOS-only calls in here, so the unit can be unit tested
with Free Pascal on a modern OS (see TESTS\TESTS.PAS)
------------------------------}

{ --------- interface -------- }
interface

const
  { Directory separator - backslash on DOS, forward slash when unit testing on Linux/macOS }
  {$IFDEF UNIX}
  PathSep = '/';
  AllFilesMask = '*';
  {$ELSE}
  PathSep = '\';
  AllFilesMask = '*.*';
  {$ENDIF}
  MinutesInDay = 1440;

var
  VerboseOutput:boolean; { Set from SETTINGS.TXT }

procedure VerboseWriteln(output:string);
function ConvertToString(input:longint):string;
function ConvertToInteger(input:string):longint;
function FormatDatePart(input:word; expectedLength:byte):string;
function GetFormattedTime:string;
function GetFormattedDate:string;
function MinutesToFriendlyTime(minutes:longint):string;
function MinutesBetweenTimes(startTime:string; endTime:string):word;
function DayNumber(year,month,day:word):longint;
function ElapsedMinutes(startDay:longint; startMinute:word; endDay:longint; endMinute:word):longint;
function FormatBytes(bytes:longint):string;
function DosErrorText(code:word):string;
function ParseMemoryKB(value:string):word;
{ Strings }
function PadRight(s:string; width:byte):string;
function PadColumn(s:string; width:byte):string;
function Trim(s:string):string;
function UpStr(s:string):string;
function LowerStr(s:string):string;
function TitleCase(s:string):string;
function CompareText(a,b:string):integer;
function ContainsText(haystack,needle:string):boolean;
function SplitKeyValue(line:string; var key:string; var value:string):boolean;
function WrapText(var text:string; width:byte):string;
{ Paths }
function NormalizeDir(path:string):string;
function ScanPathCount(paths:string):integer;
function ScanPathItem(paths:string; index:integer):string;
function NormalizeScanPaths(paths:string):string;
function StripTrailingSlash(path:string):string;
function DirOfPath(path:string):string;
function FileExtension(fileName:string):string;
function FileExists(fileName:string):boolean;

{ --------- implementation --------- }
implementation
uses
    Dos;

{ Only output if VerboseOutput is enabled }
procedure VerboseWriteln(output:string);
begin
  if ( VerboseOutput ) then writeln(output);
end;

{ Convert an integer to a string }
function ConvertToString(input:longint):string;
var
  output:string[12];
begin
  Str(input, output);
  ConvertToString := output;
end;

{ Convert a string to an integer }
function ConvertToInteger(input:string):longint;
var
  code:integer;
  output:longint;
begin
  val(Trim(input), output, code);
  if code = 0 then begin
    ConvertToInteger := output;
  end else begin
    ConvertToInteger := 0; { Default on failure }
  end;
end;

function FormatDatePart(input:word; expectedLength:byte):string;
var
  output:string;
begin
  output := ConvertToString(input);

  { Add leading zeros }
  while length(output) < expectedLength do begin
    output := '0' + output;
  end;

  FormatDatePart := output;
end;

{ Get current time as string }
function GetFormattedTime:string;
var
  h,m,s,hund:word;
begin
  GetTime(h,m,s,hund);
  GetFormattedTime := concat(FormatDatePart(h,2), ':', FormatDatePart(m,2));
end;

{ Get current date as a string }
function GetFormattedDate:string;
var
  y, m, d, dow:word;
begin
  GetDate(y,m,d,dow);
  GetFormattedDate := concat(FormatDatePart(y,4), '/', FormatDatePart(m,2), '/', FormatDatePart(d,2));
end;

{ Convert minutes into a friendly time e.g. "1 hour 5 mins" }
function MinutesToFriendlyTime(minutes:longint):string;
var
  hours,remainingMinutes:longint;
  output:string;
begin
  hours := minutes div 60;
  remainingMinutes := minutes mod 60;

  output := '';

  if ( hours > 0 ) then begin
    output := ConvertToString(hours) + ' hour';
    if ( hours > 1 ) then output := output + 's';
  end;

  if ( remainingMinutes > 0 ) then begin
    if ( length(output) > 0 ) then output := output + ' ';
    output := output + ConvertToString(remainingMinutes) + ' min';
    if ( remainingMinutes > 1 ) then output := output + 's';
  end;

  if length(output) = 0 then output := 'N/A';

  MinutesToFriendlyTime := output;
end;

{ Calculate the number of minutes between two times - format HH:MM }
function MinutesBetweenTimes(startTime:string; endTime:string):word;
var
  startMinutes,endMinutes:word;
begin
  startMinutes := ConvertToInteger(copy(startTime,1,2)) * 60 + ConvertToInteger(copy(startTime,4,2));
  endMinutes := ConvertToInteger(copy(endTime,1,2)) * 60 + ConvertToInteger(copy(endTime,4,2));

  if ( endMinutes >= startMinutes ) then
    MinutesBetweenTimes := endMinutes - startMinutes
  else
    { Assume play session crossed into new day }
    MinutesBetweenTimes := MinutesInDay - startMinutes + endMinutes;
end;

{ Days since a fixed epoch - only used to measure the gap between two dates }
function DayNumber(year,month,day:word):longint;
var
  y,m:longint;
begin
  { Treat Jan/Feb as months 13/14 of the previous year so leap days fall at the end }
  y := year;
  m := month;
  if ( m < 3 ) then begin
    dec(y);
    inc(m, 12);
  end;

  DayNumber := 365 * y + y div 4 - y div 100 + y div 400 + (153 * (m - 3) + 2) div 5 + day;
end;

{ Minutes between two day number/minute of day pairs }
function ElapsedMinutes(startDay:longint; startMinute:word; endDay:longint; endMinute:word):longint;
var
  output:longint;
begin
  output := (endDay - startDay) * MinutesInDay + endMinute - startMinute;
  if ( output < 0 ) then output := 0; { Clock was changed during play }
  ElapsedMinutes := output;
end;

{ Format a byte count as a short human readable size }
function FormatBytes(bytes:longint):string;
begin
  if ( bytes < 0 ) then
    FormatBytes := 'N/A'
  else if ( bytes >= 10485760 ) then { 10MB+ }
    FormatBytes := ConvertToString(bytes div 1048576) + ' MB'
  else if ( bytes >= 10240 ) then { 10KB+ }
    FormatBytes := ConvertToString(bytes div 1024) + ' KB'
  else
    FormatBytes := ConvertToString(bytes) + ' bytes';
end;

{ Describe the common DOS errors returned when launching a game }
function DosErrorText(code:word):string;
begin
  case code of
    2: DosErrorText := 'File not found';
    3: DosErrorText := 'Path not found';
    5: DosErrorText := 'Access denied';
    8: DosErrorText := 'Not enough memory';
    10: DosErrorText := 'Bad environment';
    11: DosErrorText := 'Bad program format';
  else
    DosErrorText := 'DOS error ' + ConvertToString(code);
  end;
end;

{ Memory in KB from a value like 580, 580K or 580KB, 0 if not valid }
function ParseMemoryKB(value:string):word;
var
  kb:longint;
  code:integer;
begin
  value := UpStr(Trim(value));
  if ( copy(value, length(value) - 1, 2) = 'KB' ) then
    value := Trim(copy(value, 1, length(value) - 2))
  else if ( copy(value, length(value), 1) = 'K' ) then
    value := Trim(copy(value, 1, length(value) - 1));

  val(value, kb, code);
  if ( code = 0 ) and ( kb > 0 ) and ( kb <= 1024 ) then
    ParseMemoryKB := kb
  else
    ParseMemoryKB := 0;
end;

{ ////////////////// Strings ////////////////// }

{ Pad with spaces, or truncate, to exactly width characters }
function PadRight(s:string; width:byte):string;
begin
  if ( length(s) > width ) then s[0] := chr(width);
  while ( length(s) < width ) do s := s + ' ';
  PadRight := s;
end;

{ Pad or truncate to a table column, always leaving a space before the next column }
function PadColumn(s:string; width:byte):string;
begin
  if ( width = 0 ) then
    PadColumn := ''
  else
    PadColumn := PadRight(s, width - 1) + ' ';
end;

{ Remove leading and trailing spaces/tabs }
function Trim(s:string):string;
begin
  while ( length(s) > 0 ) and ( s[length(s)] in [' ', #9, #13, #10] ) do
    dec(s[0]);
  while ( length(s) > 0 ) and ( s[1] in [' ', #9] ) do
    delete(s, 1, 1);
  Trim := s;
end;

function UpStr(s:string):string;
var
  i:byte;
begin
  for i := 1 to length(s) do
    s[i] := UpCase(s[i]);
  UpStr := s;
end;

function LowerStr(s:string):string;
var
  i:byte;
begin
  for i := 1 to length(s) do
    if ( s[i] in ['A'..'Z'] ) then s[i] := chr(ord(s[i]) + 32);
  LowerStr := s;
end;

{ Capitalise the first letter of each word e.g. MONKEY ISLAND -> Monkey Island }
function TitleCase(s:string):string;
var
  i:byte;
  startOfWord:boolean;
begin
  startOfWord := true;
  for i := 1 to length(s) do begin
    if ( startOfWord ) then
      s[i] := UpCase(s[i])
    else if ( s[i] in ['A'..'Z'] ) then
      s[i] := chr(ord(s[i]) + 32);
    startOfWord := ( s[i] in [' ', '_', '-'] );
  end;
  TitleCase := s;
end;

{ Case-insensitive compare: <0 if a<b, 0 if equal, >0 if a>b }
function CompareText(a,b:string):integer;
var
  i,len:byte;
  ca,cb:char;
begin
  len := length(a);
  if ( length(b) < len ) then len := length(b);

  for i := 1 to len do begin
    ca := UpCase(a[i]);
    cb := UpCase(b[i]);
    if ( ca <> cb ) then begin
      CompareText := ord(ca) - ord(cb);
      exit;
    end;
  end;

  CompareText := length(a) - length(b);
end;

{ Case-insensitive search for needle within haystack }
function ContainsText(haystack,needle:string):boolean;
begin
  ContainsText := ( length(needle) = 0 ) or ( pos(UpStr(needle), UpStr(haystack)) > 0 );
end;

{ Split a "key:value" line. Key is upper cased, both are trimmed.
  Returns false for blank lines, ; comments and lines without a colon }
function SplitKeyValue(line:string; var key:string; var value:string):boolean;
var
  colon:byte;
begin
  SplitKeyValue := false;
  key := '';
  value := '';

  line := Trim(line);
  if ( length(line) = 0 ) or ( line[1] = ';' ) then exit;

  colon := pos(':', line);
  if ( colon <= 1 ) then exit;

  key := UpStr(Trim(copy(line, 1, colon - 1)));
  value := Trim(copy(line, colon + 1, 255));
  SplitKeyValue := true;
end;

{ Take the first line of up to width characters off text, breaking between words
  where possible. Call until text is empty to wrap all of it }
function WrapText(var text:string; width:byte):string;
var
  i:byte;
begin
  text := Trim(text);
  if ( length(text) <= width ) then begin
    WrapText := text;
    text := '';
    exit;
  end;

  { Last space that leaves a line short enough, otherwise break the word }
  i := width + 1;
  while ( i > 1 ) and ( text[i] <> ' ' ) do
    dec(i);
  if ( i <= 1 ) then i := width + 1;

  WrapText := Trim(copy(text, 1, i - 1));
  text := Trim(copy(text, i, 255));
end;

{ ////////////////// Paths ////////////////// }

{ Ensure a directory ends with a separator e.g. C:\GAMES -> C:\GAMES\ }
function NormalizeDir(path:string):string;
begin
  path := Trim(path);
  if ( length(path) > 0 ) and not ( path[length(path)] in ['\', '/'] ) then
    path := path + PathSep;
  NormalizeDir := path;
end;

{ ScanPath can list several directories separated by ; e.g. C:\GAMES;D:\GAMES }

{ Number of directories in a ; separated list, ignoring blanks }
function ScanPathCount(paths:string):integer;
var
  count:integer;
begin
  count := 0;
  while ( length(ScanPathItem(paths, count + 1)) > 0 ) do
    inc(count);
  ScanPathCount := count;
end;

{ Directory from a ; separated list, counting from 1, with a trailing separator.
  Blank if there isn't one }
function ScanPathItem(paths:string; index:integer):string;
var
  semicolon:byte;
  item:string;
begin
  ScanPathItem := '';
  while ( length(paths) > 0 ) do begin
    semicolon := pos(';', paths);
    if ( semicolon = 0 ) then semicolon := length(paths) + 1;
    item := NormalizeDir(copy(paths, 1, semicolon - 1));
    delete(paths, 1, semicolon);

    if ( length(item) > 0 ) then begin
      dec(index);
      if ( index = 0 ) then begin
        ScanPathItem := item;
        exit;
      end;
    end;
  end;
end;

{ Tidy a ScanPath list: each directory ends with a separator, and blanks,
  repeats and directories inside another listed directory are dropped,
  so no game is found twice }
function NormalizeScanPaths(paths:string):string;
var
  i,j,count:integer;
  item,other,result_:string;
  keep:boolean;
begin
  result_ := '';
  count := ScanPathCount(paths);

  for i := 1 to count do begin
    item := ScanPathItem(paths, i);
    keep := true;
    for j := 1 to count do
      if ( j <> i ) then begin
        other := ScanPathItem(paths, j);
        { Inside another directory, or a repeat of an earlier one }
        if ( pos(UpStr(other), UpStr(item)) = 1 ) and
           ( ( length(other) < length(item) ) or ( j < i ) ) then keep := false;
      end;

    if ( keep ) then begin
      if ( length(result_) > 0 ) then result_ := result_ + ';';
      result_ := result_ + item;
    end;
  end;

  NormalizeScanPaths := result_;
end;

{ Remove a trailing separator so the path can be passed to ChDir,
  leaving roots such as C:\ or \ alone }
function StripTrailingSlash(path:string):string;
begin
  if ( length(path) > 1 ) and ( path[length(path)] in ['\', '/'] )
     and not ( ( length(path) = 3 ) and ( path[2] = ':' ) ) then
    dec(path[0]);
  StripTrailingSlash := path;
end;

{ Directory part of a file path, including the trailing separator }
function DirOfPath(path:string):string;
var
  i:byte;
begin
  i := length(path);
  while ( i > 0 ) and not ( path[i] in ['\', '/', ':'] ) do
    dec(i);
  DirOfPath := copy(path, 1, i);
end;

{ Upper cased extension without the dot e.g. DUNE.BAT -> BAT }
function FileExtension(fileName:string):string;
var
  i:byte;
begin
  FileExtension := '';
  i := length(fileName);
  while ( i > 0 ) and not ( fileName[i] in ['.', '\', '/'] ) do
    dec(i);
  if ( i > 0 ) and ( fileName[i] = '.' ) then
    FileExtension := UpStr(copy(fileName, i + 1, 255));
end;

function FileExists(fileName:string):boolean;
var
  S:SearchRec;
begin
  FindFirst(fileName, ReadOnly + Hidden + SysFile + Archive, S);
  FileExists := ( DosError = 0 );
  {$IFDEF FPC}
  FindClose(S);
  {$ENDIF}
end;

begin
  VerboseOutput := false;
end.
