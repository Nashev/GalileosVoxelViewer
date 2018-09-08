unit Test2Unit;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.Ani, FMX.Layouts, FMX.Gestures,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.Viewport3D, FMX.Types3D,
  System.Math.Vectors, FMX.Objects3D, FMX.Controls3D, FMX.MaterialSources,
  FMX.Layers3D;

type
  TMainForm = class(TForm)
    vpMain: TViewport3D;
    l1: TLight;
    c1: TCamera;
    LightMaterialSource1: TLightMaterialSource;
    img3d1: TImage3D;
    Grid3D1: TGrid3D;
    dmy1: TDummy;
    dmy2: TDummy;
    dmy3: TDummy;
    StrokeCube1: TStrokeCube;
    RoundCube1: TRoundCube;

    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure vpMainMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure vpMainMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; var Handled: Boolean);
  private
    MouseDownPosition: TPointF;
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin

end;

procedure TMainForm.vpMainMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  MouseDownPosition := PointF(X,Y)
end;

procedure TMainForm.vpMainMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; var Handled: Boolean);
begin
  with dmy3.Position do
    if z + WheelDelta / 100 < 0 then
      z := z + WheelDelta / 100
    else
      z := 0;
end;

end.
