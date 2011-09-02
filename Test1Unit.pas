unit Test1Unit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Spin, Contnrs,
  ComCtrls, AppEvnts;

type
  TWaiting = class
    class procedure Start;
    class procedure Finish;
  end;

  TVoxelSlice = class
  private
    FMemoryStream: TMemoryStream;
  public
    property MemoryStream: TMemoryStream read FMemoryStream;
    constructor Create(AFileName: string);
    destructor Destroy; override;
  end;
  TVoxelValue = Word;
const
  MaxVoxelValue = $FFF;
type
  TVoxelCoord = 0..511;
  TVoxelCoords = record
    X, Y, Z: TVoxelCoord;
  end;
  function VoxelCoords(X, Y, Z: TVoxelCoord):TVoxelCoords;
type
  TCoordTransformer = class
    function ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer; ACubeRect: TRect): TVoxelCoords; virtual; abstract;
    function VoxelToScreen(ACoords, AViewPoint: TVoxelCoords; ACubeRect: TRect): TPoint; virtual; abstract;
  end;

  TCoordTransformerXY = class(TCoordTransformer)
    function ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer; ACubeRect: TRect): TVoxelCoords; override;
    function VoxelToScreen(ACoords, AViewPoint: TVoxelCoords; ACubeRect: TRect): TPoint; override;
  end;
  TCoordTransformerYZ = class(TCoordTransformer)
    function ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer; ACubeRect: TRect): TVoxelCoords; override;
    function VoxelToScreen(ACoords, AViewPoint: TVoxelCoords; ACubeRect: TRect): TPoint; override;
  end;
  TCoordTransformerXZ = class(TCoordTransformer)
    function ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer; ACubeRect: TRect): TVoxelCoords; override;
    function VoxelToScreen(ACoords, AViewPoint: TVoxelCoords; ACubeRect: TRect): TPoint; override;
  end;

  TUpdatePixelColorCallback = procedure (var APixel: TColor; Voxel: TVoxelValue; n: Integer) of object;

  TVoxelArray = class
  private
    FList: TObjectList;
    FMask: string;
    function GetSlices(Index: Integer): TVoxelSlice;
    function GetVoxel(Coords: TVoxelCoords): TVoxelValue;
  public
    constructor Create(AMask: string);
    destructor Destroy; override;
    property Slices[Index: Integer]: TVoxelSlice read GetSlices;
    procedure Draw(CurrentPosition: TVoxelCoords; Deep: Integer; CoordTransformer: TCoordTransformer; ColorCallback: TUpdatePixelColorCallback; CubeRect: TRect; ScreenBuffer: TBitmap);
    property Voxel[Coords: TVoxelCoords]: TVoxelValue read GetVoxel;// write SetVoxel;
  end;

  TPanel = class(ExtCtrls.TPanel)
    procedure Paint; override;
  end;


  TMainForm = class(TForm)
    pnl1: TPanel;
    pnl2: TPanel;
    spl1: TSplitter;
    edFileName: TEdit;
    btnR: TButton;
    img: TImage;
    pnlImg: TPanel;
    tbLayer: TTrackBar;
    rgAxis: TRadioGroup;
    edDeep: TSpinEdit;
    cbUp: TCheckBox;
    edLayer: TSpinEdit;
    imgPalette: TImage;
    imgPaletteIndicator: TImage;
    edMultiplier: TSpinEdit;
    ApplicationEvents: TApplicationEvents;
    btnInverse: TButton;
    lbl1: TLabel;
    rgDrawingMode: TRadioGroup;
    pbOverlay: TPaintBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnRClick(Sender: TObject);
    procedure DrawModeChanged(Sender: TObject);
    procedure pnlImgResize(Sender: TObject);
    procedure edLayerChange(Sender: TObject);
    procedure PaletteModeChanged(Sender: TObject);
    procedure ApplicationEventsIdle(Sender: TObject; var Done: Boolean);
    procedure btnInverseClick(Sender: TObject);
    procedure tbLayerChange(Sender: TObject);
    procedure pbOverlayPaint(Sender: TObject);
    procedure pbOverlayMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure rgAxisClick(Sender: TObject);
    procedure pbOverlayMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
    VoxelArray: TVoxelArray;
    CoordTransformer: TCoordTransformer;
    ColorCallback: TUpdatePixelColorCallback;
    CubeRect: TRect;
    Multiplier: byte;
    NeedDrawPalette: Boolean;
    NeedDrawImage: Boolean;
    CurrentPosition: TVoxelCoords;
    XY: TCoordTransformerXY;
    YZ: TCoordTransformerYZ;
    XZ: TCoordTransformerXZ;
    procedure DrawImage;
    procedure UpdatePalette;
    procedure CoordSystemChanged;
    procedure DrawPaletteIndicator(Visible: Boolean; Value: TVoxelValue);
  public
    procedure UpdateSingleLayerColor(var APixel: TColor; Voxel: TVoxelValue; n: Integer);
    procedure UpdateMultiLayerSummColor (var APixel: TColor; Voxel: TVoxelValue; n: Integer);
    procedure UpdateMultiLayerFadeColor (var APixel: TColor; Voxel: TVoxelValue; n: Integer);
  end;

