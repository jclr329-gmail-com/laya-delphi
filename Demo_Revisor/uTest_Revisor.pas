unit uTest_Revisor;

{ LAYA para Delphi
  Copyright 2026 Carlos Liñán
  Licensed under the Apache License, Version 2.0.
  See LICENSE in the project root for details. }

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Laya.Results, Laya.Questions, Laya.Client, Laya.Training, Laya.DB, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs, FireDAC.Phys.SQLiteWrapper.Stat, FireDAC.VCLUI.Wait, FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf,
  FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet, FireDAC.Comp.Client, Vcl.StdCtrls, Vcl.ExtCtrls,
  System.IOUtils, Vcl.DBCtrls, Vcl.Grids, Vcl.DBGrids;

type
  TTest_Revisor = class(TForm)
    LayaEvaluator1: TLayaEvaluator;
    LayaTrainingExporter1: TLayaTrainingExporter;
    LayaServer1: TLayaServer;
    LayaQuestions1: TLayaQuestions;
    LayaResults1: TLayaResults;
    FDConnection1: TFDConnection;
    DataSource1: TDataSource;
    LayaDBAnalyzer1: TLayaDBAnalyzer;
    FDTable1: TFDTable;
    Panel1: TPanel;
    Panel2: TPanel;
    btnMedir: TButton;
    Memo1: TMemo;
    Label1: TLabel;
    Panel3: TPanel;
    Panel4: TPanel;
    DBGrid1: TDBGrid;
    DBMemo1: TDBMemo;
    Splitter1: TSplitter;
    btnExportar: TButton;
    procedure btnMedirClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure LayaDBAnalyzer1Finish(Sender: TObject; const AStats: TLayaDBStats);
    procedure LayaEvaluator1Finish(Sender: TObject);
    procedure LayaDBAnalyzer1Progress(Sender: TObject; ACurrent, ATotal: Integer; var ACancel: Boolean);
    procedure btnExportarClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Test_Revisor: TTest_Revisor;

implementation

{$R *.dfm}


procedure TTest_Revisor.btnMedirClick(Sender: TObject);
begin
     FDTable1.Filter := 'Particion = ''test''';
     FDTable1.Filtered := True;

     LayaEvaluator1.Execute;
end;


procedure TTest_Revisor.FormCreate(Sender: TObject);
begin

     FDConnection1.Params.Database := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\Database\codiesp.sdb');

     FDTable1.Active := True;
end;

procedure TTest_Revisor.LayaDBAnalyzer1Finish(Sender: TObject; const AStats: TLayaDBStats);
begin
      FDTable1.Refresh;

      Memo1.Lines.Add( AStats.asTable );
      Memo1.Lines.Add( '' );
      Memo1.Lines.Add( AStats.asText );

end;

procedure TTest_Revisor.LayaDBAnalyzer1Progress(Sender: TObject; ACurrent, ATotal: Integer; var ACancel: Boolean);
begin
     Label1.Caption := Format('Evaluando %d de %d', [ACurrent, ATotal]);
end;

procedure TTest_Revisor.LayaEvaluator1Finish(Sender: TObject);
begin
     Label1.Caption := 'Evaluación terminada';

     TFile.WriteAllText(Format('C:\LAYA\evaluacion_%s.txt', [FormatDateTime('yyyymmdd_hhnnss', Now)]), LayaEvaluator1.AsText, TEncoding.UTF8);
end;


procedure TTest_Revisor.btnExportarClick(Sender: TObject);
var
  S: TLayaExportStats;
begin
  FDTable1.Filtered := False;   // exportar todos los casos, no solo los de test

  LayaTrainingExporter1.Execute;

  S := LayaTrainingExporter1.Stats;
  Memo1.Lines.Text := Format(
    'Registros revisados:'#9'%d' + sLineBreak +
    'Filas escritas:'#9'%d' + sLineBreak +
    '  train:'#9'%d' + sLineBreak +
    '  test:'#9'%d' + sLineBreak +
    'Respuestas exportadas:'#9'%d' + sLineBreak +
    'Sin respuestas legibles:'#9'%d' + sLineBreak +
    'Sin texto:'#9'%d',
    [S.Records, S.Written, S.Train, S.Test, S.Questions, S.NoGold, S.NoText]);

end;

end.
