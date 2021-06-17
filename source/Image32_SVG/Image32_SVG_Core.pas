unit Image32_SVG_Core;

(*******************************************************************************
* Author    :  Angus Johnson                                                   *
* Version   :  2.24                                                            *
* Date      :  17 June 2021                                                    *
* Website   :  http://www.angusj.com                                           *
* Copyright :  Angus Johnson 2019-2021                                         *
*                                                                              *
* Purpose   :  Essential structures and functions to read SVG files            *
*                                                                              *
* License   :  Use, modification & distribution is subject to                  *
*              Boost Software License Ver 1                                    *
*              http://www.boost.org/LICENSE_1_0.txt                            *
*******************************************************************************)

interface

{$I Image32.inc}

uses
  SysUtils, Classes, Types, Math,
  {$IFDEF XPLAT_GENERICS} Generics.Collections, Generics.Defaults,{$ENDIF}
  Image32, Image32_Vector, Image32_Ttf, Image32_Transform;

type
  TElementMeasureUnit = (emuBoundingBox, emuUserSpace);
  TMeasureUnit = (muUndefined, muPixel, muPercent,
    muDegree, muRadian, muInch, muCm, muMm, muEm, muEx, muPt, muPica);

  //////////////////////////////////////////////////////////////////////
  // TValue - Structure to store numerics with measurement units.
  //          Includes methods to scale percent units depending on the 
  //          supplied bounding width/height/area etc. 
  //////////////////////////////////////////////////////////////////////

  TValue = {$IFDEF RECORD_METHODS} record {$ELSE} object {$ENDIF}
    rawVal  : double;
    mu      : TMeasureUnit;
    pcBelow : double; //manages % vs frac. ambiguity with untyped values
    procedure Init(asPercentBelow: double);
    procedure SetValue(val: double; measureUnit: TMeasureUnit = muUndefined);
    function  GetValue(scale: double; fontSize: double = 16.0): double;
    function  GetValueX(const scale: double; fontSize: double): double;
    function  GetValueY(const scale: double; fontSize: double): double;
    function  GetValueXY(const scaleRec: TRectD; fontSize: double): double;
    function  IsValid: Boolean;
    function  IsPercent: Boolean;
  end;

  TValuePt = {$IFDEF RECORD_METHODS} record {$ELSE} object {$ENDIF}
    X       : TValue;
    Y       : TValue;
    procedure Init(asPercentBelow: double);
    function  GetPoint(const scaleRec: TRectD; fontSize: double): TPointD;
    function  IsValid: Boolean;
  end;

  TValueRecWH = {$IFDEF RECORD_METHODS} record {$ELSE} object {$ENDIF}
    left    : TValue;
    top     : TValue;
    width   : TValue;
    height  : TValue;
    procedure Init(asPercentBelow: double);
    function  GetRectD(const scaleRec: TRectD; fontSize: double): TRectD;
    function  GetRectWH(const scaleRec: TRectD; fontSize: double): TRectWH;
    function  IsValid: Boolean;
    function  IsEmpty: Boolean;
  end;

  //////////////////////////////////////////////////////////////////////
  // TAnsi - alternative to AnsiString with a little less overhead.
  //////////////////////////////////////////////////////////////////////
  
  TAnsi = {$IFDEF RECORD_METHODS} record {$ELSE} object {$ENDIF}
    text: PAnsiChar;
    len : integer;
    function AsAnsiString: AnsiString;
  end;
  TArrayOfTAnsi = array of TAnsi;

  TSvgItalicSyle  = (sfsUndefined, sfsNone, sfsItalic);
  TFontDecoration = (fdUndefined, fdNone, fdUnderline, fdStrikeThrough);
  TSvgTextAlign = (staUndefined, staLeft, staCenter, staRight);

  TSVGFontInfo = record
    family      : TTtfFontFamily;
    size        : double;
    spacing     : double;
    textLength  : double;
    italic      : TSvgItalicSyle;
    weight      : Integer;
    align       : TSvgTextAlign;
    decoration  : TFontDecoration;
    baseShift   : TValue;
  end;

  TSizeType = (stAverage, stWidth, stHeight);

  //////////////////////////////////////////////////////////////////////
  // TClassStylesList: custom TStringList that stores ansistring objects
  //////////////////////////////////////////////////////////////////////

  PAnsStringiRec = ^TAnsiStringRec;   //used internally by TClassStylesList
  TAnsiStringRec = record
    ansi  : AnsiString;
  end;

  TClassStylesList = class
  private
    fList : TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    function  AddAppendStyle(const classname: string; const ansi: AnsiString): integer;
    function  GetStyle(const classname: AnsiString): AnsiString;
    procedure Clear;
  end;

  //////////////////////////////////////////////////////////////////////
  // TSvgParser and associated classes - a simple parser for SVG xml
  //////////////////////////////////////////////////////////////////////

  PAttrib = ^TAttrib;         //element attribute
  TAttrib = record
    hash      : Cardinal;     //hashed name
    name      : AnsiString;
    value     : AnsiString;
  end;

  TSvgParser = class;

  TParserBaseEl = class       //(abstract) base element class
  public
    name        : TAnsi;
    {$IFDEF XPLAT_GENERICS}
    attribs     : TList <PAttrib>;
    {$ELSE}
    attribs     : TList;
    {$ENDIF}
    owner       : TSvgParser;
    selfClosed  : Boolean;
    constructor Create(owner: TSvgParser); virtual;
    destructor  Destroy; override;
    procedure   Clear; virtual;
    function    ParseHeader(var c: PAnsiChar; endC: PAnsiChar): Boolean; virtual;
    function    ParseAttribName(var c: PAnsiChar; endC: PAnsiChar; attrib: PAttrib): Boolean;
    function    ParseAttribValue(var c: PAnsiChar; endC: PAnsiChar; attrib: PAttrib): Boolean;
    function    ParseAttributes(var c: PAnsiChar; endC: PAnsiChar): Boolean; virtual;
    procedure   ParseStyleAttribute(const style: AnsiString);
  end;

  TDocTypeEl = class(TParserBaseEl)
  private
    procedure   SkipWord(var c, endC: PAnsiChar);
    function    ParseEntities(var c, endC: PAnsiChar): Boolean;
  public
    function    ParseAttributes(var c: PAnsiChar; endC: PAnsiChar): Boolean; override;
  end;

  TSvgEl = class(TParserBaseEl) //<svg> el. PLUS all contained els.
  public
    hash        : Cardinal;
    text        : TAnsi;
    {$IFDEF XPLAT_GENERICS}
    childs      : TList<TSvgEl>;
    {$ELSE}
    childs      : TList;
    {$ENDIF}
    constructor Create(owner: TSvgParser); override;
    destructor  Destroy; override;
    procedure   Clear; override;
    function    ParseHeader(var c: PAnsiChar; endC: PAnsiChar): Boolean; override;
    function    ParseContent(var c: PAnsiChar; endC: PAnsiChar): Boolean; virtual;
  end;

  TSvgParser = class             
  private
    svgStream : TMemoryStream;
    procedure ParseStream;
  public
    classStyles :TClassStylesList;
    xmlHeader   : TParserBaseEl;
    docType     : TDocTypeEl;
    svgTree     : TSvgEl;
    {$IFDEF XPLAT_GENERICS}
    entities    : TList<TSvgEl>;
    {$ELSE}
    entities    : TList;
    {$ENDIF}
    constructor Create;
    destructor  Destroy; override;
    procedure   Clear;
    function    FindEntity(hash: Cardinal): PAttrib;
    function LoadFromFile(const filename: string): Boolean;
    function LoadFromStream(stream: TStream): Boolean;
  end;

  //////////////////////////////////////////////////////////////////////
  //TDpath structures
  //////////////////////////////////////////////////////////////////////

  TDsegType = (dsMove, dsLine, dsHorz, dsVert, dsArc,
    dsQBez, dsCBez, dsQSpline, dsCSpline, dsClose);

  PDpathSeg = ^TDpathSeg;
  TDpathSeg = record
    segType : TDsegType;
    vals    : TArrayOfDouble;
  end;

  PDpath = ^TDpath;
  TDpath = {$IFDEF RECORD_METHODS} record {$ELSE} object {$ENDIF}
    firstPt   : TPointD;
    isClosed  : Boolean;
    segs      : array of TDpathSeg;
    function GetBounds: TRectD;
    //scalePending: if an SVG will be scaled later, then this parameter
    //allows curve 'flattening' to occur with a corresponding precision
    function GetFlattenedPath(scalePending: double = 1.0): TPathD;
    //GetSimplePath - ignores curves and is only used with markers
    function GetSimplePath: TPathD;
  end;
  TDpaths = array of TDpath;

  //////////////////////////////////////////////////////////////////////
  // Miscellaneous SVG functions
  //////////////////////////////////////////////////////////////////////

  //general parsing functions //////////////////////////////////////////
  function ParseNextWord(var c: PAnsiChar; endC: PAnsiChar;
    out word: AnsiString): Boolean;
  function ParseNextWordEx(var c: PAnsiChar; endC: PAnsiChar;
    out word: AnsiString): Boolean;
  function ParseNextNum(var c: PAnsiChar; endC: PAnsiChar;
    skipComma: Boolean; out val: double): Boolean;
  function ParseNextNumEx(var c: PAnsiChar; endC: PAnsiChar; skipComma: Boolean;
    out val: double; out measureUnit: TMeasureUnit): Boolean;
  function GetHash(const name: AnsiString): cardinal;
  function GetHashCaseSensitive(name: PAnsiChar; nameLen: integer): cardinal;
  function ExtractRef(const href: AnsiString): AnsiString;
  function IsNumPending(c, endC: PAnsiChar; ignoreComma: Boolean): Boolean;
  function AnsiStringToColor32(const value: AnsiString; var color: TColor32): Boolean;
  function MakeDashArray(const dblArray: TArrayOfDouble; scale: double): TArrayOfInteger;
  function Match(c: PAnsiChar; const compare: AnsiString): Boolean; overload;
  function PAnsiCharToTAnsi(var c: PAnsiChar; endC: PAnsiChar; out value: TAnsi): Boolean;
  procedure PAnsiCharToAnsiString(var c: PAnsiChar; endC: PAnsiChar; out value: AnsiString);

  //special parsing functions //////////////////////////////////////////
  function ParsePathDAttribute(const value: AnsiString): TDpaths;
  procedure ParseStyleElementContent(const value: TAnsi; stylesList: TClassStylesList);
  function ParseTransform(const transform: AnsiString): TMatrixD;

  procedure GetSvgFontInfo(const value: AnsiString; var fontInfo: TSVGFontInfo);
  function GetSvgArcInfo(const p1, p2: TPointD; radii: TPointD; phi_rads: double;
    fA, fS: boolean; out startAngle, endAngle: double; out rec: TRectD): Boolean;
  function HtmlDecode(const html: ansiString): ansistring;

