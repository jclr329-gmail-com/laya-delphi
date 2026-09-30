unit Laya.Training;

(* LAYA components - evaluation and training data.

  Both components work on top of a TLayaDBAnalyzer and reuse its whole
  configuration: DataSetTarget, FieldsSource, LinkMode, Mappings, questions
  and, above all, FieldLock. Only the records marked in FieldLock (reviewed by
  a person) are used: the values in their answer fields are the truth ("gold").

  TLayaEvaluator
    Runs the model again over the reviewed records (writing nothing) and
    compares its answers with the gold ones: accuracy per question, errors
    that were decided with confidence versus errors sent to review, confusion
    and a suggested AcceptThreshold for a target precision.

  TLayaTrainingExporter
    Writes the reviewed records as a JSON Lines file in the format of the
    LocalLLaMA/typed-decisions dataset (columns id, workflow, split, state,
    questions, gold, n_questions), which the official Laya fine-tuning
    notebook reads through its build_training_item function.

  Gold values are read back from the answer fields in the same formats that
  TLayaDBAnalyzer writes (key, caption, level, boolean, TrueValue/FalseValue). *)

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  System.Generics.Defaults, Data.DB, Vcl.StdCtrls,
  Laya.Questions, Laya.Results, Laya.Client, Laya.DB;

