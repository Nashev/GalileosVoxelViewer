program TestProject2;

uses
  FMX.Forms,
  Test2Unit in 'Test2Unit.pas' {MainForm},
  AbGzTyp in 'Abbrevia 4.0\source\AbGzTyp.pas',
  AbUtils in 'Abbrevia 4.0\source\AbUtils.pas',
  VoxelReaderUnit in 'VoxelReaderUnit.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
