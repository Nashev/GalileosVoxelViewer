unit Test1Unit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Spin, Contnrs,
  ComCtrls, AppEvnts, VoxelReaderUnit;

type
  TWaiting = class
    class procedure Start;
    class procedure Finish;
  end;

  TPanel = class(ExtCtrls.TPanel)
    procedure Paint; override;
  end;

  TMainForm = class(TForm)
    pnl1: TPanel;
    pnl2: TPanel;
    spl1: TSplitter;
    edFileName: TComboBox;
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
    chkDoubleZoom: TCheckBox;
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
    procedure rgPaintEngineClick(Sender: TObject);
  private
    VoxelArray: TVoxelArray;
    CoordTransformer: TCoordTransformer;
    ColorCallback: TUpdatePixelColorCallback;
    ZeroScreenOffset: TPoint;
    Multiplier: byte;
    NeedDrawPalette: Boolean;
    NeedDrawImage: Boolean;
    CurrentPosition: TVoxelCoords;
    XY: TCoordTransformerXY;
    YZ: TCoordTransformerYZ;
    XZ: TCoordTransformerXZ;
    Zoomer: TCoordTransformerZoom;
    procedure DrawImage;
    procedure UpdatePalette;
    procedure CoordSystemChanged;
    procedure DrawPaletteIndicator(Visible: Boolean; Value: TVoxelValue);
    procedure Draw(AVoxelArray: TVoxelArray; ACurrentPosition: TVoxelCoords;
      AThickness: Integer; ACoordTransformer: TCoordTransformer;
      AColorCallback: TUpdatePixelColorCallback; AZeroScreenOffset: TPoint;
      AScreenBuffer: TBitmap);
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

{ TPanel }

procedure TPanel.Paint;
begin
  if Name <> 'pnlImg' then
    inherited Paint;
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

{ TMainForm }

procedure TMainForm.Draw(AVoxelArray: TVoxelArray; ACurrentPosition: TVoxelCoords; AThickness: Integer; ACoordTransformer: TCoordTransformer; AColorCallback: TUpdatePixelColorCallback; AZeroScreenOffset: TPoint; AScreenBuffer: TBitmap);
type
  TLine = array [0..511] of TColor;
var
  sc: ^TLine;
  RenderRect, ClipRect, CubeRect: TRect;
  LayerOffset: Integer;

  procedure Loops(Layer: Integer);
  var
    i, j: Integer;
  begin
    for j := RenderRect.Top to RenderRect.Bottom do
      begin
        sc := AScreenBuffer.ScanLine[j];
        for i := RenderRect.Left to RenderRect.Right do
          AColorCallback(sc[i], AVoxelArray.Voxel[ACoordTransformer.ScreenToVoxel(i - AZeroScreenOffset.X, j - AZeroScreenOffset.Y, ACurrentPosition, Layer)], Abs(AThickness));
      end;
  end;

begin
  ClipRect := AScreenBuffer.Canvas.ClipRect;
  Inc(ClipRect.Top);
  Inc(ClipRect.Left);
  Dec(ClipRect.Bottom);
  Dec(ClipRect.Right);

  CubeRect := Rect(0,0, ACoordTransformer.ScreenWidth, ACoordTransformer.ScreenHeight);
  OffsetRect(CubeRect, AZeroScreenOffset.X, AZeroScreenOffset.Y);
  if not IntersectRect(RenderRect, CubeRect, ClipRect) then
    Exit;

  if AThickness > 0 then
    for LayerOffset := 0 to AThickness do
      Loops(LayerOffset)
  else
    for LayerOffset := AThickness to 0 do
      Loops(LayerOffset);
end;

procedure TMainForm.btnRClick(Sender: TObject);
begin
  FreeAndNil(VoxelArray);
  VoxelArray := TVoxelArray.Create(edFileName.Text);
  CoordSystemChanged;
  DrawImage;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(VoxelArray);
end;

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
  Thickness: Integer;