type
  TLayaEvalSample = record
    Confidence: Double;   // probability of the predicted answer
    Correct: Boolean;
    Decided: Boolean;     // accepted or rejected (not review)
  end;

  TLayaEvalError = record
    RecordKey: string;
    Question: string;
    Gold: string;
    Predicted: string;
    Probability: Double;
    Decision: TLayaDecision;
  end;

  TLayaQuestionEval = class
  private
    FName: string;
    FKind: TLayaQuestionKind;
    FTotal: Integer;
    FCorrect: Integer;
    FDecided: Integer;
    FDecidedWrong: Integer;
    FReview: Integer;
    FReviewCorrect: Integer;
    FProbGoldSum: Double;
    FSamples: TList<TLayaEvalSample>;
    FConfusion: TDictionary<string, Integer>;
  public
    constructor Create(const AName: string; AKind: TLayaQuestionKind);
    destructor Destroy; override;
    procedure Add(const AGold: string; AAnswer: TLayaAnswer);
    function Accuracy: Double;
    { Mean probability the model gave to the right answer (calibration hint) }
    function MeanProbGold: Double;
    (* Lowest threshold whose automatically decided answers reach
       ATargetPrecision; ACoverage = share of cases decided automatically.
       Returns 1.0 (always review) if no threshold reaches the target.
       For noul questions: AcceptThreshold = t, RejectThreshold = 1 - t. *)
    function SuggestThreshold(ATargetPrecision: Double; out ACoverage: Double): Double;
    { 'gold -> predicted: n' for the wrong combinations }
    function ConfusionText: string;

    property Name: string read FName;
    property Kind: TLayaQuestionKind read FKind;
    property Total: Integer read FTotal;
    property Correct: Integer read FCorrect;
    property Decided: Integer read FDecided;
    property DecidedWrong: Integer read FDecidedWrong;
    property Review: Integer read FReview;
    property ReviewCorrect: Integer read FReviewCorrect;
  end;

  TLayaEvaluator = class(TComponent)
  private
    FAnalyzer: TLayaDBAnalyzer;
    FOutTXT: TCustomMemo;
    FTargetPrecision: Double;
    FMaxErrorsListed: Integer;
    FOnFinish: TNotifyEvent;
    FQuestions: TObjectList<TLayaQuestionEval>;
    FErrors: TList<TLayaEvalError>;
    FRecords: Integer;
    FNoGold: Integer;
    FStats: TLayaDBStats;
    FModelName: string;
    FBusy: Boolean;
    FAlive: ILayaAlive;
    procedure SetAnalyzer(const Value: TLayaDBAnalyzer);
    procedure SetOutTXT(const Value: TCustomMemo);
    function GetQuestionEval(Index: Integer): TLayaQuestionEval;
    function GetQuestionCount: Integer;
    function GetErrorCount: Integer;
    function GetError(Index: Integer): TLayaEvalError;
    function FindEval(const AName: string): TLayaQuestionEval;
    function CurrentKey: string;
    procedure EvaluateRecord(AResults: TLayaResults);
    procedure EvaluationFinished(const AStats: TLayaDBStats);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Asynchronous, like TLayaDBAnalyzer.Execute. OnFinish is fired at the end }
    procedure Execute;
    procedure Cancel;
    procedure Clear;

    { Readable report }
    function AsText: string;
    { One row per question, columns separated by #9 }
    function AsTable: string;

    property Busy: Boolean read FBusy;
    property Records: Integer read FRecords;
    property RecordsWithoutGold: Integer read FNoGold;
    property ModelName: string read FModelName;
    property QuestionCount: Integer read GetQuestionCount;
    property QuestionEvals[Index: Integer]: TLayaQuestionEval read GetQuestionEval;
    property ErrorCount: Integer read GetErrorCount;
    property Errors[Index: Integer]: TLayaEvalError read GetError;
    property AnalyzerStats: TLayaDBStats read FStats;
  published
    property Analyzer: TLayaDBAnalyzer read FAnalyzer write SetAnalyzer;
    { Optional memo where AsText is written at the end }
    property OutTXT: TCustomMemo read FOutTXT write SetOutTXT;
    { Precision wanted for the suggested thresholds (0.9 = 90 %) }
    property TargetPrecision: Double read FTargetPrecision write FTargetPrecision;
    property MaxErrorsListed: Integer read FMaxErrorsListed write FMaxErrorsListed default 50;
    property OnFinish: TNotifyEvent read FOnFinish write FOnFinish;
  end;

  TLayaExportStats = record
    Records: Integer;       // reviewed records visited
    Written: Integer;       // rows written
    Train: Integer;
    Test: Integer;
    Questions: Integer;     // gold answers written
    NoGold: Integer;        // reviewed records without any readable answer
    NoText: Integer;        // reviewed records without text
  end;

  TLayaTrainingExporter = class(TComponent)
  private
    FAnalyzer: TLayaDBAnalyzer;
    FFileName: string;
    FWorkflow: string;
    FTestPercent: Integer;
    FSeed: Integer;
    FLabelSmoothing: Double;
    FFieldSplit: string;
    FStats: TLayaExportStats;
    procedure SetAnalyzer(const Value: TLayaDBAnalyzer);
    function GoldJSON(AQuestion: TLayaQuestion; const ALabel: string): TJSONObject;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    { Synchronous. Returns the number of rows written to FileName }
    function Execute: Integer;
    property Stats: TLayaExportStats read FStats;
  published
    property Analyzer: TLayaDBAnalyzer read FAnalyzer write SetAnalyzer;
    { .jsonl file to write }
    property FileName: string read FFileName write FFileName;
    { Name of the task, stored in the 'workflow' column and in every id }
    property Workflow: string read FWorkflow write FWorkflow;
    { Share of records reserved for the test split }
    property TestPercent: Integer read FTestPercent write FTestPercent default 20;
    { The split is random but repeatable with the same Seed }
    property Seed: Integer read FSeed write FSeed default 42;
    { 0 = one-hot gold probabilities; e.g. 0.05 spreads 5 % over the options }
    property LabelSmoothing: Double read FLabelSmoothing write FLabelSmoothing;
    (* Optional field of DataSetTarget with the split of each record: 'test'
       goes to test, any other value to train. When empty, TestPercent and
       Seed decide. *)
    property FieldSplit: string read FFieldSplit write FFieldSplit;
  end;

{ Reads the gold answer of AQuestion from AField, written with AMapping.
  ALabel receives the key LAYA uses: option key, level number or true/false. }
function LayaReadGold(AMapping: TLayaFieldMapping; AQuestion: TLayaQuestion;
  AField: TField; out ALabel: string): Boolean;

implementation

uses
  System.Math, System.IOUtils;

type
  TLayaTrainingAlive = class(TInterfacedObject, ILayaAlive)
  private
    FAlive: Boolean;
  public
    constructor Create;
    function IsAlive: Boolean;
    procedure Kill;
  end;

constructor TLayaTrainingAlive.Create;
begin
  inherited Create;
  FAlive := True;
end;

function TLayaTrainingAlive.IsAlive: Boolean;
begin
  Result := FAlive;
end;

procedure TLayaTrainingAlive.Kill;
begin
  FAlive := False;
end;

resourcestring
  SNoAnalyzer = 'No se ha indicado el analizador (Analyzer).';
  SEvalBusy = 'La evaluación ya está en marcha.';
  SNoFileName = 'No se ha indicado el archivo de salida (FileName).';
  SNoLockField = 'El analizador no tiene FieldLock: solo se exportan registros revisados.';
  SNoTarget = 'El analizador no tiene DataSetTarget abierto.';
  SNoQuestions = 'El analizador no tiene preguntas.';

const
  TRUE_TEXTS: array[0..8] of string = ('S', 'SI', 'SÍ', 'Y', 'YES', 'TRUE', 'T', 'V', '1');
  FALSE_TEXTS: array[0..5] of string = ('N', 'NO', 'FALSE', 'F', '0', '');

function InList(const S: string; const AList: array of string): Boolean;
var
  I: Integer;
begin
  for I := Low(AList) to High(AList) do
    if SameText(S, AList[I]) then
      Exit(True);
  Result := False;
end;

function LayaReadGold(AMapping: TLayaFieldMapping; AQuestion: TLayaQuestion;
  AField: TField; out ALabel: string): Boolean;
var
  S: string;
  I, L: Integer;
  B: Boolean;
begin
  Result := False;
  ALabel := '';
  if (AMapping = nil) or (AQuestion = nil) or (AField = nil) or AField.IsNull then
    Exit;

  case AQuestion.Kind of
    qkNoul:
      begin
        if AField.DataType = ftBoolean then
          B := AField.AsBoolean
        else if AField is TNumericField then
        begin
          if AMapping.AnswerFormat = afScore then
            B := AField.AsFloat >= 0.5     // P(true) was written
          else
            B := AField.AsFloat <> 0;
        end
        else
        begin
          S := Trim(AField.AsString);
          if S = '' then
            Exit;
          if SameText(S, AMapping.TrueValue) or InList(S, TRUE_TEXTS) then
            B := True
          else if SameText(S, AMapping.FalseValue) or InList(S, FALSE_TEXTS) then
            B := False
          else
            Exit;
        end;
        if B then
          ALabel := 'true'
        else
          ALabel := 'false';
        Result := True;
      end;

    qkChoice:
      begin
        if (AField is TNumericField) and (AMapping.AnswerFormat = afLevel) then
        begin
          L := AField.AsInteger;
          if (L >= 0) and (L < AQuestion.Options.Count) then
            ALabel := AQuestion.Options[L].Key;
        end
        else
        begin
          S := Trim(AField.AsString);
          I := AQuestion.Options.IndexOfKey(S);
          if I < 0 then
            for L := 0 to AQuestion.Options.Count - 1 do
              if SameText(AQuestion.Options[L].Caption, S) then
              begin
                I := L;
                Break;
              end;
          if I >= 0 then
            ALabel := AQuestion.Options[I].Key;
        end;
        Result := ALabel <> '';
      end;

    qkScore:
      begin
        L := -1;
        if AField is TNumericField then
          L := Trunc(AField.AsFloat + 0.5)
        else
        begin
          S := Trim(AField.AsString);
          if not TryStrToInt(S, L) then
          begin
            L := -1;
            for I := 0 to AQuestion.Options.Count - 1 do
              if SameText(AQuestion.Options[I].Caption, S) or
                 SameText(AQuestion.Options[I].Key, S) then
              begin
                L := I;
                Break;
              end;
          end;
        end;
        if (L >= 0) and (L < AQuestion.Options.Count) then
        begin
          ALabel := IntToStr(L);
          Result := True;
        end;
      end;
  end;
end;

{ TLayaQuestionEval }

constructor TLayaQuestionEval.Create(const AName: string; AKind: TLayaQuestionKind);
begin
  inherited Create;
  FName := AName;
  FKind := AKind;
  FSamples := TList<TLayaEvalSample>.Create;
  FConfusion := TDictionary<string, Integer>.Create;
end;

destructor TLayaQuestionEval.Destroy;
begin
  FConfusion.Free;
  FSamples.Free;
  inherited;
end;

procedure TLayaQuestionEval.Add(const AGold: string; AAnswer: TLayaAnswer);
var
  S: TLayaEvalSample;
  K: string;
  N: Integer;
begin
  Inc(FTotal);
  S.Correct := AAnswer.Answer = AGold;
  S.Confidence := AAnswer.Probability;
  S.Decided := AAnswer.Decision <> ldReview;
  FSamples.Add(S);

  if S.Correct then
    Inc(FCorrect);
  if S.Decided then
  begin
    Inc(FDecided);
    if not S.Correct then
      Inc(FDecidedWrong);
  end
  else
  begin
    Inc(FReview);
    if S.Correct then
      Inc(FReviewCorrect);
  end;
  FProbGoldSum := FProbGoldSum + AAnswer.ProbabilityOf(AGold);

  if not S.Correct then
  begin
    K := AGold + ' -> ' + AAnswer.Answer;
    if FConfusion.TryGetValue(K, N) then
      FConfusion[K] := N + 1
    else
      FConfusion.Add(K, 1);
  end;
end;

function TLayaQuestionEval.Accuracy: Double;
begin
  if FTotal = 0 then
    Result := 0
  else
    Result := FCorrect / FTotal;
end;

function TLayaQuestionEval.MeanProbGold: Double;
begin
  if FTotal = 0 then
    Result := 0
  else
    Result := FProbGoldSum / FTotal;
end;

function TLayaQuestionEval.SuggestThreshold(ATargetPrecision: Double;
  out ACoverage: Double): Double;
var
  Sorted: TArray<TLayaEvalSample>;
  I, Best, CumCorrect: Integer;
begin
  Result := 1.0;
  ACoverage := 0;
  if FSamples.Count = 0 then
    Exit;
  Sorted := FSamples.ToArray;
  TArray.Sort<TLayaEvalSample>(Sorted, TComparer<TLayaEvalSample>.Construct(
    function(const A, B: TLayaEvalSample): Integer
    begin
      Result := CompareValue(B.Confidence, A.Confidence);   // descending
    end));

  Best := -1;
  CumCorrect := 0;
  for I := 0 to High(Sorted) do
  begin
    if Sorted[I].Correct then
      Inc(CumCorrect);
    if CumCorrect / (I + 1) >= ATargetPrecision then
      Best := I;
  end;
  if Best >= 0 then
  begin
    Result := Sorted[Best].Confidence;
    ACoverage := (Best + 1) / Length(Sorted);
  end;
end;

function TLayaQuestionEval.ConfusionText: string;
var
  Pair: TPair<string, Integer>;
  Keys: TList<string>;
  K: string;
begin
  Result := '';
  Keys := TList<string>.Create;
  try
    for Pair in FConfusion do
      Keys.Add(Pair.Key);
    Keys.Sort;
    for K in Keys do
    begin
      if Result <> '' then
        Result := Result + ';  ';
      Result := Result + Format('%s: %d', [K, FConfusion[K]]);
    end;
  finally
    Keys.Free;
  end;
end;

{ TLayaEvaluator }

constructor TLayaEvaluator.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAlive := TLayaTrainingAlive.Create;
  FQuestions := TObjectList<TLayaQuestionEval>.Create(True);
  FErrors := TList<TLayaEvalError>.Create;
  FTargetPrecision := 0.9;
  FMaxErrorsListed := 50;
end;

destructor TLayaEvaluator.Destroy;
begin
  FAlive.Kill;   // pending callbacks of the analyzer will do nothing
  if FBusy and (FAnalyzer <> nil) then
    FAnalyzer.Cancel;
  FErrors.Free;
  FQuestions.Free;
  inherited;
end;

procedure TLayaEvaluator.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FAnalyzer then
      FAnalyzer := nil;
    if AComponent = FOutTXT then
      FOutTXT := nil;
  end;
end;

procedure TLayaEvaluator.SetAnalyzer(const Value: TLayaDBAnalyzer);
begin
  if FAnalyzer <> nil then
    FAnalyzer.RemoveFreeNotification(Self);
  FAnalyzer := Value;
  if FAnalyzer <> nil then
    FAnalyzer.FreeNotification(Self);
end;

procedure TLayaEvaluator.SetOutTXT(const Value: TCustomMemo);
begin
  if FOutTXT <> nil then
    FOutTXT.RemoveFreeNotification(Self);
  FOutTXT := Value;
  if FOutTXT <> nil then
    FOutTXT.FreeNotification(Self);
end;

function TLayaEvaluator.GetQuestionCount: Integer;
begin
  Result := FQuestions.Count;
end;

function TLayaEvaluator.GetQuestionEval(Index: Integer): TLayaQuestionEval;
begin
  Result := FQuestions[Index];
end;

function TLayaEvaluator.GetErrorCount: Integer;
begin
  Result := FErrors.Count;
end;

function TLayaEvaluator.GetError(Index: Integer): TLayaEvalError;
begin
  Result := FErrors[Index];
end;

function TLayaEvaluator.FindEval(const AName: string): TLayaQuestionEval;
var
  E: TLayaQuestionEval;
begin
  for E in FQuestions do
    if SameText(E.Name, AName) then
      Exit(E);
  Result := nil;
end;

procedure TLayaEvaluator.Clear;
begin
  FQuestions.Clear;
  FErrors.Clear;
  FRecords := 0;
  FNoGold := 0;
  FStats := Default(TLayaDBStats);
  FModelName := '';
end;

function TLayaEvaluator.CurrentKey: string;
var
  DS: TDataSet;
begin
  DS := FAnalyzer.DataSetTarget;
  if (FAnalyzer.FieldKeyTarget <> '') and (DS.FindField(FAnalyzer.FieldKeyTarget) <> nil) then
    Result := DS.FieldByName(FAnalyzer.FieldKeyTarget).AsString
  else
    Result := IntToStr(DS.RecNo);
end;

procedure TLayaEvaluator.Execute;
var
  Q: TLayaQuestions;
  I: Integer;
  Alive: ILayaAlive;
begin
  if FBusy then
    raise ELayaError.Create(SEvalBusy);
  if FAnalyzer = nil then
    raise ELayaError.Create(SNoAnalyzer);
  Q := FAnalyzer.ActiveQuestions;
  if Q = nil then
    raise ELayaError.Create(SNoQuestions);

  Clear;
  { one evaluation per question that has an answer field to read the gold from }
  for I := 0 to Q.Count - 1 do
    if Q[I].Enabled and (FAnalyzer.FindAnswerMapping(Q[I].Name) <> nil) then
      FQuestions.Add(TLayaQuestionEval.Create(Q[I].Name, Q[I].Kind));

  FBusy := True;
  Alive := FAlive;
  if FOutTXT <> nil then
    FOutTXT.Lines.Text := 'Evaluando... el informe aparecerá aquí al terminar.';
  try
    FAnalyzer.ExecuteEvaluation(
      procedure(AResults: TLayaResults)
      begin
        if Alive.IsAlive then
          EvaluateRecord(AResults);
      end,
      procedure(const AStats: TLayaDBStats)
      begin
        if Alive.IsAlive then
          EvaluationFinished(AStats);
      end);
  except
    on E: Exception do
    begin
      FBusy := False;
      if FOutTXT <> nil then
        FOutTXT.Lines.Text := 'No se pudo iniciar la evaluación: ' + E.Message;
      raise;
    end;
  end;
end;

procedure TLayaEvaluator.Cancel;
begin
  if FBusy and (FAnalyzer <> nil) then
    FAnalyzer.Cancel;
end;

procedure TLayaEvaluator.EvaluateRecord(AResults: TLayaResults);
var
  E: TLayaQuestionEval;
  Q: TLayaQuestion;
  M: TLayaFieldMapping;
  A: TLayaAnswer;
  Gold: string;
  Err: TLayaEvalError;
  AnyGold: Boolean;
begin
  Inc(FRecords);
  AnyGold := False;
  for E in FQuestions do
  begin
    Q := FAnalyzer.ActiveQuestions.FindQuestion(E.Name);
    M := FAnalyzer.FindAnswerMapping(E.Name);
    A := AResults.ByName(E.Name);
    if (Q = nil) or (M = nil) or (A = nil) then
      Continue;
    if not LayaReadGold(M, Q, FAnalyzer.DataSetTarget.FindField(M.FieldAnswer), Gold) then
      Continue;
    AnyGold := True;
    E.Add(Gold, A);
    if (A.Answer <> Gold) and (FErrors.Count < FMaxErrorsListed) then
    begin
      Err.RecordKey := CurrentKey;
      Err.Question := E.Name;
      Err.Gold := Gold;
      Err.Predicted := A.Answer;
      Err.Probability := A.Probability;
      Err.Decision := A.Decision;
      FErrors.Add(Err);
    end;
  end;
  if not AnyGold then
    Inc(FNoGold);
end;

procedure TLayaEvaluator.EvaluationFinished(const AStats: TLayaDBStats);
begin
  FBusy := False;
  FStats := AStats;
  if (FAnalyzer <> nil) and (FAnalyzer.Server <> nil) then
    FModelName := FAnalyzer.Server.ModelName;
  if FOutTXT <> nil then
    FOutTXT.Lines.Text := AsText;
  if Assigned(FOnFinish) then
    FOnFinish(Self);
end;

function TLayaEvaluator.AsText: string;
var
  SB: TStringBuilder;
  E: TLayaQuestionEval;
  Err: TLayaEvalError;
  T, Cov: Double;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine(Format('Evaluación sobre %d registros revisados (modelo: %s)',
      [FRecords, FModelName]));
    if FNoGold > 0 then
      SB.AppendLine(Format('Registros revisados sin ninguna respuesta legible: %d', [FNoGold]));
    if FStats.Cancelled then
      SB.AppendLine('ATENCIÓN: la evaluación se canceló antes de terminar.');

    for E in FQuestions do
    begin
      SB.AppendLine;
      SB.AppendLine(Format('%s (%s)', [E.Name, LAYA_KIND_NAMES[E.Kind]]));
      if E.Total = 0 then
      begin
        SB.AppendLine('  Sin datos revisados.');
        Continue;
      end;
      SB.AppendLine(Format('  Aciertos:%s%d de %d (%.1f %%)',
        [#9, E.Correct, E.Total, E.Accuracy * 100]));
      SB.AppendLine(Format('  Decididas sin revisión:%s%d, con %d errores',
        [#9, E.Decided, E.DecidedWrong]));
      SB.AppendLine(Format('  Enviadas a revisión:%s%d (%d eran correctas)',
        [#9, E.Review, E.ReviewCorrect]));
      SB.AppendLine(Format('  Prob. media de la respuesta correcta:%s%.1f %%',
        [#9, E.MeanProbGold * 100]));
      T := E.SuggestThreshold(FTargetPrecision, Cov);
      if T >= 1.0 then
        SB.AppendLine(Format('  Umbral sugerido (precisión %.0f %%):%sninguno alcanza la precisión; revisar siempre',
          [FTargetPrecision * 100, #9]))
      else if E.Kind = qkNoul then
        SB.AppendLine(Format('  Umbral sugerido (precisión %.0f %%):%sAccept %.2f / Reject %.2f; decidiría solo el %.0f %% de los casos',
          [FTargetPrecision * 100, #9, T, 1 - T, Cov * 100]))
      else
        SB.AppendLine(Format('  Umbral sugerido (precisión %.0f %%):%sAccept %.2f; decidiría solo el %.0f %% de los casos',
          [FTargetPrecision * 100, #9, T, Cov * 100]));
      if E.ConfusionText <> '' then
        SB.AppendLine('  Confusiones (real -> predicha):' + #9 + E.ConfusionText);
    end;

    if FErrors.Count > 0 then
    begin
      SB.AppendLine;
      SB.AppendLine('Errores:');
      for Err in FErrors do
        SB.AppendLine(Format('  registro %s%s%s: real %s, predicha %s (%.1f %%, %s)',
          [Err.RecordKey, #9, Err.Question, Err.Gold, Err.Predicted,
           Err.Probability * 100, LAYA_DECISION_NAMES[Err.Decision]]));
    end;
    Result := SB.ToString.TrimRight;
  finally
    SB.Free;
  end;
end;

function TLayaEvaluator.AsTable: string;
var
  SB: TStringBuilder;
  E: TLayaQuestionEval;
  T, Cov: Double;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append(string.Join(#9, ['Pregunta', 'Tipo', 'Casos', 'Aciertos',
      'Precisión', 'Decididas', 'Errores decididos', 'A revisión',
      'Prob. correcta', 'Umbral sugerido', 'Cobertura']));
    for E in FQuestions do
    begin
      T := E.SuggestThreshold(FTargetPrecision, Cov);
      SB.AppendLine;
      SB.Append(string.Join(#9, [E.Name, LAYA_KIND_NAMES[E.Kind],
        IntToStr(E.Total), IntToStr(E.Correct),
        FormatFloat('0.000', E.Accuracy), IntToStr(E.Decided),
        IntToStr(E.DecidedWrong), IntToStr(E.Review),
        FormatFloat('0.000', E.MeanProbGold), FormatFloat('0.00', T),
        FormatFloat('0.00', Cov)]));
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

{ TLayaTrainingExporter }

constructor TLayaTrainingExporter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FWorkflow := 'custom';
  FTestPercent := 20;
  FSeed := 42;
  FLabelSmoothing := 0;
end;

procedure TLayaTrainingExporter.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FAnalyzer) then
    FAnalyzer := nil;
end;

procedure TLayaTrainingExporter.SetAnalyzer(const Value: TLayaDBAnalyzer);
begin
  if FAnalyzer <> nil then
    FAnalyzer.RemoveFreeNotification(Self);
  FAnalyzer := Value;
  if FAnalyzer <> nil then
    FAnalyzer.FreeNotification(Self);
end;

(* Gold in the typed-decisions format:
     choice {"type","label","probabilities":{key:p},"confidence"}
     score  {"type","label":"<level>","probabilities":{"0":p,...},"confidence"}
     noul   {"type","label":"true|false","noul":p,"probabilities":{"false","true"},"confidence"}
   confidence = (pmax - 1/k) / (1 - 1/k), which is |2p - 1| for noul. *)
function TLayaTrainingExporter.GoldJSON(AQuestion: TLayaQuestion;
  const ALabel: string): TJSONObject;
var
  Probs: TJSONObject;
  Keys: TArray<string>;
  I, K: Integer;
  Eps, PGold, POther, PTrue: Double;
begin
  Eps := EnsureRange(FLabelSmoothing, 0, 0.5);
  Result := TJSONObject.Create;
  try
    Result.AddPair('type', LAYA_KIND_NAMES[AQuestion.Kind]);
    Result.AddPair('label', ALabel);
    Probs := TJSONObject.Create;

    if AQuestion.Kind = qkNoul then
    begin
      if ALabel = 'true' then
        PTrue := 1 - Eps / 2
      else
        PTrue := Eps / 2;
      Result.AddPair('noul', TJSONNumber.Create(PTrue));
      Probs.AddPair('false', TJSONNumber.Create(1 - PTrue));
      Probs.AddPair('true', TJSONNumber.Create(PTrue));
      Result.AddPair('probabilities', Probs);
      Result.AddPair('confidence', TJSONNumber.Create(Abs(2 * PTrue - 1)));
    end
    else
    begin
      K := AQuestion.Options.Count;
      SetLength(Keys, K);
      for I := 0 to K - 1 do
        if AQuestion.Kind = qkScore then
          Keys[I] := IntToStr(I)
        else
          Keys[I] := AQuestion.Options[I].Key;
      PGold := 1 - Eps + Eps / K;
      POther := Eps / K;
      for I := 0 to K - 1 do
        if Keys[I] = ALabel then
          Probs.AddPair(Keys[I], TJSONNumber.Create(PGold))
        else
          Probs.AddPair(Keys[I], TJSONNumber.Create(POther));
      Result.AddPair('probabilities', Probs);
      Result.AddPair('confidence', TJSONNumber.Create((PGold - 1 / K) / (1 - 1 / K)));
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TLayaTrainingExporter.Execute: Integer;
var
  DS: TDataSet;
  Q: TLayaQuestions;
  QI: TLayaQuestion;
  M: TLayaFieldMapping;
  Texts: TList<string>;
  Lines: TStringBuilder;
  Row, State, QuestionsObj, GoldObj: TJSONObject;
  Gold, StateKey, Split, Text: string;
  I, N, Rnd: Integer;
  IsTest: Boolean;
  Bookmark: TBookmark;
begin
  if FAnalyzer = nil then
    raise ELayaError.Create(SNoAnalyzer);
  if Trim(FFileName) = '' then
    raise ELayaError.Create(SNoFileName);
  if Trim(FAnalyzer.FieldLock) = '' then
    raise ELayaError.Create(SNoLockField);
  DS := FAnalyzer.DataSetTarget;
  if (DS = nil) or not DS.Active then
    raise ELayaError.Create(SNoTarget);
  Q := FAnalyzer.ActiveQuestions;
  if Q = nil then
    raise ELayaError.Create(SNoQuestions);
  if FFieldSplit <> '' then
    DS.FieldByName(FFieldSplit);   // clear error if the field does not exist

  if FAnalyzer.Server <> nil then
    StateKey := FAnalyzer.Server.StateKey
  else
    StateKey := 'text';

  FStats := Default(TLayaExportStats);
  Rnd := FSeed;
  Texts := TList<string>.Create;
  Lines := TStringBuilder.Create;
  Bookmark := DS.Bookmark;
  DS.DisableControls;
  try
    DS.First;
    while not DS.Eof do
    begin
      if FAnalyzer.IsLocked then
      begin
        Inc(FStats.Records);

        Texts.Clear;
        FAnalyzer.CollectTexts(Texts);
        Text := Trim(string.Join(sLineBreak + sLineBreak, Texts.ToArray));

        QuestionsObj := TJSONObject.Create;
        GoldObj := TJSONObject.Create;
        try
          N := 0;
          for I := 0 to Q.Count - 1 do
          begin
            QI := Q[I];
            if not QI.Enabled then
              Continue;
            M := FAnalyzer.FindAnswerMapping(QI.Name);
            if (M = nil) or
               not LayaReadGold(M, QI, DS.FindField(M.FieldAnswer), Gold) then
              Continue;
            QuestionsObj.AddPair(QI.Name, QI.ToJSON);
            GoldObj.AddPair(QI.Name, GoldJSON(QI, Gold));
            Inc(N);
          end;

          if Text = '' then
            Inc(FStats.NoText)
          else if N = 0 then
            Inc(FStats.NoGold)
          else
          begin
            if FFieldSplit <> '' then
              IsTest := SameText(Trim(DS.FieldByName(FFieldSplit).AsString), 'test')
            else
            begin
              { repeatable pseudo-random split (linear congruential generator) }
              Rnd := Integer((Int64(Rnd) * 1103515245 + 12345) and $7FFFFFFF);
              IsTest := (Rnd mod 100) < FTestPercent;
            end;
            if IsTest then
            begin
              Split := 'test';
              Inc(FStats.Test);
            end
            else
            begin
              Split := 'train';
              Inc(FStats.Train);
            end;

            State := TJSONObject.Create;
            Row := TJSONObject.Create;
            try
              State.AddPair(StateKey, Text);
              Row.AddPair('id', Format('%s_%s_%.6d', [Split, FWorkflow, FStats.Written]));
              Row.AddPair('workflow', FWorkflow);
              Row.AddPair('split', Split);
              Row.AddPair('state', State.ToJSON);
              Row.AddPair('questions', QuestionsObj.ToJSON);
              Row.AddPair('gold', GoldObj.ToJSON);
              Row.AddPair('n_questions', TJSONNumber.Create(N));
              Lines.Append(Row.ToJSON);
              Lines.Append(#10);
            finally
              Row.Free;
              State.Free;
            end;
            Inc(FStats.Written);
            Inc(FStats.Questions, N);
          end;
        finally
          GoldObj.Free;
          QuestionsObj.Free;
        end;
      end;
      DS.Next;
    end;

    { UTF-8 without BOM, one JSON object per line }
    TFile.WriteAllBytes(FFileName, TEncoding.UTF8.GetBytes(Lines.ToString));
  finally
    try
      DS.Bookmark := Bookmark;
    except
      { the original record no longer exists }
    end;
    DS.EnableControls;
    Lines.Free;
    Texts.Free;
  end;
  Result := FStats.Written;
end;

end.
