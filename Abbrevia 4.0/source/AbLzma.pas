(* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is TurboPower Abbrevia
 *
 * The Initial Developer of the Original Code is Craig Peterson
 *
 * Portions created by the Initial Developer are Copyright (C) 2011
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 * Craig Peterson <capeterson@users.sourceforge.net>
 *
 * ***** END LICENSE BLOCK ***** *)

{*********************************************************}
{* ABBREVIA: AbLzma.pas                                  *}
{*********************************************************}
{* ABBREVIA: Lzma compression/decompression procedures.  *}
{*********************************************************}

unit AbLzma;

{$I AbDefine.inc}

interface

uses
  Classes;

// Raw Lzma routines
procedure LzmaDecode(aProperties: PByte; aPropSize: Integer; aSrc, aDes: TStream;
  aUncompressedSize: Int64 = -1);

// LzmaUtil stream routines
procedure LzDecode(inStream, outStream: TStream);
procedure LzEncode(inStream, outStream: TStream; fileSize: Int64);


implementation

uses
  {$IFDEF BCB}
  AbCrtl,
  {$ELSE}
  crtl,
  {$ENDIF}
  Windows,
  SysUtils;

{ C runtime library ======================================================== }

type
  UInt16 = Word;
  UInt32 = LongWord;
  PUInt32 = ^UInt32;
  size_t = {$IF defined(CPUX64)}Int64{$ELSE}Integer{$IFEND}; // NativeInt is 8 bytes in Delphi 2007

function __beginthreadex(security: Pointer; stack_size: Cardinal;
  start_address: Pointer; arglist: Pointer; initflag: Cardinal;
  thrdaddr: Pointer): PUInt; cdecl;
  external 'msvcrt.dll' {$IFNDEF BCB}name '_beginthreadex'{$ENDIF};

function _BigAlloc(size: size_t): Pointer; cdecl;
begin
  Result := GetMemory(size);
end;

procedure _BigFree(address: Pointer); cdecl;
begin
  FreeMemory(address);
end;

function _MyAlloc(size: size_t): Pointer; cdecl;
begin
  Result := GetMemory(size);
end;

procedure _MyFree(address: Pointer); cdecl;
begin
  FreeMemory(address);
end;


{ Types.h declarations ===================================================== }

const
  SZ_OK = 0;

  SZ_ERROR_DATA = 1;
  SZ_ERROR_MEM = 2;
  SZ_ERROR_CRC = 3;
  SZ_ERROR_UNSUPPORTED = 4;
  SZ_ERROR_PARAM = 5;
  SZ_ERROR_INPUT_EOF = 6;
  SZ_ERROR_OUTPUT_EOF = 7;
  SZ_ERROR_READ = 8;
  SZ_ERROR_WRITE = 9;
  SZ_ERROR_PROGRESS = 10;
  SZ_ERROR_FAIL = 11;
  SZ_ERROR_THREAD = 12;

  SZ_ERROR_ARCHIVE = 16;
  SZ_ERROR_NO_ARCHIVE = 17;

type
  SRes = Integer;

  ISeqInStream = packed record
    Read: function(p: Pointer; var buf; var size: size_t): SRes; cdecl;
  end;

  ISeqOutStream = packed record
    Write: function(p: Pointer; const buf; size: size_t): size_t; cdecl;
  end;

  ICompressProgress = packed record
    Progress: function(p: Pointer; inSize, outSize: Int64): SRes; cdecl;
  end;

  ISzAlloc = packed record
    Alloc: function(p: Pointer; size: size_t): Pointer; cdecl;
    Free: procedure(p: Pointer; address: Pointer); cdecl;
  end;

procedure RINOK(x: SRes);
begin
  if x <> 0 then raise Exception.CreateFmt('RINOK(%d)', [x]);
end;


{ LzmaDec.h declarations ==================================================== }

type
  CLzmaProb = Word;

// LZMA Properties
const
  LZMA_PROPS_SIZE = 5;

type
  CLzmaProps = packed record
    lc, lp, pb: Cardinal;
    dicSize: UInt32;
  end;

// LZMA Decoder state
const
  LZMA_REQUIRED_INPUT_MAX = 20;

