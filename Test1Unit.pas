unit Test1Unit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, GoodSplitUnit, ExtCtrls, icControlLabelUnit, Spin, Contnrs,
  ComCtrls;

type
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

  TVoxelToPixelPixelCoordTransformCallback = function (i, j, ALayer: Integer; ACubeRect: TRect): TVoxelCoords of object;
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
    procedure Draw(MinLayer, MaxLayer: Integer; Backward: Boolean; CoordCallBack:TVoxelToPixelPixelCoordTransformCallback; ColorCallback: TUpdatePixelColorCallback; CubeRect: TRect; ScreenBuffer: TBitmap);
    property Voxel[Coords: TVoxelCoords]: TVoxelValue read GetVoxel;// write SetVoxel;
  end;

  TPanel = class(ExtCtrls.TPanel)
    procedure Paint; override;
  end;


  TMainForm = class(TForm)
    pnl1: TPanel;
    pnl2: TPanel;
    spl1: TicSplitter;
    edFileName: TEdit;
    btnR: TButton;
    img: TImage;
    pnlImg: TPanel;
    tbLayer: TTrackBar;
    rgAxis: TRadioGroup;
    edDeep: TSpinEdit;
    cbUp: TCheckBox;
    edLayer: TSpinEdit;
    cbMany: TCheckBox;
    imgPalette: TImage;
    imgPaletteIndicator: TImage;
    procedure btnRClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure DrawModeChanged(Sender: TObject);
    procedure pnlImgResize(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure edLayerChange(Sender: TObject);
    procedure PaletteModeChanged(Sender: TObject);
    procedure imgMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
  private
    VoxelArray: TVoxelArray;
    CoordCallBack:TVoxelToPixelPixelCoordTransformCallback;
    ColorCallback: TUpdatePixelColorCallback;
    CubeRect: TRect;
    procedure DrawImage;
    procedure DrawPalette;
    procedure DrawPaletteIndicator(Visible: Boolean; Value: TVoxelValue);
  public
    function XY(i, j, ALayer: Integer; ACubeRect: TRect): TVoxelCoords;
    function YZ(i, j, ALayer: Integer; ACubeRect: TRect): TVoxelCoords;
    function XZ(i, j, ALayer: Integer; ACubeRect: TRect): TVoxelCoords;

    procedure UpdateMultiLayerColor (var APixel: TColor; Voxel: TVoxelValue; n: Integer);
    procedure UpdateSingleLayerColor(var APixel: TColor; Voxel: TVoxelValue; n: Integer);
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

function TMainForm.XY(i, j, ALayer: Integer; ACubeRect: TRect): TVoxelCoords;
begin
  Result.X := max(0, min(511, i - ACubeRect.Left));
  Result.Y := max(0, min(511, 511 - (j - ACubeRect.Top)));
  Result.Z := max(0, min(511, ALayer));
end;

function TMainForm.YZ(i, j, ALayer: Integer; ACubeRect: TRect): TVoxelCoords;
begin
  Result.X := max(0, min(511, ALayer));
  Result.Y := max(0, min(511, i - ACubeRect.Left));
  Result.Z := max(0, min(511, 511 - (j - ACubeRect.Top)));
end;

function TMainForm.XZ(i, j, ALayer: Integer; ACubeRect: TRect): TVoxelCoords;
begin
  Result.X := max(0, min(511, i - ACubeRect.Left));
  Result.Y := max(0, min(511, ALayer));
  Result.Z := max(0, min(511, 511 - (j - ACubeRect.Top)));
end;

procedure TMainForm.UpdateMultiLayerColor (var APixel: TColor; Voxel: TVoxelValue; n: Integer);
var
  k: Single;
  c: Byte;
begin
  k := 3 * Voxel * Voxel / (MaxVoxelValue * MaxVoxelValue);
  //k := Voxel / MaxVoxelValue;

  // c   := Trunc(255 * k * 0.8 + TRGBQuad(APixel).rgbRed * (1-k) * 0.8);
  c   := Trunc(min(255, TRGBQuad(APixel).rgbRed + 255 * k / n));

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

procedure TMainForm.DrawPalette;
type
  TLine = array [0..511] of TColor;
var
  ScreenBuffer: TBitmap;
  sc: ^TLine;
  RenderRect, ClipRect: TRect;
  n: Integer;
  Layer: Integer;
  i, j: Integer;
  ColorCallback: TUpdatePixelColorCallback;

begin
  ScreenBuffer := imgPalette.Picture.Bitmap;
  if cbMany.Checked then
    ColorCallback := UpdateMultiLayerColor
  else
    ColorCallback := UpdateSingleLayerColor;

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
  pnlImg.Invalidate;
  Application.ProcessMessages;
end;

procedure TMainForm.DrawImage;
begin
  edLayer.Value := tbLayer.Position;
  if not cbMany.Checked then
      begin
        tbLayer.SelStart := tbLayer.Position;
        tbLayer.SelEnd   := tbLayer.Position;
      end
    else
      if cbUp.Checked then
        begin
          tbLayer.SelStart := tbLayer.Position;
          tbLayer.SelEnd   := min(511, tbLayer.Position + edDeep.Value);
        end
      else
        begin
          tbLayer.SelStart := max(0, tbLayer.Position - edDeep.Value);
          tbLayer.SelEnd   := tbLayer.Position;
        end;

  if not Assigned(VoxelArray) then
    Exit;

  img.Picture.Bitmap.Canvas.Brush.Color := clBlack;
  img.Picture.Bitmap.Canvas.Brush.Style := bsSolid;
  img.Picture.Bitmap.Canvas.FillRect(img.Picture.Bitmap.Canvas.ClipRect);

  case rgAxis.ItemIndex of
    0: CoordCallback := XY;
    1: CoordCallback := YZ;
    2: CoordCallback := XZ;
  end;
  if cbMany.Checked then
    ColorCallback := UpdateMultiLayerColor
  else
    ColorCallback := UpdateSingleLayerColor;

  CubeRect := Rect(0, 0, 511, 511);
  with CenterPoint(img.Picture.Bitmap.Canvas.ClipRect) do
    OffsetRect(CubeRect, X-255, Y-255);

  VoxelArray.Draw(tbLayer.SelStart, tbLayer.SelEnd, cbUp.Checked, CoordCallback, ColorCallback, CubeRect, img.Picture.Bitmap);
  pnlImg.Invalidate;
  Application.ProcessMessages;
end;

procedure TMainForm.imgMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if Assigned(VoxelArray) then
    DrawPaletteIndicator(True, VoxelArray.Voxel[CoordCallBack(X, Y, tbLayer.Position, CubeRect)])
end;

procedure TMainForm.DrawModeChanged(Sender: TObject);
begin
  DrawImage;
end;

procedure TMainForm.PaletteModeChanged(Sender: TObject);
begin
  DrawPalette;
  DrawImage;
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
  DrawPalette;
  imgPaletteIndicator.Picture.Bitmap.Width  := imgPaletteIndicator.Width;
  imgPaletteIndicator.Picture.Bitmap.Height := imgPaletteIndicator.Height;
  DrawPaletteIndicator(False, 0);
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  img.Picture.Bitmap.PixelFormat := pf32bit;
  imgPalette.Picture.Bitmap.PixelFormat := pf32bit;
  DrawPalette;
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

procedure TVoxelArray.Draw(MinLayer, MaxLayer: Integer; Backward: Boolean; CoordCallBack:TVoxelToPixelPixelCoordTransformCallback; ColorCallback: TUpdatePixelColorCallback; CubeRect: TRect; ScreenBuffer: TBitmap);
type
  TLine = array [0..511] of TColor;
var
  sc: ^TLine;
  RenderRect, ClipRect: TRect;
  n: Integer;
  Layer: Integer;

  procedure Loops(Layer: Integer);
  var
    i, j: Integer;
  begin
    for j := RenderRect.Top to RenderRect.Bottom do
      begin
        sc := ScreenBuffer.ScanLine[j];
        for i := RenderRect.Left to RenderRect.Right do
          begin
            ColorCallback(sc[i], Voxel[CoordCallback(i, j, Layer, CubeRect)], n);
          end;
      end;
  end;

begin
  ClipRect := ScreenBuffer.Canvas.ClipRect;
  Inc(ClipRect.Top);
  Inc(ClipRect.Left);
  Dec(ClipRect.Bottom);
  Dec(ClipRect.Right);
  n := MaxLayer - MinLayer + 1;

  if not IntersectRect(RenderRect, CubeRect, ClipRect) then
    Exit;

  if not Backward then
    for Layer := MinLayer to MaxLayer do
      Loops(Layer)
  else
    for Layer := MaxLayer downto MinLayer do
      Loops(Layer);
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

end.
