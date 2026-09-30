unit Laya.Results;

{ LAYA para Delphi
  Copyright 2026 Carlos Liñán
  Licensed under the Apache License, Version 2.0.
  See LICENSE in the project root for details. }


{ LAYA components - results of a prediction.

  TLayaResults parses the full response of the LAYA server (/predict) into a
  list of TLayaAnswer objects, one per question.

  TLayaAnswer.Answer is always a key:
    qkChoice  the chosen option key
    qkScore   the level number as text ('0', '1', '2'...)
    qkNoul    'true' or 'false'
  TLayaAnswer.AnswerCaption is the human-readable label of that answer.
  TLayaAnswer.Probability is the probability of that answer.
  TLayaAnswer.Decision applies the thresholds of the question
  (see Laya.Questions).

  Outputs: assign OutTXT and/or OutJSON to memos and they are filled
  automatically every time the results change. AsText returns the same
  readable text that is written to OutTXT. }

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  Vcl.StdCtrls,
  Laya.Questions;

type
  TLayaDecision = (ldAccepted, ldReview, ldRejected);

const
  LAYA_DECISION_NAMES: array[TLayaDecision] of string =
    ('accepted', 'review', 'rejected');

type
  { What AsText / OutTXT show: the readable caption or the key }
  TLayaTextAnswer = (taCaption, taKey);

  TLayaOptionProbability = record
    Key: string;
    Caption: string;
    Probability: Double;
  end;

  TLayaAnswer = class
  private
    FName: string;
    FKind: TLayaQuestionKind;
    FAnswer: string;
    FAnswerCaption: string;
    FProbability: Double;
    FPTrue: Double;
    FScore: Double;
    FLevel: Integer;
    FConfidence: Double;
    FAnswerConfidence: Double;
    FActProbability: Double;
    FDecision: TLayaDecision;
    FProbabilities: TArray<TLayaOptionProbability>;
    function GetAsBoolean: Boolean;
    function GetDecisionName: string;
    procedure SetNoul(APTrue: Double);
    procedure ComputeDecision(AQuestion: TLayaQuestion);
    function AggregationMetric: Double;
    procedure AssignMean(const ASources: TArray<TLayaAnswer>; AQuestion: TLayaQuestion);
  public
    procedure Assign(ASource: TLayaAnswer);
    procedure LoadFromJSON(const AName: string; AJSON: TJSONObject;
      AQuestion: TLayaQuestion);
    { Probability of a given key (0 if not present) }
    function ProbabilityOf(const AKey: string): Double;

    property Name: string read FName;
    property Kind: TLayaQuestionKind read FKind;
    property Answer: string read FAnswer;
    property AnswerCaption: string read FAnswerCaption;
    property Probability: Double read FProbability;
    { qkNoul: raw P(true) }
    property PTrue: Double read FPTrue;
    { qkNoul: True when P(true) >= 0.5 }
    property AsBoolean: Boolean read GetAsBoolean;
    { qkScore: expected value on the scale (e.g. 1.72) }
    property Score: Double read FScore;
    { qkScore: rounded level; qkChoice: index of the option in the question
      (-1 if unknown); qkNoul: -1 }
    property Level: Integer read FLevel;
    property Confidence: Double read FConfidence;
    property AnswerConfidence: Double read FAnswerConfidence;
    property ActProbability: Double read FActProbability;
    property Decision: TLayaDecision read FDecision;
    property DecisionName: string read GetDecisionName;
    property Probabilities: TArray<TLayaOptionProbability> read FProbabilities;
  end;

  TLayaResults = class(TComponent)
  private
    FItems: TObjectList<TLayaAnswer>;
    FRawJSON: string;
    FOutTXT: TCustomMemo;
    FOutJSON: TCustomMemo;
    FTextAnswer: TLayaTextAnswer;
    FOutputsDisabled: Integer;
    FOnChange: TNotifyEvent;
    function GetCount: Integer;
    function GetAnswer(Index: Integer): TLayaAnswer;
    procedure DoChange;
    procedure UpdateOutputs;
    procedure SetOutTXT(const Value: TCustomMemo);
    procedure SetOutJSON(const Value: TCustomMemo);
    procedure SetTextAnswer(const Value: TLayaTextAnswer);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    { AJSON: full response of /predict. AQuestions is optional but recommended:
      it provides thresholds and option captions. }
    procedure LoadFromJSON(const AJSON: string; AQuestions: TLayaQuestions);
    { nil if there is no answer with that name }
    function ByName(const AName: string): TLayaAnswer;
    { While disabled (calls can be nested), OutTXT and OutJSON are not
      updated; OnChange is still fired. EnableOutputs refreshes them. }
    procedure DisableOutputs;
    procedure EnableOutputs;
    function OutputsDisabled: Boolean;
    { Combines several results (chunks of a long text, several reports...)
      into this one, using the Aggregation of each question:
        agFirst  the answer of the first source
        agMax    the source with the highest value (noul: P(true);
                 score: Score; choice: probability of its answer)
        agMin    the source with the lowest value
        agMean   average of the probability distributions }
    procedure Aggregate(const ASources: array of TLayaResults;
      AQuestions: TLayaQuestions);
    { Readable text of all the answers (the same written to OutTXT) }
    function AsText: string;
    { RawJSON indented; RawJSON itself if it is not valid JSON }
    function FormattedJSON: string;

    property Count: Integer read GetCount;
    property Answers[Index: Integer]: TLayaAnswer read GetAnswer; default;
    property RawJSON: string read FRawJSON;
  published
    property OutTXT: TCustomMemo read FOutTXT write SetOutTXT;
    property OutJSON: TCustomMemo read FOutJSON write SetOutJSON;
    property TextAnswer: TLayaTextAnswer read FTextAnswer write SetTextAnswer default taCaption;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

