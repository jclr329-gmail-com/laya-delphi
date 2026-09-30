program Demo_General;

uses
  Vcl.Forms,
  uGeneral in 'uGeneral.pas' {fGeneral};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfGeneral, fGeneral);
  Application.Run;
end.
