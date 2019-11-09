unit Test2Unit;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.Ani, FMX.Layouts, FMX.Gestures,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.Viewport3D, FMX.Types3D, FMX.Graphics,
  System.Math.Vectors, FMX.Objects3D, FMX.Controls3D, FMX.MaterialSources,
  FMX.Layers3D, FMX.ListBox, VoxelReaderUnit, FMX.Edit, FMX.EditBox, FMX.SpinBox;

type
  TWaiting = class
    class procedure Start;
    class procedure Finish;
  end;

  TMainForm = class(TForm)
    vp1: TViewport3D;
    grd3d1: TGrid3D;
    rndcb1: TRoundCube;
    img: TLightMaterialSource;
    c1: TCamera;
    l1: TLight;
    dmy1: TDummy;
    dmy2: TDummy;
    dmy3: TDummy;
    sphr1: TSphere;
    btnR:TButton;
    edFileName: TComboBox;
    edLayer: TEdit;
    tbLayer: TTrackBar;
    ed1: TSpinBox;
    rgDrawingMode: TComboBox;
    rgAxis: TComboBox;
    procedure vp1MouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; var Handled: Boolean);
    procedure vp1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure vp1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure btnRClick(Sender: TObject);
    procedure tbLayerChange(Sender: TObject);
    procedure rgAxisCchange(Sender: TObject);
    procedure PaletteModeChanged(Sender: TObject);
    procedure btnInverseClick(Sender: TObject);
    procedure edLayerChange(Sender: TObject);
    procedure cbUpChange(Sender: TObject);
  private
    MouseDownPosition: TPointF;
  public
    VoxelArray: TVoxelArray;
    ColorCallback: TUpdatePixelColorCallback;
    NeedDrawImage: Boolean;
    CoordTransformer: TCoordTransformer;
    CurrentPosition: TVoxelCoords;
    procedure DrawImage;
    procedure Draw(AVoxelArray: TVoxelArray; ACurrentPosition: TVoxelCoords;
      AThickness: Integer; ACoordTransformer: TCoordTransformer;
      AColorCallback: TUpdatePixelColorCallback; AZeroScreenOffset: TPoint;
      AScreenBuffer: TBitmap);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

{ TWaiting }

class procedure TWaiting.Finish;
begin
  MainForm.Cursor := crDefault;
end;

class procedure TWaiting.Start;
begin
  MainForm.Cursor := crHourGlass;
end;

procedure TMainForm.btnInverseClick(Sender: TObject);
begin
  //
end;

procedure TMainForm.btnRClick(Sender: TObject);
begin
  FreeAndNil(CoordTransformer);
  FreeAndNil(VoxelArray);
  VoxelArray := TVoxelArray.Create(edFileName.Selected.Text);
  CoordTransformer := TCoordTransformerXY.Create;
  CoordTransformer.VoxelArray := VoxelArray;
  DrawImage;
end;

procedure TMainForm.cbUpChange(Sender: TObject);
begin
  //
end;

procedure TMainForm.Draw(AVoxelArray: TVoxelArray;
  ACurrentPosition: TVoxelCoords; AThickness: Integer;
  ACoordTransformer: TCoordTransformer;
  AColorCallback: TUpdatePixelColorCallback; AZeroScreenOffset: TPoint;
  AScreenBuffer: TBitmap);
type
  TLine = array [0..511] of TAlphaColor;
var
  sc: ^TLine;
  RenderRect: TRect;
  BitmapData: TBitmapData;
  LayerOffset: Integer;

  procedure Loops(Layer: Integer);
  var
    i, j: Integer;
  begin
    for j := RenderRect.Top to RenderRect.Bottom do
      begin
        sc := BitmapData.GetScanline(j);
        for i := RenderRect.Left to RenderRect.Right do
          AColorCallback(sc[i], AVoxelArray.Voxel[ACoordTransformer.ScreenToVoxel(i - AZeroScreenOffset.X, j - AZeroScreenOffset.Y, ACurrentPosition, Layer)], Abs(AThickness));
      end;
  end;

begin
  RenderRect := AScreenBuffer.Bounds;

  AScreenBuffer.Map(TMapAccess.ReadWrite, BitmapData);
  try
    if AThickness > 0 then
      for LayerOffset := 0 to AThickness do
        Loops(LayerOffset)
    else
      for LayerOffset := AThickness to 0 do
        Loops(LayerOffset);
  finally
    AScreenBuffer.Unmap(BitmapData);
  end;
end;

procedure TMainForm.DrawImage;
var
  Thickness: Integer;
begin
  NeedDrawImage := False;
  TWaiting.Start;
  try
    edLayer.Text := FloatToStr(tbLayer.Value);
//     if rgDrawingMode.ItemIndex = 0 then
//         begin
//           tbLayer.SelStart := tbLayer.Position;
//           tbLayer.SelEnd   := tbLayer.Position;
          Thickness := 0;
//         end
//       else
//         if cbUp.Checked then
//           begin
//             tbLayer.SelStart := tbLayer.Position;
//             tbLayer.SelEnd   := min(tbLayer.Max, tbLayer.Position + edDeep.Value);
//             Thickness := tbLayer.SelStart - tbLayer.SelEnd;
//           end
//         else
//           begin
//             tbLayer.SelStart := max(tbLayer.Min, tbLayer.Position - edDeep.Value);
//             tbLayer.SelEnd   := tbLayer.Position;
//             Thickness := tbLayer.SelEnd - tbLayer.SelStart;
//           end;

    if not Assigned(CoordTransformer) then
      Exit;

    img.Texture := TBitmap.Create;
    img.Texture.SetSize(CoordTransformer.ScreenWidth, CoordTransformer.ScreenHeight);
    img.Texture.Canvas.ClearRect(img.Texture.Bounds);

    if not Assigned(VoxelArray) then
      Exit;

    Draw(VoxelArray, CurrentPosition, Thickness, CoordTransformer, ColorCallback, Point(0,0), img.Texture);
    Application.ProcessMessages;
  finally
    TWaiting.Finish;
  end;
end;

procedure TMainForm.edLayerChange(Sender: TObject);
begin
  //
end;

procedure TMainForm.PaletteModeChanged(Sender: TObject);
begin
  //
end;

procedure TMainForm.rgAxisCchange(Sender: TObject);
begin
  //
end;

procedure TMainForm.tbLayerChange(Sender: TObject);
begin
   //
end;

procedure TMainForm.vp1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  MouseDownPosition := PointF(X,Y)
end;

procedure TMainForm.vp1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Single);
var
  s: Integer;
begin
  if ssLeft in Shift then begin
    if vp1.Context.CurrentCameraMatrix.M[1].Normalize.Y > 0 then
      s := 1
    else
      s := -1;
    dmy1.RotationAngle.y := dmy1.RotationAngle.y + (MouseDownPosition.X - X) * s;
    dmy2.RotationAngle.x := dmy2.RotationAngle.x + MouseDownPosition.Y - Y;
    MouseDownPosition := PointF(X,Y)
  end;
end;

procedure TMainForm.vp1MouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; var Handled: Boolean);
begin
  with dmy3.Position do
    if z + WheelDelta / 100 < 0 then
      z := z + WheelDelta / 100
    else
      z := 0;
end;


end.
