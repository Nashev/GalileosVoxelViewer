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
{* ABBREVIA: AbWavPack.pas                               *}
{*********************************************************}
{* ABBREVIA: WavPack decompression procedures            *}
{*********************************************************}

unit AbWavPack;

{$I AbDefine.inc}

interface

uses
  Classes;

// Decompress a WavPack compressed stream from aSrc and write to aDes.
// aSrc must not allow reads past the compressed data.
procedure DecompressWavPack(aSrc, aDes: TStream);


implementation

uses
  {$IFDEF BCB}
  AbCrtl,
  {$ELSE}
  crtl,
  {$ENDIF}
  Math,
  SysUtils;

// Compile using
//   bcc32 -DWIN32 -DNO_USE_FSTREAMS -c -w-8004 -w-8012 -w-8017 -w-8057 -w-8065 *.c
//
// In wavpack_local.h remove the line "#define FASTCALL __fastcall"

{ C runtime library ======================================================== }

function _fabs(x: Double): Double; cdecl;
begin
  if x < 0 then Result := -1
  else Result := x
end;

function _floor(x: Double): Integer; cdecl;
begin
  Result := Floor(x);
end;

function _labs(n: Integer): Integer; cdecl;
begin
  if n < 0 then Result := -n
  else Result := n;
end;

function __stricmp(str1, str2: PAnsiChar): Integer; cdecl;
  external 'msvcrt.dll' name '_stricmp';

function _strncmp(str1, str2: PAnsiChar; num: Integer): Integer; cdecl;
  external 'msvcrt.dll' {$IFNDEF BCB}name 'strncmp'{$ENDIF};


{ Forward declarations ===================================================== }

// bits.c
procedure _bs_open_read; external;
procedure _bs_close_read; external;
procedure _bs_open_write; external;
procedure _bs_close_write; external;
procedure _little_endian_to_native; external;
procedure _native_to_little_endian; external;

// extra1.c
procedure _execute_mono; external;

// extra2.c
procedure _execute_stereo; external;

// float.c
procedure _float_values; external;
procedure _read_float_info; external;
procedure _scan_float_data; external;
procedure _send_float_data; external;
procedure _WavpackFloatNormalize; external;
procedure _write_float_info; external;

// metadata.c
procedure _add_to_metadata; external;
procedure _copy_metadata; external;
procedure _free_metadata; external;
procedure _process_metadata; external;
procedure _read_metadata_buff; external;
procedure _write_metadata_block; external;

// pack.c
procedure _pack_block; external;
procedure _pack_init; external;

// tags.c
procedure _load_tag; external;
procedure _valid_tag; external;

// unpack.c
procedure _check_crc_error; external;
procedure _free_tag; external;
procedure _unpack_init; external;
procedure _unpack_samples; external;

// unpack3.c
procedure _free_stream3; external;
procedure _get_version3; external;
procedure _get_sample_index3; external;
procedure _open_file3; external;
procedure _seek_sample3; external;
procedure _unpack_samples3; external;

// words.c
procedure _exp2s; external;
procedure _flush_word; external;
procedure _get_word; external;
procedure _get_words_lossless; external;
procedure _init_words; external;
procedure _log2s; external;
procedure _log2buffer; external;
procedure _nosend_word; external;
procedure _read_hybrid_profile; external;
procedure _read_entropy_vars; external;
procedure _restore_weight; external;
procedure _scan_word; external;
procedure _send_word; external;
procedure _send_words_lossless; external;
procedure _store_weight; external;
procedure _write_entropy_vars; external;
procedure _write_hybrid_profile; external;


{ Linker derectives ======================================================== }

{$L wv_bits.obj}
{$L wv_extra1.obj}
{$L wv_extra2.obj}
{$L wv_float.obj}
{$L wv_metadata.obj}
{$L wv_pack.obj}
{$L wv_tags.obj}
{$L wv_unpack.obj}
{$L wv_unpack3.obj}
{$L wv_words.obj}
{$L wv_wputils.obj}


{ wavpack_local.h ========================================================== }

const
  OPEN_WVC       = $1;     // open/read "correction" file
  OPEN_TAGS      = $2;     // read ID3v1 / APEv2 tags (seekable file)
  OPEN_WRAPPER   = $4;     // make audio wrapper available (i.e. RIFF)
  OPEN_2CH_MAX   = $8;     // open multichannel as stereo (no downmix)
  OPEN_NORMALIZE = $10;    // normalize floating point data to +/- 1.0
  OPEN_STREAMING = $20;    // "streaming" mode blindly unpacks blocks
                           // w/o regard to header file position info
  OPEN_EDIT_TAGS = $40;    // allow editing of tags

