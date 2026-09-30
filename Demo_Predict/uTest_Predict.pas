unit uTest_Predict;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Laya.Results, Laya.Questions, Laya.Client, Vcl.StdCtrls, Vcl.ExtCtrls, Laya.DB, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs, FireDAC.Phys.SQLiteWrapper.Stat, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Stan.Param,
  FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, Vcl.Buttons, Vcl.DBCtrls, FireDAC.Comp.DataSet, Vcl.Grids, Vcl.DBGrids, Vcl.Mask;

type
  TFTestPredict = class(TForm)
    LayaServer1: TLayaServer;
    LayaQuestions1: TLayaQuestions;
    LayaResults1: TLayaResults;
    Panel2: TPanel;
    Panel1: TPanel;
    Memo1: TMemo;
    Splitter1: TSplitter;
    Memo2: TMemo;
    Splitter2: TSplitter;
    Panel3: TPanel;
    FDConnection1: TFDConnection;
    FDTable1: TFDTable;
    DataSource1: TDataSource;
    DBNavigator1: TDBNavigator;
    FDTable1id: TFDAutoIncField;
    FDTable1Pregunta: TWideMemoField;
    FDTable1Departamento_text: TStringField;
    FDTable1Departamento_prct: TFloatField;
    FDTable1Departamento_dec: TStringField;
    FDTable1Urgencia_key: TIntegerField;
    FDTable1Urgencia_name: TStringField;
    FDTable1Urgencia_prct: TFloatField;
    FDTable1Baja_name: TStringField;
    FDTable1Baja_prct: TFloatField;
    FDTable1Baja_dec: TStringField;
    FDTable1Revisado: TIntegerField;
    FDTable1Fecha_analisis: TDateTimeField;
    FDTable1Modelo: TStringField;
    Label2: TLabel;
    DBMemo1: TDBMemo;
    Label3: TLabel;
    DBEdit1: TDBEdit;
    Label4: TLabel;
    DBEdit2: TDBEdit;
    Label5: TLabel;
    DBEdit3: TDBEdit;
    Label6: TLabel;
    DBEdit4: TDBEdit;
    Label7: TLabel;
    DBEdit5: TDBEdit;
    Label8: TLabel;
    DBEdit6: TDBEdit;
    Label9: TLabel;
    DBEdit7: TDBEdit;
    Label10: TLabel;
    DBEdit8: TDBEdit;
    Label11: TLabel;
    DBEdit9: TDBEdit;
    Label12: TLabel;
    DBEdit10: TDBEdit;
    Label13: TLabel;
    DBEdit11: TDBEdit;
    Label14: TLabel;
    DBEdit12: TDBEdit;
    LayaDBAnalyzer1: TLayaDBAnalyzer;
    Label15: TLabel;
    DBEdit13: TDBEdit;
    Panel4: TPanel;
    btnEste: TButton;
    btnAnalizar: TButton;
    CheckBox1: TCheckBox;
    Memo3: TMemo;
    Label16: TLabel;
    Label17: TLabel;
    Splitter3: TSplitter;
    Label18: TLabel;
    Panel5: TPanel;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    RadioButton1: TRadioButton;
    RadioButton2: TRadioButton;
    Label1: TLabel;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure LayaResults1Change(Sender: TObject);
    procedure RadioButton2Click(Sender: TObject);
    procedure RadioButton1Click(Sender: TObject);
    procedure btnAnalizarClick(Sender: TObject);
    procedure LayaDBAnalyzer1Finish(Sender: TObject; const AStats: TLayaDBStats);
    procedure LayaDBAnalyzer1Progress(Sender: TObject; ACurrent, ATotal: Integer; var ACancel: Boolean);
    procedure btnEsteClick(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FTestPredict: TFTestPredict;

implementation

{$R *.dfm}




procedure TFTestPredict.Button1Click(Sender: TObject);
begin
     if LayaServer1.CheckHealth=true then Label1.Caption:='Ok' else Label1.Caption:='Error';
end;

procedure TFTestPredict.Button2Click(Sender: TObject);
begin
     if not LayaServer1.Predict( Memo1.Text ) then begin
        Memo2.Lines.Add('Error: ' + LayaServer1.LastError);
        Exit;
     end;
end;


procedure TFTestPredict.Button3Click(Sender: TObject);
begin
     if not LayaServer1.Predict then begin
        Memo2.Lines.Add('Error: ' + LayaServer1.LastError);
        Exit;
     end;
end;

procedure TFTestPredict.CheckBox1Click(Sender: TObject);
begin
     LayaDBAnalyzer1.DisableControls := CheckBox1.Checked;
end;

procedure TFTestPredict.FormCreate(Sender: TObject);
begin

     FDConnection1.Params.Database := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\Database\Clientes.sdb');

     Memo1.lines.clear;
     Memo1.lines.add( 'Cancelé hace dos semanas y sigo sin reembolso. Si no se soluciona me doy de baja.' ) ;

     RadioButton1.Checked := True;

     FDTable1.active := True;
end;


procedure TFTestPredict.LayaResults1Change(Sender: TObject);
begin
     Label1.Caption := Format('%d respuestas en %d ms', [LayaResults1.Count, LayaServer1.LastElapsedMs]);
end;

procedure TFTestPredict.RadioButton1Click(Sender: TObject);
begin
     LayaResults1.OutJSON := nil;
     LayaResults1.OutTXT := Memo2;

end;

procedure TFTestPredict.RadioButton2Click(Sender: TObject);
begin
     LayaResults1.OutJSON := Memo2;
     LayaResults1.OutTXT := nil;
end;


procedure TFTestPredict.btnAnalizarClick(Sender: TObject);
begin
     Memo3.lines.Clear;
     LayaDBAnalyzer1.Execute;
end;

procedure TFTestPredict.btnEsteClick(Sender: TObject);
begin
     Memo3.lines.Clear;
     LayaDBAnalyzer1.ExecuteCurrent;
end;



procedure TFTestPredict.LayaDBAnalyzer1Finish(Sender: TObject; const AStats: TLayaDBStats);
begin
      FDTable1.Refresh;

      Memo3.Lines.Add( AStats.asTable );
      Memo3.Lines.Add( '' );
      Memo3.Lines.Add( AStats.asText );

end;


procedure TFTestPredict.LayaDBAnalyzer1Progress(Sender: TObject; ACurrent, ATotal: Integer; var ACancel: Boolean);
begin
     Label1.Caption := Format('Registros: %d de %d. Completado %.0f %%', [ACurrent, ATotal,  ACurrent/ATotal*100 ]);
end;

end.