{$IF COMPILERVERSION < 17}
type
  TSetOfChar = set of Char;
function CharInSet(chr: Char; chrs: TSetOfChar): Boolean;
{$IFEND}

const
  clInvalid   = $00010001;
  clCurrent   = $00010002;
  sqrt2       = 1.4142135623731;
  quote       = '''';
  dquote      = '"';
  space       = #32;

  {$I Image32_SVG_Hash_Consts.inc}

var
  LowerCaseTable : array[#0..#255] of AnsiChar;

implementation

type
  TColorConst = record
    ColorName : string;
    ColorValue: Cardinal;
  end;

const
  buffSize    = 32;

  //include hashed html entity constants
  {$I html_entity_hash_consts.inc}

var
  ColorConstList : TStringList;

//------------------------------------------------------------------------------
// Miscellaneous functions ...
//------------------------------------------------------------------------------

{$IF COMPILERVERSION < 17}
function CharInSet(chr: Char; chrs: TSetOfChar): Boolean;
begin
  Result := chr in chrs;
end;
{$IFEND}
//------------------------------------------------------------------------------

function SkipBlanks(var c: PAnsiChar; endC: PAnsiChar): Boolean;
begin
  while (c < endC) and (c^ <= space) do inc(c);
  Result := (c < endC);
end;
//------------------------------------------------------------------------------

function SkipBlanksAndComma(var current: PAnsiChar; currentEnd: PAnsiChar): Boolean;
begin
  Result := SkipBlanks(current, currentEnd);
  if not Result or (current^ <> ',') then Exit;
  inc(current);
  Result := SkipBlanks(current, currentEnd);
end;
//------------------------------------------------------------------------------

function SkipStyleBlanks(var c: PAnsiChar; endC: PAnsiChar): Boolean;
var
  inComment: Boolean;
begin
  //style content may include multi-line comment blocks
  inComment := false;
  while (c < endC) do
  begin
    if inComment then
    begin
      if (c^ = '*') and ((c +1)^ = '/')  then
      begin
        inComment := false;
        inc(c);
      end;
    end
    else if (c^ > space) then
    begin
      inComment := (c^ = '/') and ((c +1)^ = '*');
      if not inComment then break;
    end;
    inc(c);
  end;
  Result := (c < endC);
end;
//------------------------------------------------------------------------------

function IsAlpha(c: AnsiChar): Boolean; {$IFDEF INLINE} inline; {$ENDIF}
begin
  Result := CharInSet(c, ['A'..'Z','a'..'z']);
end;
//------------------------------------------------------------------------------

function GetSingleDigit(var c, endC: PAnsiChar;
  out digit: integer): Boolean;
begin
  Result := SkipBlanksAndComma(c, endC) and (c^ >= '0') and (c^ <= '9');
  if not Result then Exit;
  digit := Ord(c^) - Ord('0');
  inc(c);
end;
//------------------------------------------------------------------------------

function ParseStyleNameLen(var c: PAnsiChar; endC: PAnsiChar): integer;
var
  c2: PAnsiChar;
const
  validNonFirstChars =  ['0'..'9','A'..'Z','a'..'z','-'];
begin
  Result := 0;
  //nb: style names may start with a hyphen
  if (c^ = '-') then
  begin
    if not IsAlpha((c+1)^) then Exit;
  end
  else if not IsAlpha(c^) then Exit;

  c2 := c; inc(c);
  while (c < endC) and CharInSet(c^, validNonFirstChars) do inc(c);
  Result := c - c2;
end;
//------------------------------------------------------------------------------

function ParseNextWord(var c: PAnsiChar; endC: PAnsiChar; out word: AnsiString): Boolean;
var
  c2: PAnsiChar;
begin
  Result := SkipBlanksAndComma(c, endC);
  if not Result then Exit;
  c2 := c;
  while (c < endC) and
    (LowerCaseTable[c^] >= 'a') and (LowerCaseTable[c^] <= 'z') do
      inc(c);
  PAnsiCharToAnsiString(c2, c, word);
end;
//------------------------------------------------------------------------------

function ParseNextWordEx(var c: PAnsiChar; endC: PAnsiChar;
  out word: AnsiString): Boolean;
var
  isQuoted: Boolean;
  c2: PAnsiChar;
begin
  Result := SkipBlanksAndComma(c, endC);
  if not Result then Exit;
  isQuoted := (c^) = quote;
  if isQuoted then
  begin
    inc(c);
    c2 := c;
    while (c < endC) and (c^ <> quote) do inc(c);
    PAnsiCharToAnsiString(c2, c,word);
    inc(c);
  end else
  begin
    Result := CharInSet(LowerCaseTable[c^], ['A'..'Z', 'a'..'z']);
    if not Result then Exit;
    c2 := c;
    inc(c);
    while (c < endC) and
      CharInSet(LowerCaseTable[c^], ['A'..'Z', 'a'..'z', '-', '_']) do inc(c);
    PAnsiCharToAnsiString(c2, c,word);
  end;
end;
//------------------------------------------------------------------------------

function ParseNameLength(var c: PAnsiChar; endC: PAnsiChar): integer; overload;
var
  c2: PAnsiChar;
const
  validNonFirstChars =  ['0'..'9','A'..'Z','a'..'z','_',':','-'];
begin
  c2 := c;
  inc(c);
  while (c < endC) and CharInSet(c^, validNonFirstChars) do inc(c);
  Result := c - c2;
end;
//------------------------------------------------------------------------------

{$OVERFLOWCHECKS OFF}
function GetHash(const name: AnsiString): cardinal;
var
  i: integer;
  c: PAnsiChar;
begin
  //https://en.wikipedia.org/wiki/Jenkins_hash_function
  c := PAnsiChar(name);
  Result := 0;
  if c = nil then Exit;
  for i := 1 to Length(name) do
  begin
    Result := (Result + Ord(LowerCaseTable[c^]));
    Result := Result + (Result shl 10);
    Result := Result xor (Result shr 6);
    inc(c);
  end;
  Result := Result + (Result shl 3);
  Result := Result xor (Result shr 11);
  Result := Result + (Result shl 15);
end;
//------------------------------------------------------------------------------

function GetHashCaseSensitive(name: PAnsiChar; nameLen: integer): cardinal;
var
  i: integer;
begin
  Result := 0;
  for i := 1 to nameLen do
  begin
    Result := (Result + Ord(name^));
    Result := Result + (Result shl 10);
    Result := Result xor (Result shr 6);
    inc(name);
  end;
  Result := Result + (Result shl 3);
  Result := Result xor (Result shr 11);
  Result := Result + (Result shl 15);
end;
{$OVERFLOWCHECKS ON}
//------------------------------------------------------------------------------

function ParseNextWordHashed(var c: PAnsiChar; endC: PAnsiChar): cardinal;
var
  name: TAnsi;
begin
  name.text := c;
  name.len := ParseNameLength(c, endC);
  if name.len = 0 then Result := 0
  else Result := GetHash(name.AsAnsiString);
end;
//------------------------------------------------------------------------------

function ParseNextNumEx(var c: PAnsiChar; endC: PAnsiChar; skipComma: Boolean;
  out val: double; out measureUnit: TMeasureUnit): Boolean;
var
  decPos,exp: integer;
  isNeg, expIsNeg: Boolean;
  start: PAnsiChar;
begin
  Result := false;
  measureUnit := muUndefined;

  //skip white space +/- single comma
  if skipComma then
  begin
    while (c < endC) and (c^ <= space) do inc(c);
    if (c^ = ',') then inc(c);
  end;
  while (c < endC) and (c^ <= space) do inc(c);
  if (c = endC) then Exit;

  decPos := -1; exp := Invalid; expIsNeg := false;
  isNeg := c^ = '-';
  if isNeg then inc(c);

  val := 0;
  start := c;
  while c < endC do
  begin
{$IF COMPILERVERSION >= 17}
    if Ord(c^) = Ord(FormatSettings.DecimalSeparator) then
{$ELSE}
    if Ord(current^) = Ord(DecimalSeparator) then
{$IFEND}
    begin
      if decPos >= 0 then break;
      decPos := 0;
    end
    else if (LowerCaseTable[c^] = 'e') and
      (CharInSet((c+1)^, ['-','0'..'9'])) then
    begin
      if (c +1)^ = '-' then expIsNeg := true;
      inc(c);
      exp := 0;
    end
    else if (c^ < '0') or (c^ > '9') then
      break
    else if IsValid(exp) then
    begin
      exp := exp * 10 + (Ord(c^) - Ord('0'))
    end else
    begin
      val := val *10 + Ord(c^) - Ord('0');
      if decPos >= 0 then inc(decPos);
    end;
    inc(c);
  end;
  Result := c > start;
  if not Result then Exit;

  if decPos > 0 then val := val * Power(10, -decPos);
  if isNeg then val := -val;
  if IsValid(exp) then
  begin
    if expIsNeg then
      val := val * Power(10, -exp) else
      val := val * Power(10, exp);
  end;

  //https://oreillymedia.github.io/Using_SVG/guide/units.html
  case c^ of
    '%':
      begin
        inc(c);
        measureUnit := muPercent;
      end;
    'c': //convert cm to pixels
      if ((c+1)^ = 'm') then
      begin
        inc(c, 2);
        measureUnit := muCm;
      end;
    'd': //ignore deg
      if ((c+1)^ = 'e') and ((c+2)^ = 'g') then
      begin
        inc(c, 3);
        measureUnit := muDegree;
      end;
    'e': //convert cm to pixels
      if ((c+1)^ = 'm') then
      begin
        inc(c, 2);
        measureUnit := muEm;
      end
      else if ((c+1)^ = 'x') then
      begin
        inc(c, 2);
        measureUnit := muEx;
      end;
    'i': //convert inchs to pixels
      if ((c+1)^ = 'n') then
      begin
        inc(c, 2);
        measureUnit := muInch;
      end;
    'm': //convert mm to pixels
      if ((c+1)^ = 'm') then
      begin
        inc(c, 2);
        measureUnit := muMm;
      end;
    'p':
      case (c+1)^ of
        'c':
          begin
            inc(c, 2);
            measureUnit := muPica;
          end;
        't':
          begin
            inc(c, 2);
            measureUnit := muPt;
          end;
        'x':
          begin
            inc(c, 2);
            measureUnit := muPixel;
          end;
      end;
    'r': //convert radian angles to degrees
      if ((c+1)^ = 'a') and ((c+2)^ = 'd') then
      begin
        inc(c, 3);
        measureUnit := muRadian;
      end;
  end;
end;
//------------------------------------------------------------------------------

function ParseNextNum(var c: PAnsiChar; endC: PAnsiChar;
  skipComma: Boolean; out val: double): Boolean;
var
  tmp: TValue;
begin
  tmp.Init(0);
  Result := ParseNextNumEx(c, endC, skipComma, tmp.rawVal, tmp.mu);
  val := tmp.GetValue(1);
end;
//------------------------------------------------------------------------------

function ExtractRef(const href: AnsiString): AnsiString; {$IFDEF INLINE} inline; {$ENDIF}
var
  c, c2, endC: PAnsiChar;
begin
  c := PAnsiChar(href);
  endC := c + Length(href);
  if Match(c, 'url(') then
  begin
    inc(c, 4);
    dec(endC); // avoid trailing ')'
  end;
  if c^ = '#' then inc(c);
  c2 := c;
  while (c < endC) and (c^ <> ')') do inc(c);
  PAnsiCharToAnsiString(c2, c, Result);
end;
//------------------------------------------------------------------------------

function ParseNextChar(var c: PAnsiChar; endC: PAnsiChar): AnsiChar;
begin
  Result := #0;
  if not SkipBlanks(c, endC) then Exit;
  Result := c^;
  inc(c);
end;
//------------------------------------------------------------------------------

function ParseQuoteChar(var c: PAnsiChar; endC: PAnsiChar): AnsiChar;
begin
  if SkipBlanks(c, endC) and (c^ in [quote, dquote]) then
  begin
    Result := c^;
    inc(c);
  end else
    Result := #0;
end;
//------------------------------------------------------------------------------

function AnsiTrim(var name: TAnsi): Boolean;
var
  endC: PAnsiChar;
begin
  while (name.len > 0) and (name.text^ <= space) do
  begin
    inc(name.text); dec(name.len);
  end;
  Result := name.len > 0;
  if not Result then Exit;
  endC := name.text + name.len -1;
  while endC^ <= space do
  begin
    dec(endC); dec(name.len);
  end;
end;
//------------------------------------------------------------------------------

function PAnsiCharToTAnsi(var c: PAnsiChar;  endC: PAnsiChar;
  out value: TAnsi): Boolean;
begin
  SkipBlanks(c, endC);
  value.text := c;
  value.len := ParseNameLength(c, endC);
  Result := value.len > 0;
end;
//------------------------------------------------------------------------------

procedure PAnsiCharToAnsiString(var c: PAnsiChar; endC: PAnsiChar; out value: AnsiString);
var
  len: integer;
begin
  len := endC - c;
  SetLength(value, len);
  if len > 0 then
  begin
    Move(c^, value[1], len * SizeOf(AnsiChar));
    c := endC;
  end;
end;
//------------------------------------------------------------------------------

function Match(c: PAnsiChar; const compare: AnsiString): Boolean;
var
  i: integer;
begin
  Result := false;
  for i := 1 to Length(compare) do
  begin
    if LowerCaseTable[c^] <> compare[i] then Exit;
    inc(c);
  end;
  Result := true;
end;
//------------------------------------------------------------------------------

function Match(c: PAnsiChar; const compare: TAnsi): Boolean; overload;
var
  i: integer;
  c1, c2: PAnsiChar;
begin
  Result := false;
  c1 := c; c2 := compare.text;
  for i := 0 to compare.len -1 do
  begin
    if LowerCaseTable[c1^] <> LowerCaseTable[c2^] then Exit;
    inc(c1); inc(c2);
  end;
  Result := true;
end;
//------------------------------------------------------------------------------

function IsKnownEntity(owner: TSvgParser;
  var c: PAnsiChar; endC: PAnsiChar; out entity: PAttrib): boolean;
var
  c2, c3: PAnsiChar;
  entityName: AnsiString;
begin
  inc(c); //skip ampersand.
  c2 := c; c3 := c;
  ParseNameLength(c3, endC);
  PAnsiCharToAnsiString(c2, c3, entityName);
  entity := owner.FindEntity(GetHash(entityName));
  Result := (c3^ = ';') and Assigned(entity);
  //nb: increments 'c' only if the entity is found.
  if Result then c := c3 +1 else dec(c);
end;
//------------------------------------------------------------------------------

function ParseQuotedString(var c: PAnsiChar; endC: PAnsiChar;
  out ansi: AnsiString): Boolean;
var
  quote: AnsiChar;
  c2: PAnsiChar;
begin
  quote := c^;
  inc(c);
  c2 := c;
  while (c < endC) and (c^ <> quote) do inc(c);
  Result := (c < endC);
  if not Result then Exit;
  PAnsiCharToAnsiString(c2, c, ansi);
  inc(c);
end;
//------------------------------------------------------------------------------

function IsNumPending(c, endC: PAnsiChar; ignoreComma: Boolean): Boolean;
begin
  Result := false;

  //skip white space +/- single comma
  if ignoreComma then
  begin
    while (c < endC) and (c^ <= space) do inc(c);
    if (c^ = ',') then inc(c);
  end;
  while (c < endC) and (c^ <= ' ') do inc(c);
  if (c = endC) then Exit;

  if (c^ = '-') then inc(c);
  if (c^ = '.') then inc(c);
  Result := (c < endC) and (c^ >= '0') and (c^ <= '9');
end;
//------------------------------------------------------------------------------

function ParseTransform(const transform: AnsiString): TMatrixD;
var
  i: integer;
  c, endC: PAnsiChar;
  c2: AnsiChar;
  word: AnsiString;
  values: array[0..5] of double;
  mat: TMatrixD;
begin
  c := PAnsiChar(transform);
  endC := c + Length(transform);
  Result := IdentityMatrix; //in case of invalid or referenced value

  while ParseNextWord(c, endC, word) do
  begin
    if Length(word) < 5 then Exit;
    if ParseNextChar(c, endC) <> '(' then Exit; //syntax check
    //reset values variables
    for i := 0 to High(values) do values[i] := InvalidD;
    //and since every transform function requires at least one value
    if not ParseNextNum(c, endC, false, values[0]) then Break;
    //now get additional variables
    i := 1;
    while (i < 6) and IsNumPending(c, endC, true) do
    begin
      ParseNextNum(c, endC, true, values[i]);
      inc(i);
    end;
    if ParseNextChar(c, endC) <> ')' then Exit; //syntax check

    mat := IdentityMatrix;

    //scal(e), matr(i)x, tran(s)late, rota(t)e, skew(X), skew(Y)
    case LowerCaseTable[word[5]] of
      'e' : //scalE
        if not IsValid(values[1]) then
          MatrixScale(mat, values[0]) else
            MatrixScale(mat, values[0], values[1]);
      'i' : //matrIx
        if IsValid(values[5]) then
        begin
          mat[0,0] :=  values[0];
          mat[0,1] :=  values[1];
          mat[1,0] :=  values[2];
          mat[1,1] :=  values[3];
          mat[2,0] :=  values[4];
          mat[2,1] :=  values[5];
        end;
      's' : //tranSlateX, tranSlateY & tranSlate
        if Length(word) =10  then
        begin
          c2 := LowerCaseTable[word[10]];
          if c2 = 'x' then
            MatrixTranslate(mat, values[0], 0)
          else if c2 = 'y' then
            MatrixTranslate(mat, 0, values[0]);
        end
        else if IsValid(values[1]) then
          MatrixTranslate(mat, values[0], values[1])
        else
          MatrixTranslate(mat, values[0], 0);
      't' : //rotaTe
        if IsValid(values[2]) then
          MatrixRotate(mat, PointD(values[1],values[2]), DegToRad(values[0]))
        else
          MatrixRotate(mat, NullPointD, DegToRad(values[0]));
       'x' : //skewX
         begin
            MatrixSkew(mat, DegToRad(values[0]), 0);
         end;
       'y' : //skewY
         begin
            MatrixSkew(mat, 0, DegToRad(values[0]));
         end;
    end;
    Result := MatrixMultiply(Result, mat);
  end;
end;
//------------------------------------------------------------------------------

procedure GetSvgFontInfo(const value: AnsiString; var fontInfo: TSVGFontInfo);
var
  c, endC: PAnsiChar;
  hash: Cardinal;
begin
  c := PAnsiChar(value);
  endC := c + Length(value);
  while (c < endC) and SkipBlanks(c, endC) do
  begin
    if c = ';' then
      break
    else if IsNumPending(c, endC, true) then
      ParseNextNum(c, endC, true, fontInfo.size)
    else
    begin
      hash := ParseNextWordHashed(c, endC);
      case hash of
        hSans_045_Serif   : fontInfo.family := ttfSansSerif;
        hSerif            : fontInfo.family := ttfSerif;
        hMonospace        : fontInfo.family := ttfMonospace;
        hBold             : fontInfo.weight := 600;
        hItalic           : fontInfo.italic := sfsItalic;
        hNormal           : 
          begin
            fontInfo.weight := 400;
            fontInfo.italic := sfsNone;
          end;
        hStart            : fontInfo.align := staLeft;
        hMiddle           : fontInfo.align := staCenter;
        hEnd              : fontInfo.align := staRight;
        hline_045_through : fontInfo.decoration := fdStrikeThrough;
        hUnderline        : fontInfo.decoration := fdUnderline;
      end;
    end;
  end;
end;
//------------------------------------------------------------------------------

function HtmlDecode(const html: ansiString): ansistring;
var
  val, len: integer;
  c,ce,endC: PAnsiChar;
begin
  len := Length(html);
  SetLength(Result, len*3);
  c := PAnsiChar(html);
  endC := c + len;
  ce := c;
  len := 1;
  while (ce < endC) and (ce^ <> '&') do
    inc(ce);

  while (ce < endC) do
  begin
    if ce > c then
    begin
      Move(c^, Result[len], ce - c);
      inc(len, ce - c);
    end;
    c := ce; inc(ce);
    while (ce < endC) and (ce^ <> ';') do inc(ce);
    if ce = endC then break;

    val := -1; //assume error
    if (c +1)^ = '#' then
    begin
      val := 0;
      //decode unicode value
      if (c +2)^ = 'x' then
      begin
        inc(c, 3);
        while c < ce do
        begin
          if (c^ >= 'a') and (c^ <= 'f') then
            val := val * 16 + Ord(c^) - 87
          else if (c^ >= 'A') and (c^ <= 'F') then
            val := val * 16 + Ord(c^) - 55
          else if (c^ >= '0') and (c^ <= '9') then
            val := val * 16 + Ord(c^) - 48
          else
          begin
            val := -1;
            break;
          end;
          inc(c);
        end;
      end else
      begin
        inc(c, 2);
        while c < ce do
        begin
          val := val * 10 + Ord(c^) - 48;
          inc(c);
        end;
      end;
    end else
    begin
      //decode html entity ...
      case GetHashCaseSensitive(c, ce - c) of
        {$I html_entity_values.inc}
      end;
    end;

    //convert unicode value to utf8 chars
    //this saves the overhead of multiple ansistring<-->string conversions.
    case val of
      0 .. $7F:
        begin
          result[len] := AnsiChar(val);
          inc(len);
        end;
      $80 .. $7FF:
        begin
          Result[len] := AnsiChar($C0 or (val shr 6));
          Result[len+1] := AnsiChar($80 or (val and $3f));
          inc(len, 2);
        end;
      $800 .. $7FFF:
        begin
          Result[len] := AnsiChar($E0 or (val shr 12));
          Result[len+1] := AnsiChar($80 or ((val shr 6) and $3f));
          Result[len+2] := AnsiChar($80 or (val and $3f));
          inc(len, 3);
        end;
      $10000 .. $10FFFF:
        begin
          Result[len] := AnsiChar($F0 or (val shr 18));
          Result[len+1] := AnsiChar($80 or ((val shr 12) and $3f));
          Result[len+2] := AnsiChar($80 or ((val shr 6) and $3f));
          Result[len+3] := AnsiChar($80 or (val and $3f));
          inc(len, 4);
        end;
      else
      begin
        //ie: error
        Move(c^, Result[len], ce- c +1);
        inc(len, ce - c +1);
      end;
    end;
    inc(ce);
    c := ce;
    while (ce < endC) and (ce^ <> '&') do inc(ce);
  end;
  if (c < endC) and (ce > c) then
  begin
    Move(c^, Result[len], (ce - c));
    inc(len, ce - c);
  end;
  setLength(Result, len -1);
end;
//------------------------------------------------------------------------------

function HexByteToInt(h: AnsiChar): Cardinal;
begin
  case h of
    '0'..'9': Result := Ord(h) - Ord('0');
    'A'..'F': Result := 10 + Ord(h) - Ord('A');
    'a'..'f': Result := 10 + Ord(h) - Ord('a');
    else Result := 0;
  end;
end;
//------------------------------------------------------------------------------

function IsFraction(val: double): Boolean;
begin
  Result := (val <> 0) and (val > -1) and (val < 1);
end;
//------------------------------------------------------------------------------

function AnsiStringToColor32(const value: AnsiString; var color: TColor32): Boolean;
var
  i, len  : integer;
  j       : Cardinal;
  clr     : TColor32;
  alpha   : Byte;
  vals    : array[0..3] of double;
  mus     :  array[0..3] of TMeasureUnit;
  c, endC : PAnsiChar;
begin
  Result := false;
  len := Length(value);
  if len < 3 then Exit;
  c := PAnsiChar(value);
  endC := c + len;

  if (color = clInvalid) or (color = clCurrent) or (color = clNone32) then
    alpha := 255 else
    alpha := color shr 24;

  if Match(c, 'rgb') then
  begin
    endC := c + len;
    inc(c, 3);
    if (c^ = 'a') then inc(c);
    if (ParseNextChar(c, endC) <> '(') or
      not ParseNextNumEx(c, endC, false, vals[0], mus[0]) or
      not ParseNextNumEx(c, endC, true, vals[1], mus[1]) or
      not ParseNextNumEx(c, endC, true, vals[2], mus[2]) then Exit;
    for i := 0 to 2 do
      if mus[i] = muPercent then
        vals[i] := vals[i] * 255 / 100;

    if ParseNextNumEx(c, endC, true, vals[3], mus[3]) then
      alpha := 255 else //stops further alpha adjustment
      vals[3] := 255;
    if ParseNextChar(c, endC) <> ')' then Exit;
    for i := 0 to 3 do if IsFraction(vals[i]) then
      vals[i] := vals[i] * 255;
    color := ClampByte(Round(vals[3])) shl 24 +
      ClampByte(Round(vals[0])) shl 16 +
      ClampByte(Round(vals[1])) shl 8 +
      ClampByte(Round(vals[2]));
  end
  else if (c^ = '#') then           //#RRGGBB or #RGB
  begin
    if (len = 7) then
    begin
      clr := $0;
      for i := 1 to 6 do
      begin
        inc(c);
        clr := clr shl 4 + HexByteToInt(c^);
      end;
      clr := clr or $FF000000;
    end
    else if (len = 4) then
    begin
      clr := $0;
      for i := 1 to 3 do
      begin
        inc(c);
        j := HexByteToInt(c^);
        clr := clr shl 4 + j;
        clr := clr shl 4 + j;
      end;
      clr := clr or $FF000000;
    end
    else
      Exit;
    color :=  clr;
  end else                                        //color name lookup
  begin
    i := ColorConstList.IndexOf(string(value));
    if i < 0 then Exit;
    color := Cardinal(ColorConstList.Objects[i]);
  end;

  //and in case the opacity has been set before the color
  if (alpha < 255) then
    color := (color and $FFFFFF) or alpha shl 24;
  Result := true;
end;
//------------------------------------------------------------------------------

function MakeDashArray(const dblArray: TArrayOfDouble; scale: double): TArrayOfInteger;
var
  i, len: integer;
  dist: double;
begin
  dist := 0;
  len := Length(dblArray);
  SetLength(Result, len);
  for i := 0 to len -1 do
  begin
    Result[i] := Ceil(dblArray[i] * scale);
    dist := Result[i] + dist;
  end;
  if dist = 0 then
    Result := nil
  else if len = 1 then
  begin
    SetLength(Result, 2);
    Result[1] := Result[0];
  end;
end;
//------------------------------------------------------------------------------

function PeekNextChar(var c: PAnsiChar; endC: PAnsiChar): AnsiChar;
begin
  if not SkipBlanks(c, endC) then
    Result := #0 else
    Result := c^;
end;
//------------------------------------------------------------------------------

procedure ParseStyleElementContent(const value: TAnsi;
  stylesList: TClassStylesList);
var
  len, cap: integer;
  names: array of string;

  procedure AddName(const name: string);
  begin
    if len = cap then
    begin
      cap := cap + buffSize;
      SetLength(names, cap);
    end;
    names[len] := name;
    inc(len);
  end;

var
  i: integer;
  aclassName: TAnsi;
  aStyle: TAnsi;
  c, endC: PAnsiChar;
begin
  //https://oreillymedia.github.io/Using_SVG/guide/style.html

  stylesList.Clear;
  if value.len = 0 then Exit;

  len := 0; cap := 0;
  c := value.text;
  endC := c + value.len;

  SkipBlanks(c, endC);
  if Match(c, '<![cdata[') then inc(c, 9);

  while SkipStyleBlanks(c, endC) and
    CharInSet(LowerCaseTable[PeekNextChar(c, endC)], ['.', '#', 'a'..'z']) do
  begin
    //get one or more class names for each pending style
    aclassName.text := c;
    aclassName.len := ParseNameLength(c, endC);

    AddName(Lowercase(String(aclassName.AsAnsiString)));
    if PeekNextChar(c, endC) = ',' then
    begin
      inc(c);
      Continue;
    end;
    if len = 0 then break;
    SetLength(names, len); //ie no more comma separated names

    //now get the style
    if PeekNextChar(c, endC) <> '{' then Break;
    inc(c);
    aStyle.text := c;
    while (c < endC) and (c^ <> '}') do inc(c);
    if (c = endC) then break;
    aStyle.len := c - aStyle.text;

    //finally, for each class name add (or append) this style
    for i := 0 to High(names) do
      stylesList.AddAppendStyle(names[i], aStyle.AsAnsiString);
    names := nil;
    len := 0; cap := 0;
    inc(c);
  end;
end;

//------------------------------------------------------------------------------
// TSvg classes 
//------------------------------------------------------------------------------

constructor TParserBaseEl.Create(owner: TSvgParser);
begin
{$IFDEF XPLAT_GENERICS}
  attribs := TList<PAttrib>.Create;
{$ELSE}
  attribs := TList.Create;
{$ENDIF}
  selfClosed := true;
  Self.owner := owner;
end;
//------------------------------------------------------------------------------

destructor TParserBaseEl.Destroy;
begin
  Clear;
  attribs.Free;
  inherited;
end;
//------------------------------------------------------------------------------

procedure TParserBaseEl.Clear;
var
  i: integer;
begin
  for i := 0 to attribs.Count -1 do
    Dispose(PAttrib(attribs[i]));
  attribs.Clear;
end;
//------------------------------------------------------------------------------

function TParserBaseEl.ParseHeader(var c: PAnsiChar; endC: PAnsiChar): Boolean;
var
  className, style: AnsiString;
begin
  SkipBlanks(c, endC);
  name.text := c;
  name.len := ParseNameLength(c, endC);

  //load the class's style (ie undotted style) if found.
  className := name.AsAnsiString;
  style := owner.classStyles.GetStyle(classname);
  if style <> '' then ParseStyleAttribute(style);

  Result := ParseAttributes(c, endC);
end;
//------------------------------------------------------------------------------

function TParserBaseEl.ParseAttribName(var c: PAnsiChar;
  endC: PAnsiChar; attrib: PAttrib): Boolean;
var
  c2: PAnsiChar;
  //attribName: AnsiString;
begin
  Result := SkipBlanks(c, endC);
  if not Result then Exit;
  c2 := c;
  ParseNameLength(c, endC);
  PAnsiCharToAnsiString(c2, c, attrib.Name);
  attrib.hash := GetHash(attrib.Name);
end;
//------------------------------------------------------------------------------

function TParserBaseEl.ParseAttribValue(var c: PAnsiChar;
  endC: PAnsiChar; attrib: PAttrib): Boolean;
var
  quoteChar : AnsiChar;
  c2, c3: PAnsiChar;
begin
  Result := ParseNextChar(c, endC) = '=';
  if not Result then Exit;
  quoteChar := ParseQuoteChar(c, endC);
  if quoteChar = #0 then Exit;
  //trim leading and trailing spaces
  while (c < endC) and (c^ <= space) do inc(c);
  c2 := c;
  while (c < endC) and (c^ <> quoteChar) do inc(c);
  c3 := c;
  while (c3 > c2) and ((c3 -1)^ <= space) do 
    dec(c3);
  PAnsiCharToAnsiString(c2, c3, attrib.value);
  inc(c); //skip end quote
end;
//------------------------------------------------------------------------------

function TParserBaseEl.ParseAttributes(var c: PAnsiChar; endC: PAnsiChar): Boolean;
var
  attrib, styleAttrib, classAttrib, idAttrib: PAttrib;
  ansi: AnsiString;
  sc: Boolean;
begin
  Result := false;
  styleAttrib := nil;  classAttrib := nil;  idAttrib := nil;

  while SkipBlanks(c, endC) do
  begin
    if CharInSet(c^, ['/', '?', '>']) then
    begin
      if (c^ <> '>') then
      begin
        inc(c);
        if (c^ <> '>') then Exit; //error
        selfClosed := true;
      end;
      inc(c);
      Result := true;
      break;
    end
    else if (c^ = 'x') and Match(c, 'xml:') then
    begin
      inc(c, 4); //ignore xml: prefixes
    end;

    New(attrib);
    if not ParseAttribName(c, endC, attrib) or
      not ParseAttribValue(c, endC, attrib) then
    begin
      Dispose(attrib);
      Exit;
    end;

    attribs.Add(attrib);    
    case attrib.hash of
      hId     : idAttrib := attrib;
      hClass  : classAttrib := attrib;
      hStyle  : styleAttrib := attrib;
    end;    
  end;

  if assigned(classAttrib) then 
    with classAttrib^ do
    begin
      //get the 'dotted' classname
      ansi := '.' + value;
      //get the style definition
      ansi := owner.classStyles.GetStyle(ansi);
      if ansi <> '' then ParseStyleAttribute(ansi);
    end;

  if assigned(styleAttrib) then
    ParseStyleAttribute(styleAttrib.value);
    
  if assigned(idAttrib) then
  begin
    //get the 'hashed' classname
    ansi := '#' + idAttrib.value;
    //get the style definition
    ansi := owner.classStyles.GetStyle(ansi);
    if ansi <> '' then ParseStyleAttribute(ansi);
  end;
  
end;
//------------------------------------------------------------------------------

procedure TParserBaseEl.ParseStyleAttribute(const style: AnsiString);
var
  styleName, styleVal: TAnsi;
  c, endC: PAnsiChar;
  attrib: PAttrib;
begin
  //there are 4 ways to load styles (in ascending precedence) -
  //1. a class element style (called during element contruction)
  //2. a non-element class style (called via a class attribute)
  //3. an inline style (called via a style attribute)
  //4. an id specific class style

  c := PAnsiChar(style);
  endC := c + Length(style);
  while SkipStyleBlanks(c, endC) do
  begin
    styleName.text := c;
    styleName.len := ParseStyleNameLen(c, endC);
    if styleName.len = 0 then Break;

    if (ParseNextChar(c, endC) <> ':') or  //syntax check
      not SkipBlanks(c,endC) then Break;

    styleVal.text := c;
    inc(c);
    while (c < endC) and (c^ <> ';') do inc(c);
    styleVal.len := c - styleVal.text;
    AnsiTrim(styleVal);
    inc(c);

    new(attrib);
    attrib.name := styleName.AsAnsiString;
    attrib.value := styleVal.AsAnsiString;
    attrib.hash := GetHash(attrib.name);
    attribs.Add(attrib);
  end;
end;
//------------------------------------------------------------------------------

procedure TDocTypeEl.SkipWord(var c, endC: PAnsiChar);
begin
  while (c < endC) and (c^ > space) do inc(c);
  inc(c);
end;
//------------------------------------------------------------------------------

function TDocTypeEl.ParseEntities(var c, endC: PAnsiChar): Boolean;
var
  attrib: PAttrib;
begin
  attrib := nil;
  inc(c); //skip opening '['
  while (c < endC) and SkipBlanks(c, endC) do
  begin
    if (c^ = ']') then break
    else if not Match(c, '<!entity') then
    begin
      while c^ > space do inc(c); //skip word.
      Continue;
    end;
    inc(c, 8);
    new(attrib);
    if not ParseAttribName(c, endC, attrib) then break;
    SkipBlanks(c, endC);
    if not (c^ in [quote, dquote]) then break;
    if not ParseQuotedString(c, endC, attrib.value) then break;
    attribs.Add(attrib);
    attrib := nil;
    SkipBlanks(c, endC);
    if c^ <> '>' then break;
    inc(c); //skip entity's trailing '>'
  end;
  if Assigned(attrib) then Dispose(attrib);
  Result := (c < endC) and (c^ = ']');
  inc(c);
end;
//------------------------------------------------------------------------------

function TDocTypeEl.ParseAttributes(var c: PAnsiChar; endC: PAnsiChar): Boolean;
var
  dummy : AnsiString;
begin
  while SkipBlanks(c, endC) do
  begin
    //we're currently only interested in ENTITY declarations
    case c^ of
      '[': ParseEntities(c, endC);
      '"', '''': ParseQuotedString(c, endC, dummy);
      '>': break;
      else SkipWord(c, endC);
    end;
  end;
  Result := (c < endC) and (c^ = '>');
  inc(c);
