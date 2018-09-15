unit VoxelReaderUnit;

interface

uses
  Types, SysUtils, Variants, Classes, Contnrs, UITypes;

type
  TVoxelSlice = class
  private
    FMemoryStream: TMemoryStream;
    FSize: Integer;
  public
    property MemoryStream: TMemoryStream read FMemoryStream;
    property Size: Integer read FSize;
    constructor Create(AFileName: string);
    destructor Destroy; override;
  end;

  TVoxelValue = type Word;
  TVoxelValues = array of TVoxelValue;

  TVoxelCoord = Integer;
  TVoxelCoords = record
    X, Y, Z: TVoxelCoord;
    procedure Init(AX, AY, AZ: TVoxelCoord);
  end;

  TVoxelArray = class;

  TCoordTransformer = class
  private
    FVoxelArray: TVoxelArray;
  public
    function ScreenWidth: Integer; virtual; abstract;
    function ScreenHeight: Integer; virtual; abstract;
    function ScreenDeep: Integer; virtual; abstract;
    function GetDeep(AViewPoint: TVoxelCoords): Integer; virtual; abstract;
    procedure SetDeep(var AViewPoint: TVoxelCoords; ADeep: Integer); virtual; abstract;
    function ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer): TVoxelCoords; virtual; abstract;
    function VoxelToScreen(ACoords, AViewPoint: TVoxelCoords): TPoint; virtual; abstract;
    property VoxelArray: TVoxelArray read FVoxelArray write FVoxelArray;
  end;

  TCoordTransformerXY = class(TCoordTransformer)
  public
    function ScreenWidth: Integer; override;
    function ScreenHeight: Integer; override;
    function ScreenDeep: Integer; override;
    function GetDeep(AViewPoint: TVoxelCoords): Integer; override;
    procedure SetDeep(var AViewPoint: TVoxelCoords; ADeep: Integer); override;
    function ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer): TVoxelCoords; override;
    function VoxelToScreen(ACoords, AViewPoint: TVoxelCoords): TPoint; override;
  end;

  TCoordTransformerYZ = class(TCoordTransformer)
  public
    function ScreenWidth: Integer; override;
    function ScreenHeight: Integer; override;
    function ScreenDeep: Integer; override;
    function GetDeep(AViewPoint: TVoxelCoords): Integer; override;
    procedure SetDeep(var AViewPoint: TVoxelCoords; ADeep: Integer); override;
    function ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer): TVoxelCoords; override;
    function VoxelToScreen(ACoords, AViewPoint: TVoxelCoords): TPoint; override;
  end;

  TCoordTransformerXZ = class(TCoordTransformer)
  public
    function ScreenWidth: Integer; override;
    function ScreenHeight: Integer; override;
    function ScreenDeep: Integer; override;
    function GetDeep(AViewPoint: TVoxelCoords): Integer; override;
    procedure SetDeep(var AViewPoint: TVoxelCoords; ADeep: Integer); override;
    function ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer): TVoxelCoords; override;
    function VoxelToScreen(ACoords, AViewPoint: TVoxelCoords): TPoint; override;
  end;

  TCoordTransformerFree = class(TCoordTransformer)
  public
    function ScreenWidth: Integer; override;
    function ScreenHeight: Integer; override;
    function ScreenDeep: Integer; override;
    function GetDeep(AViewPoint: TVoxelCoords): Integer; override;
    procedure SetDeep(var AViewPoint: TVoxelCoords; ADeep: Integer); override;
    function ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer): TVoxelCoords; override;
    function VoxelToScreen(ACoords, AViewPoint: TVoxelCoords): TPoint; override;
  end;

  TCoordTransformerZoom = class(TCoordTransformer)
  private
    FWrappedTransformer: TCoordTransformer;
    FZoomFactor: Single;
  public
    function ScreenWidth: Integer; override;
    function ScreenHeight: Integer; override;
    function ScreenDeep: Integer; override;
    function GetDeep(AViewPoint: TVoxelCoords): Integer; override;
    procedure SetDeep(var AViewPoint: TVoxelCoords; ADeep: Integer); override;
    function ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer): TVoxelCoords; override;
    function VoxelToScreen(ACoords, AViewPoint: TVoxelCoords): TPoint; override;
    property WrappedTransformer: TCoordTransformer read FWrappedTransformer write FWrappedTransformer;
    property ZoomFactor: Single read FZoomFactor write FZoomFactor;
  end;

  TUpdatePixelColorCallback = procedure (var APixel: TColor; Voxel: TVoxelValue; n: Integer) of object;

  TVoxelArray = class
  private
    FList: TObjectList;
    FFileNameMask: string;
    FSize: TVoxelCoords;
    function GetSlice(Index: Integer): TVoxelSlice;
    function GetVoxel(Coords: TVoxelCoords): TVoxelValue;
    function GetFileName(Index: Integer): string;
  public
    constructor Create(AGWGFileName: string);
    destructor Destroy; override;
    property Slices[Index: Integer]: TVoxelSlice read GetSlice;
    property Voxel[Coords: TVoxelCoords]: TVoxelValue read GetVoxel;// write SetVoxel;
    property FileNames[Index: Integer]: string read GetFileName;
    property Size: TVoxelCoords read FSize;
  end;