type
  int32_t = LongInt;
  uint32_t = LongWord;

  WavpackStreamReader = record
    read_bytes: function(id, data: Pointer; bcount: int32_t): int32_t; cdecl;
    get_pos: function(id: Pointer): uint32_t; cdecl;
    set_pos_abs: function(id: Pointer; pos: uint32_t): Integer; cdecl;
    set_pos_rel: function(id: Pointer; delta: int32_t; mode: Integer): Integer; cdecl;
    push_back_byte: function(id: Pointer; c: Integer): Integer; cdecl;
    get_length: function(id: Pointer): uint32_t; cdecl;
    can_seek: function(id: Pointer): Integer; cdecl;
    write_bytes: function(id, data: Pointer; bcount: int32_t): int32_t; cdecl;
  end;

  WavpackContext = Pointer;


{ wputils.c ================================================================ }

function _WavpackOpenFileInputEx(const reader: WavpackStreamReader;
  wv_id, wvc_id: Pointer; error: PAnsiChar; flags, norm_offset: Integer): WavpackContext;
  cdecl; external;

function _WavpackGetWrapperBytes(wpc: WavpackContext): uint32_t; cdecl; external;
function _WavpackGetWrapperData(wpc: WavpackContext): PByte; cdecl; external;
procedure _WavpackFreeWrapper (wpc: WavpackContext); cdecl; external;

procedure _WavpackSeekTrailingWrapper(wpc: WavpackContext); cdecl; external;

function _WavpackGetNumSamples(wpc: WavpackContext): uint32_t; cdecl; external;
function _WavpackGetNumChannels(wpc: WavpackContext): Integer; cdecl; external;
function _WavpackGetBytesPerSample (wpc: WavpackContext): Integer; cdecl; external;

function _WavpackUnpackSamples(wpc: WavpackContext; buffer: Pointer;
  samples: uint32_t): uint32_t; cdecl; external;

function _WavpackCloseFile(wpc: WavpackContext): WavpackContext; cdecl; external;


{ TWavPackStream implementation ============================================ }

type
  PWavPackStream = ^TWavPackStream;
  TWavPackStream = record
    HasPushedByte: Boolean;
    PushedByte: Byte;
    Stream: TStream;
  end;
{ -------------------------------------------------------------------------- }
function TWavPackStream_read_bytes(id, data: Pointer; bcount: int32_t): int32_t; cdecl;
begin
  if PWavPackStream(id).HasPushedByte then begin
    PByte(data)^ := PWavPackStream(id).PushedByte;
    PWavPackStream(id).HasPushedByte := False;
    Inc(PByte(data));
    Dec(bcount);
    if bcount = 0 then
      Result := 1
    else
      Result := PWavPackStream(id).Stream.Read(data^, bcount) + 1;
  end
  else
    Result := PWavPackStream(id).Stream.Read(data^, bcount);
end;
{ -------------------------------------------------------------------------- }
function TWavPackStream_get_pos(id: Pointer): uint32_t; cdecl;
begin
  Result := PWavPackStream(id).Stream.Position;
end;
{ -------------------------------------------------------------------------- }
function TWavPackStream_set_pos_abs(id: Pointer; pos: uint32_t): Integer; cdecl;
begin
  PWavPackStream(id).Stream.Position := pos;
  Result := 0;
end;
{ -------------------------------------------------------------------------- }
function TWavPackStream_set_pos_rel(id: Pointer; delta: int32_t;
  mode: Integer): Integer; cdecl;
begin
  PWavPackStream(id).Stream.Seek(delta, mode);
  Result := 1;
end;
{ -------------------------------------------------------------------------- }
function TWavPackStream_push_back_byte(id: Pointer; c: Integer): Integer; cdecl;
begin
  Assert(not PWavPackStream(id).HasPushedByte);
  PWavPackStream(id).HasPushedByte := True;
  PWavPackStream(id).PushedByte := Byte(c);
  Result := 1;
end;
{ -------------------------------------------------------------------------- }
function TWavPackStream_get_length(id: Pointer): uint32_t; cdecl;
begin
  Result := PWavPackStream(id).Stream.Size;
end;
{ -------------------------------------------------------------------------- }
function TWavPackStream_can_seek(id: Pointer): Integer; cdecl;
begin
  Result := 1;
end;
{ -------------------------------------------------------------------------- }
function TWavPackStream_write_bytes(id, data: Pointer;
  bcount: int32_t): int32_t; cdecl;
begin
  Result := PWavPackStream(id).Stream.Write(data^, bcount);
end;


{ Decompression routines =================================================== }

{ -------------------------------------------------------------------------- }
// Reformat samples from longs in processor's native endian mode to
// little-endian data with (possibly) less than 4 bytes / sample.
//
// Based on wvunpack.c::format_samples.
// Conversions simplified since we only support little-endian processors
function FormatSamples(bps: Integer; dst, src: PByte; samcnt: uint32_t): PByte;
var
  sample: LongWord;