resourcestring
  SResponseNotObject = 'La respuesta del servidor LAYA no es un objeto JSON.';
  SResponseNoAnswers = 'La respuesta del servidor LAYA no contiene "answers".';
  SUnknownAnswerType = 'No se reconoce el tipo de la respuesta "%s".';

function JStr(AObj: TJSONObject; const AName: string): string;
var
  V: TJSONValue;
begin
  V := AObj.GetValue(AName);
  if V <> nil then
    Result := V.Value
  else
    Result := '';
end;

function JNum(AObj: TJSONObject; const AName: string): Double;
var
  V: TJSONValue;
begin
  V := AObj.GetValue(AName);
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsDouble
  else
    Result := 0;
end;

function OptionCaption(const AKey: string; ALegend: TJSONObject;
  AQuestion: TLayaQuestion): string;
var
  V: TJSONValue;
  I: Integer;
begin
  if ALegend <> nil then
  begin
    V := ALegend.GetValue(AKey);
    if V <> nil then
      Exit(V.Value);
  end;
  if AQuestion <> nil then
  begin
    I := AQuestion.Options.IndexOfKey(AKey);
    if I >= 0 then
      Exit(AQuestion.Options[I].Caption);
  end;
  Result := AKey;
end;

{ TLayaAnswer }

function TLayaAnswer.GetAsBoolean: Boolean;
begin
  Result := FPTrue >= 0.5;
end;

function TLayaAnswer.GetDecisionName: string;
begin
  Result := LAYA_DECISION_NAMES[FDecision];
end;

function TLayaAnswer.ProbabilityOf(const AKey: string): Double;
var
  I: Integer;
begin
  for I := 0 to High(FProbabilities) do
    if FProbabilities[I].Key = AKey then
      Exit(FProbabilities[I].Probability);
  Result := 0;
end;

procedure TLayaAnswer.LoadFromJSON(const AName: string; AJSON: TJSONObject;
  AQuestion: TLayaQuestion);
