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
 * The Initial Developer of the Original Code is
 * TurboPower Software
 *
 * Portions created by the Initial Developer are Copyright (C) 1997-2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 * Craig Peterson <capeterson@users.sourceforge.net>
 *
 * ***** END LICENSE BLOCK ***** *)

{*********************************************************}
{* ABBREVIA: AbCrtl.pas                                  *}
{*********************************************************}
{* ABBREVIA: C++Builder C runtime functions              *}
{*********************************************************}

unit AbCrtl;

{$I AbDefine.inc}

interface

const
  __turboFloat: LongInt = 0;

procedure __llshl; cdecl;
procedure __llushr; cdecl;
procedure __ftol; cdecl; external 'msvcrt.dll';

{ ctype.h declarations ===================================================== }
function _isdigit(ch: Integer): Integer; cdecl;

{ string.h declarations ==================================================== }
procedure _memcpy(var Dest; const Src; Count: Integer); cdecl;
procedure _memmove(var Dest; const Src; Count: Integer); cdecl;
procedure _memset(var Dest; Value: Byte; Count: Integer); cdecl;
function _strlen(P: PAnsiChar): Integer; cdecl;
function _strcpy(Des, Src: PAnsiChar): PAnsiChar; cdecl;
function _strncpy(Des, Src: PAnsiChar; MaxLen: Integer): PAnsiChar; cdecl;

function _memcmp(s1,s2: Pointer; numBytes: LongWord): integer; cdecl;
  external 'msvcrt.dll';
function _wcscpy(strDestination, strSource: PWideChar): PWideChar; cdecl;
  external 'msvcrt.dll';

{ stdlib.h declarations ==================================================== }
function _malloc(Size: Integer): Pointer; cdecl;
procedure _free(Ptr: Pointer); cdecl;
function _realloc(Ptr: Pointer; Size: Integer): Pointer; cdecl;

{ intrin.h declarations ==================================================== }
procedure ___cpuid(CPUInfo: PInteger; InfoType: Integer); cdecl;

{ stdio.h declarations ===================================================== }
function _sprintf(S: PChar; const Format: PChar): Integer;
  cdecl; varargs; external 'msvcrt.dll';

implementation

{ ctype.h declarations ===================================================== }
function _isdigit(ch: Integer): Integer; cdecl;
begin
  if AnsiChar(ch) in ['0'..'9'] then
    Result := 1
  else
    Result := 0;
end;
{ -------------------------------------------------------------------------- }
procedure __llshl; cdecl;
asm
  jmp System.@_llshl
end;
{ -------------------------------------------------------------------------- }
procedure __llushr; cdecl;
asm
  jmp System.@_llushr
end;

{ string.h declarations ==================================================== }
procedure _memcpy(var Dest; const Src; Count: Integer); cdecl;
begin
  Move(Src, Dest, Count);
end;
{ -------------------------------------------------------------------------- }
procedure _memmove(var Dest; const Src; Count: Integer); cdecl;
begin
  Move(Src, Dest, Count);
end;
{ -------------------------------------------------------------------------- }
procedure _memset(var Dest; Value: Byte; Count: Integer); cdecl;
begin
  FillChar(Dest, Count, Value);
end;
{ -------------------------------------------------------------------------- }
function _strlen(P: PAnsiChar): Integer; cdecl;
asm
  jmp System.@PCharLen
end;
{ -------------------------------------------------------------------------- }
function _strcpy(Des, Src: PAnsiChar): PAnsiChar; cdecl;
begin
  Result := Des;
  Move(Src^, Des^, _strlen(Src) + 1);
end;
{ -------------------------------------------------------------------------- }
function _strncpy(Des, Src: PAnsiChar; MaxLen: Integer): PAnsiChar; cdecl;
var
  Len: Integer;
begin
  Len := _strlen(Src);
  if Len > MaxLen then
    Len := MaxLen;
  Move(Src^, Des^, Len);
  if Len < MaxLen then
    FillChar(Des[Len], MaxLen - Len, 0);
  Result := Des;
end;

{ stdlib.h declarations ==================================================== }
function _malloc(Size: Integer): Pointer; cdecl;
begin
  GetMem(Result, Size);
end;
{ -------------------------------------------------------------------------- }
procedure _free(Ptr: Pointer); cdecl;
begin
  FreeMem(Ptr)
end;
{ -------------------------------------------------------------------------- }
function _realloc(Ptr: Pointer; Size: Integer): Pointer; cdecl;
begin
  Result := ReallocMemory(Ptr, Size);
end;

{ intrin.h declarations ==================================================== }
procedure ___cpuid(CPUInfo: PInteger; InfoType: Integer); cdecl;
asm
	push ebx
	push esi
	mov eax, InfoType
	cpuid
	mov esi, CPUInfo
	mov [esi], eax
	mov [esi + 4], ebx
	mov [esi + 8], ecx
	mov [esi + 12], edx
	pop esi
	pop ebx
end;
{ -------------------------------------------------------------------------- }

end.
