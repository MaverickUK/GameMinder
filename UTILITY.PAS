Unit Utility;
{-----------------------------
Misc utility routines
------------------------------}

{ --------- interface -------- }
interface

function ConvertToString(input:integer):string;
function ConvertToInteger(input:string):integer;
function FormatDatePart(input:word; expectedLength:byte):string;
function GetFormattedTime:string;
function GetFormattedDate:string;
function MinutesToFriendlyTime(minutes:word):string;
function MinutesBetweenTimes( startTime:string; endTime:string):word;

{ --------- implementation --------- }
implementation 
uses
    Objects,
    Dos;

{ Convert an integer to a string }
function ConvertToString(input:integer):string;
var
  output:string[10];
begin
  Str(input, output);
  ConvertToString := output;
end;

{ Convert a string to an integer }
function ConvertToInteger(input:string):integer;
var
  code,output:integer;
begin
  val(input, output, code);
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
const
  days: array[0..6] of String[9] = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');
var
  y, m, d, dow:word;
begin
  GetDate(y,m,d,dow);
  GetFormattedDate := concat(FormatDatePart(y,4), '/', FormatDatePart(m,2), '/', FormatDatePart(d,2));
end;

{ Convert minutes into a friendly time }
function MinutesToFriendlyTime(minutes:word):string;
var
  hours,remainingMinutes:word;
  output:string;
begin
  hours := minutes div 60;
  remainingMinutes := minutes mod 60;

  { Init }
  output := '';

  if ( minutes > 60 ) then begin
    output := ConvertToString(hours);
    output := concat(output, ' hour');

    if ( hours > 1 ) then output := concat(output,'s');

    if ( remainingMinutes > 0 ) then begin
      output := concat(output,' ', ConvertToString(remainingMinutes), ' min');
      if ( remainingMinutes > 1) then output := concat(output, 's');
    end;
  end
  else
  begin 
    { TODO: Remove this code duplication }
    if ( minutes > 0 ) then begin
      output := concat(output,' ', ConvertToString(minutes), ' min');

      if ( minutes > 1) then output := concat(output, 's');
    end;
  end;

  if length(output) = 0 then output := 'N/A';

  MinutesToFriendlyTime := output;
end;

{ Calculate the number of minutes between two times - format HH:MM }
function MinutesBetweenTimes( startTime:string; endTime:string):word;
const
  minutesInDay = 1440;
var
  startMinutes,endMinutes:word;
  tempHours,tempMinutes:byte;
  output:word;
begin
  { Extract hours/minutes from time string }
  tempHours := ConvertToInteger(copy(startTime,1,2));
  tempMinutes := ConvertToInteger(copy(startTime,4,2));

  startMinutes := (tempHours * 60) + tempMinutes;

  { Extract hours/minutes from time string }
  tempHours := ConvertToInteger(copy(endTime,1,2));    
  tempMinutes := ConvertToInteger(copy(endTime,4,2));   

  endMinutes := (tempHours * 60) + tempMinutes;    
  output := endMinutes - startMinutes;

  if ( startMinutes > endMinutes) then begin 
    { Assume play session crossed into new day }
    output := minutesInDay - output;
  end;

  MinutesBetweenTimes := output;
end;

end.