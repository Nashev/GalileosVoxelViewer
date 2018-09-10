unit Test2Unit;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.Ani, FMX.Layouts, FMX.Gestures,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.Viewport3D, FMX.Types3D,
  System.Math.Vectors, FMX.Objects3D, FMX.Controls3D, FMX.MaterialSources,
  FMX.Layers3D, FMX.ListBox, VoxelReaderUnit, FMX.Edit;

type
  TMainForm = class(TForm)
    vp1: TViewport3D;
    grd3d1: TGrid3D;
    rndcb1: TRoundCube;
    LightMaterialSource1: TLightMaterialSource;
    c1: TCamera;
    l1: TLight;
    dmy1: TDummy;
    dmy2: TDummy;
    dmy3: TDummy;
    sphr1: TSphere;
    btnR:TButton;
    edFileName: TComboBox;
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
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

procedure TMainForm.btnInverseClick(Sender: TObject);
begin
  //
end;

procedure TMainForm.btnRClick(Sender: TObject);
begin
  FreeAndNil(VoxelArray);
  VoxelArray := TVoxelArray.Create(edFileName.Selected.Text);
  // DrawImage;
end;

procedure TMainForm.cbUpChange(Sender: TObject);
begin
  //
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