var
  K: TLayaQuestionKind;
  Legend: TJSONObject;
  Pair: TJSONPair;
  Item: TLayaOptionProbability;
  List: TList<TLayaOptionProbability>;
begin
  FName := AName;
  if LayaKindFromString(JStr(AJSON, 'type'), K) then
    FKind := K
  else if AQuestion <> nil then
    FKind := AQuestion.Kind
  else
    raise ELayaError.CreateFmt(SUnknownAnswerType, [AName]);

  FConfidence := JNum(AJSON, 'confidence');
  FAnswerConfidence := JNum(AJSON, 'answer_confidence');
  FActProbability := 0;
  if AJSON.GetValue('action') is TJSONObject then
    FActProbability := JNum(TJSONObject(AJSON.GetValue('action')), 'act_probability');

  Legend := nil;
  if AJSON.GetValue('legend') is TJSONObject then
    Legend := TJSONObject(AJSON.GetValue('legend'));

  { Probability of every option }
  List := TList<TLayaOptionProbability>.Create;
  try
    if AJSON.GetValue('probabilities') is TJSONObject then
      for Pair in TJSONObject(AJSON.GetValue('probabilities')) do
      begin
        Item.Key := Pair.JsonString.Value;
        Item.Caption := OptionCaption(Item.Key, Legend, AQuestion);
        if Pair.JsonValue is TJSONNumber then
          Item.Probability := TJSONNumber(Pair.JsonValue).AsDouble
        else
          Item.Probability := 0;
        List.Add(Item);
      end;
    FProbabilities := List.ToArray;
  finally
    List.Free;
  end;

  FLevel := -1;
  FScore := 0;
  FPTrue := 0;
  case FKind of
    qkChoice:
      begin
        FAnswer := JStr(AJSON, 'choice');
        FAnswerCaption := OptionCaption(FAnswer, nil, AQuestion);
        FProbability := ProbabilityOf(FAnswer);
        if AQuestion <> nil then
          FLevel := AQuestion.Options.IndexOfKey(FAnswer);
      end;
    qkScore:
      begin
        FScore := JNum(AJSON, 'score');
        FLevel := Trunc(FScore + 0.5);   // round half up
        if FLevel < 0 then
          FLevel := 0;
        if (Length(FProbabilities) > 0) and (FLevel > High(FProbabilities)) then
          FLevel := High(FProbabilities);
        FAnswer := IntToStr(FLevel);
        FAnswerCaption := OptionCaption(FAnswer, Legend, AQuestion);
        FProbability := ProbabilityOf(FAnswer);
      end;
    qkNoul:
      begin
        SetNoul(JNum(AJSON, 'noul'));
      end;
  end;

  ComputeDecision(AQuestion);
end;

procedure TLayaAnswer.SetNoul(APTrue: Double);
begin
  FPTrue := APTrue;
  if FPTrue >= 0.5 then
  begin
    FAnswer := 'true';
    FProbability := FPTrue;
  end
  else
  begin
    FAnswer := 'false';
    FProbability := 1 - FPTrue;
  end;
  FAnswerCaption := FAnswer;
  FLevel := -1;
  SetLength(FProbabilities, 2);
  FProbabilities[0].Key := 'true';
  FProbabilities[0].Caption := 'true';
  FProbabilities[0].Probability := FPTrue;
  FProbabilities[1].Key := 'false';
  FProbabilities[1].Caption := 'false';
  FProbabilities[1].Probability := 1 - FPTrue;
end;

procedure TLayaAnswer.ComputeDecision(AQuestion: TLayaQuestion);
var
  Accept, Reject: Double;
begin
  if AQuestion <> nil then
  begin
    Accept := AQuestion.AcceptThreshold;
    Reject := AQuestion.RejectThreshold;
  end
  else
  begin
    Accept := LAYA_DEFAULT_ACCEPT;
    Reject := LAYA_DEFAULT_REJECT;
  end;

  if FKind = qkNoul then
  begin
    if FPTrue >= Accept then
      FDecision := ldAccepted
    else if FPTrue <= Reject then
      FDecision := ldRejected
    else
      FDecision := ldReview;
  end
  else if FProbability >= Accept then
    FDecision := ldAccepted
  else
    FDecision := ldReview;