end;
//------------------------------------------------------------------------------

constructor TSvgEl.Create(owner: TSvgParser);
begin
  inherited Create(owner);
{$IFDEF XPLAT_GENERICS}
  childs := TList<TSvgEl>.Create;
{$ELSE}
  childs := TList.Create;
{$ENDIF}
  selfClosed := false;
end;
//------------------------------------------------------------------------------

destructor TSvgEl.Destroy;
begin
  inherited;
  childs.Free;
end;
//------------------------------------------------------------------------------

procedure TSvgEl.Clear;
var
  i: integer;
begin
  for i := 0 to childs.Count -1 do
    TSvgEl(childs[i]).free;
  childs.Clear;
  inherited;
end;
//------------------------------------------------------------------------------

function TSvgEl.ParseHeader(var c: PAnsiChar; endC: PAnsiChar): Boolean;
begin
  Result := inherited;
  if Result then
    hash := GetHash(name.AsAnsiString);
end;
//------------------------------------------------------------------------------

function TSvgEl.ParseContent(var c: PAnsiChar; endC: PAnsiChar): Boolean;
var
  child: TSvgEl;
  entity: PAttrib;
  tmpC, tmpEndC: PAnsiChar;
begin
  Result := false;
  while SkipBlanks(c, endC) do
  begin
    if (c^ = '<') then
    begin
      inc(c);
      case c^ of
        '!':
          begin
            if Match(c, '!--') then             //start comment
            begin
              inc(c, 3);
              while (c < endC) and ((c^ <> '-') or
                not Match(c, '-->')) do inc(c); //end comment
              inc(c, 3);
            end else
            begin
              //it's quite likely <![CDATA[
              text.text := c - 1;
              while (c < endC) and (c^ <> '<') do inc(c);
              text.len := c - text.text;
              //and if <style><![CDATA[ ... then load the styles too
              if (hash = hStyle) then
                ParseStyleElementContent(text, owner.classStyles);
            end;
          end;
        '/', '?':
          begin
            //element closing tag
            inc(c);
            if Match(c, name) then
            begin
              inc(c, name.len);
              //very rarely there's a space before '>'
              SkipBlanks(c, endC);
              Result := c^ = '>';
              inc(c);
            end;
            Exit;
          end;
        else
        begin
          //starting a new element
          child := TSvgEl.Create(owner);
          childs.Add(child);
          if not child.ParseHeader(c, endC) then break;
          if not child.selfClosed then
              child.ParseContent(c, endC);
        end;
      end;
    end
    else if c^ = '>' then
    begin
      break; //oops! something's wrong
    end
    else if (c^ = '&') and IsKnownEntity(owner, c, endC, entity) then
    begin
      tmpC := PAnsiChar(entity.value);
      tmpEndC := tmpC + Length(entity.value);
      ParseContent(tmpC, tmpEndC);
    end
    else if (hash = hTSpan) or (hash = hText) or (hash = hTextPath) then
    begin
      //text content: and because text can be mixed with one or more
      //<tspan> elements we need to create sub-elements for each text block.
      //And <tspan> elements can even have <tspan> sub-elements.
      tmpC := c;
      //preserve a leading space
      if (tmpC -1)^ = space then dec(tmpC);
      while (c < endC) and (c^ <> '<') do inc(c);
      if (hash = hTextPath) then
      begin
        text.text := tmpC;
        text.len := c - tmpC;
      end else
      begin
        child := TSvgEl.Create(owner);
        childs.Add(child);
        child.text.text := tmpC;
        child.text.len := c - tmpC;
      end;
    end else
    begin
      tmpC := c;
      while (c < endC) and (c^ <> '<') do inc(c);
      text.text := tmpC;
      text.len := c - tmpC;

      //if <style> element then load styles into owner.classStyles
      if (hash = hStyle) then
        ParseStyleElementContent(text, owner.classStyles);
    end;
  end;
