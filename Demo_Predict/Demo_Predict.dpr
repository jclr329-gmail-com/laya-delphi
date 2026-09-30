program Demo_Predict;

uses
  Vcl.Forms,
  uTest_Predict in 'uTest_Predict.pas' {FTestPredict};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFTestPredict, FTestPredict);
  Application.Run;
end.
