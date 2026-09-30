unit Laya.Questions;

{ LAYA para Delphi
  Copyright 2026 Carlos Liñán
  Licensed under the Apache License, Version 2.0.
  See LICENSE in the project root for details. }


{ LAYA components - question definitions.

  TLayaQuestions holds a collection of typed questions (choice, score, noul)
  and converts them to the JSON format expected by the LAYA server.

  Question kinds:
    qkChoice  pick one option. Options: Key = identifier returned by LAYA,
              Description = explanation sent to the model.
    qkScore   level on an ordered scale. Options are the levels, in order
              (lowest first). The text sent is Description (or Key if empty).
    qkNoul    yes/no statement. No options. Returns P(true).

  Thresholds (used by TLayaResults to compute the decision):
    qkNoul    P(true) >= AcceptThreshold  -> ldAccepted (yes, confident)
              P(true) <= RejectThreshold  -> ldRejected (no, confident)
              otherwise                   -> ldReview
    qkChoice/ probability of the chosen answer >= AcceptThreshold -> ldAccepted
    qkScore   otherwise -> ldReview (RejectThreshold is not used) }

interface

uses
  System.SysUtils, System.Classes, System.JSON, Vcl.StdCtrls;

type
  ELayaError = class(Exception);

  TLayaQuestionKind = (qkChoice, qkScore, qkNoul);
  TLayaAggregation = (agMax, agMean, agMin, agFirst);

const
  LAYA_KIND_NAMES: array[TLayaQuestionKind] of string =
    ('choice', 'score', 'noul');
  LAYA_AGGREGATION_NAMES: array[TLayaAggregation] of string =
    ('max', 'mean', 'min', 'first');
  LAYA_DEFAULT_ACCEPT = 0.8;
  LAYA_DEFAULT_REJECT = 0.2;
  LAYA_MAX_CHOICE_OPTIONS = 20;

