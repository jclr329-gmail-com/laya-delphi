unit uGeneral;

{ LAYA para Delphi
  Copyright 2026 Carlos Liñán
  Licensed under the Apache License, Version 2.0.
  See LICENSE in the project root for details. }

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Laya.Results, Laya.Questions, Laya.Client,
  System.JSON;

type
  TfGeneral = class(TForm)
    Panel2: TPanel;
    Splitter1: TSplitter;
    Label17: TLabel;
    Panel1: TPanel;
    Label18: TLabel;
    Memo1: TMemo;
    Panel5: TPanel;
    Label1: TLabel;
    btnSalud: TButton;
    btnPredic: TButton;
    RadioButton1: TRadioButton;
    RadioButton2: TRadioButton;
    Memo2: TMemo;
    LayaServer1: TLayaServer;
    LayaQuestions1: TLayaQuestions;
    LayaResults1: TLayaResults;
    Edit1: TEdit;
    Label2: TLabel;
    procedure btnPredicClick(Sender: TObject);
    procedure RadioButton1Click(Sender: TObject);
    procedure RadioButton2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnSaludClick(Sender: TObject);
  private
    { Private declarations }
    procedure ShowOutput;
  public
    { Public declarations }
  end;

var
  fGeneral: TfGeneral;

implementation

{$R *.dfm}



procedure TfGeneral.ShowOutput;
begin
  if LayaResults1.Count > 0 then
  begin
    if RadioButton1.Checked then
      Memo2.Text := LayaResults1.AsText
    else
      Memo2.Text := LayaResults1.FormattedJSON;
  end
  else if LayaQuestions1.Count > 0 then
  begin
    if RadioButton1.Checked then
      Memo2.Text := 'Modelo: ' + LayaServer1.ModelName + sLineBreak + LayaQuestions1.AsText
    else
      Memo2.Text := LayaQuestions1.FormattedJSON;
  end;
end;
{ ---------- Eventos ---------- }

procedure TfGeneral.FormCreate(Sender: TObject);
begin
  Memo1.Lines.Clear;
  Memo2.Lines.Clear;
  Edit1.Text := LayaServer1.BaseURL;
  btnPredic.Enabled := False;    // hasta tener preguntas
  RadioButton1.Checked := True;
end;

procedure TfGeneral.btnSaludClick(Sender: TObject);
begin
  btnPredic.Enabled := False;
  LayaResults1.Clear;            // así se muestran las preguntas, no resultados viejos
  Memo2.Lines.Clear;
  LayaServer1.BaseURL := Trim(Edit1.Text);

  if not LayaServer1.CheckHealth then
  begin
    Memo2.Lines.Add('Error: ' + LayaServer1.LastError);
    Exit;
  end;
  if not LayaServer1.LoadQuestions then
  begin
    Memo2.Lines.Add('Modelo: ' + LayaServer1.ModelName);
    Memo2.Lines.Add('Error: ' + LayaServer1.LastError);
    Exit;
  end;

  ShowOutput;
  btnPredic.Enabled := True;
end;

procedure TfGeneral.btnPredicClick(Sender: TObject);
begin
  if Trim(Memo1.Text) = '' then
  begin
    ShowMessage('Escribe o pega un texto para analizar.');
    Exit;
  end;
  if not LayaServer1.Predict then
    Memo2.Lines.Add('Error: ' + LayaServer1.LastError);
end;

procedure TfGeneral.RadioButton1Click(Sender: TObject);
begin
  LayaResults1.OutJSON := nil;
  LayaResults1.OutTXT := Memo2;
  ShowOutput;
end;

procedure TfGeneral.RadioButton2Click(Sender: TObject);
begin
  LayaResults1.OutTXT := nil;
  LayaResults1.OutJSON := Memo2;
  ShowOutput;
end;


end.