var
  MainForm: TMainForm;

implementation
uses AbGzTyp, AbUtils, Types, Math;
{$R *.dfm}

procedure TMainForm.btnRClick(Sender: TObject);
begin
  FreeAndNil(VoxelArray);
  VoxelArray := TVoxelArray.Create(edFileName.Text);
  DrawImage;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(VoxelArray);
end;

///////////////////////////////////////////////////////////

function TCoordTransformerXY.ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer; ACubeRect: TRect): TVoxelCoords;
begin
  Result.X := max(0, min(511, i - ACubeRect.Left));
  Result.Y := max(0, min(511, 511 - (j - ACubeRect.Top)));
  Result.Z := AViewPoint.Z + Deep;
end;

function TCoordTransformerYZ.ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer; ACubeRect: TRect): TVoxelCoords;
begin
  Result.X := AViewPoint.X + Deep;
  Result.Y := max(0, min(511, i - ACubeRect.Left));
  Result.Z := max(0, min(511, 511 - (j - ACubeRect.Top)));
end;

function TCoordTransformerXZ.ScreenToVoxel(i, j: Integer; AViewPoint: TVoxelCoords; Deep: Integer; ACubeRect: TRect): TVoxelCoords;
begin
  Result.X := max(0, min(511, i - ACubeRect.Left));
  Result.Y := AViewPoint.Y + Deep;
  Result.Z := max(0, min(511, 511 - (j - ACubeRect.Top)));
end;

///////////////////////////////////////////////////////////

function TCoordTransformerXY.VoxelToScreen(ACoords, AViewPoint: TVoxelCoords; ACubeRect: TRect): TPoint;
begin
  Result.X := ACubeRect.Left + ACoords.X;        //  X = i - dx        =>    i = X + dx
  Result.Y := ACubeRect.Top  + 511 - ACoords.Y;  //  Y = c - (j - dy)  =>    j = c - Y + dy
end;

function TCoordTransformerYZ.VoxelToScreen(ACoords, AViewPoint: TVoxelCoords; ACubeRect: TRect): TPoint;
begin
  Result.X := ACubeRect.Left + ACoords.Y;
  Result.Y := ACubeRect.Top  + 511 - ACoords.Z;
end;

function TCoordTransformerXZ.VoxelToScreen(ACoords, AViewPoint: TVoxelCoords; ACubeRect: TRect): TPoint;
begin
  Result.X := ACubeRect.Left + ACoords.X;
  Result.Y := ACubeRect.Top  + 511 - ACoords.Z;
end;

///////////////////////////////////////////////////////////


procedure TMainForm.UpdateMultiLayerSummColor (var APixel: TColor; Voxel: TVoxelValue; n: Integer);
var
  k: Single;
  c: Byte;
begin
  k := 3 * Voxel * Voxel / (MaxVoxelValue * MaxVoxelValue)  * (Multiplier / 10);
  //k := Voxel / MaxVoxelValue;

  c   := Trunc(min(255, TRGBQuad(APixel).rgbRed + 255 * k / n));

  TRGBQuad(APixel).rgbRed   := c;
  TRGBQuad(APixel).rgbGreen := c;
  TRGBQuad(APixel).rgbBlue  := c;
  TRGBQuad(APixel).rgbReserved := 0;