type
  CLzmaDec = packed record
    prop: CLzmaProps;
    probs: ^CLzmaProb;
    dic: PByte;
    buf: PByte;
    range, code: UInt32;
    dicPos: size_t;
    dicBufSize: size_t;
    processedPos: UInt32;
    checkDicSize: UInt32 ;
    state: Cardinal;
    reps: array[0..3] of UInt32;
    remainLen: Cardinal;
    needFlush: Integer;
    needInitState: Integer;
    numProbs: UInt32;
    tempBufSize: Cardinal;
    tempBuf: array[0..LZMA_REQUIRED_INPUT_MAX - 1] of Byte;
  end;

type
  ELzmaFinishMode = LongInt;

const
  LZMA_FINISH_ANY = 0; // finish at any point
  LZMA_FINISH_END = 1; // block must be finished at the end

type
  ELzmaStatus = LongInt;

const
  LZMA_STATUS_NOT_SPECIFIED = 0;               // use main error code instead
  LZMA_STATUS_FINISHED_WITH_MARK = 1;          // stream was finished with end mark.
  LZMA_STATUS_NOT_FINISHED = 3;                // stream was not finished
  LZMA_STATUS_NEEDS_MORE_INPUT = 4;            // you must provide more input bytes
  LZMA_STATUS_MAYBE_FINISHED_WITHOUT_MARK = 5; // there is probability that stream was finished without end mark

procedure _LzmaDec_Construct(var p: CLzmaDec); cdecl;
begin
  p.dic := nil;
  p.probs := nil;
end;

procedure _LzmaDec_Init(var p: CLzmaDec); cdecl; external;

function _LzmaDec_DecodeToBuf(var p: CLzmaDec; var dest: Byte; var destLen: size_t;
  var src: Byte; var srcLen: size_t; finishMode: ELzmaFinishMode;
  var status: ELzmaStatus): SRes; cdecl; external;

function _LzmaDec_Allocate(var state: CLzmaDec; prop: PByte;
  propsSize: Integer; const alloc: ISzAlloc): SRes; cdecl; external;
procedure _LzmaDec_Free(var state: CLzmaDec; const alloc: ISzAlloc); cdecl; external;


{ LzmaEnc.h declarations =================================================== }

type
  CLzmaEncHandle = Pointer;

  CLzmaEncProps = packed record
    level: Integer;         // 0 <= level <= 9
    dictSize: UInt32;       // (1 << 12) <= dictSize <= (1 << 27) for 32-bit version
                            // (1 << 12) <= dictSize <= (1 << 30) for 64-bit version
                            // default = (1 << 24)
    lc: Integer;            // 0 <= lc <= 8, default = 3
    lp: Integer;            // 0 <= lp <= 4, default = 0
    pb: Integer;            // 0 <= pb <= 4, default = 2
    algo: Integer;          // 0 - fast, 1 - normal, default = 1
    fb: Integer;            // 5 <= fb <= 273, default = 32
    btMode: Integer;        // 0 - hashChain Mode, 1 - binTree mode - normal, default = 1
    numHashBytes: Integer;  // 2, 3 or 4, default = 4
    mc: UInt32;             // 1 <= mc <= (1 << 30), default = 32
    writeEndMark: Cardinal; // 0 - do not write EOPM, 1 - write EOPM, default = 0
    numThreads: Integer;    // 1 or 2, default = 2
  end;


{ Forward declarations ===================================================== }

// LzFind
procedure _MatchFinder_NeedMove; external;
procedure _MatchFinder_GetPointerToCurrentPos; external;
procedure _MatchFinder_MoveBlock; external;
procedure _MatchFinder_ReadIfRequired; external;

procedure _MatchFinder_Construct; external;

procedure _MatchFinder_Create; external;
procedure _MatchFinder_Free; external;
procedure _MatchFinder_Normalize3; external;
procedure _MatchFinder_ReduceOffsets; external;

procedure _GetMatchesSpec1; external;

procedure _MatchFinder_Init; external;
procedure _MatchFinder_CreateVTable; external;

// LzFindMt
procedure _MatchFinderMt_Construct; external;
procedure _MatchFinderMt_Destruct; external;
procedure _MatchFinderMt_Create; external;
procedure _MatchFinderMt_CreateVTable; external;
procedure _MatchFinderMt_ReleaseStream; external;

