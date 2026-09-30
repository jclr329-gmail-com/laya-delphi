unit Laya.Reg;

{ LAYA para Delphi
  Copyright 2026 Carlos Liñán
  Licensed under the Apache License, Version 2.0.
  See LICENSE in the project root for details. }


{ LAYA components - design-time registration.
  Palette page: LAYA }

interface

procedure Register;

implementation

uses
  System.Classes, System.SysUtils, System.UITypes, Data.DB, Vcl.Dialogs,
  DesignIntf, DesignEditors, ColnEdit,
  Laya.Questions, Laya.Results, Laya.Client, Laya.DB, Laya.DBEditor, Laya.Training;

type
  { ---- Object Inspector drop-down lists ---- }

  { Base: string property whose values are the field names of a dataset }
  TLayaFieldNameProperty = class(TStringProperty)
  protected
    function GetDataSet: TDataSet; virtual; abstract;
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;

  { Fields of DataSetTarget (FieldKeyTarget, FieldLock, FieldDate, FieldModel) }
  TLayaTargetFieldProperty = class(TLayaFieldNameProperty)
  protected
    function GetDataSet: TDataSet; override;
  end;

  { Fields of the source (DataSetTarget in lmSameDataSet, else DataSetSource) }
  TLayaSourceFieldProperty = class(TLayaFieldNameProperty)
  protected
    function GetDataSet: TDataSet; override;
  end;

  { Fields of DataSetTarget of the analyzer that owns the mapping }
  TLayaMappingFieldProperty = class(TLayaFieldNameProperty)
  protected
    function GetDataSet: TDataSet; override;
  end;

  { Fields of DataSetTarget of the exporter's analyzer (FieldSplit) }
  TLayaExporterFieldProperty = class(TLayaFieldNameProperty)
  protected
    function GetDataSet: TDataSet; override;
  end;

  { Question names of the analyzer that owns the mapping }
  TLayaQuestionNameProperty = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;

  TLayaServerEditor = class(TComponentEditor)
  public
    function GetVerbCount: Integer; override;
    function GetVerb(Index: Integer): string; override;
    procedure ExecuteVerb(Index: Integer); override;
  end;

  TLayaDBAnalyzerEditor = class(TComponentEditor)
  public
    procedure Edit; override;
    function GetVerbCount: Integer; override;
    function GetVerb(Index: Integer): string; override;
    procedure ExecuteVerb(Index: Integer); override;
  end;

  TLayaQuestionsEditor = class(TComponentEditor)
  public
    function GetVerbCount: Integer; override;
    function GetVerb(Index: Integer): string; override;
    procedure ExecuteVerb(Index: Integer); override;
  end;

function MappingAnalyzer(APersistent: TPersistent): TLayaDBAnalyzer;
var
  M: TLayaFieldMapping;
begin
  Result := nil;
  if APersistent is TLayaFieldMapping then
  begin
    M := TLayaFieldMapping(APersistent);
    if (M.Collection <> nil) and (M.Collection.Owner is TLayaDBAnalyzer) then
      Result := TLayaDBAnalyzer(M.Collection.Owner);
  end;
end;

{ TLayaFieldNameProperty }

function TLayaFieldNameProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paValueList, paSortList, paMultiSelect];
end;

procedure TLayaFieldNameProperty.GetValues(Proc: TGetStrProc);
var
  DS: TDataSet;
  L: TStringList;
  I: Integer;
begin
  DS := GetDataSet;
  if DS = nil then
    Exit;
  L := TStringList.Create;
  try
    try
      DS.GetFieldNames(L);
    except
      { closed dataset without connection: no list, the value can be typed }
      L.Clear;
    end;
    for I := 0 to L.Count - 1 do
      Proc(L[I]);
  finally
    L.Free;
  end;
end;

{ TLayaTargetFieldProperty }

function TLayaTargetFieldProperty.GetDataSet: TDataSet;
begin
  if GetComponent(0) is TLayaDBAnalyzer then
    Result := TLayaDBAnalyzer(GetComponent(0)).DataSetTarget
  else
    Result := nil;