end;

function TLayaAnswer.AggregationMetric: Double;
begin
  case FKind of
    qkNoul: Result := FPTrue;
    qkScore: Result := FScore;
  else
    Result := FProbability;
  end;
end;

procedure TLayaAnswer.Assign(ASource: TLayaAnswer);
begin
  FName := ASource.FName;
  FKind := ASource.FKind;
  FAnswer := ASource.FAnswer;
  FAnswerCaption := ASource.FAnswerCaption;
  FProbability := ASource.FProbability;
  FPTrue := ASource.FPTrue;
  FScore := ASource.FScore;
  FLevel := ASource.FLevel;
  FConfidence := ASource.FConfidence;
  FAnswerConfidence := ASource.FAnswerConfidence;
  FActProbability := ASource.FActProbability;
  FDecision := ASource.FDecision;
  FProbabilities := Copy(ASource.FProbabilities);
end;

procedure TLayaAnswer.AssignMean(const ASources: TArray<TLayaAnswer>;
  AQuestion: TLayaQuestion);
var
  I, J, K, N: Integer;
  Sum: TList<TLayaOptionProbability>;
  Item: TLayaOptionProbability;
  Found: Boolean;
  PTrue, Score, Conf, AnsConf, Act: Double;
begin
  Assign(ASources[0]);
  N := Length(ASources);
  if N <= 1 then
    Exit;

  PTrue := 0;
  Score := 0;
  Conf := 0;
  AnsConf := 0;
  Act := 0;
  for I := 0 to N - 1 do
  begin
    PTrue := PTrue + ASources[I].FPTrue / N;
    Score := Score + ASources[I].FScore / N;
    Conf := Conf + ASources[I].FConfidence / N;
    AnsConf := AnsConf + ASources[I].FAnswerConfidence / N;
    Act := Act + ASources[I].FActProbability / N;
  end;
  FConfidence := Conf;
  FAnswerConfidence := AnsConf;
  FActProbability := Act;

  if FKind = qkNoul then
  begin
    SetNoul(PTrue);
    Exit;
  end;

  { Average of the distributions, option by option }
  Sum := TList<TLayaOptionProbability>.Create;
  try
    for I := 0 to N - 1 do
      for J := 0 to High(ASources[I].FProbabilities) do
      begin
        Found := False;
        for K := 0 to Sum.Count - 1 do
          if Sum[K].Key = ASources[I].FProbabilities[J].Key then
          begin
            Item := Sum[K];
            Item.Probability := Item.Probability +
              ASources[I].FProbabilities[J].Probability / N;
            Sum[K] := Item;
            Found := True;
            Break;
          end;
        if not Found then
        begin
          Item := ASources[I].FProbabilities[J];
          Item.Probability := Item.Probability / N;
          Sum.Add(Item);
        end;
      end;
    FProbabilities := Sum.ToArray;
  finally
    Sum.Free;
  end;

  if FKind = qkScore then
  begin
    FScore := Score;
    FLevel := Trunc(FScore + 0.5);
    if FLevel < 0 then
      FLevel := 0;
    if (Length(FProbabilities) > 0) and (FLevel > High(FProbabilities)) then
      FLevel := High(FProbabilities);
    FAnswer := IntToStr(FLevel);
    FAnswerCaption := FAnswer;
    for I := 0 to High(FProbabilities) do
      if FProbabilities[I].Key = FAnswer then
        FAnswerCaption := FProbabilities[I].Caption;
    FProbability := ProbabilityOf(FAnswer);
  end
  else  { qkChoice: the option with the highest average }
  begin
    K := -1;
    for I := 0 to High(FProbabilities) do
      if (K < 0) or (FProbabilities[I].Probability > FProbabilities[K].Probability) then
        K := I;
    if K >= 0 then
    begin
      FAnswer := FProbabilities[K].Key;
      FAnswerCaption := FProbabilities[K].Caption;
      FProbability := FProbabilities[K].Probability;
      if AQuestion <> nil then
        FLevel := AQuestion.Options.IndexOfKey(FAnswer);
    end;
  end;