end;
//------------------------------------------------------------------------------

constructor TSvgParser.Create;
begin
  classStyles := TClassStylesList.Create;
  svgStream   := TMemoryStream.Create;
  xmlHeader   := TParserBaseEl.Create(Self);
  docType     := TDocTypeEl.Create(Self);
{$IFDEF XPLAT_GENERICS}
  entities    := TList<TSvgEl>.Create;
{$ELSE}
  entities    := TList.Create;
{$ENDIF}
  svgTree     := nil;
end;
//------------------------------------------------------------------------------

destructor TSvgParser.Destroy;
begin
  Clear;
  svgStream.Free;
  xmlHeader.Free;
  docType.Free;
  entities.Free;
  classStyles.Free;
end;
//------------------------------------------------------------------------------

procedure TSvgParser.Clear;
begin
  classStyles.Clear;
  svgStream.Clear;
  xmlHeader.Clear;
  docType.Clear;
  entities.Clear;
  FreeAndNil(svgTree);
end;
//------------------------------------------------------------------------------

function TSvgParser.FindEntity(hash: Cardinal): PAttrib;
var
  i: integer;
begin
  //there are usually so few, that there seems little point sorting etc.
  for i := 0 to docType.attribs.Count -1 do
    if PAttrib(docType.attribs[i]).hash = hash then
    begin
      Result := PAttrib(docType.attribs[i]);
      Exit;
    end;
  Result := nil;