end;

{ TLayaSourceFieldProperty }

function TLayaSourceFieldProperty.GetDataSet: TDataSet;
var
  A: TLayaDBAnalyzer;
begin
  Result := nil;
  if GetComponent(0) is TLayaDBAnalyzer then
  begin
    A := TLayaDBAnalyzer(GetComponent(0));
    if A.LinkMode = lmSameDataSet then
      Result := A.DataSetTarget
    else
      Result := A.DataSetSource;
  end;
end;

{ TLayaMappingFieldProperty }

function TLayaMappingFieldProperty.GetDataSet: TDataSet;
var
  A: TLayaDBAnalyzer;
begin
  A := MappingAnalyzer(GetComponent(0));
  if A <> nil then
    Result := A.DataSetTarget
  else
    Result := nil;
end;

{ TLayaExporterFieldProperty }

function TLayaExporterFieldProperty.GetDataSet: TDataSet;
begin
  Result := nil;
  if (GetComponent(0) is TLayaTrainingExporter) and
     (TLayaTrainingExporter(GetComponent(0)).Analyzer <> nil) then
    Result := TLayaTrainingExporter(GetComponent(0)).Analyzer.DataSetTarget;
end;

{ TLayaQuestionNameProperty }

function TLayaQuestionNameProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paValueList, paSortList, paMultiSelect];
end;

procedure TLayaQuestionNameProperty.GetValues(Proc: TGetStrProc);
var
  A: TLayaDBAnalyzer;
  Q: TLayaQuestions;
  I: Integer;
begin
  A := MappingAnalyzer(GetComponent(0));
  if A = nil then
    Exit;
  Q := A.Questions;
  if (Q = nil) and (A.Server <> nil) then
    Q := A.Server.Questions;
  if Q = nil then
    Exit;
  for I := 0 to Q.Count - 1 do
    if Q[I].Enabled then
      Proc(Q[I].Name);
end;

{ TLayaServerEditor }

function TLayaServerEditor.GetVerbCount: Integer;
begin
  Result := 2;
end;

function TLayaServerEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := 'Probar conexión...';
    1: Result := 'Cargar preguntas del servidor...';
  else
    Result := '';
  end;
end;

procedure TLayaServerEditor.ExecuteVerb(Index: Integer);
var
  S: TLayaServer;
