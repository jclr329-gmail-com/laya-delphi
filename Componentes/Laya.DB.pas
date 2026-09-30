unit Laya.DB;

{ LAYA para Delphi
  Copyright 2026 Carlos Liñán
  Licensed under the Apache License, Version 2.0.
  See LICENSE in the project root for details. }


(* LAYA components - analysis of database records.

  TLayaDBAnalyzer walks through a target dataset (e.g. PATIENTS), collects the
  text of each record from the source (e.g. REPORTS), asks the LAYA server and
  writes the answers back into fields of the target dataset.

  LinkMode (where the text comes from):
    lmSameDataSet   FieldsSource are fields of the target record itself.
    lmMasterDetail  DataSetSource is already a detail of DataSetTarget
                    (MasterSource / MasterFields): all its visible records are
                    used for the current target record.
    lmFilter        DataSetSource is filtered with
                    FieldKeySource = <value of FieldKeyTarget>.

  Long texts are split into chunks of ChunkSize characters (with ChunkOverlap)
  and every report is sent separately. The answers of all chunks and reports
  are combined with the Aggregation of each question (see
  TLayaResults.Aggregate). The combined answers go to Results (if assigned).

  Mappings: one item per question to write.
    FieldAnswer       field for the answer (see AnswerFormat).
    FieldProbability  float field: P(true) for noul, probability of the
                      answer for choice/score.
    FieldDecision     string field: 'accepted', 'review' or 'rejected'.
    WriteMode         wmDecidedOnly leaves FieldAnswer NULL when the decision
                      is 'review'.

  The process is asynchronous: Execute returns immediately and the work goes
  on record by record; every event runs in the main thread. OnFinish is
  always fired at the end (also after Cancel or an error). *)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Diagnostics, Data.DB,
  Laya.Questions, Laya.Results, Laya.Client;