end;

procedure TMainForm.UpdateMultiLayerFadeColor (var APixel: TColor; Voxel: TVoxelValue; n: Integer);
var
  k: Single;
  c: Byte;
begin
  k := 3 * Voxel * Voxel / (MaxVoxelValue * MaxVoxelValue) * (Multiplier / 100);
  //k := Voxel / MaxVoxelValue;

  c := Trunc(255 * k + TRGBQuad(APixel).rgbRed * (1-k));

  TRGBQuad(APixel).rgbRed   := c;
  TRGBQuad(APixel).rgbGreen := c;
  TRGBQuad(APixel).rgbBlue  := c;
  TRGBQuad(APixel).rgbReserved := 0;
end;

procedure TMainForm.UpdateSingleLayerColor(var APixel: TColor; Voxel: TVoxelValue; n: Integer);
var
  c: Byte;
begin
  c := Lo(Voxel shr 4); // TODO: non linear palette
  TRGBQuad(APixel).rgbRed   := c;
  TRGBQuad(APixel).rgbGreen := c;
  TRGBQuad(APixel).rgbBlue  := c;
  TRGBQuad(APixel).rgbReserved := 0;
end;

procedure TMainForm.UpdatePalette;
type
  TLine = array [0..511] of TColor;
var
  ScreenBuffer: TBitmap;
  sc: ^TLine;
  RenderRect, ClipRect: TRect;
  i, j: Integer;

begin
  Multiplier := edMultiplier.Value;
  ScreenBuffer := imgPalette.Picture.Bitmap;

  case rgDrawingMode.ItemIndex of
    0: ColorCallback := UpdateSingleLayerColor;
    1: ColorCallback := UpdateMultiLayerSummColor;
    2: ColorCallback := UpdateMultiLayerFadeColor;
  end;

  ClipRect := ScreenBuffer.Canvas.ClipRect;
  Inc(ClipRect.Top);
  Inc(ClipRect.Left);
  Dec(ClipRect.Bottom);
  Dec(ClipRect.Right);

  ScreenBuffer.Canvas.Brush.Color := clBlack;
  ScreenBuffer.Canvas.Brush.Style := bsSolid;
  ScreenBuffer.Canvas.FillRect(ScreenBuffer.Canvas.ClipRect);

  RenderRect := ClipRect;

  for j := RenderRect.Bottom downto RenderRect.Top do
    begin
      sc := ScreenBuffer.ScanLine[j];
      for i := RenderRect.Left to RenderRect.Right do
        begin
          ColorCallback(sc[i], Trunc(MaxVoxelValue * j / ScreenBuffer.Height), Trunc(1 + edDeep.Value * i / ScreenBuffer.Width));
        end;
    end;
  NeedDrawPalette := False;
  pnlImg.Invalidate;
  Application.ProcessMessages;
end;

procedure TMainForm.DrawImage;
var
  Deep: Integer;
begin
  NeedDrawImage := False;
  TWaiting.Start;
  try
    edLayer.Value := tbLayer.Position;
    if rgDrawingMode.ItemIndex = 0 then
        begin
          tbLayer.SelStart := tbLayer.Position;
          tbLayer.SelEnd   := tbLayer.Position;
          Deep := 0;
        end
      else
        if cbUp.Checked then
          begin
            tbLayer.SelStart := tbLayer.Position;
            tbLayer.SelEnd   := min(511, tbLayer.Position + edDeep.Value);
            Deep := tbLayer.SelStart - tbLayer.SelEnd;
          end
        else
          begin
            tbLayer.SelStart := max(0, tbLayer.Position - edDeep.Value);
            tbLayer.SelEnd   := tbLayer.Position;
            Deep := tbLayer.SelEnd - tbLayer.SelStart;
          end;

    img.Picture.Bitmap.Canvas.Brush.Color := clBlack;
    img.Picture.Bitmap.Canvas.Brush.Style := bsSolid;
    img.Picture.Bitmap.Canvas.FillRect(img.Picture.Bitmap.Canvas.ClipRect);

    if not Assigned(VoxelArray) then
      Exit;

    CubeRect := Rect(0, 0, 511, 511);
    with CenterPoint(img.Picture.Bitmap.Canvas.ClipRect) do
      OffsetRect(CubeRect, X-255, Y-255);

    VoxelArray.Draw(CurrentPosition, Deep, CoordTransformer, ColorCallback, CubeRect, img.Picture.Bitmap);
    pnlImg.Invalidate;
    Application.ProcessMessages;
  finally
    TWaiting.Finish;
  end;