begin
  while samcnt > 0 do begin
    Dec(samcnt);
    // Get next sample
    sample := PLongWord(src)^;
    // Convert and write to output
    case bps of
      1: begin
        dst^ := sample + 128;
      end;
      2: begin
        PWord(dst)^ := sample;
      end;
      3: begin
        PByteArray(dst)[0] := sample;
        PByteArray(dst)[1] := sample shr 8;
        PByteArray(dst)[2] := sample shr 16;
      end;
      4: begin
        PLongWord(dst)^ := sample;
      end;
    end;
    Inc(src, SizeOf(LongWord));
    Inc(dst, bps);
  end;
  Result := dst;
end;
{ -------------------------------------------------------------------------- }
// Decompress a WavPack compressed stream from aSrc and write to aDes.
// aSrc must not allow reads past the compressed data.
//
// Based on wvunpack.c::unpack_file()
procedure DecompressWavPack(aSrc, aDes: TStream);
type
  PtrInt = {$IF DEFINED(CPUX64)}Int64{$ELSE}LongInt{$IFEND};
const
  OutputBufSize = 256 * 1024;
var
  StreamReader: WavpackStreamReader;
  Context: WavpackContext;
  Src: TWavpackStream;
  Error: array[0..79] of AnsiChar;
  SamplesToUnpack, SamplesUnpacked: uint32_t;
  NumChannels, bps, BytesPerSample: Integer;
  OutputBuf, OutputPtr: PByte;
  DecodeBuf: Pointer;
begin
  OutputBuf := nil;
  DecodeBuf := nil;

  StreamReader.read_bytes := TWavPackStream_read_bytes;
  StreamReader.get_pos := TWavPackStream_get_pos;
  StreamReader.set_pos_abs := TWavPackStream_set_pos_abs;
  StreamReader.set_pos_rel := TWavPackStream_set_pos_rel;
  StreamReader.push_back_byte := TWavPackStream_push_back_byte;
  StreamReader.get_length := TWavPackStream_get_length;
  StreamReader.can_seek := TWavPackStream_can_seek;
  StreamReader.write_bytes := TWavPackStream_write_bytes;

  FillChar(Src, SizeOf(Src), 0);
  Src.Stream := aSrc;

  Context := _WavpackOpenFileInputEx(StreamReader, @Src, nil, Error, OPEN_WRAPPER, 0);
  if Context = nil then
    raise Exception.Create('WavPack decompression failed: ' + Error);
  try
    // Write .wav header
    if _WavpackGetWrapperBytes(Context) > 0 then begin
      aDes.WriteBuffer(_WavpackGetWrapperData(Context)^, _WavpackGetWrapperBytes(Context));
      _WavpackFreeWrapper(Context);
    end;

    NumChannels := _WavpackGetNumChannels(Context);
    bps := _WavpackGetBytesPerSample(Context);
    BytesPerSample := NumChannels * bps;

    GetMem(OutputBuf, OutputBufSize);
    OutputPtr := OutputBuf;
    GetMem(DecodeBuf, 4096 * NumChannels * SizeOf(Integer));

    repeat
      // Unpack samples
      SamplesToUnpack := (OutputBufSize - (PtrInt(OutputPtr) - PtrInt(OutputBuf))) div BytesPerSample;
      if (SamplesToUnpack > 4096) then
        SamplesToUnpack := 4096;
      SamplesUnpacked := _WavpackUnpackSamples(Context, DecodeBuf, SamplesToUnpack);

      // Convert from 32-bit integers down to appriopriate bit depth
      // and copy to output buffer.
      if (SamplesUnpacked > 0) then
        OutputPtr := FormatSamples(bps, OutputPtr, DecodeBuf,
          SamplesUnpacked * uint32_t(NumChannels));

      // Write output when it's full or when we're done
      if (SamplesUnpacked = 0) or
         ((OutputBufSize - (PtrInt(OutputPtr) - PtrInt(OutputBuf))) < BytesPerSample) then begin
        aDes.WriteBuffer(OutputBuf^, PtrInt(OutputPtr) - PtrInt(OutputBuf));
        OutputPtr := OutputBuf;
      end;
    until (SamplesUnpacked = 0);

    // Write .wav footer
    while _WavpackGetWrapperBytes(Context) > 0 do begin
      try
        aDes.WriteBuffer(_WavpackGetWrapperData(Context)^,
          _WavpackGetWrapperBytes(Context));
      finally
        _WavpackFreeWrapper(Context);
      end;
      // Check for more RIFF data
      _WavpackUnpackSamples (Context, DecodeBuf, 1);
    end;
  finally
    if DecodeBuf <> nil then
      FreeMemory(DecodeBuf);
    if OutputBuf <> nil then
      FreeMemory(OutputBuf);
    _WavpackCloseFile(Context);
  end;
end;

end.