end;
//------------------------------------------------------------------------------

function TSvgParser.LoadFromFile(const filename: string): Boolean;
begin
  try
    svgStream.LoadFromFile(filename);
    Result := true;
    ParseStream;
  except
    Result := false;
  end;
end;
//------------------------------------------------------------------------------

function TSvgParser.LoadFromStream(stream: TStream): Boolean;
begin
  try
    svgStream.LoadFromStream(stream);
    Result := true;
    ParseStream;
  except
    Result := false;
  end;
end;
//------------------------------------------------------------------------------

procedure TSvgParser.ParseStream;
var
  c, endC: PAnsiChar;
begin
  c := svgStream.Memory;
  endC := c + svgStream.Size;
  SkipBlanks(c, endC);
  if Match(c, '<?xml') then
  begin
    inc(c, 2); //todo: accommodate space after '<' eg using sMatchEl function
    if not xmlHeader.ParseHeader(c, endC) then Exit;
    SkipBlanks(c, endC);
  end;
  if Match(c, '<!doctype') then
  begin
    inc(c, 2);
    if not docType.ParseHeader(c, endC) then Exit;
  end;
  while SkipBlanks(c, endC) do
  begin
    if (c^ = '<') and Match(c, '<svg') then
    begin
      inc(c);
      svgTree := TSvgEl.Create(self);
      if svgTree.ParseHeader(c, endC) and
        not svgTree.selfClosed then
          svgTree.ParseContent(c, endC);
      break;
    end;
    inc(c);
  end;
end;

//------------------------------------------------------------------------------
// TDpath
//------------------------------------------------------------------------------

