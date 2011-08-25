program TestProject1;

uses
  Forms,
  Test1Unit in 'Test1Unit.pas' {MainForm},
  AbGzTyp in 'Abbrevia 4.0\source\AbGzTyp.pas',
  AbUtils in 'Abbrevia 4.0\source\AbUtils.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