end;

{ TLayaResults }

constructor TLayaResults.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TObjectList<TLayaAnswer>.Create(True);
end;

destructor TLayaResults.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TLayaResults.DoChange;
begin
  UpdateOutputs;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TLayaResults.SetOutTXT(const Value: TCustomMemo);
begin
  if FOutTXT = Value then
    Exit;
  if FOutTXT <> nil then
    FOutTXT.RemoveFreeNotification(Self);
  FOutTXT := Value;
  if FOutTXT <> nil then
    FOutTXT.FreeNotification(Self);
end;

procedure TLayaResults.SetOutJSON(const Value: TCustomMemo);
begin
  if FOutJSON = Value then
    Exit;
  if FOutJSON <> nil then
    FOutJSON.RemoveFreeNotification(Self);
  FOutJSON := Value;
  if FOutJSON <> nil then
    FOutJSON.FreeNotification(Self);
end;

procedure TLayaResults.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FOutTXT then
      FOutTXT := nil;
    if AComponent = FOutJSON then
      FOutJSON := nil;
  end;
end;

procedure TLayaResults.SetTextAnswer(const Value: TLayaTextAnswer);
begin
  if FTextAnswer = Value then
    Exit;
  FTextAnswer := Value;
  UpdateOutputs;
end;

procedure TLayaResults.Aggregate(const ASources: array of TLayaResults;
  AQuestions: TLayaQuestions);
var
  I, J: Integer;
  Q: TLayaQuestion;
  List: TList<TLayaAnswer>;
  Best, Agg: TLayaAnswer;
  Metric, BestMetric: Double;
  Raws: TStringBuilder;
  N: Integer;
begin
  FItems.Clear;

  { RawJSON: the source response, or a JSON array with all of them }
  N := 0;
  Raws := TStringBuilder.Create;
  try
    for J := Low(ASources) to High(ASources) do
      if (ASources[J] <> nil) and (ASources[J].RawJSON <> '') then
      begin
        if N > 0 then
          Raws.Append(',');
        Raws.Append(ASources[J].RawJSON);
        Inc(N);
      end;
    if N = 1 then
      FRawJSON := Raws.ToString
    else if N > 1 then
      FRawJSON := '[' + Raws.ToString + ']'
    else
      FRawJSON := '';
  finally
    Raws.Free;
  end;

  List := TList<TLayaAnswer>.Create;
  try
    for I := 0 to AQuestions.Count - 1 do
    begin
      Q := AQuestions[I];
      if not Q.Enabled then
        Continue;
      List.Clear;
      for J := Low(ASources) to High(ASources) do
        if (ASources[J] <> nil) and (ASources[J].ByName(Q.Name) <> nil) then
          List.Add(ASources[J].ByName(Q.Name));
      if List.Count = 0 then
        Continue;

      Agg := TLayaAnswer.Create;
      FItems.Add(Agg);
      case Q.Aggregation of
        agMax, agMin:
          begin
            Best := List[0];
            BestMetric := Best.AggregationMetric;
            for J := 1 to List.Count - 1 do
            begin
              Metric := List[J].AggregationMetric;
              if ((Q.Aggregation = agMax) and (Metric > BestMetric)) or
                 ((Q.Aggregation = agMin) and (Metric < BestMetric)) then
              begin
                Best := List[J];
                BestMetric := Metric;
              end;
            end;
            Agg.Assign(Best);
          end;
        agMean:
          Agg.AssignMean(List.ToArray, Q);
      else  { agFirst }
        Agg.Assign(List[0]);
      end;
      Agg.ComputeDecision(Q);
    end;
  finally
    List.Free;
  end;
  DoChange;