type
  TLayaOption = class(TCollectionItem)
  private
    FKey: string;
    FDescription: string;
  protected
    function GetDisplayName: string; override;
  public
    procedure Assign(Source: TPersistent); override;
    { Description, or Key when Description is empty }
    function Caption: string;
  published
    property Key: string read FKey write FKey;
    property Description: string read FDescription write FDescription;
  end;

  TLayaOptions = class(TOwnedCollection)
  private
    function GetItem(Index: Integer): TLayaOption;
  public
    constructor Create(AOwner: TPersistent);
    function Add: TLayaOption;
    function AddOption(const AKey, ADescription: string): TLayaOption;
    function IndexOfKey(const AKey: string): Integer;
    property Items[Index: Integer]: TLayaOption read GetItem; default;
  end;

  TLayaQuestion = class(TCollectionItem)
  private
    FName: string;
    FKind: TLayaQuestionKind;
    FInstructions: string;
    FOptions: TLayaOptions;
    FAcceptThreshold: Double;
    FRejectThreshold: Double;
    FAggregation: TLayaAggregation;
    FEnabled: Boolean;
    procedure SetOptions(const Value: TLayaOptions);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    { Question in LAYA wire format: {"type":..., "instructions":..., "criteria":...}
    function ToJSON: TJSONObject;
    { Raises ELayaError if the definition is not usable }
    procedure Validate;
  published
    property Name: string read FName write FName;
    property Kind: TLayaQuestionKind read FKind write FKind default qkNoul;
    property Instructions: string read FInstructions write FInstructions;
    property Options: TLayaOptions read FOptions write SetOptions;
    property AcceptThreshold: Double read FAcceptThreshold write FAcceptThreshold;
    property RejectThreshold: Double read FRejectThreshold write FRejectThreshold;
    property Aggregation: TLayaAggregation read FAggregation write FAggregation default agMax;
    property Enabled: Boolean read FEnabled write FEnabled default True;
  end;

  TLayaQuestionCollection = class(TOwnedCollection)
  private
    function GetItem(Index: Integer): TLayaQuestion;
  public
    constructor Create(AOwner: TPersistent);
    function Add: TLayaQuestion;
    function IndexOfName(const AName: string): Integer;
    function FindByName(const AName: string): TLayaQuestion;
    property Items[Index: Integer]: TLayaQuestion read GetItem; default;
  end;

  TLayaQuestions = class(TComponent)
  private
    FItems: TLayaQuestionCollection;
    FInTXT: TCustomMemo;
    procedure SetItems(const Value: TLayaQuestionCollection);
    procedure SetInTXT(const Value: TCustomMemo);
    function GetCount: Integer;
    function GetQuestion(Index: Integer): TLayaQuestion;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Clear;
    { AOptions: 'key=description' or just 'key' }
    function AddChoice(const AName, AInstructions: string;
      const AOptions: array of string): TLayaQuestion;
    { ALevels: ordered from lowest to highest }
    function AddScore(const AName, AInstructions: string;
      const ALevels: array of string): TLayaQuestion;
    function AddNoul(const AName, AInstructions: string): TLayaQuestion;

    function FindQuestion(const AName: string): TLayaQuestion;
    function EnabledCount: Integer;
    procedure Validate;

    { Enabled questions in LAYA wire format: {"name": {...}
    function ToJSON: TJSONObject;
    function ToJSONString: string;

    { Full definitions (thresholds, aggregation...) in a readable JSON file }
    function DefinitionsToJSON: string;
    procedure DefinitionsFromJSON(const AJSON: string);
    procedure SaveToFile(const AFileName: string);
    procedure LoadFromFile(const AFileName: string);

    { Readable list of the questions: name, kind, instructions and options }
    function AsText: string;
    { DefinitionsToJSON indented, for display }
    function FormattedJSON: string;

    property Count: Integer read GetCount;
    property Questions[Index: Integer]: TLayaQuestion read GetQuestion; default;
  published
    property Items: TLayaQuestionCollection read FItems write SetItems;
    (* Memo with the text to analyse:
       - TLayaServer.Predict / PredictAsync without text read it from here.
       - TLayaDBAnalyzer writes here the text it is sending, unless its
         DisableControls is True. *)
    property InTXT: TCustomMemo read FInTXT write SetInTXT;
  end;

function LayaKindFromString(const S: string; out AKind: TLayaQuestionKind): Boolean;

implementation

uses
  System.IOUtils;

resourcestring
  SQuestionNoName = 'La pregunta nº %d no tiene nombre (Name).';
  SQuestionNoInstructions = 'La pregunta "%s" no tiene texto (Instructions).';
  SQuestionBadThresholds = 'La pregunta "%s" tiene umbrales incorrectos: ' +
    'debe cumplirse 0 <= RejectThreshold <= AcceptThreshold <= 1.';
  SQuestionFewOptions = 'La pregunta "%s" necesita al menos 2 opciones.';
  SQuestionTooManyOptions = 'La pregunta "%s" tiene más de %d opciones; ' +
    'LAYA pierde precisión. Divídela en una pregunta general y otra detallada.';
  SOptionEmpty = 'La pregunta "%s" tiene una opción vacía.';
  SOptionDuplicate = 'La pregunta "%s" tiene la opción "%s" repetida.';
  SQuestionDuplicate = 'Hay dos preguntas con el nombre "%s".';
  SNoQuestions = 'No hay ninguna pregunta activa.';
  SInvalidQuestionsFile = 'El archivo no contiene definiciones de preguntas válidas.';

function LayaKindFromString(const S: string; out AKind: TLayaQuestionKind): Boolean;
var
  K: TLayaQuestionKind;
begin
  for K := Low(TLayaQuestionKind) to High(TLayaQuestionKind) do
    if SameText(S, LAYA_KIND_NAMES[K]) then
    begin
      AKind := K;
      Exit(True);
    end;
  Result := False;
end;

{ TLayaOption }

procedure TLayaOption.Assign(Source: TPersistent);
begin
  if Source is TLayaOption then
  begin
    FKey := TLayaOption(Source).FKey;
    FDescription := TLayaOption(Source).FDescription;
  end
  else
    inherited Assign(Source);
end;

function TLayaOption.Caption: string;
begin
  if FDescription <> '' then
    Result := FDescription
  else
    Result := FKey;
end;

function TLayaOption.GetDisplayName: string;
begin
  if (FKey = '') and (FDescription = '') then
    Result := inherited GetDisplayName
  else if FDescription = '' then
    Result := FKey
  else
    Result := FKey + ' = ' + FDescription;
end;

{ TLayaOptions }

constructor TLayaOptions.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TLayaOption);
end;

function TLayaOptions.Add: TLayaOption;
begin
  Result := TLayaOption(inherited Add);
end;

function TLayaOptions.AddOption(const AKey, ADescription: string): TLayaOption;
begin
  Result := Add;
  Result.Key := AKey;
  Result.Description := ADescription;
end;

function TLayaOptions.GetItem(Index: Integer): TLayaOption;
begin
  Result := TLayaOption(inherited Items[Index]);
end;

function TLayaOptions.IndexOfKey(const AKey: string): Integer;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if SameText(Items[I].Key, AKey) then
      Exit(I);
  Result := -1;
end;

{ TLayaQuestion }

constructor TLayaQuestion.Create(Collection: TCollection);
begin
  inherited Create(Collection);
  FOptions := TLayaOptions.Create(Self);
  FKind := qkNoul;
  FAcceptThreshold := LAYA_DEFAULT_ACCEPT;
  FRejectThreshold := LAYA_DEFAULT_REJECT;
  FAggregation := agMax;
  FEnabled := True;
end;

destructor TLayaQuestion.Destroy;
begin
  FOptions.Free;
  inherited;
end;

procedure TLayaQuestion.Assign(Source: TPersistent);
var
  Src: TLayaQuestion;
begin
  if Source is TLayaQuestion then
  begin
    Src := TLayaQuestion(Source);
    FName := Src.FName;
    FKind := Src.FKind;
    FInstructions := Src.FInstructions;
    FOptions.Assign(Src.FOptions);
    FAcceptThreshold := Src.FAcceptThreshold;
    FRejectThreshold := Src.FRejectThreshold;
    FAggregation := Src.FAggregation;
    FEnabled := Src.FEnabled;
  end
  else
    inherited Assign(Source);
end;

function TLayaQuestion.GetDisplayName: string;
begin
  if FName = '' then
    Result := inherited GetDisplayName
  else
    Result := FName + ' (' + LAYA_KIND_NAMES[FKind] + ')';
end;

procedure TLayaQuestion.SetOptions(const Value: TLayaOptions);
begin
  FOptions.Assign(Value);
end;

function TLayaQuestion.ToJSON: TJSONObject;
var
  Criteria: TJSONObject;
  Levels: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('type', LAYA_KIND_NAMES[FKind]);
    Result.AddPair('instructions', FInstructions);
    case FKind of
      qkChoice:
        begin
          Criteria := TJSONObject.Create;
          Result.AddPair('criteria', Criteria);
          for I := 0 to FOptions.Count - 1 do
            Criteria.AddPair(FOptions[I].Key, FOptions[I].Caption);
        end;
      qkScore:
        begin
          Levels := TJSONArray.Create;
          Result.AddPair('criteria', Levels);
          for I := 0 to FOptions.Count - 1 do
            Levels.Add(FOptions[I].Caption);
        end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TLayaQuestion.Validate;
var
  I, J: Integer;
begin
  if Trim(FName) = '' then
    raise ELayaError.CreateFmt(SQuestionNoName, [Index]);
  if Trim(FInstructions) = '' then
    raise ELayaError.CreateFmt(SQuestionNoInstructions, [FName]);
  if (FRejectThreshold < 0) or (FAcceptThreshold > 1) or
     (FRejectThreshold > FAcceptThreshold) then
    raise ELayaError.CreateFmt(SQuestionBadThresholds, [FName]);

  if FKind in [qkChoice, qkScore] then
  begin
    if FOptions.Count < 2 then
      raise ELayaError.CreateFmt(SQuestionFewOptions, [FName]);
    if (FKind = qkChoice) and (FOptions.Count > LAYA_MAX_CHOICE_OPTIONS) then
      raise ELayaError.CreateFmt(SQuestionTooManyOptions,
        [FName, LAYA_MAX_CHOICE_OPTIONS]);
    for I := 0 to FOptions.Count - 1 do
    begin
      if ((FKind = qkChoice) and (Trim(FOptions[I].Key) = '')) or
         (Trim(FOptions[I].Caption) = '') then
        raise ELayaError.CreateFmt(SOptionEmpty, [FName]);
      if FKind = qkChoice then
        for J := I + 1 to FOptions.Count - 1 do
          if SameText(FOptions[I].Key, FOptions[J].Key) then
            raise ELayaError.CreateFmt(SOptionDuplicate,
              [FName, FOptions[I].Key]);
    end;
  end;
end;

{ TLayaQuestionCollection }

constructor TLayaQuestionCollection.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TLayaQuestion);
end;

function TLayaQuestionCollection.Add: TLayaQuestion;
begin
  Result := TLayaQuestion(inherited Add);
end;

function TLayaQuestionCollection.GetItem(Index: Integer): TLayaQuestion;
begin
  Result := TLayaQuestion(inherited Items[Index]);
end;

function TLayaQuestionCollection.IndexOfName(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if SameText(Items[I].Name, AName) then
      Exit(I);
  Result := -1;
end;

function TLayaQuestionCollection.FindByName(const AName: string): TLayaQuestion;
var
  I: Integer;
begin
  I := IndexOfName(AName);
  if I >= 0 then
    Result := Items[I]
  else
    Result := nil;
end;

{ TLayaQuestions }

constructor TLayaQuestions.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TLayaQuestionCollection.Create(Self);
end;

destructor TLayaQuestions.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TLayaQuestions.SetInTXT(const Value: TCustomMemo);
begin
  if FInTXT = Value then
    Exit;
  if FInTXT <> nil then
    FInTXT.RemoveFreeNotification(Self);
  FInTXT := Value;
  if FInTXT <> nil then
    FInTXT.FreeNotification(Self);
end;

procedure TLayaQuestions.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FInTXT) then
    FInTXT := nil;
end;

procedure TLayaQuestions.SetItems(const Value: TLayaQuestionCollection);
begin
  FItems.Assign(Value);
end;

function TLayaQuestions.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TLayaQuestions.GetQuestion(Index: Integer): TLayaQuestion;
begin
  Result := FItems[Index];
end;

procedure TLayaQuestions.Clear;
begin
  FItems.Clear;
end;

function TLayaQuestions.AddChoice(const AName, AInstructions: string;
  const AOptions: array of string): TLayaQuestion;
var
  I, P: Integer;
  S: string;
begin
  Result := FItems.Add;
  Result.Name := AName;
  Result.Kind := qkChoice;
  Result.Instructions := AInstructions;
  for I := Low(AOptions) to High(AOptions) do
  begin
    S := AOptions[I];
    P := Pos('=', S);
    if P > 0 then
      Result.Options.AddOption(Trim(Copy(S, 1, P - 1)), Trim(Copy(S, P + 1, MaxInt)))
    else
      Result.Options.AddOption(Trim(S), '');
  end;
end;

function TLayaQuestions.AddScore(const AName, AInstructions: string;
  const ALevels: array of string): TLayaQuestion;
var
  I: Integer;
begin
  Result := FItems.Add;
  Result.Name := AName;
  Result.Kind := qkScore;
  Result.Instructions := AInstructions;
  for I := Low(ALevels) to High(ALevels) do
    Result.Options.AddOption(IntToStr(I - Low(ALevels)), ALevels[I]);
end;

function TLayaQuestions.AddNoul(const AName, AInstructions: string): TLayaQuestion;
begin
  Result := FItems.Add;
  Result.Name := AName;
  Result.Kind := qkNoul;
  Result.Instructions := AInstructions;
end;

function TLayaQuestions.FindQuestion(const AName: string): TLayaQuestion;
begin
  Result := FItems.FindByName(AName);
end;

function TLayaQuestions.EnabledCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FItems.Count - 1 do
    if FItems[I].Enabled then
      Inc(Result);
end;

procedure TLayaQuestions.Validate;
var
  I, J: Integer;
begin
  if EnabledCount = 0 then
    raise ELayaError.Create(SNoQuestions);
  for I := 0 to FItems.Count - 1 do
  begin
    if FItems[I].Enabled then
      FItems[I].Validate;
    for J := I + 1 to FItems.Count - 1 do
      if SameText(FItems[I].Name, FItems[J].Name) then
        raise ELayaError.CreateFmt(SQuestionDuplicate, [FItems[I].Name]);
  end;
end;

function TLayaQuestions.ToJSON: TJSONObject;
var
  I: Integer;
begin
  Result := TJSONObject.Create;
  try
    for I := 0 to FItems.Count - 1 do
      if FItems[I].Enabled then
        Result.AddPair(FItems[I].Name, FItems[I].ToJSON);
  except
    Result.Free;
    raise;
  end;
end;

function TLayaQuestions.ToJSONString: string;
var
  O: TJSONObject;
begin
  O := ToJSON;
  try
    Result := O.ToJSON;
  finally
    O.Free;
  end;
end;

function TLayaQuestions.DefinitionsToJSON: string;
var
  Root, QO, OO: TJSONObject;
  QA, OA: TJSONArray;
  I, J: Integer;
  Q: TLayaQuestion;
begin
  Root := TJSONObject.Create;
  try
    QA := TJSONArray.Create;
    Root.AddPair('questions', QA);
    for I := 0 to FItems.Count - 1 do
    begin
      Q := FItems[I];
      QO := TJSONObject.Create;
      QA.AddElement(QO);
      QO.AddPair('name', Q.Name);
      QO.AddPair('kind', LAYA_KIND_NAMES[Q.Kind]);
      QO.AddPair('instructions', Q.Instructions);
      QO.AddPair('acceptThreshold', TJSONNumber.Create(Q.AcceptThreshold));
      QO.AddPair('rejectThreshold', TJSONNumber.Create(Q.RejectThreshold));
      QO.AddPair('aggregation', LAYA_AGGREGATION_NAMES[Q.Aggregation]);
      QO.AddPair('enabled', TJSONBool.Create(Q.Enabled));
      OA := TJSONArray.Create;
      QO.AddPair('options', OA);
      for J := 0 to Q.Options.Count - 1 do
      begin
        OO := TJSONObject.Create;
        OA.AddElement(OO);
        OO.AddPair('key', Q.Options[J].Key);
        OO.AddPair('description', Q.Options[J].Description);
      end;
    end;
    Result := Root.Format(2);
  finally
    Root.Free;
  end;
end;

function TLayaQuestions.AsText: string;
var
  SL: TStringList;
  I, J: Integer;
  Q: TLayaQuestion;
begin
  SL := TStringList.Create;
  try
    SL.Add(Format('Preguntas: %d', [FItems.Count]));
    for I := 0 to FItems.Count - 1 do
    begin
      Q := FItems[I];
      SL.Add('');
      if Q.Enabled then
        SL.Add(Format('%s  (%s)', [Q.Name, LAYA_KIND_NAMES[Q.Kind]]))
      else
        SL.Add(Format('%s  (%s, desactivada)', [Q.Name, LAYA_KIND_NAMES[Q.Kind]]));
      SL.Add('  ' + Q.Instructions);
      for J := 0 to Q.Options.Count - 1 do
        if Q.Options[J].Description <> '' then
          SL.Add(Format('    · %s: %s', [Q.Options[J].Key, Q.Options[J].Description]))
        else
          SL.Add('    · ' + Q.Options[J].Key);
    end;
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

function TLayaQuestions.FormattedJSON: string;
var
  V: TJSONValue;
begin
  Result := DefinitionsToJSON;
  V := TJSONObject.ParseJSONValue(Result);
  try
    if V <> nil then
      Result := V.Format(2);
  finally
    V.Free;
  end;
end;

procedure TLayaQuestions.DefinitionsFromJSON(const AJSON: string);
var
  Root, QV, OV: TJSONValue;
  QO, OO: TJSONObject;
  Q: TLayaQuestion;
  K: TLayaQuestionKind;
  Agg: TLayaAggregation;
  S: string;
begin
  Root := TJSONObject.ParseJSONValue(AJSON);
  try
    if not (Root is TJSONObject) or
       not (TJSONObject(Root).GetValue('questions') is TJSONArray) then
      raise ELayaError.Create(SInvalidQuestionsFile);

    FItems.BeginUpdate;
    try
      FItems.Clear;
      for QV in TJSONArray(TJSONObject(Root).GetValue('questions')) do
      begin
        if not (QV is TJSONObject) then
          Continue;
        QO := TJSONObject(QV);
        Q := FItems.Add;
        Q.Name := QO.GetValue<string>('name', '');
        if LayaKindFromString(QO.GetValue<string>('kind', ''), K) then
          Q.Kind := K;
        Q.Instructions := QO.GetValue<string>('instructions', '');
        Q.AcceptThreshold := QO.GetValue<Double>('acceptThreshold', LAYA_DEFAULT_ACCEPT);
        Q.RejectThreshold := QO.GetValue<Double>('rejectThreshold', LAYA_DEFAULT_REJECT);
        S := QO.GetValue<string>('aggregation', 'max');
        for Agg := Low(TLayaAggregation) to High(TLayaAggregation) do
          if SameText(S, LAYA_AGGREGATION_NAMES[Agg]) then
            Q.Aggregation := Agg;
        Q.Enabled := QO.GetValue<Boolean>('enabled', True);
        if QO.GetValue('options') is TJSONArray then
          for OV in TJSONArray(QO.GetValue('options')) do
            if OV is TJSONObject then
            begin
              OO := TJSONObject(OV);
              Q.Options.AddOption(OO.GetValue<string>('key', ''),
                OO.GetValue<string>('description', ''));
            end;
      end;
    finally
      FItems.EndUpdate;
    end;
  finally
    Root.Free;
  end;
end;

procedure TLayaQuestions.SaveToFile(const AFileName: string);
begin
  TFile.WriteAllText(AFileName, DefinitionsToJSON, TEncoding.UTF8);
end;

procedure TLayaQuestions.LoadFromFile(const AFileName: string);
begin
  DefinitionsFromJSON(TFile.ReadAllText(AFileName, TEncoding.UTF8));
end;

end.