function TDpath.GetFlattenedPath(scalePending: double): TPathD;
var
  i,j, pathLen, pathCap: integer;
  currPt, radii, pt2, pt3, pt4: TPointD;
  lastQCtrlPt, lastCCtrlPt: TPointD;
  arcFlag, sweepFlag: integer;
  angle, arc1, arc2, bezTolerance: double;
  rec: TRectD;
  path2: TPathD;

  procedure AddPoint(const pt: TPointD);
  begin
    if pathLen = pathCap then
    begin
      pathCap := pathCap + buffSize;
      SetLength(Result, pathCap);
    end;
    Result[pathLen] := pt;
    currPt := pt;
    inc(pathLen);
  end;

  procedure AddPath(const p: TPathD);
  var
    i, pLen: integer;
  begin
    pLen := Length(p);
    if pLen = 0 then Exit;
    currPt := p[pLen -1];
    if pathLen + pLen >= pathCap then
    begin
      pathCap := pathLen + pLen + buffSize;
      SetLength(Result, pathCap);
    end;
    for i := 0 to pLen -1 do
    begin
      Result[pathLen] := p[i];
      inc(pathLen);
    end;
  end;

begin
  if scalePending <= 0 then scalePending := 1.0;

  bezTolerance := BezierTolerance / scalePending;
  pathLen := 0; pathCap := 0;
  lastQCtrlPt := InvalidPointD;
  lastCCtrlPt := InvalidPointD;
  AddPoint(firstPt);
  for i := 0 to High(segs) do
    with segs[i] do
    begin
      case segType of
        dsLine:
          if High(vals) > 0 then
            for j := 0 to High(vals) div 2 do
              AddPoint(PointD(vals[j*2], vals[j*2 +1]));
        dsHorz:
          for j := 0 to High(vals) do
            AddPoint(PointD(vals[j], currPt.Y));
        dsVert:
          for j := 0 to High(vals) do
            AddPoint(PointD(currPt.X, vals[j]));
        dsArc:
          if High(vals) > 5 then
            for j := 0 to High(vals) div 7 do
            begin
              radii.X   := vals[j*7];
              radii.Y   := vals[j*7 +1];
              angle     := DegToRad(vals[j*7 +2]);
              arcFlag   := Round(vals[j*7 +3]);
              sweepFlag := Round(vals[j*7 +4]);
              pt2.X := vals[j*7 +5];
              pt2.Y := vals[j*7 +6];

              GetSvgArcInfo(currPt, pt2, radii, angle,
                arcFlag <> 0, sweepFlag <> 0, arc1, arc2, rec);
              if (sweepFlag = 0)  then
              begin
                path2 := Arc(rec, arc2, arc1, scalePending);
                path2 := ReversePath(path2);
              end else
                path2 := Arc(rec, arc1, arc2, scalePending);
              path2 := RotatePath(path2, rec.MidPoint, angle);
              AddPath(path2);
            end;
        dsQBez:
          if High(vals) > 2 then
            for j := 0 to High(vals) div 4 do
            begin
              pt2.X := vals[j*4];
              pt2.Y := vals[j*4 +1];
              pt3.X := vals[j*4 +2];
              pt3.Y := vals[j*4 +3];
              lastQCtrlPt := pt2;
              path2 := FlattenQBezier(currPt, pt2, pt3, bezTolerance);
              AddPath(path2);
            end;
        dsQSpline:
          if High(vals) > 0 then
            for j := 0 to High(vals) div 2 do
            begin
              if IsValid(lastQCtrlPt) then
                pt2 := ReflectPoint(lastQCtrlPt, currPt) else
                pt2 := currPt;
              pt3.X := vals[j*2];
              pt3.Y := vals[j*2 +1];
              lastQCtrlPt := pt2;
              path2 := FlattenQBezier(currPt, pt2, pt3, bezTolerance);
              AddPath(path2);
            end;
        dsCBez:
          if High(vals) > 4 then
            for j := 0 to High(vals) div 6 do
            begin
              pt2.X := vals[j*6];
              pt2.Y := vals[j*6 +1];
              pt3.X := vals[j*6 +2];
              pt3.Y := vals[j*6 +3];
              pt4.X := vals[j*6 +4];
              pt4.Y := vals[j*6 +5];
              lastCCtrlPt := pt3;
              path2 := FlattenCBezier(currPt, pt2, pt3, pt4, bezTolerance);
              AddPath(path2);
            end;
        dsCSpline:
          if High(vals) > 2 then
            for j := 0 to High(vals) div 4 do
            begin
              if IsValid(lastCCtrlPt) then
                pt2 := ReflectPoint(lastCCtrlPt, currPt) else
                pt2 := currPt;
              pt3.X := vals[j*4];
              pt3.Y := vals[j*4 +1];
              pt4.X := vals[j*4 +2];
              pt4.Y := vals[j*4 +3];
              lastCCtrlPt := pt3;
              path2 := FlattenCBezier(currPt, pt2, pt3, pt4, bezTolerance);
              AddPath(path2);
            end;
      end;
    end;
  SetLength(Result, pathLen);
end;
//------------------------------------------------------------------------------

function TDpath.GetSimplePath: TPathD;
var
  i,j, pathLen, pathCap: integer;
  currPt, radii, pt2, pt3, pt4: TPointD;
  arcFlag, sweepFlag: integer;
  angle, arc1, arc2, bezTolerance: double;
  rec: TRectD;
  path2: TPathD;

  procedure AddPoint(const pt: TPointD);
  begin
    if pathLen = pathCap then
    begin
      pathCap := pathCap + buffSize;
      SetLength(Result, pathCap);
    end;
    Result[pathLen] := pt;
    currPt := pt;
    inc(pathLen);
  end;

begin
  pathLen := 0; pathCap := 0;
  AddPoint(firstPt);
  for i := 0 to High(segs) do
    with segs[i] do
    begin
      case segType of
        dsLine:
          if High(vals) > 0 then
            for j := 0 to High(vals) div 2 do
              AddPoint(PointD(vals[j*2], vals[j*2 +1]));
        dsHorz:
          for j := 0 to High(vals) do
            AddPoint(PointD(vals[j], currPt.Y));
        dsVert:
          for j := 0 to High(vals) do
            AddPoint(PointD(currPt.X, vals[j]));
        dsArc:
          if High(vals) > 5 then
            for j := 0 to High(vals) div 7 do
              AddPoint(PointD(vals[j*7 +5], vals[j*7 +6]));
        dsQBez:
          if High(vals) > 2 then
            for j := 0 to High(vals) div 4 do
            begin
              pt2.X := vals[j*4];
              pt2.Y := vals[j*4 +1];
              AddPoint(PointD(vals[j*4 +2], vals[j*4 +3]));
            end;
        dsQSpline:
          if High(vals) > 0 then
            for j := 0 to High(vals) div 2 do
              AddPoint(PointD(vals[j*2 +1], vals[j*2 +1]));
        dsCBez:
          if High(vals) > 4 then
            for j := 0 to High(vals) div 6 do
              AddPoint(PointD(vals[j*6 +4], vals[j*6 +5]));
        dsCSpline:
          if High(vals) > 2 then
            for j := 0 to High(vals) div 4 do
              AddPoint(PointD(vals[j*4 +2], vals[j*4 +3]));
      end;
    end;
  SetLength(Result, pathLen);
end;
//------------------------------------------------------------------------------

function TDpath.GetBounds: TRectD;
var
  i,j, pathLen, pathCap: integer;
  currPt, radii, pt2, pt3, pt4: TPointD;
  lastQCtrlPt, lastCCtrlPt: TPointD;
  arcFlag, sweepFlag: integer;
  angle, arc1, arc2: double;
  rec: TRectD;
  path2, path3: TPathD;

  procedure AddPoint(const pt: TPointD);
  begin
    if pathLen = pathCap then
    begin
      pathCap := pathCap + buffSize;
      SetLength(path2, pathCap);
    end;
    path2[pathLen] := pt;
    currPt := pt;
    inc(pathLen);
  end;

  procedure AddPath(const p: TPathD);
  var
    i, pLen: integer;
  begin
    pLen := Length(p);
    if pLen = 0 then Exit;
    currPt := p[pLen -1];
    if pathLen + pLen >= pathCap then
    begin
      pathCap := pathLen + pLen + buffSize;
      SetLength(path2, pathCap);
    end;
    for i := 0 to pLen -1 do
    begin
      path2[pathLen] := p[i];
      inc(pathLen);
    end;
  end;

begin
  path2 := nil;
  pathLen := 0; pathCap := 0;
  lastQCtrlPt := InvalidPointD;
  lastCCtrlPt := InvalidPointD;
  AddPoint(firstPt);
  for i := 0 to High(segs) do
    with segs[i] do
    begin
      case segType of
        dsLine:
          if High(vals) > 0 then
            for j := 0 to High(vals) div 2 do
              AddPoint(PointD(vals[j*2], vals[j*2 +1]));
        dsHorz:
          for j := 0 to High(vals) do
            AddPoint(PointD(vals[j], currPt.Y));
        dsVert:
          for j := 0 to High(vals) do
            AddPoint(PointD(currPt.X, vals[j]));
        dsArc:
          if High(vals) > 5 then
            for j := 0 to High(vals) div 7 do
            begin
              radii.X   := vals[j*7];
              radii.Y   := vals[j*7 +1];
              angle     := DegToRad(vals[j*7 +2]);
              arcFlag   := Round(vals[j*7 +3]);
              sweepFlag := Round(vals[j*7 +4]);
              pt2.X := vals[j*7 +5];
              pt2.Y := vals[j*7 +6];

              GetSvgArcInfo(currPt, pt2, radii, angle,
                arcFlag <> 0, sweepFlag <> 0, arc1, arc2, rec);
              if (sweepFlag = 0)  then
              begin
                path3 := Arc(rec, arc2, arc1, 1);
                path3 := ReversePath(path3);
              end else
                path3 := Arc(rec, arc1, arc2, 1);
              path3 := RotatePath(path3, rec.MidPoint, angle);
              AddPath(path3);
            end;
        dsQBez:
          if High(vals) > 2 then
            for j := 0 to High(vals) div 4 do
            begin
              pt2.X := vals[j*4];
              pt2.Y := vals[j*4 +1];
              pt3.X := vals[j*4 +2];
              pt3.Y := vals[j*4 +3];
              lastQCtrlPt := pt2;
              path3 := FlattenQBezier(currPt, pt2, pt3, 1);
              AddPath(path3);
            end;
        dsQSpline:
          if High(vals) > 0 then
            for j := 0 to High(vals) div 2 do
            begin
              if IsValid(lastQCtrlPt) then
                pt2 := ReflectPoint(lastQCtrlPt, currPt) else
                pt2 := currPt;
              pt3.X := vals[j*2];
              pt3.Y := vals[j*2 +1];
              lastQCtrlPt := pt2;
              path3 := FlattenQBezier(currPt, pt2, pt3, 1);
              AddPath(path3);
            end;
        dsCBez:
          if High(vals) > 4 then
            for j := 0 to High(vals) div 6 do
            begin
              pt2.X := vals[j*6];
              pt2.Y := vals[j*6 +1];
              pt3.X := vals[j*6 +2];
              pt3.Y := vals[j*6 +3];
              pt4.X := vals[j*6 +4];
              pt4.Y := vals[j*6 +5];
              lastCCtrlPt := pt3;
              path3 := FlattenCBezier(currPt, pt2, pt3, pt4, 1);
              AddPath(path3);
            end;
        dsCSpline:
          if High(vals) > 2 then
            for j := 0 to High(vals) div 4 do
            begin
              if IsValid(lastCCtrlPt) then
                pt2 := ReflectPoint(lastCCtrlPt, currPt) else
                pt2 := currPt;
              pt3.X := vals[j*4];
              pt3.Y := vals[j*4 +1];
              pt4.X := vals[j*4 +2];
              pt4.Y := vals[j*4 +3];
              lastCCtrlPt := pt3;
              path3 := FlattenCBezier(currPt, pt2, pt3, pt4, 1);
              AddPath(path3);
            end;
      end;
    end;
  SetLength(path2, pathLen);
  Result := GetBoundsD(path2);