// LzmaEnc
procedure _LzmaEncProps_Init(var p: CLzmaEncProps); cdecl; external;

// LzmaEnc - CLzmaEncHandle interface
function _LzmaEnc_Create(const alloc: ISzAlloc): CLzmaEncHandle; cdecl; external;
procedure _LzmaEnc_Destroy(p: CLzmaEncHandle; const alloc, allocBig: ISzAlloc); cdecl; external;
function _LzmaEnc_SetProps(p: CLzmaEncHandle; var props: CLzmaEncProps): SRes; cdecl; external;
function _LzmaEnc_WriteProperties(p: CLzmaEncHandle; properties: PByte;
  var size: size_t): SRes; cdecl; external;
function _LzmaEnc_Encode(p: CLzmaEncHandle; var outStream: ISeqOutStream;
  var inStream: ISeqInStream; var progress: ICompressProgress;
  const alloc, allocBig: ISzAlloc): SRes; cdecl; external;
function _LzmaEnc_MemEncode(p: CLzmaEncHandle; dest: PByte; var destLen: size_t;
  src: PByte; srcLen: size_t; writeEndMark: Integer;
  const progress: ICompressProgress; const alloc, allocBig: ISzAlloc): SRes; cdecl; external;


{ Linker derectives ======================================================== }

{$L LzFind.obj}
{$L LzFindMt.obj}
{$L LzmaDec.obj}
{$L LzmaEnc.obj}
{$L Threads.obj}


{ Helper Routines ========================================================== }

function SzAlloc(p: Pointer; size: size_t): Pointer; cdecl;
begin
  Result := GetMemory(size);
end;

procedure SzFree(p, address: Pointer); cdecl;
begin
  FreeMemory(address);
end;

var
  g_Alloc: ISzAlloc = (
    Alloc: SzAlloc;
    Free: SzFree);


{ CSeq*Stream implementation =============================================== }

type
  CSeqInStream = packed record
	  Intf: ISeqInStream;
	  Stream: TStream;
  end;

  CSeqOutStream = packed record
	  Intf: ISeqOutStream;
	  Stream: TStream;
  end;
{ -------------------------------------------------------------------------- }
function ISeqInStream_Read(p: Pointer; var buf; var size: size_t): SRes; cdecl;
begin
  try
  	size := CSeqInStream(p^).Stream.Read(buf, size);
  	Result := SZ_OK;
  except
	  Result := SZ_ERROR_DATA;
  end;
end;
{ -------------------------------------------------------------------------- }
function ISeqOutStream_Write(p: Pointer; const buf; size: size_t): size_t; cdecl;
begin
  try
	  Result := CSeqOutStream(p^).Stream.Write(buf, size);
  except
	  Result := 0;
  end;
end;


{ Linker derectives ======================================================== }

// Decompress an Lzma compressed stream.
// Based on LzmaUtil.c::Decode2
function LzmaDecode2(var aState: CLzmaDec; aOutStream, aInStream: TStream;
  aUncompressedSize: Int64 = -1): SRes;
const
  IN_BUF_SIZE = 1 shl 16;
  OUT_BUF_SIZE = 1 shl 16;
var
  hasSize: Boolean;
  inBuf: array[0..IN_BUF_SIZE - 1] of Byte;
  outBuf: array[0..OUT_BUF_SIZE - 1] of Byte;
  inPos, inSize, outPos: size_t;
  inProcessed, outProcessed: size_t;
  finishMode: ELzmaFinishMode;
  status: ELzmaStatus;