begin
  S := Component as TLayaServer;
  case Index of
    0:
      if S.CheckHealth then
        ShowMessage(Format('Conexión correcta con %s' + sLineBreak +
          'Modelo: %s' + sLineBreak + 'Tiempo: %d ms',
          [S.BaseURL, S.ModelName, S.LastElapsedMs]))
      else
        ShowMessage('No se pudo conectar:' + sLineBreak + sLineBreak + S.LastError);
    1:
      begin
        if S.Questions = nil then
        begin
          ShowMessage('Asigna primero la propiedad Questions del servidor.');
          Exit;
        end;
        if (S.Questions.Count > 0) and
           (MessageDlg(Format('%s tiene %d preguntas. ¿Sustituirlas por las del servidor?',
             [S.Questions.Name, S.Questions.Count]),
             mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
          Exit;
        if S.LoadQuestions then
        begin
          Designer.Modified;
          ShowMessage(Format('Cargadas %d preguntas en %s.',
            [S.Questions.Count, S.Questions.Name]));
        end
        else
          ShowMessage('No se pudieron cargar las preguntas:' + sLineBreak + sLineBreak +
            S.LastError);
      end;
  end;
end;

{ TLayaQuestionsEditor }

function TLayaQuestionsEditor.GetVerbCount: Integer;
begin
  Result := 3;
end;

function TLayaQuestionsEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := 'Editar preguntas...';
    1: Result := 'Cargar desde archivo...';
    2: Result := 'Guardar en archivo...';
  else
    Result := '';
  end;
end;

procedure TLayaQuestionsEditor.ExecuteVerb(Index: Integer);
var
  Q: TLayaQuestions;
  OpenDlg: TOpenDialog;
  SaveDlg: TSaveDialog;
begin
  Q := Component as TLayaQuestions;
  case Index of
    0:
      ShowCollectionEditor(Designer, Q, Q.Items, 'Items');
    1:
      begin
        OpenDlg := TOpenDialog.Create(nil);
        try
          OpenDlg.Filter := 'Preguntas LAYA (*.json)|*.json|Todos (*.*)|*.*';
          if OpenDlg.Execute then
          begin
            Q.LoadFromFile(OpenDlg.FileName);
            Designer.Modified;
          end;
        finally
          OpenDlg.Free;
        end;
      end;
    2:
      begin
        SaveDlg := TSaveDialog.Create(nil);
        try
          SaveDlg.Filter := 'Preguntas LAYA (*.json)|*.json';
          SaveDlg.DefaultExt := 'json';
          SaveDlg.Options := SaveDlg.Options + [ofOverwritePrompt];
          if SaveDlg.Execute then
            Q.SaveToFile(SaveDlg.FileName);
        finally
          SaveDlg.Free;
        end;
      end;
  end;
end;

{ TLayaDBAnalyzerEditor }

procedure TLayaDBAnalyzerEditor.Edit;
begin
  ExecuteVerb(0);
end;

function TLayaDBAnalyzerEditor.GetVerbCount: Integer;
begin
  Result := 1;
end;

function TLayaDBAnalyzerEditor.GetVerb(Index: Integer): string;
begin
  Result := 'Configurar...';
end;

procedure TLayaDBAnalyzerEditor.ExecuteVerb(Index: Integer);
begin
  if LayaEditDBAnalyzer(Component as TLayaDBAnalyzer) then
    Designer.Modified;
end;

procedure Register;
begin
  RegisterComponents('LAYA', [TLayaServer, TLayaQuestions, TLayaResults,
    TLayaDBAnalyzer, TLayaEvaluator, TLayaTrainingExporter]);
  RegisterComponentEditor(TLayaServer, TLayaServerEditor);
  RegisterComponentEditor(TLayaQuestions, TLayaQuestionsEditor);
  RegisterComponentEditor(TLayaDBAnalyzer, TLayaDBAnalyzerEditor);

  RegisterPropertyEditor(TypeInfo(string), TLayaDBAnalyzer, 'FieldKeyTarget', TLayaTargetFieldProperty);
  RegisterPropertyEditor(TypeInfo(string), TLayaDBAnalyzer, 'FieldLock', TLayaTargetFieldProperty);
  RegisterPropertyEditor(TypeInfo(string), TLayaDBAnalyzer, 'FieldDate', TLayaTargetFieldProperty);
  RegisterPropertyEditor(TypeInfo(string), TLayaDBAnalyzer, 'FieldModel', TLayaTargetFieldProperty);
  RegisterPropertyEditor(TypeInfo(string), TLayaDBAnalyzer, 'FieldKeySource', TLayaSourceFieldProperty);
  RegisterPropertyEditor(TypeInfo(string), TLayaDBAnalyzer, 'FieldsSource', TLayaSourceFieldProperty);

  RegisterPropertyEditor(TypeInfo(string), TLayaFieldMapping, 'QuestionName', TLayaQuestionNameProperty);
  RegisterPropertyEditor(TypeInfo(string), TLayaFieldMapping, 'FieldAnswer', TLayaMappingFieldProperty);
  RegisterPropertyEditor(TypeInfo(string), TLayaFieldMapping, 'FieldProbability', TLayaMappingFieldProperty);
  RegisterPropertyEditor(TypeInfo(string), TLayaFieldMapping, 'FieldDecision', TLayaMappingFieldProperty);
  RegisterPropertyEditor(TypeInfo(string), TLayaTrainingExporter, 'FieldSplit', TLayaExporterFieldProperty);
end;

end.