end;
//------------------------------------------------------------------------------

function ConvertValue(const value: TValue;
  scale: double; fontSize: double): double;
const
  mm  = 96 / 25.4;
  cm  = 96 / 2.54;
  rad = 180 / PI;
  pt  = 4 / 3;
begin
  if fontSize = 0 then fontSize := 96;

  //https://oreillymedia.github.io/Using_SVG/guide/units.html
  //todo: still lots of units to support (eg times for animation)
  with value do
    if not IsValid or (rawVal = 0) then
      Result := 0
    else
      case value.mu of
        muUndefined:
          if (Abs(rawVal) < pcBelow) then
            Result := rawVal * scale else
            Result := rawVal;
        muPercent:
          Result := rawVal * 0.01 * scale;
        muRadian:
          Result := rawVal * rad;
        muInch:
          Result := rawVal * 96;
        muCm:
          Result := rawVal * cm;
        muMm:
          Result := rawVal * mm;
        muEm:
          Result := rawVal * fontSize;
        muEx:
          Result := rawVal * fontSize * 0.5;
        muPica:
          Result := rawVal * 16;
        muPt:
          Result := rawVal * pt;
        else
          Result := rawVal;
      end;
end;

//------------------------------------------------------------------------------
// TValue
//------------------------------------------------------------------------------

procedure TValue.Init(asPercentBelow: double);
begin
  rawVal  := InvalidD;
  mu      := muUndefined;
  pcBelow := asPercentBelow;
end;
//------------------------------------------------------------------------------

procedure TValue.SetValue(val: double; measureUnit: TMeasureUnit);
begin
  rawVal  := val;
  mu      := measureUnit;
end;
//------------------------------------------------------------------------------

function TValue.GetValue(scale: double; fontSize: double): double;
begin
  Result := ConvertValue(self, scale, fontSize);
end;
//------------------------------------------------------------------------------

function TValue.GetValueX(const scale: double; fontSize: double): double;
begin
  Result := ConvertValue(self, scale, fontSize);
end;
//------------------------------------------------------------------------------

function TValue.GetValueY(const scale: double; fontSize: double): double;
begin
  Result := ConvertValue(self, scale, fontSize);
end;
//------------------------------------------------------------------------------

function TValue.GetValueXY(const scaleRec: TRectD; fontSize: double): double;
begin
  //https://www.w3.org/TR/SVG11/coords.html#Units
  Result := ConvertValue(self,
    Hypot(scaleRec.Width, scaleRec.Height)/sqrt2, fontSize);
end;
//------------------------------------------------------------------------------

function TValue.IsValid: Boolean;
begin
  Result := Image32_Vector.IsValid(rawVal);
end;
//------------------------------------------------------------------------------

function TValue.IsPercent: Boolean;
begin
  case mu of
    muUndefined: Result := Abs(rawVal) < pcBelow;
    muPercent: Result := True;
    else Result := False;
  end;
end;

//------------------------------------------------------------------------------
// TValuePt
//------------------------------------------------------------------------------

procedure TValuePt.Init(asPercentBelow: double);
begin
  X.Init(asPercentBelow);
  Y.Init(asPercentBelow);
end;
//------------------------------------------------------------------------------

function TValuePt.GetPoint(const scaleRec: TRectD; fontSize: double): TPointD;
begin
  Result.X := X.GetValueX(scaleRec.Width, fontSize);
  Result.Y := Y.GetValueY(scaleRec.Height, fontSize);
end;
//------------------------------------------------------------------------------

function TValuePt.IsValid: Boolean;
begin
  Result := X.IsValid and Y.IsValid;
end;

//------------------------------------------------------------------------------
// TValueRec
//------------------------------------------------------------------------------

procedure TValueRecWH.Init(asPercentBelow: double);
begin
  left.Init(asPercentBelow);
  top.Init(asPercentBelow);
  width.Init(asPercentBelow);
  height.Init(asPercentBelow);
end;
//------------------------------------------------------------------------------

function TValueRecWH.GetRectD(const scaleRec: TRectD; fontSize: double): TRectD;
begin
  with GetRectWH(scaleRec, fontSize) do
  begin
    Result.Left :=Left;
    Result.Top := Top;
    Result.Right := Left + Width;
    Result.Bottom := Top + Height;
  end;
end;
//------------------------------------------------------------------------------

function TValueRecWH.GetRectWH(const scaleRec: TRectD; fontSize: double): TRectWH;
begin
  if not left.IsValid then
    Result.Left := 0 else
    Result.Left := left.GetValueX(scaleRec.Width, fontSize);

  if not top.IsValid then
    Result.Top := 0 else
    Result.Top := top.GetValueY(scaleRec.Height, fontSize);

  Result.Width := width.GetValueX(scaleRec.Width, fontSize);
  Result.Height := height.GetValueY(scaleRec.Height, fontSize);
end;
//------------------------------------------------------------------------------

function TValueRecWH.IsValid: Boolean;
begin
  Result := width.IsValid and height.IsValid;
end;
//------------------------------------------------------------------------------

function TValueRecWH.IsEmpty: Boolean;
begin
  Result := (width.rawVal <= 0) or (height.rawVal <= 0);
end;

//------------------------------------------------------------------------------
// TClassStylesList
//------------------------------------------------------------------------------

constructor TClassStylesList.Create;
begin
  fList := TStringList.Create;
  fList.Duplicates := dupIgnore;
  fList.CaseSensitive := false;
  fList.Sorted := True;
end;
//------------------------------------------------------------------------------

destructor TClassStylesList.Destroy;
begin
  Clear;
  fList.Free;
  inherited Destroy;
end;
//------------------------------------------------------------------------------

function TClassStylesList.AddAppendStyle(const classname: string; const ansi: AnsiString): integer;
var
  i: integer;
  sr: PAnsStringiRec;
begin
  Result := fList.IndexOf(classname);
  if (Result >= 0) then
  begin
    sr := PAnsStringiRec(fList.Objects[Result]);
    i := Length(sr.ansi);
    if sr.ansi[i] <> ';' then
      sr.ansi := sr.ansi + ';' + ansi else
      sr.ansi := sr.ansi + ansi;
  end else
  begin
    new(sr);
    sr.ansi := ansi;
    Result := fList.AddObject(classname, Pointer(sr));
  end;
end;
//------------------------------------------------------------------------------

function TClassStylesList.GetStyle(const classname: AnsiString): AnsiString;
var
  i: integer;
begin
  SetLength(Result, 0);
  i := fList.IndexOf(string(className));
  if i >= 0 then
    Result := PAnsStringiRec(fList.objects[i]).ansi;
end;
//------------------------------------------------------------------------------

procedure TClassStylesList.Clear;
var
  i: integer;
begin
  for i := 0 to fList.Count -1 do
    Dispose(PAnsStringiRec(fList.Objects[i]));
  fList.Clear;
end;

//------------------------------------------------------------------------------
// TAnsi
//------------------------------------------------------------------------------

function TAnsi.AsAnsiString: AnsiString;
begin
  SetLength(Result, len);
  if len > 0 then  
    Move(text^, Result[1], len);
end;

//------------------------------------------------------------------------------
// SvgArc and support functions
//------------------------------------------------------------------------------

function TrigClampVal(val: double): double; {$IFDEF INLINE} inline; {$ENDIF}
begin
  //force : -1 <= val <= 1
  if val < -1 then Result := -1
  else if val > 1 then Result := 1
  else Result := val;
end;
//------------------------------------------------------------------------------

function  Radian2(vx, vy: double): double;
begin
  Result := ArcCos( TrigClampVal(vx / Sqrt( vx * vx + vy * vy)) );
  if( vy < 0.0 ) then Result := -Result;
end;
//------------------------------------------------------------------------------

function  Radian4(ux, uy, vx, vy: double): double;
var
  dp, md: double;
begin
  dp := ux * vx + uy * vy;
  md := Sqrt( ( ux * ux + uy * uy ) * ( vx * vx + vy * vy ) );
    Result := ArcCos( TrigClampVal(dp / md) );
    if( ux * vy - uy * vx < 0.0 ) then Result := -Result;
end;
//------------------------------------------------------------------------------

//https://stackoverflow.com/a/12329083
function GetSvgArcInfo(const p1, p2: TPointD; radii: TPointD;
  phi_rads: double; fA, fS: boolean;
  out startAngle, endAngle: double; out rec: TRectD): Boolean;
var
  x1_, y1_, rxry, rxy1_, ryx1_, s_phi, c_phi: double;
  hd_x, hd_y, hs_x, hs_y, sum_of_sq, lambda, coe: double;
  cx, cy, cx_, cy_, xcr1, xcr2, ycr1, ycr2, deltaAngle: double;
const
  twoPi: double = PI *2;