begin
  Result := 0;
  hasSize := aUncompressedSize <> -1;
  inPos := 0;
  inSize := 0;
  outPos := 0;
  _LzmaDec_Init(aState);
  while True do
  begin
    if inPos = inSize then
    begin
      inSize := aInStream.Read(inBuf, IN_BUF_SIZE);
      inPos := 0;
      if inSize = 0 then Break;
    end
    else
    begin
      inProcessed := inSize - inPos;
      outProcessed := OUT_BUF_SIZE - outPos;
      finishMode := LZMA_FINISH_ANY;
      if hasSize and (outProcessed > aUncompressedSize) then begin
        outProcessed := size_t(aUncompressedSize);
        finishMode := LZMA_FINISH_END;
      end;

      Result := _LzmaDec_DecodeToBuf(aState, outBuf[outPos], outProcessed,
        inBuf[inPos], inProcessed, finishMode, status);
      Inc(inPos, inProcessed);
      Inc(outPos, outProcessed);
      Dec(aUncompressedSize, outProcessed);

      if aOutStream <> nil then
        if aOutStream.Write(outBuf, outPos) <> outPos then begin
          Result := SZ_ERROR_WRITE;
          Exit;
        end;

      outPos := 0;

      if (Result <> SZ_OK) or (hasSize and (aUncompressedSize = 0)) then
        Exit;

      if (inProcessed = 0) and (outProcessed = 0) then
      begin
        if hasSize or (status <> LZMA_STATUS_FINISHED_WITH_MARK) then
          Result := SZ_ERROR_DATA;
        Exit;
      end;
    end;
  end;
end;
{ -------------------------------------------------------------------------- }
// Decompress an LZMA compressed stream.
procedure LzmaDecode(aProperties: PByte; aPropSize: Integer; aSrc, aDes: TStream;
  aUncompressedSize: Int64 = -1);
var
  LzmaState: CLzmaDec;
begin
  _LzmaDec_Construct(LzmaState);
  try
    RINOK(_LzmaDec_Allocate(LzmaState, aProperties, aPropSize, g_Alloc));
    RINOK(LzmaDecode2(LzmaState, aDes, aSrc, aUncompressedSize));
  finally
    _LzmaDec_Free(LzmaState, g_Alloc);
  end;
end;
{ -------------------------------------------------------------------------- }
// Decompresses streams compressed with the LZMA SDK's LzmaUtil.exe.
// Based on LzmaUtil.c::Decode
procedure LzDecode(inStream, outStream: TStream);
var
  UncompressedSize: Int64;
  i: Integer;
  // header: 5 bytes of LZMA properties and 8 bytes of uncompressed size
  header: array [0..LZMA_PROPS_SIZE + 7] of Byte;
begin
  // Read and parse header
  inStream.ReadBuffer(header, SizeOf(Header));

  UncompressedSize := 0;
  for i := 0 to 7 do
    Inc(UncompressedSize, Int64(header[LZMA_PROPS_SIZE + i] shl (i * 8)));

  LzmaDecode(@header[0], LZMA_PROPS_SIZE, inStream, outStream, UncompressedSize);
end;
{ -------------------------------------------------------------------------- }
// Compresses a stream so it's compatible with the LZMA SDK's LzmaUtil.exe.
// Based on LzmaUtil.c::Encode
procedure LzEncode(inStream, outStream: TStream; fileSize: Int64);
var
  enc: CLzmaEncHandle;
  props: CLzmaEncProps;
  header: array[0..LZMA_PROPS_SIZE + 7] of Byte;
  headerSize: size_t;
  i: Integer;
  inStreamRec: CSeqInStream;
  outStreamRec: CSeqOutStream;
begin
  inStreamRec.Intf.Read := ISeqInStream_Read;
  inStreamRec.Stream := inStream;
  outStreamRec.Intf.Write := ISeqOutStream_Write;
  outStreamRec.Stream := outStream;

  enc := _LzmaEnc_Create(g_Alloc);
  if enc = nil then
    RINOK(SZ_ERROR_MEM);
  try
    _LzmaEncProps_Init(props);
    RINOK(_LzmaEnc_SetProps(enc, props));

    headerSize := LZMA_PROPS_SIZE;

    RINOK(_LzmaEnc_WriteProperties(enc, @header[0], headerSize));
    for i := 0 to 7 do begin
      header[headerSize] := Byte(fileSize shr (8 * i));
      Inc(headerSize);
    end;
    if outStream.Write(header, headerSize) <> headerSize then
      RINOK(SZ_ERROR_WRITE)
    else
      RINOK(_LzmaEnc_Encode(enc, outStreamRec.Intf, inStreamRec.Intf,
        ICompressProgress(nil^), g_Alloc, g_Alloc));
  finally
    _LzmaEnc_Destroy(enc, g_Alloc, g_Alloc);
  end;
end;


end.
