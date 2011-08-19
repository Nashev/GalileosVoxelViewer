program TestProject1;

uses
  ExceptionLog,
  Forms,
  Test1Unit in 'Test1Unit.pas' {Form1},
  AbGzTyp in 'Abbrevia 4.0\source\AbGzTyp.pas',
  AbUtils in 'Abbrevia 4.0\source\AbUtils.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