begin
    Result := false;
    if (radii.X < 0) then radii.X := -radii.X;
    if (radii.Y < 0) then radii.Y := -radii.Y;
    if (radii.X = 0) or (radii.Y = 0) then Exit;

    Image32_Vector.GetSinCos(phi_rads, s_phi, c_phi);;
    hd_x := (p1.X - p2.X) / 2.0; // half diff of x
    hd_y := (p1.Y - p2.Y) / 2.0; // half diff of y
    hs_x := (p1.X + p2.X) / 2.0; // half sum of x
    hs_y := (p1.Y + p2.Y) / 2.0; // half sum of y

    // F6.5.1
    x1_ := c_phi * hd_x + s_phi * hd_y;
    y1_ := c_phi * hd_y - s_phi * hd_x;

    // F.6.6 Correction of out-of-range radii
    // Step 3: Ensure radii are large enough
    lambda := (x1_ * x1_) / (radii.X * radii.X) +
      (y1_ * y1_) / (radii.Y * radii.Y);
    if (lambda > 1) then
    begin
      radii.X := radii.X * Sqrt(lambda);
      radii.Y := radii.Y * Sqrt(lambda);
    end;

    rxry := radii.X * radii.Y;
    rxy1_ := radii.X * y1_;
    ryx1_ := radii.Y * x1_;
    sum_of_sq := rxy1_ * rxy1_ + ryx1_ * ryx1_; // sum of square
    if (sum_of_sq = 0) then Exit;

    coe := Sqrt(Abs((rxry * rxry - sum_of_sq) / sum_of_sq));
    if (fA = fS) then coe := -coe;

    // F6.5.2
    cx_ := coe * rxy1_ / radii.Y;
    cy_ := -coe * ryx1_ / radii.X;

    // F6.5.3
    cx := c_phi * cx_ - s_phi * cy_ + hs_x;
    cy := s_phi * cx_ + c_phi * cy_ + hs_y;

    xcr1 := (x1_ - cx_) / radii.X;
    xcr2 := (x1_ + cx_) / radii.X;
    ycr1 := (y1_ - cy_) / radii.Y;
    ycr2 := (y1_ + cy_) / radii.Y;

    // F6.5.5
    startAngle := Radian2(xcr1, ycr1);
    NormalizeAngle(startAngle);

    // F6.5.6
    deltaAngle := Radian4(xcr1, ycr1, -xcr2, -ycr2);
    while (deltaAngle > twoPi) do deltaAngle := deltaAngle - twoPi;
    while (deltaAngle < 0.0) do deltaAngle := deltaAngle + twoPi;
    if not fS then deltaAngle := deltaAngle - twoPi;
    endAngle := startAngle + deltaAngle;
    NormalizeAngle(endAngle);

    rec.Left := cx - radii.X;
    rec.Right := cx + radii.X;
    rec.Top := cy - radii.Y;
    rec.Bottom := cy + radii.Y;

    Result := true;
end;

//------------------------------------------------------------------------------
// DParse and support functions
//------------------------------------------------------------------------------

function GetSegType(var c, endC: PAnsiChar; out isRelative: Boolean): TDsegType;
var
  ch: AnsiChar;
begin
  Result := dsMove;
  if not SkipBlanks(c, endC) then Exit;
  ch := upcase(c^);
  if not CharInSet(ch, ['A','C','H','M','L','Q','S','T','V','Z']) then Exit;
  case ch of
    'M': Result := dsMove;
    'L': Result := dsLine;
    'H': Result := dsHorz;
    'V': Result := dsVert;
    'A': Result := dsArc;
    'Q': Result := dsQBez;
    'C': Result := dsCBez;
    'T': Result := dsQSpline;
    'S': Result := dsCSpline;
    'Z': Result := dsClose;
  end;
  isRelative := c^ >= 'a';
  inc(c);
end;
//------------------------------------------------------------------------------

function ParsePathDAttribute(const value: AnsiString): TDpaths;
var
  currSeg     : PDpathSeg;
  currDpath   : PDpath;
  currSegCnt  : integer;
  currSegCap  : integer;
  currSegType : TDsegType;
  lastPt      : TPointD;

  procedure StartNewDpath;
  var
    cnt: integer;
  begin
    if Assigned(currDpath) then
    begin
      if not Assigned(currDpath.segs) then Exit;
      SetLength(currSeg.vals, currSegCnt);
    end;
    cnt := Length(Result);
    SetLength(Result, cnt +1);
    currDpath := @Result[cnt];
    currDpath.firstPt := lastPt;
    currDpath.isClosed := False;
    currDpath.segs := nil;
    currSeg := nil;
  end;

  procedure StartNewSeg;
  var
    cnt: integer;
  begin
    if Assigned(currSeg) then
      SetLength(currSeg.vals, currSegCnt)
    else if not Assigned(currDpath) then
      StartNewDpath;

    cnt := Length(currDpath.segs);
    SetLength(currDpath.segs, cnt +1);
    currSeg := @currDpath.segs[cnt];
    currSeg.segType := currSegType;

    currSegCap := buffSize;
    SetLength(currSeg.vals, currSegCap);
    currSegCnt := 0;
  end;

  procedure AddSegValue(val: double);
  begin
    if not Assigned(currSeg) then StartNewSeg;

    if currSegCnt = currSegCap then
    begin
      inc(currSegCap, buffSize);
      SetLength(currSeg.vals, currSegCap);
    end;
    currSeg.vals[currSegCnt] := val;
    inc(currSegCnt);
  end;

  procedure AddSegPoint(const pt: TPointD);
  begin
    AddSegValue(pt.X); AddSegValue(pt.Y);
  end;

  function Parse2Num(var c, endC: PAnsiChar;
    var pt: TPointD; isRelative: Boolean): Boolean;
  begin
    Result := ParseNextNum(c, endC, true, pt.X) and
      ParseNextNum(c, endC, true, pt.Y);
    if not Result or not isRelative then Exit;
    pt.X := pt.X + lastPt.X;
    pt.Y := pt.Y + lastPt.Y;
  end;

var
  i: integer;
  d: double;
  c, endC: PAnsiChar;
  currPt: TPointD;
  isRelative: Boolean;
begin
  currSeg     := nil;
  currSegCnt  := 0;
  currSegCap  := 0;
  currDpath   := nil;
  currSegType := dsMove;

  c := PAnsiChar(value);
  endC := c + Length(value);
  isRelative := false;
  currPt := NullPointD;

  while true do
  begin
    currSegType := GetSegType(c, endC, isRelative);

    lastPt := currPt;

    if (currSegType = dsMove) then
    begin

      if not Assigned(currSeg) and not PointsEqual(currPt, NullPointD) then
        AddSegPoint(currPt);

      if Assigned(currSeg) then
      begin
        SetLength(currSeg.vals, currSegCnt); //trim buffer
        currDpath.isClosed := false;
      end;
      currDpath := nil;
      currSeg := nil;

      if not Parse2Num(c, endC, currPt, isRelative) then break;
      lastPt :=  currPt;

      //values immediately following a Move are implicitly Line statements
      if IsNumPending(c, endC, true) then
        currSegType := dsLine else
        Continue;
    end
    else if (currSegType = dsClose) then
    begin
      if not Assigned(currSeg) and not PointsEqual(currPt, NullPointD) then
        AddSegPoint(currPt);

      if Assigned(currSeg) then
      begin
        SetLength(currSeg.vals, currSegCnt); //trim buffer
        currDpath.isClosed := true;
        currDpath := nil;
        currSeg := nil;
      end;
      Continue;
    end;

    if Assigned(currSeg) then
      SetLength(currSeg.vals, currSegCnt); //trim buffer
    currSeg := nil;

    case currSegType of
      dsHorz:
        while IsNumPending(c, endC, true) do
        begin
          ParseNextNum(c, endC, true, currPt.X);
          if isRelative then
            currPt.X := currPt.X + lastPt.X;
          AddSegValue(currPt.X);
          lastPt := currPt;
        end;

      dsVert:
        while IsNumPending(c, endC, true) do
        begin
          ParseNextNum(c, endC, true, currPt.Y);
          if isRelative then
            currPt.Y := currPt.Y + lastPt.Y;
          AddSegValue(currPt.Y);
          lastPt := currPt;
        end;

      dsLine:
        while true do
        begin
          if not Parse2Num(c, endC, currPt, isRelative) then break;
          AddSegPoint(currPt);
          lastPt := currPt;
          SkipBlanks(c, endC);
          if IsNumPending(c, endC, true) then Continue;
          if LowerCaseTable[c^] = 'l' then GetSegType(c, endC, isRelative)
          else break;
        end;

      dsQSpline:
        while IsNumPending(c, endC, true) do
        begin
          if not Parse2Num(c, endC, currPt, isRelative) then break;
          AddSegPoint(currPt);
          lastPt := currPt;
        end;

      dsCSpline:
        while IsNumPending(c, endC, true) do
        begin
          if not Parse2Num(c, endC, currPt, isRelative) then break;
          AddSegPoint(currPt);
          if not Parse2Num(c, endC, currPt, isRelative) then break;
          AddSegPoint(currPt);
          lastPt := currPt;
        end;

      dsQBez:
        while IsNumPending(c, endC, true) do
        begin
          if not Parse2Num(c, endC, currPt, isRelative) then break;
          AddSegPoint(currPt);
          if not Parse2Num(c, endC, currPt, isRelative) then break;
          AddSegPoint(currPt);
          lastPt := currPt;
        end;

      dsCBez:
        while IsNumPending(c, endC, true) do
        begin
          if not Parse2Num(c, endC, currPt, isRelative) then break;
          AddSegPoint(currPt);
          if not Parse2Num(c, endC, currPt, isRelative) then break;
          AddSegPoint(currPt);
          if not Parse2Num(c, endC, currPt, isRelative) then break;
          AddSegPoint(currPt);
          lastPt := currPt;
        end;

      dsArc:
        while IsNumPending(c, endC, true) do
        begin
          if not Parse2Num(c, endC, currPt, false) then break;
          AddSegPoint(currPt);                              //radii
          if ParseNextNum(c, endC, true, d) then
            AddSegValue(d);                                 //angle
          if not GetSingleDigit(c, endC, i) then break;     //arc-flag
          AddSegValue(i);
          if not GetSingleDigit(c, endC, i) then break;     //sweep-flag
          AddSegValue(i);
          if not Parse2Num(c, endC, currPt, isRelative) then break;
          AddSegPoint(currPt);
          lastPt := currPt;
        end;
    end;
  end;
  if Assigned(currSeg) then
    SetLength(currSeg.vals, currSegCnt); //trim buffer
end;

//------------------------------------------------------------------------------
// initialization procedures
//------------------------------------------------------------------------------

procedure MakeLowerCaseTable;
var
  i: AnsiChar;
begin
  for i:= #0 to #$40 do LowerCaseTable[i]:= i;
  for i:= #$41 to #$5A do LowerCaseTable[i]:= AnsiChar(Ord(i) + $20);
  for i:= #$5B to #$FF do LowerCaseTable[i]:= i;
end;
//------------------------------------------------------------------------------

procedure MakeColorConstList;
var
  i: integer;
  {$I html_color_consts.inc}
begin
  ColorConstList := TStringList.Create;
  ColorConstList.CaseSensitive := false;
  ColorConstList.Capacity := Length(ColorConsts);
  for i := 0 to High(ColorConsts) do
    with ColorConsts[i] do
      ColorConstList.AddObject(ColorName, Pointer(ColorValue));
  ColorConstList.Sorted := true;
end;

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

initialization
  MakeLowerCaseTable;
  MakeColorConstList;

finalization
  ColorConstList.Free;
end.