const
  MaxVoxelValue = $FFF;

implementation

uses AbGzTyp, AbUtils, Math;
{ TVoxelCoords }

procedure TVoxelCoords.Init(AX, AY, AZ: TVoxelCoord);
begin
  X := AX;
  Y := AY;
  Z := AZ;
end;

///////////////////////////////////////////////////////////

function TCoordTransformerXY.ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer): TVoxelCoords;
begin
  Result.X := max(0, min(VoxelArray.Size.X - 1, i));
  Result.Y := max(0, min(VoxelArray.Size.Y - 1, VoxelArray.Size.Y - 1 - j));
  Result.Z := max(0, min(VoxelArray.Size.Z - 1, AViewPoint.Z + Deep));
end;

function TCoordTransformerYZ.ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer): TVoxelCoords;
begin
  Result.X := max(0, min(VoxelArray.Size.X - 1, AViewPoint.X + Deep));
  Result.Y := max(0, min(VoxelArray.Size.Y - 1, i));
  Result.Z := max(0, min(VoxelArray.Size.Z - 1, VoxelArray.Size.Z - 1 - j));
end;

function TCoordTransformerXZ.ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer): TVoxelCoords;
begin
  Result.X := max(0, min(VoxelArray.Size.X - 1, i));
  Result.Y := max(0, min(VoxelArray.Size.Y - 1, AViewPoint.Y + Deep));
  Result.Z := max(0, min(VoxelArray.Size.Z - 1, VoxelArray.Size.Z - 1 - j));
end;

///////////////////////////////////////////////////////////

function TCoordTransformerXY.VoxelToScreen(ACoords, AViewPoint: TVoxelCoords): TPoint;
begin
  Result.X := ACoords.X;                 //  X = i - dx        =>    i = X + dx
  Result.Y := ScreenHeight - ACoords.Y;  //  Y = c - (j - dy)  =>    j = c - Y + dy
end;

function TCoordTransformerYZ.VoxelToScreen(ACoords, AViewPoint: TVoxelCoords): TPoint;
begin
  Result.X := ACoords.Y;
  Result.Y := ScreenHeight - ACoords.Z;
end;

function TCoordTransformerXZ.VoxelToScreen(ACoords, AViewPoint: TVoxelCoords): TPoint;
begin
  Result.X := ACoords.X;
  Result.Y := ScreenHeight - ACoords.Z;
end;

///////////////////////////////////////////////////////////

function TCoordTransformerXY.GetDeep(AViewPoint: TVoxelCoords): Integer;
begin
  Result := ScreenDeep - 1 - AViewPoint.Z;
end;

function TCoordTransformerYZ.GetDeep(AViewPoint: TVoxelCoords): Integer;
begin
  Result := AViewPoint.X;
end;

function TCoordTransformerXZ.GetDeep(AViewPoint: TVoxelCoords): Integer;
begin
  Result := ScreenDeep - 1 - AViewPoint.Y;
end;

procedure TCoordTransformerXY.SetDeep(var AViewPoint: TVoxelCoords; ADeep: Integer);
begin
  AViewPoint.Z := ScreenDeep - 1 - ADeep;
end;

procedure TCoordTransformerYZ.SetDeep(var AViewPoint: TVoxelCoords; ADeep: Integer);
begin
  AViewPoint.X := ADeep;
end;

procedure TCoordTransformerXZ.SetDeep(var AViewPoint: TVoxelCoords; ADeep: Integer);
begin
  AViewPoint.Y := ScreenDeep - 1 - ADeep;
end;

///////////////////////////////////////////////////////////

function TCoordTransformerXY.ScreenWidth: Integer;
begin
  Result := VoxelArray.Size.X;
end;

function TCoordTransformerXY.ScreenHeight: Integer;
begin
  Result := VoxelArray.Size.Y;
end;

function TCoordTransformerXY.ScreenDeep: Integer;
begin
  Result := VoxelArray.Size.Z;
end;

function TCoordTransformerYZ.ScreenWidth: Integer;
begin
  Result := VoxelArray.Size.Y;
end;

function TCoordTransformerYZ.ScreenHeight: Integer;
begin
  Result := VoxelArray.Size.Z;
end;

function TCoordTransformerYZ.ScreenDeep: Integer;
begin
  Result := VoxelArray.Size.X;
end;

function TCoordTransformerXZ.ScreenWidth: Integer;
begin
  Result := VoxelArray.Size.X;
end;

function TCoordTransformerXZ.ScreenHeight: Integer;
begin
  Result := VoxelArray.Size.Z;
end;

function TCoordTransformerXZ.ScreenDeep: Integer;
begin
  Result := VoxelArray.Size.Y;
end;

///////////////////////////////////////////////////////////