end;

procedure TMainForm.DrawModeChanged(Sender: TObject);
begin
  NeedDrawImage := True;
end;

procedure TMainForm.PaletteModeChanged(Sender: TObject);
begin
  NeedDrawPalette := True;
  NeedDrawImage := True;
end;

procedure TMainForm.DrawPaletteIndicator(Visible: Boolean; Value: TVoxelValue);
begin
  with imgPaletteIndicator.Picture.Bitmap, Canvas do
  begin
    Brush.Color := clBtnFace;
    Brush.Style := bsSolid;
    FillRect(ClipRect);
    if Visible then
      begin
        Brush.Color := clBtnText;
        with Point(0, trunc(Value * Height / MaxVoxelValue)) do
          Polygon([
            Point(3, Y - 4),
            Point(9, Y),
            Point(3, Y + 4)
          ]);
      end;
  end;
  imgPaletteIndicator.Invalidate;
end;

procedure TMainForm.pnlImgResize(Sender: TObject);
begin
  img.Picture.Bitmap.Width  := img.Width;
  img.Picture.Bitmap.Height := img.Height;
  DrawImage;
  imgPalette.Picture.Bitmap.Width  := imgPalette.Width;
  imgPalette.Picture.Bitmap.Height := imgPalette.Height;
  UpdatePalette;
  imgPaletteIndicator.Picture.Bitmap.Width  := imgPaletteIndicator.Width;
  imgPaletteIndicator.Picture.Bitmap.Height := imgPaletteIndicator.Height;
  DrawPaletteIndicator(False, 0);
  pbOverlay.BoundsRect := pnlImg.ClientRect;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  img.Picture.Bitmap.PixelFormat := pf32bit;
  imgPalette.Picture.Bitmap.PixelFormat := pf32bit;
  UpdatePalette;

  XY := TCoordTransformerXY.Create;
  YZ := TCoordTransformerYZ.Create;
  XZ := TCoordTransformerXZ.Create;

  CurrentPosition := VoxelCoords(255, 255, 255);
  CoordSystemChanged;
end;

procedure TMainForm.edLayerChange(Sender: TObject);
begin
  tbLayer.Position := edLayer.Value;
end;

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
end;

destructor TVoxelSlice.Destroy;
begin
  FreeAndNil(FMemoryStream);
  inherited;
end;

{ TVoxelArray }

constructor TVoxelArray.Create(AMask: string);
var
  z: Integer;
begin
  FMask := AMask;
  FList := TObjectList.Create(True);
  FList.Capacity := 512;
  for z := 0 to 511 do
    FList.Add(nil);
end;

destructor TVoxelArray.Destroy;
begin
  FreeAndNil(FList);
  inherited;
end;

function TVoxelArray.GetSlices(Index: Integer): TVoxelSlice;
begin
  Result := FList[Index] as TVoxelSlice;
  if not Assigned(Result) then
    begin
      Result := TVoxelSlice.Create(StringReplace(FMask, '#Z', Format('%.3d', [Index]), []));
      FList[Index] := Result;
    end;
end;

procedure TVoxelArray.Draw(CurrentPosition: TVoxelCoords; Deep: Integer; CoordTransformer: TCoordTransformer; ColorCallback: TUpdatePixelColorCallback; CubeRect: TRect; ScreenBuffer: TBitmap);
type
  TLine = array [0..511] of TColor;
var
  sc: ^TLine;
  RenderRect, ClipRect: TRect;
  LayerOffset: Integer;

  procedure Loops(Layer: Integer);
  var
    i, j: Integer;
  begin
    for j := RenderRect.Top to RenderRect.Bottom do
      begin
        sc := ScreenBuffer.ScanLine[j];
        for i := RenderRect.Left to RenderRect.Right do
          begin
            ColorCallback(sc[i], Voxel[CoordTransformer.ScreenToVoxel(i, j, CurrentPosition, Layer, CubeRect)], Abs(Deep));
          end;
      end;
  end;