begin
  NeedDrawImage := False;
  TWaiting.Start;
  try
    edLayer.Value := tbLayer.Position;
    if rgDrawingMode.ItemIndex = 0 then
        begin
          tbLayer.SelStart := tbLayer.Position;
          tbLayer.SelEnd   := tbLayer.Position;
          Thickness := 0;
        end
      else
        if cbUp.Checked then
          begin
            tbLayer.SelStart := tbLayer.Position;
            tbLayer.SelEnd   := min(tbLayer.Max, tbLayer.Position + edDeep.Value);
            Thickness := tbLayer.SelStart - tbLayer.SelEnd;
          end
        else
          begin
            tbLayer.SelStart := max(tbLayer.Min, tbLayer.Position - edDeep.Value);
            tbLayer.SelEnd   := tbLayer.Position;
            Thickness := tbLayer.SelEnd - tbLayer.SelStart;
          end;

    img.Picture.Bitmap.Canvas.Brush.Color := clBlack;
    img.Picture.Bitmap.Canvas.Brush.Style := bsSolid;
    img.Picture.Bitmap.Canvas.FillRect(img.Picture.Bitmap.Canvas.ClipRect);

    if not Assigned(VoxelArray) then
      Exit;

    with CenterPoint(img.Picture.Bitmap.Canvas.ClipRect) do
      ZeroScreenOffset := Point(X - CoordTransformer.ScreenWidth div 2, Y - CoordTransformer.ScreenHeight div 2);

    Draw(VoxelArray, CurrentPosition, Thickness, CoordTransformer, ColorCallback, ZeroScreenOffset, img.Picture.Bitmap);
    pnlImg.Invalidate;
    Application.ProcessMessages;
  finally
    TWaiting.Finish;
  end;
end;

procedure TMainForm.DrawModeChanged(Sender: TObject);
begin
  CoordSystemChanged;
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
  Zoomer := TCoordTransformerZoom.Create;
  Zoomer.ZoomFactor := 2;

  CurrentPosition.Init(255, 255, 255);
  CoordSystemChanged;
end;

procedure TMainForm.edLayerChange(Sender: TObject);
begin
  tbLayer.Position := edLayer.Value;
  DrawModeChanged(nil);
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

procedure TMainForm.pbOverlayPaint(Sender: TObject);

  procedure Line(X1, Y1, X2, Y2: Integer);
  begin
    pbOverlay.Canvas.MoveTo(X1, Y1);
    pbOverlay.Canvas.LineTo(X2, Y2);
  end;
var
  Pos: TPoint;
begin
  if not Assigned(VoxelArray) then
    Exit;

  pbOverlay.Canvas.Pen.Style := psSolid;
  pbOverlay.Canvas.Pen.Color := clYellow;
  Pos := CoordTransformer.VoxelToScreen(CurrentPosition, CurrentPosition);
  with Pos do
    begin
      Inc(X, ZeroScreenOffset.X);
      Inc(Y, ZeroScreenOffset.Y);
      Line(X,    Y-10, X,    Y+10);
      Line(X-10, Y,    X+10, Y   );
    end;
end;

procedure TMainForm.pbOverlayMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if Assigned(VoxelArray) then
    DrawPaletteIndicator(True, VoxelArray.Voxel[CoordTransformer.ScreenToVoxel(X - ZeroScreenOffset.X, Y - ZeroScreenOffset.Y, CurrentPosition, 0)]);
  pbOverlay.Invalidate;
end;

procedure TMainForm.rgAxisClick(Sender: TObject);
begin
  CoordSystemChanged;
end;

procedure TMainForm.rgPaintEngineClick(Sender: TObject);
begin
//  case rgPaintEngine.ItemIndex of
//    0: ActivateGDI;
//    1: ActivateOpenGL;
//    2: ActivateDirectX;
//  end;
end;

procedure TMainForm.tbLayerChange(Sender: TObject); // вызывается и из edLayerChange, и из btnInverseClick
begin
  CoordTransformer.SetDeep(CurrentPosition, tbLayer.Position);
  if tbLayer.Position = edLayer.Value then
    Exit;

  DrawModeChanged(nil);
end;

procedure TMainForm.CoordSystemChanged;
begin
  case rgAxis.ItemIndex of
    0: CoordTransformer := XY;
    1: CoordTransformer := YZ;
    2: CoordTransformer := XZ;
  end;
  CoordTransformer.VoxelArray := VoxelArray;
  Zoomer.WrappedTransformer := CoordTransformer;
  if chkDoubleZoom.Checked then
    CoordTransformer := Zoomer;
  if Assigned(VoxelArray) then begin
    tbLayer.OnChange := nil;
    tbLayer.Max := CoordTransformer.ScreenDeep - 1;
    edLayer.MaxValue := tbLayer.Max;
    tbLayer.Position := CoordTransformer.GetDeep(CurrentPosition);
    tbLayer.OnChange := tbLayerChange;
    NeedDrawImage := True;
  end;
end;

procedure TMainForm.pbOverlayMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  CurrentPosition := CoordTransformer.ScreenToVoxel(X - ZeroScreenOffset.X, Y - ZeroScreenOffset.Y, CurrentPosition, 0);
end;

end.