{ TSlice }

constructor TVoxelSlice.Create(AFileName: string);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  FMemoryStream := TMemoryStream.Create;
  try
    with TAbGzipStreamHelper.Create(Stream) do
      try
        ReadHeader;
        if VerifyHeader(Item.GZHeader) then
          begin
            MemoryStream.Clear;
            ExtractItemData(MemoryStream);
          end
        else
          begin
            Stream.seek(0, soFromBeginning);
            MemoryStream.LoadFromStream(Stream)
          end;
      finally
        Free;
      end;
  finally
    Stream.Free;
  end;
  FSize := Round(sqrt(MemoryStream.Size div 2));
end;

destructor TVoxelSlice.Destroy;
begin
  FreeAndNil(FMemoryStream);
  inherited;
end;

{ TVoxelArray }

constructor TVoxelArray.Create(AGWGFileName: string);
begin
  AGWGFileName := ChangeFileExt(AGWGFileName, '');
  FFileNameMask := ExtractFileDir(AGWGFileName) + '\' + ExtractFileName(AGWGFileName) + '\' + ExtractFileName(AGWGFileName);
  FList := TObjectList.Create(True);
  FSize.Z := 0;
  while FileExists(FileNames[FSize.Z]) do
    Inc(FSize.Z);
  FList.Capacity := FSize.Z;
  FList.Count := FSize.Z;
  // в остальных двух размерах сориентируемся по первому слою:
  if FSize.Z > 0 then
    FSize.X := Slices[0].Size
  else
    FSize.X := 0;
  FSize.Y := FSize.X;
end;

destructor TVoxelArray.Destroy;
begin
  FreeAndNil(FList);
  inherited;
end;

function TVoxelArray.GetFileName(Index: Integer): string;
begin
  Result := FFileNameMask + Format('_%.3d', [Index]);
end;

function TVoxelArray.GetSlice(Index: Integer): TVoxelSlice;
begin
  Result := FList[Index] as TVoxelSlice;
  if not Assigned(Result) then
    begin
      Result := TVoxelSlice.Create(FileNames[Index]);
      FList[Index] := Result;
    end;
end;

function TVoxelArray.GetVoxel(Coords: TVoxelCoords): TVoxelValue;
var
  Slice: TVoxelSlice;
begin
  Slice := Slices[Coords.Z];
  Result := TVoxelValues(Slice.MemoryStream.Memory)[Coords.Y * Slice.Size + Coords.X];
end;

{ TCoordTransformerFree }

function TCoordTransformerFree.GetDeep(AViewPoint: TVoxelCoords): Integer;
begin

end;

function TCoordTransformerFree.ScreenDeep: Integer;
begin

end;

function TCoordTransformerFree.ScreenHeight: Integer;
begin

end;

function TCoordTransformerFree.ScreenToVoxel(i, j: Integer;
  AViewPoint: TVoxelCoords; Deep: Integer): TVoxelCoords;
begin

end;

function TCoordTransformerFree.ScreenWidth: Integer;
begin

end;

procedure TCoordTransformerFree.SetDeep(var AViewPoint: TVoxelCoords;
  ADeep: Integer);
begin

end;

function TCoordTransformerFree.VoxelToScreen(ACoords, AViewPoint: TVoxelCoords): TPoint;
begin

end;

{ TCoordTransformerZoom }

function TCoordTransformerZoom.GetDeep(AViewPoint: TVoxelCoords): Integer;
begin
  Result := Round(FWrappedTransformer.GetDeep(AViewPoint) * ZoomFactor);
end;

function TCoordTransformerZoom.ScreenDeep: Integer;
begin
  Result := Round(FWrappedTransformer.ScreenDeep * ZoomFactor);
end;

function TCoordTransformerZoom.ScreenHeight: Integer;
begin
  Result := Round(FWrappedTransformer.ScreenHeight * ZoomFactor);
end;

function TCoordTransformerZoom.ScreenToVoxel(i, j: Integer;
  AViewPoint: TVoxelCoords; Deep: Integer): TVoxelCoords;
begin
  i := Round(i / ZoomFactor);
  j := Round(j / ZoomFactor);
  Result := FWrappedTransformer.ScreenToVoxel(i, j, AViewPoint, Deep);
end;

function TCoordTransformerZoom.ScreenWidth: Integer;
begin
  Result := Round(FWrappedTransformer.ScreenWidth * ZoomFactor);
end;

procedure TCoordTransformerZoom.SetDeep(var AViewPoint: TVoxelCoords; ADeep: Integer);
begin
  FWrappedTransformer.SetDeep(AViewPoint, Round(ADeep / ZoomFactor));
end;

function TCoordTransformerZoom.VoxelToScreen(ACoords, AViewPoint: TVoxelCoords): TPoint;
begin
  Result := FWrappedTransformer.VoxelToScreen(ACoords, AViewPoint);
  Result.X := Round(Result.X * ZoomFactor);
  Result.Y := Round(Result.Y * ZoomFactor);
end;

end.