type
  TLayaLinkMode = (lmSameDataSet, lmMasterDetail, lmFilter);
  TLayaProcessMode = (pmAll, pmEmpty);
  TLayaAnswerFormat = (afAuto, afKey, afCaption, afLevel, afScore);
  TLayaWriteMode = (wmAlways, wmDecidedOnly);

  TLayaFieldMapping = class(TCollectionItem)
  private
    FQuestionName: string;
    FAnswerField: string;
    FProbabilityField: string;
    FDecisionField: string;
    FAnswerFormat: TLayaAnswerFormat;
    FWriteMode: TLayaWriteMode;
    FTrueValue: string;
    FFalseValue: string;
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(Collection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property QuestionName: string read FQuestionName write FQuestionName;
    property FieldAnswer: string read FAnswerField write FAnswerField;
    property FieldProbability: string read FProbabilityField write FProbabilityField;
    property FieldDecision: string read FDecisionField write FDecisionField;
    property AnswerFormat: TLayaAnswerFormat read FAnswerFormat write FAnswerFormat default afAuto;
    property WriteMode: TLayaWriteMode read FWriteMode write FWriteMode default wmAlways;
    { Used by afAuto for noul answers written into string fields }
    property TrueValue: string read FTrueValue write FTrueValue;
    property FalseValue: string read FFalseValue write FFalseValue;
  end;

  TLayaFieldMappings = class(TOwnedCollection)
  private
    function GetItem(Index: Integer): TLayaFieldMapping;
  public
    constructor Create(AOwner: TPersistent);
    function Add: TLayaFieldMapping;
    property Items[Index: Integer]: TLayaFieldMapping read GetItem; default;
  end;

  TLayaDBStats = record
    Records: Integer;     // target records visited
    Processed: Integer;   // records analysed and written
    Skipped: Integer;     // locked, already filled, empty text or skipped by event
    Errors: Integer;
    Requests: Integer;    // calls to the server (one per chunk)
    Accepted: Integer;    // answers
    Review: Integer;
    Rejected: Integer;
    Cancelled: Boolean;
    ElapsedMs: Int64;
  private
    procedure GetPairs(out ANames, AValues: TArray<string>);
  public
    { One line per item: 'Registros:' + #9 + '14' }
    function AsText: string;
    { Two lines: names separated by #9, then values separated by #9
      (ready to paste into a spreadsheet) }
    function AsTable: string;
  end;

  TLayaBeforeRecordEvent = procedure(Sender: TObject; var ASkip: Boolean) of object;
  TLayaPrepareTextEvent = procedure(Sender: TObject; ADataSet: TDataSet;
    var AText: string; var ASkip: Boolean) of object;
  TLayaAfterRecordEvent = procedure(Sender: TObject; AResults: TLayaResults;
    var AWrite: Boolean) of object;
  TLayaWriteValueEvent = procedure(Sender: TObject; AMapping: TLayaFieldMapping;
    AAnswer: TLayaAnswer; AField: TField; var AHandled: Boolean) of object;
  TLayaProgressEvent = procedure(Sender: TObject; ACurrent, ATotal: Integer;
    var ACancel: Boolean) of object;
  TLayaRecordErrorEvent = procedure(Sender: TObject; const AMessage: string;
    var AContinue: Boolean) of object;
  TLayaFinishEvent = procedure(Sender: TObject; const AStats: TLayaDBStats) of object;

  { Used by TLayaEvaluator (evaluation mode) }
  TLayaEvalRecordProc = reference to procedure(AResults: TLayaResults);
  TLayaEvalFinishProc = reference to procedure(const AStats: TLayaDBStats);

  TLayaDBAnalyzer = class(TComponent)
  private
    FServer: TLayaServer;
    FQuestions: TLayaQuestions;
    FResults: TLayaResults;
    FTargetDataSet: TDataSet;
    FTargetKeyField: string;
    FSourceDataSet: TDataSet;
    FSourceKeyField: string;
    FSourceFields: string;
    FLinkMode: TLayaLinkMode;
    FChunkSize: Integer;
    FChunkOverlap: Integer;
    FMappings: TLayaFieldMappings;
    FProcessMode: TLayaProcessMode;
    FLockField: string;
    FDateField: string;
    FModelField: string;
    FMaxRecords: Integer;
    FStopOnError: Boolean;
    FDisableControls: Boolean;

    FOnBeforeRecord: TLayaBeforeRecordEvent;
    FOnPrepareText: TLayaPrepareTextEvent;
    FOnAfterRecord: TLayaAfterRecordEvent;
    FOnWriteValue: TLayaWriteValueEvent;
    FOnProgress: TLayaProgressEvent;
    FOnRecordError: TLayaRecordErrorEvent;
    FOnFinish: TLayaFinishEvent;

    { Run state }
    FAlive: ILayaAlive;
    FBusy: Boolean;
    FCancel: Boolean;
    FSingle: Boolean;
    FCurrent: Integer;
    FTotal: Integer;
    FStats: TLayaDBStats;
    FStopwatch: TStopwatch;
    FChunks: TList<string>;
    FChunkIndex: Integer;
    FChunkResults: TObjectList<TLayaResults>;
    FInternalResults: TLayaResults;
    FBookmark: TBookmark;
    FTargetControlsDisabled: Boolean;
    FSourceControlsDisabled: Boolean;
    FOutputsDisabledOn: TLayaResults;
    FEvaluating: Boolean;
    FEvalOnRecord: TLayaEvalRecordProc;
    FEvalOnFinish: TLayaEvalFinishProc;

    procedure SetServer(const Value: TLayaServer);
    procedure SetQuestions(const Value: TLayaQuestions);
    procedure SetResults(const Value: TLayaResults);
    procedure SetTargetDataSet(const Value: TDataSet);
    procedure SetSourceDataSet(const Value: TDataSet);
    procedure SetMappings(const Value: TLayaFieldMappings);

    function ActiveResults: TLayaResults;
    procedure CheckConfig;
    procedure Start(ASingle: Boolean);
    procedure QueueNext(AMoveNext: Boolean);
    procedure ProcessRecord;
    procedure SendChunk;
    procedure ChunkDone(ASuccess: Boolean);
    procedure RecordFinished;
    procedure RecordError(const AMessage: string);
    procedure Finish;

    function IsAlreadyFilled: Boolean;
    function FieldsText(ADataSet: TDataSet): string;
    function KeyFilterExpression: string;
    procedure WriteRecord(AResults: TLayaResults);
    procedure WriteAnswer(AMapping: TLayaFieldMapping; AAnswer: TLayaAnswer; AField: TField);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Processes the target dataset from the first record }
    procedure Execute;
    { Processes only the current target record }
    procedure ExecuteCurrent;
    { Stops after the request in progress }
    procedure Cancel;

    (* Evaluation mode, used by TLayaEvaluator: processes only the records
       marked in FieldLock, writes nothing, and passes the combined answers of
       each record to AOnRecord (with the target positioned on that record).
       OnAfterRecord and OnFinish are not fired; AOnFinish is. *)
    procedure ExecuteEvaluation(AOnRecord: TLayaEvalRecordProc;
      AOnFinish: TLayaEvalFinishProc);

    { Helpers shared with TLayaEvaluator and TLayaTrainingExporter }
    function ActiveQuestions: TLayaQuestions;
    { True if the current target record is marked in FieldLock }
    function IsLocked: Boolean;
    { Texts of the current target record (one per source record) }
    procedure CollectTexts(ATexts: TList<string>);
    { First mapping of the question that writes an answer field, or nil }
    function FindAnswerMapping(const AQuestion: string): TLayaFieldMapping;

    property Busy: Boolean read FBusy;
    property Evaluating: Boolean read FEvaluating;
    property Stats: TLayaDBStats read FStats;
  published
    property Server: TLayaServer read FServer write SetServer;
    { Optional: if empty, Server.Questions is used }
    property Questions: TLayaQuestions read FQuestions write SetQuestions;
    { Optional: receives the combined answers of each record }
    property Results: TLayaResults read FResults write SetResults;

    property DataSetTarget: TDataSet read FTargetDataSet write SetTargetDataSet;
    property FieldKeyTarget: string read FTargetKeyField write FTargetKeyField;
    property DataSetSource: TDataSet read FSourceDataSet write SetSourceDataSet;
    property FieldKeySource: string read FSourceKeyField write FSourceKeyField;
    { Field names separated by ';' }
    property FieldsSource: string read FSourceFields write FSourceFields;
    property LinkMode: TLayaLinkMode read FLinkMode write FLinkMode default lmSameDataSet;

    property ChunkSize: Integer read FChunkSize write FChunkSize default 2000;
    property ChunkOverlap: Integer read FChunkOverlap write FChunkOverlap default 200;

    property Mappings: TLayaFieldMappings read FMappings write SetMappings;

    property ProcessMode: TLayaProcessMode read FProcessMode write FProcessMode default pmAll;
    { Records where this field is true / 'S' / 1 are never touched
      (e.g. data confirmed by a person) }
    property FieldLock: string read FLockField write FLockField;
    property FieldDate: string read FDateField write FDateField;
    property FieldModel: string read FModelField write FModelField;
    { 0 = no limit }
    property MaxRecords: Integer read FMaxRecords write FMaxRecords default 0;
    property StopOnError: Boolean read FStopOnError write FStopOnError default True;
    property DisableControls: Boolean read FDisableControls write FDisableControls default True;

    property OnBeforeRecord: TLayaBeforeRecordEvent read FOnBeforeRecord write FOnBeforeRecord;
    property OnPrepareText: TLayaPrepareTextEvent read FOnPrepareText write FOnPrepareText;
    property OnAfterRecord: TLayaAfterRecordEvent read FOnAfterRecord write FOnAfterRecord;
    property OnWriteValue: TLayaWriteValueEvent read FOnWriteValue write FOnWriteValue;
    property OnProgress: TLayaProgressEvent read FOnProgress write FOnProgress;
    property OnRecordError: TLayaRecordErrorEvent read FOnRecordError write FOnRecordError;
    property OnFinish: TLayaFinishEvent read FOnFinish write FOnFinish;
  end;

{ Splits a text into chunks of about ASize characters, cutting at spaces,
  with AOverlap characters repeated between consecutive chunks }
procedure LayaSplitText(const AText: string; ASize, AOverlap: Integer;
  AChunks: TList<string>);

implementation

resourcestring
  SDBBusy = 'El analizador ya está en marcha.';
  SDBNoServer = 'No se ha indicado el servidor (Server).';
  SDBNoQuestions = 'No hay preguntas: asigna Questions o Server.Questions.';
  SDBNoTarget = 'No se ha indicado DataSetTarget o no está abierto.';
  SDBNoSource = 'No se ha indicado DataSetSource o no está abierto.';
  SDBNoSourceFields = 'No se ha indicado FieldsSource.';
  SDBNoKeys = 'Con LinkMode = lmFilter hay que indicar FieldKeyTarget y FieldKeySource.';
  SDBNoMappings = 'No hay ninguna asignación en Mappings.';
  SDBUnknownQuestion = 'La asignación nº %d usa la pregunta "%s", que no existe o no está activa.';
  SDBServerNotReady = 'El servidor LAYA no responde: %s';
  SDBNullKey = 'El registro actual no tiene valor en %s.';
  SDBTargetMoved = 'No se pudo volver al registro que se estaba analizando.';
  SDBNoLockField = 'Para evaluar o exportar hay que indicar FieldLock: ' +
    'solo se usan los registros revisados por una persona.';

type
  TLayaDBAlive = class(TInterfacedObject, ILayaAlive)
  private
    FAlive: Boolean;
  public
    constructor Create;
    function IsAlive: Boolean;
    procedure Kill;
  end;

constructor TLayaDBAlive.Create;
begin
  inherited Create;
  FAlive := True;
end;

function TLayaDBAlive.IsAlive: Boolean;
begin
  Result := FAlive;
end;

procedure TLayaDBAlive.Kill;
begin
  FAlive := False;
end;

function IsSpace(C: Char): Boolean;
begin
  Result := CharInSet(C, [' ', #9, #10, #13]);
end;

procedure LayaSplitText(const AText: string; ASize, AOverlap: Integer;
  AChunks: TList<string>);
var
  S: string;
  L, Start, Stop, Cut: Integer;
begin
  S := Trim(AText);
  L := Length(S);
  if L = 0 then
    Exit;
  if (ASize <= 0) or (L <= ASize) then
  begin
    AChunks.Add(S);
    Exit;
  end;
  if AOverlap < 0 then
    AOverlap := 0;
  if AOverlap > ASize div 2 then
    AOverlap := ASize div 2;

  Start := 1;
  while Start <= L do
  begin
    Stop := Start + ASize - 1;
    if Stop >= L then
    begin
      AChunks.Add(Trim(Copy(S, Start, MaxInt)));
      Break;
    end;
    { cut at the last space of the second half of the chunk }
    Cut := Stop;
    while (Cut > Start + ASize div 2) and not IsSpace(S[Cut]) do
      Dec(Cut);
    if Cut <= Start + ASize div 2 then
      Cut := Stop;
    AChunks.Add(Trim(Copy(S, Start, Cut - Start + 1)));

    { next chunk starts AOverlap characters before, at the start of a word }
    Start := Cut + 1 - AOverlap;
    while (Start > 1) and (Start <= Cut) and not IsSpace(S[Start - 1]) do
      Inc(Start);
  end;
end;

{ TLayaDBStats }

procedure TLayaDBStats.GetPairs(out ANames, AValues: TArray<string>);
begin
  ANames := TArray<string>.Create(
    'Registros', 'Procesados', 'Saltados', 'Errores',
    'Respuestas aceptadas', 'Respuestas a revisar', 'Respuestas rechazadas',
    'Peticiones al servidor', 'Tiempo');
  AValues := TArray<string>.Create(
    IntToStr(Records), IntToStr(Processed), IntToStr(Skipped), IntToStr(Errors),
    IntToStr(Accepted), IntToStr(Review), IntToStr(Rejected),
    IntToStr(Requests), Format('%.1f s', [ElapsedMs / 1000]));
end;

function TLayaDBStats.AsText: string;
var
  Names, Values: TArray<string>;
  I: Integer;
begin
  GetPairs(Names, Values);
  Result := '';
  for I := 0 to High(Names) do
  begin
    if I > 0 then
      Result := Result + sLineBreak;
    Result := Result + Names[I] + ':' + #9 + Values[I];
  end;
end;

function TLayaDBStats.AsTable: string;
var
  Names, Values: TArray<string>;
begin
  GetPairs(Names, Values);
  Result := string.Join(#9, Names) + sLineBreak + string.Join(#9, Values);
end;

{ TLayaFieldMapping }

constructor TLayaFieldMapping.Create(Collection: TCollection);
begin
  inherited Create(Collection);
  FAnswerFormat := afAuto;
  FWriteMode := wmAlways;
  FTrueValue := 'S';
  FFalseValue := 'N';
end;

procedure TLayaFieldMapping.Assign(Source: TPersistent);
var
  Src: TLayaFieldMapping;
begin
  if Source is TLayaFieldMapping then
  begin
    Src := TLayaFieldMapping(Source);
    FQuestionName := Src.FQuestionName;
    FAnswerField := Src.FAnswerField;
    FProbabilityField := Src.FProbabilityField;
    FDecisionField := Src.FDecisionField;
    FAnswerFormat := Src.FAnswerFormat;
    FWriteMode := Src.FWriteMode;
    FTrueValue := Src.FTrueValue;
    FFalseValue := Src.FFalseValue;
  end
  else
    inherited Assign(Source);
end;

function TLayaFieldMapping.GetDisplayName: string;
begin
  if FQuestionName = '' then
    Result := inherited GetDisplayName
  else
    Result := FQuestionName + ' -> ' + FAnswerField;
end;

{ TLayaFieldMappings }

constructor TLayaFieldMappings.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TLayaFieldMapping);
end;

function TLayaFieldMappings.Add: TLayaFieldMapping;
begin
  Result := TLayaFieldMapping(inherited Add);
end;

function TLayaFieldMappings.GetItem(Index: Integer): TLayaFieldMapping;
begin
  Result := TLayaFieldMapping(inherited Items[Index]);
end;

{ TLayaDBAnalyzer }

constructor TLayaDBAnalyzer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAlive := TLayaDBAlive.Create;
  FMappings := TLayaFieldMappings.Create(Self);
  FChunks := TList<string>.Create;
  FChunkResults := TObjectList<TLayaResults>.Create(True);
  FInternalResults := TLayaResults.Create(nil);
  FLinkMode := lmSameDataSet;
  FChunkSize := 2000;
  FChunkOverlap := 200;
  FProcessMode := pmAll;
  FStopOnError := True;
  FDisableControls := True;
end;

destructor TLayaDBAnalyzer.Destroy;
begin
  FAlive.Kill;
  FInternalResults.Free;
  FChunkResults.Free;
  FChunks.Free;
  FMappings.Free;
  inherited;
end;

procedure TLayaDBAnalyzer.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FServer then
      FServer := nil;
    if AComponent = FQuestions then
      FQuestions := nil;
    if AComponent = FResults then
      FResults := nil;
    if AComponent = FOutputsDisabledOn then
      FOutputsDisabledOn := nil;
    if AComponent = FTargetDataSet then
      FTargetDataSet := nil;
    if AComponent = FSourceDataSet then
      FSourceDataSet := nil;
  end;
end;

procedure TLayaDBAnalyzer.SetServer(const Value: TLayaServer);
begin
  if FServer <> nil then
    FServer.RemoveFreeNotification(Self);
  FServer := Value;
  if FServer <> nil then
    FServer.FreeNotification(Self);
end;

procedure TLayaDBAnalyzer.SetQuestions(const Value: TLayaQuestions);
begin
  if FQuestions <> nil then
    FQuestions.RemoveFreeNotification(Self);
  FQuestions := Value;
  if FQuestions <> nil then
    FQuestions.FreeNotification(Self);
end;

procedure TLayaDBAnalyzer.SetResults(const Value: TLayaResults);
begin
  if FResults <> nil then
    FResults.RemoveFreeNotification(Self);
  FResults := Value;
  if FResults <> nil then
    FResults.FreeNotification(Self);
end;

procedure TLayaDBAnalyzer.SetTargetDataSet(const Value: TDataSet);
begin
  if FTargetDataSet <> nil then
    FTargetDataSet.RemoveFreeNotification(Self);
  FTargetDataSet := Value;
  if FTargetDataSet <> nil then
    FTargetDataSet.FreeNotification(Self);
end;

procedure TLayaDBAnalyzer.SetSourceDataSet(const Value: TDataSet);
begin
  if FSourceDataSet <> nil then
    FSourceDataSet.RemoveFreeNotification(Self);
  FSourceDataSet := Value;
  if FSourceDataSet <> nil then
    FSourceDataSet.FreeNotification(Self);
end;

procedure TLayaDBAnalyzer.SetMappings(const Value: TLayaFieldMappings);
begin
  FMappings.Assign(Value);
end;

function TLayaDBAnalyzer.ActiveQuestions: TLayaQuestions;
begin
  Result := FQuestions;
  if (Result = nil) and (FServer <> nil) then
    Result := FServer.Questions;
end;

function TLayaDBAnalyzer.ActiveResults: TLayaResults;
begin
  if FResults <> nil then
    Result := FResults
  else
    Result := FInternalResults;
end;

procedure TLayaDBAnalyzer.CheckConfig;
var
  I: Integer;
  Q: TLayaQuestions;
  QI: TLayaQuestion;
  M: TLayaFieldMapping;
begin
  if FBusy then
    raise ELayaError.Create(SDBBusy);
  if FServer = nil then
    raise ELayaError.Create(SDBNoServer);
  Q := ActiveQuestions;
  if Q = nil then
    raise ELayaError.Create(SDBNoQuestions);
  Q.Validate;
  if (FTargetDataSet = nil) or not FTargetDataSet.Active then
    raise ELayaError.Create(SDBNoTarget);
  if (FLinkMode <> lmSameDataSet) and
     ((FSourceDataSet = nil) or not FSourceDataSet.Active) then
    raise ELayaError.Create(SDBNoSource);
  if Trim(FSourceFields) = '' then
    raise ELayaError.Create(SDBNoSourceFields);
  if (FLinkMode = lmFilter) and
     ((Trim(FTargetKeyField) = '') or (Trim(FSourceKeyField) = '')) then
    raise ELayaError.Create(SDBNoKeys);
  if FMappings.Count = 0 then
    raise ELayaError.Create(SDBNoMappings);

  { every field name must exist: FieldByName raises a clear error if not }
  for I := 0 to FMappings.Count - 1 do
  begin
    M := FMappings[I];

    {QI := Q.FindQuestion(M.QuestionName);
    if (QI = nil) or not QI.Enabled then
      raise ELayaError.CreateFmt(SDBUnknownQuestion, [I, M.QuestionName]);}

    QI := Q.FindQuestion(M.QuestionName);
    if QI = nil then
      raise ELayaError.CreateFmt(SDBUnknownQuestion, [I, M.QuestionName]);
    if not QI.Enabled then
      Continue;   // pregunta desactivada: se ignora su asignación

    if M.FieldAnswer <> '' then
      FTargetDataSet.FieldByName(M.FieldAnswer);
    if M.FieldProbability <> '' then
      FTargetDataSet.FieldByName(M.FieldProbability);
    if M.FieldDecision <> '' then
      FTargetDataSet.FieldByName(M.FieldDecision);
  end;
  if FLockField <> '' then
    FTargetDataSet.FieldByName(FLockField);
  if FDateField <> '' then
    FTargetDataSet.FieldByName(FDateField);
  if FModelField <> '' then
    FTargetDataSet.FieldByName(FModelField);
  if FTargetKeyField <> '' then
    FTargetDataSet.FieldByName(FTargetKeyField);
end;

procedure TLayaDBAnalyzer.Execute;
begin
  Start(False);
end;

procedure TLayaDBAnalyzer.ExecuteCurrent;
begin
  Start(True);
end;

procedure TLayaDBAnalyzer.Cancel;
begin
  FCancel := True;
end;

procedure TLayaDBAnalyzer.ExecuteEvaluation(AOnRecord: TLayaEvalRecordProc;
  AOnFinish: TLayaEvalFinishProc);
begin
  if FBusy then
    raise ELayaError.Create(SDBBusy);
  if Trim(FLockField) = '' then
    raise ELayaError.Create(SDBNoLockField);
  FEvalOnRecord := AOnRecord;
  FEvalOnFinish := AOnFinish;
  FEvaluating := True;
  try
    Start(False);
  except
    FEvaluating := False;
    FEvalOnRecord := nil;
    FEvalOnFinish := nil;
    raise;
  end;
end;

function TLayaDBAnalyzer.FindAnswerMapping(const AQuestion: string): TLayaFieldMapping;
var
  I: Integer;
begin
  for I := 0 to FMappings.Count - 1 do
    if SameText(FMappings[I].QuestionName, AQuestion) and
       (FMappings[I].FieldAnswer <> '') then
      Exit(FMappings[I]);
  Result := nil;
end;

procedure TLayaDBAnalyzer.Start(ASingle: Boolean);
begin
  CheckConfig;
  if not FServer.CheckHealth then
    raise ELayaError.CreateFmt(SDBServerNotReady, [FServer.LastError]);

  FStats := Default(TLayaDBStats);
  FStopwatch := TStopwatch.StartNew;
  FBusy := True;
  FCancel := False;
  FSingle := ASingle;
  FCurrent := 0;

  if ASingle then
    FTotal := 1
  else
  begin
    FTotal := FTargetDataSet.RecordCount;
    if (FMaxRecords > 0) and ((FTotal < 0) or (FTotal > FMaxRecords)) then
      FTotal := FMaxRecords;
  end;

  FTargetControlsDisabled := False;
  FSourceControlsDisabled := False;
  FOutputsDisabledOn := nil;
  if FDisableControls then
  begin
    { the memos of Results are not refreshed either until the end }
    if FResults <> nil then
    begin
      FResults.DisableOutputs;
      FOutputsDisabledOn := FResults;
      FOutputsDisabledOn.FreeNotification(Self);
    end;
    { in master-detail the detail must keep following the master, and
      DisableControls on the master would stop it }
    if FLinkMode <> lmMasterDetail then
    begin
      FTargetDataSet.DisableControls;
      FTargetControlsDisabled := True;
    end;
    if (FSourceDataSet <> nil) and (FSourceDataSet <> FTargetDataSet) and
       (FLinkMode <> lmSameDataSet) then
    begin
      FSourceDataSet.DisableControls;
      FSourceControlsDisabled := True;
    end;
  end;

  if not ASingle then
    FTargetDataSet.First;
  QueueNext(False);
end;

(* Continues in a later message cycle: keeps the window responsive and
   avoids deep recursion when many records are skipped *)
procedure TLayaDBAnalyzer.QueueNext(AMoveNext: Boolean);
var
  Alive: ILayaAlive;
begin
  Alive := FAlive;
  if AMoveNext and not FSingle and (FTargetDataSet <> nil) then
    FTargetDataSet.Next;
  TThread.ForceQueue(nil,
    procedure
    begin
      if Alive.IsAlive then
        ProcessRecord;
    end);
end;

procedure TLayaDBAnalyzer.ProcessRecord;
var
  Texts: TList<string>;
  S: string;
  Skip, StopNow: Boolean;
begin
  if (FTargetDataSet = nil) or (FServer = nil) or FCancel or
     FTargetDataSet.Eof or (FSingle and (FCurrent >= 1)) or
     ((FMaxRecords > 0) and (FCurrent >= FMaxRecords)) then
  begin
    Finish;
    Exit;
  end;

  Inc(FCurrent);
  Inc(FStats.Records);

  StopNow := False;
  if Assigned(FOnProgress) then
    FOnProgress(Self, FCurrent, FTotal, StopNow);
  if StopNow then
  begin
    FCancel := True;
    Finish;
    Exit;
  end;

  try
    if FEvaluating then
      Skip := not IsLocked   // evaluation: only the records reviewed by a person
    else
      Skip := IsLocked or ((FProcessMode = pmEmpty) and IsAlreadyFilled);
    if not Skip and Assigned(FOnBeforeRecord) then
      FOnBeforeRecord(Self, Skip);

    FChunks.Clear;
    if not Skip then
    begin
      Texts := TList<string>.Create;
      try
        CollectTexts(Texts);
        for S in Texts do
          LayaSplitText(S, FChunkSize, FChunkOverlap, FChunks);
      finally
        Texts.Free;
      end;
    end;

    if Skip or (FChunks.Count = 0) then
    begin
      Inc(FStats.Skipped);
      QueueNext(True);
      Exit;
    end;

    FBookmark := FTargetDataSet.Bookmark;
    FChunkResults.Clear;
    FChunkIndex := 0;
    SendChunk;
  except
    on E: Exception do
      RecordError(E.Message);
  end;
end;

procedure TLayaDBAnalyzer.SendChunk;
var
  R: TLayaResults;
  Alive: ILayaAlive;
begin
  R := TLayaResults.Create(nil);
  FChunkResults.Add(R);
  Inc(FStats.Requests);
  { show the text being analysed, only when the controls are not disabled }
  if not FDisableControls and (ActiveQuestions.InTXT <> nil) then
    ActiveQuestions.InTXT.Lines.Text := FChunks[FChunkIndex];
  Alive := FAlive;
  FServer.PredictAsync(FChunks[FChunkIndex], ActiveQuestions, R,
    procedure(ASuccess: Boolean)
    begin
      if Alive.IsAlive then
        ChunkDone(ASuccess);
    end);
end;

procedure TLayaDBAnalyzer.ChunkDone(ASuccess: Boolean);
begin
  if not ASuccess then
  begin
    RecordError(FServer.LastError);
    Exit;
  end;
  try
    Inc(FChunkIndex);
    if FChunkIndex < FChunks.Count then
      SendChunk
    else
      RecordFinished;
  except
    on E: Exception do
      RecordError(E.Message);
  end;
end;

procedure TLayaDBAnalyzer.RecordFinished;
var
  Res: TLayaResults;
  DoWrite: Boolean;
  I: Integer;
begin
  Res := ActiveResults;
  Res.Aggregate(FChunkResults.ToArray, ActiveQuestions);

  if FEvaluating then
  begin
    try
      FTargetDataSet.Bookmark := FBookmark;
    except
      raise ELayaError.Create(SDBTargetMoved);
    end;
    if Assigned(FEvalOnRecord) then
      FEvalOnRecord(Res);
    Inc(FStats.Processed);
    for I := 0 to Res.Count - 1 do
      case Res[I].Decision of
        ldAccepted: Inc(FStats.Accepted);
        ldReview: Inc(FStats.Review);
        ldRejected: Inc(FStats.Rejected);
      end;
    QueueNext(True);
    Exit;
  end;

  DoWrite := True;
  if Assigned(FOnAfterRecord) then
    FOnAfterRecord(Self, Res, DoWrite);

  if DoWrite then
  begin
    { go back to the analysed record, in case the cursor moved meanwhile }
    try
      FTargetDataSet.Bookmark := FBookmark;
    except
      raise ELayaError.Create(SDBTargetMoved);
    end;
    WriteRecord(Res);
    Inc(FStats.Processed);
    for I := 0 to Res.Count - 1 do
      case Res[I].Decision of
        ldAccepted: Inc(FStats.Accepted);
        ldReview: Inc(FStats.Review);
        ldRejected: Inc(FStats.Rejected);
      end;
  end
  else
    Inc(FStats.Skipped);

  QueueNext(True);
end;

procedure TLayaDBAnalyzer.RecordError(const AMessage: string);
var
  Continue_: Boolean;
begin
  Inc(FStats.Errors);
  if (FTargetDataSet <> nil) and (FTargetDataSet.State in dsEditModes) then
    FTargetDataSet.Cancel;

  Continue_ := not FStopOnError;
  if Assigned(FOnRecordError) then
    FOnRecordError(Self, AMessage, Continue_);

  if Continue_ then
    QueueNext(True)
  else
  begin
    FCancel := True;
    Finish;
  end;
end;

procedure TLayaDBAnalyzer.Finish;
begin
  if not FBusy then
    Exit;
  FBusy := False;
  FChunkResults.Clear;
  FChunks.Clear;
  if FTargetControlsDisabled and (FTargetDataSet <> nil) then
    FTargetDataSet.EnableControls;
  if FSourceControlsDisabled and (FSourceDataSet <> nil) then
    FSourceDataSet.EnableControls;
  FTargetControlsDisabled := False;
  FSourceControlsDisabled := False;
  if FOutputsDisabledOn <> nil then
  begin
    FOutputsDisabledOn.EnableOutputs;   // shows the last record
    if FOutputsDisabledOn <> FResults then
      FOutputsDisabledOn.RemoveFreeNotification(Self);
    FOutputsDisabledOn := nil;
  end;
  FStats.Cancelled := FCancel;
  FStats.ElapsedMs := FStopwatch.ElapsedMilliseconds;
  if FEvaluating then
  begin
    FEvaluating := False;
    FEvalOnRecord := nil;
    if Assigned(FEvalOnFinish) then
      FEvalOnFinish(FStats);
    FEvalOnFinish := nil;
  end
  else if Assigned(FOnFinish) then
    FOnFinish(Self, FStats);
end;

function TLayaDBAnalyzer.IsLocked: Boolean;
var
  F: TField;
  S: string;
begin
  Result := False;
  if FLockField = '' then
    Exit;
  F := FTargetDataSet.FieldByName(FLockField);
  if F.IsNull then
    Exit;
  if F.DataType = ftBoolean then
    Result := F.AsBoolean
  else
  begin
    S := Trim(F.AsString);
    Result := (S <> '') and not SameText(S, '0') and not SameText(S, 'N') and
      not SameText(S, 'F') and not SameText(S, 'False') and not SameText(S, 'No');
  end;
end;

function TLayaDBAnalyzer.IsAlreadyFilled: Boolean;
var
  I: Integer;
begin
  { the record needs work if any answer field is still NULL }
  for I := 0 to FMappings.Count - 1 do
    if (FMappings[I].FieldAnswer <> '') and
       FTargetDataSet.FieldByName(FMappings[I].FieldAnswer).IsNull then
      Exit(False);
  Result := True;
end;

function TLayaDBAnalyzer.FieldsText(ADataSet: TDataSet): string;
var
  Names: TArray<string>;
  I: Integer;
  N, V: string;
  Multi: Boolean;
begin
  Result := '';
  Names := FSourceFields.Split([';', ','], TStringSplitOptions.ExcludeEmpty);
  Multi := Length(Names) > 1;
  for I := 0 to High(Names) do
  begin
    N := Trim(Names[I]);
    if N = '' then
      Continue;
    V := Trim(ADataSet.FieldByName(N).AsString);
    if V = '' then
      Continue;
    if Result <> '' then
      Result := Result + sLineBreak;
    if Multi then
      Result := Result + N + ': ' + V
    else
      Result := Result + V;
  end;
end;

function TLayaDBAnalyzer.KeyFilterExpression: string;
var
  F: TField;
begin
  F := FTargetDataSet.FieldByName(FTargetKeyField);
  if F.IsNull then
    raise ELayaError.CreateFmt(SDBNullKey, [FTargetKeyField]);
  if F.DataType in [ftSmallint, ftInteger, ftWord, ftAutoInc, ftLargeint,
    ftShortint, ftByte, ftLongWord] then
    Result := FSourceKeyField + ' = ' + F.AsString
  else
    Result := FSourceKeyField + ' = ' + QuotedStr(F.AsString);
end;

procedure TLayaDBAnalyzer.CollectTexts(ATexts: TList<string>);

  procedure AddFrom(ADataSet: TDataSet);
  var
    S: string;
    Skip: Boolean;
  begin
    S := FieldsText(ADataSet);
    Skip := False;
    if Assigned(FOnPrepareText) then
      FOnPrepareText(Self, ADataSet, S, Skip);
    if not Skip and (Trim(S) <> '') then
      ATexts.Add(S);
  end;

var
  SavedFilter: string;
  SavedFiltered: Boolean;
begin
  case FLinkMode of
    lmSameDataSet:
      AddFrom(FTargetDataSet);

    lmMasterDetail:
      begin
        FSourceDataSet.First;
        while not FSourceDataSet.Eof do
        begin
          AddFrom(FSourceDataSet);
          FSourceDataSet.Next;
        end;
      end;

    lmFilter:
      begin
        SavedFilter := FSourceDataSet.Filter;
        SavedFiltered := FSourceDataSet.Filtered;
        try
          FSourceDataSet.Filtered := False;
          FSourceDataSet.Filter := KeyFilterExpression;
          FSourceDataSet.Filtered := True;
          FSourceDataSet.First;
          while not FSourceDataSet.Eof do
          begin
            AddFrom(FSourceDataSet);
            FSourceDataSet.Next;
          end;
        finally
          FSourceDataSet.Filtered := False;
          FSourceDataSet.Filter := SavedFilter;
          FSourceDataSet.Filtered := SavedFiltered;
        end;
      end;
  end;
end;

procedure TLayaDBAnalyzer.WriteAnswer(AMapping: TLayaFieldMapping;
  AAnswer: TLayaAnswer; AField: TField);
begin
  case AMapping.AnswerFormat of
    afKey:
      AField.AsString := AAnswer.Answer;
    afCaption:
      AField.AsString := AAnswer.AnswerCaption;
    afLevel:
      AField.AsInteger := AAnswer.Level;
    afScore:
      if AAnswer.Kind = qkNoul then
        AField.AsFloat := AAnswer.PTrue
      else
        AField.AsFloat := AAnswer.Score;
  else  { afAuto }
    case AAnswer.Kind of
      qkNoul:
        if AField.DataType = ftBoolean then
          AField.AsBoolean := AAnswer.AsBoolean
        else if AField is TNumericField then
          AField.AsInteger := Ord(AAnswer.AsBoolean)
        else if AAnswer.AsBoolean then
          AField.AsString := AMapping.TrueValue
        else
          AField.AsString := AMapping.FalseValue;
      qkScore:
        if AField is TNumericField then
          AField.AsInteger := AAnswer.Level
        else
          AField.AsString := AAnswer.AnswerCaption;
    else  { qkChoice }
      AField.AsString := AAnswer.Answer;
    end;
  end;
end;

procedure TLayaDBAnalyzer.WriteRecord(AResults: TLayaResults);
var
  I: Integer;
  M: TLayaFieldMapping;
  A: TLayaAnswer;
  F: TField;
  Handled: Boolean;
begin
  FTargetDataSet.Edit;
  try
    for I := 0 to FMappings.Count - 1 do
    begin
      M := FMappings[I];
      A := AResults.ByName(M.QuestionName);
      if A = nil then
        Continue;

      if M.FieldAnswer <> '' then
      begin
        F := FTargetDataSet.FieldByName(M.FieldAnswer);
        Handled := False;
        if Assigned(FOnWriteValue) then
          FOnWriteValue(Self, M, A, F, Handled);
        if not Handled then
        begin
          if (M.WriteMode = wmDecidedOnly) and (A.Decision = ldReview) then
            F.Clear
          else
            WriteAnswer(M, A, F);
        end;
      end;

      if M.FieldProbability <> '' then
      begin
        if A.Kind = qkNoul then
          FTargetDataSet.FieldByName(M.FieldProbability).AsFloat := A.PTrue
        else
          FTargetDataSet.FieldByName(M.FieldProbability).AsFloat := A.Probability;
      end;

      if M.FieldDecision <> '' then
        FTargetDataSet.FieldByName(M.FieldDecision).AsString := A.DecisionName;
    end;

    if FDateField <> '' then
      FTargetDataSet.FieldByName(FDateField).AsDateTime := Now;
    if FModelField <> '' then
      FTargetDataSet.FieldByName(FModelField).AsString := FServer.ModelName;

    FTargetDataSet.Post;
  except
    FTargetDataSet.Cancel;
    raise;
  end;
end;

end.