end;

procedure TLayaResults.DisableOutputs;
begin
  Inc(FOutputsDisabled);
end;

procedure TLayaResults.EnableOutputs;
begin
  if FOutputsDisabled > 0 then
    Dec(FOutputsDisabled);
  if FOutputsDisabled = 0 then
    UpdateOutputs;
end;

function TLayaResults.OutputsDisabled: Boolean;
begin
  Result := FOutputsDisabled > 0;
end;

procedure TLayaResults.UpdateOutputs;
begin
  if (csDestroying in ComponentState) or (FOutputsDisabled > 0) then
    Exit;
  if FOutTXT <> nil then
    FOutTXT.Lines.Text := AsText;
  if FOutJSON <> nil then
    FOutJSON.Lines.Text := FormattedJSON;
end;

function TLayaResults.AsText: string;
var
  SB: TStringBuilder;
  I: Integer;
  A: TLayaAnswer;
  P: TLayaOptionProbability;
  Txt: string;
begin
  SB := TStringBuilder.Create;
  try
    for I := 0 to FItems.Count - 1 do
    begin
      A := FItems[I];
      if I > 0 then
        SB.AppendLine;
      if FTextAnswer = taKey then
        Txt := A.Answer
      else
        Txt := A.AnswerCaption;
      SB.AppendLine(Format('%s (%s): %s  %.1f %%  -> %s',
        [A.Name, LAYA_KIND_NAMES[A.Kind], Txt, A.Probability * 100, A.DecisionName]));
      for P in A.Probabilities do
      begin
        if FTextAnswer = taKey then
          Txt := P.Key
        else
          Txt := P.Caption;
        SB.AppendLine(Format('    %s: %.1f %%', [Txt, P.Probability * 100]));
      end;
    end;
    Result := SB.ToString.TrimRight;
  finally
    SB.Free;
  end;
end;

function TLayaResults.FormattedJSON: string;
var
  V: TJSONValue;
begin
  Result := FRawJSON;
  if FRawJSON = '' then
    Exit;
  V := TJSONObject.ParseJSONValue(FRawJSON);
  try
    if V <> nil then
      Result := V.Format(2);
  finally
    V.Free;
  end;
end;

procedure TLayaResults.Clear;
begin
  FItems.Clear;
  FRawJSON := '';
  DoChange;
end;

function TLayaResults.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TLayaResults.GetAnswer(Index: Integer): TLayaAnswer;
begin
  Result := FItems[Index];
end;

function TLayaResults.ByName(const AName: string): TLayaAnswer;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
    if SameText(FItems[I].Name, AName) then
      Exit(FItems[I]);
  Result := nil;
end;

procedure TLayaResults.LoadFromJSON(const AJSON: string; AQuestions: TLayaQuestions);
var
  Root: TJSONValue;
  Pair: TJSONPair;
  Ans: TLayaAnswer;
  Q: TLayaQuestion;
begin
  FItems.Clear;
  FRawJSON := AJSON;
  Root := TJSONObject.ParseJSONValue(AJSON);
  try
   try
    if not (Root is TJSONObject) then
      raise ELayaError.Create(SResponseNotObject);
    if not (TJSONObject(Root).GetValue('answers') is TJSONObject) then
      raise ELayaError.Create(SResponseNoAnswers);

    for Pair in TJSONObject(TJSONObject(Root).GetValue('answers')) do
      if Pair.JsonValue is TJSONObject then
      begin
        Q := nil;
        if AQuestions <> nil then
          Q := AQuestions.FindQuestion(Pair.JsonString.Value);
        Ans := TLayaAnswer.Create;
        FItems.Add(Ans);
        Ans.LoadFromJSON(Pair.JsonString.Value, TJSONObject(Pair.JsonValue), Q);
      end;
   except
     DoChange;   // show what arrived, then report the error
     raise;
   end;
  finally
    Root.Free;
  end;
  DoChange;
end;

end.