begin
  ClipRect := ScreenBuffer.Canvas.ClipRect;
  Inc(ClipRect.Top);
  Inc(ClipRect.Left);
  Dec(ClipRect.Bottom);
  Dec(ClipRect.Right);

  if not IntersectRect(RenderRect, CubeRect, ClipRect) then
    Exit;

  if Deep > 0 then
    for LayerOffset := 0 to Deep do
      Loops(LayerOffset)
  else
    for LayerOffset := Deep to 0 do
      Loops(LayerOffset);
end;

function TVoxelArray.GetVoxel(Coords: TVoxelCoords): TVoxelValue;
type
  TSliceData = array [0..511, 0..511] of TVoxelValue;
  PSliceData = ^TSliceData;
begin
  Result := PSliceData(Slices[Coords.Z].MemoryStream.Memory)[Coords.Y, Coords.X];
end;

{ TPanel }

procedure TPanel.Paint;
begin
  if Name <> 'pnlImg' then
    inherited Paint;
end;

procedure TMainForm.ApplicationEventsIdle(Sender: TObject;
  var Done: Boolean);
begin
  if NeedDrawPalette then
    UpdatePalette;
  if NeedDrawImage then
    DrawImage;
end;

procedure TMainForm.btnInverseClick(Sender: TObject);
begin
  if cbUp.Checked then
    tbLayer.Position := tbLayer.SelEnd
  else
    tbLayer.Position := tbLayer.SelStart;
  cbUp.Checked := not cbUp.Checked;
end;

{ TWaiting }

class procedure TWaiting.Finish;
begin
  Screen.Cursor := crDefault;
end;

class procedure TWaiting.Start;
begin
  Screen.Cursor := crHourGlass;
end;

procedure TMainForm.pbOverlayPaint(Sender: TObject);

  procedure Line(X1, Y1, X2, Y2: Integer);
  begin
    pbOverlay.Canvas.MoveTo(X1, Y1);
    pbOverlay.Canvas.LineTo(X2, Y2);
  end;

begin
  pbOverlay.Canvas.Pen.Style := psSolid;
  pbOverlay.Canvas.Pen.Color := clYellow;
  with CoordTransformer.VoxelToScreen(CurrentPosition, CurrentPosition, CubeRect) do
    begin
      Line(X,    Y-10, X,    Y+10);
      Line(X-10, Y,    X+10, Y   );
    end;
end;

procedure TMainForm.pbOverlayMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if Assigned(VoxelArray) then
    DrawPaletteIndicator(True, VoxelArray.Voxel[CoordTransformer.ScreenToVoxel(X, Y, CurrentPosition, 0, CubeRect)]);
  pbOverlay.Invalidate;
end;

{ TVoxelCoords }

function VoxelCoords(X, Y, Z: TVoxelCoord): TVoxelCoords;
begin
  Result.X := X;
  Result.Y := Y;
  Result.Z := Z;
end;

procedure TMainForm.rgAxisClick(Sender: TObject);
begin
  CoordSystemChanged;
end;

procedure TMainForm.tbLayerChange(Sender: TObject); // вызывается и из edLayerChange, и из btnInverseClick
begin
  case rgAxis.ItemIndex of
    0: CurrentPosition.Z := 511 - tbLayer.Position;
    1: CurrentPosition.X := tbLayer.Position;
    2: CurrentPosition.Y := 511 - tbLayer.Position;
  end;

  if tbLayer.Position = edLayer.Value then
    Exit;

  DrawModeChanged(nil);
end;

procedure TMainForm.CoordSystemChanged;
begin
  case rgAxis.ItemIndex of
    0:
      begin
        CoordTransformer := XY;
        tbLayer.Position := 511 - CurrentPosition.Z;
      end;
    1:
      begin
        CoordTransformer := YZ;
        tbLayer.Position := CurrentPosition.X;
      end;
    2:
      begin
        CoordTransformer := XZ;
        tbLayer.Position := 511 - CurrentPosition.Y;
      end;
  end;
  DrawModeChanged(nil);
end;

procedure TMainForm.pbOverlayMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  CurrentPosition := CoordTransformer.ScreenToVoxel(X, Y, CurrentPosition, 0, CubeRect);
end;

end.
