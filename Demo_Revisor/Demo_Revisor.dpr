program Demo_Revisor;

uses
  Vcl.Forms,
  uTest_Revisor in 'uTest_Revisor.pas' {Test_Revisor};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TTest_Revisor, Test_Revisor);
  Application.Run;
end.
