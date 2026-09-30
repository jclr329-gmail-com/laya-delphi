unit Laya.Client;

{ LAYA para Delphi
  Copyright 2026 Carlos Liñán
  Licensed under the Apache License, Version 2.0.
  See LICENSE in the project root for details. }


{ LAYA components - connection with the LAYA server (FastAPI).

  TLayaServer builds the request from a state and a TLayaQuestions, sends it
  to /predict and fills a TLayaResults.

  Linked components: assign the Questions and Results properties and call the
  short versions: Predict(AText), PredictState(AStateJSON), PredictAsync(AText).
  The long versions with explicit AQuestions/AResults are still available and
  ignore the properties (useful to share one server among several analyses).

  State: LAYA receives a JSON object with one or more text fields.
    Predict(AText, ...)          -> "<StateKey>": AText
    PredictState(AStateJSON,...) -> any JSON object you build yourself
    StateFromFields(['motivo','juicio'], [S1, S2]) helps to build it.

  Errors:
    - Programming errors (no questions, invalid questions, busy) raise ELayaError.
    - Server or network errors do not raise: Predict returns False, LastError
      is set and OnError is fired.

  Questions from the server:
    LoadQuestions asks QuestionsPath (GET /preguntas) for the questions that
    belong to the loaded model and fills Questions (same JSON format as
    TLayaQuestions.LoadFromFile). A fine-tuned model is trained with specific
    question names and instructions, so the server is the best place to keep
    them. Returns False (LastError, OnError) if the server has none configured.

  Threads:
    - Predict / PredictState / CheckHealth / LoadQuestions are synchronous. Events run in the
      calling thread.
    - PredictAsync / PredictStateAsync send the request in a background task;
      results, events and AOnDone run in the main thread. }

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Diagnostics,
  System.Threading, System.Net.HttpClient, Vcl.StdCtrls,
  Laya.Questions, Laya.Results;

type
  TLayaBeforeRequestEvent = procedure(Sender: TObject; var ABody: string) of object;
  TLayaAfterRequestEvent = procedure(Sender: TObject; AStatusCode: Integer;
    const AResponseBody: string; AElapsedMs: Int64) of object;
  TLayaMessageEvent = procedure(Sender: TObject; const AMessage: string) of object;
  TLayaPredictDoneProc = reference to procedure(ASuccess: Boolean);

  { Shared flag so that pending async callbacks know whether the component
    still exists }
  ILayaAlive = interface
    ['{7B4C2E1A-3F5D-4B8E-9A61-2C0D5E7F8A93}']
    function IsAlive: Boolean;
    procedure Kill;
  end;

  TLayaServer = class(TComponent)
  private
    FBaseURL: string;
    FPredictPath: string;
    FHealthPath: string;
    FQuestionsPath: string;
    FConnectionTimeout: Integer;
    FResponseTimeout: Integer;
    FStateKey: string;
    FLastStatusCode: Integer;
    FLastRequestBody: string;
    FLastResponseBody: string;
    FLastElapsedMs: Int64;
    FLastError: string;
    FModelName: string;
    FBusy: Boolean;
    FAlive: ILayaAlive;
    FQuestions: TLayaQuestions;
    FResults: TLayaResults;
    FOnBeforeRequest: TLayaBeforeRequestEvent;
    FOnAfterRequest: TLayaAfterRequestEvent;
    FOnError: TLayaMessageEvent;
    FOnLog: TLayaMessageEvent;
    function BuildURL(const APath: string): string;
    procedure Log(const AMessage: string);
    procedure SetError(const AMessage: string);
    procedure CheckReady(AQuestions: TLayaQuestions; AResults: TLayaResults);
    function PrepareBody(const AStateJSON: string; AQuestions: TLayaQuestions): string;
    function HandlePredictResult(AStatusCode: Integer; const ABody, ATransportError: string;
      AElapsedMs: Int64; AQuestions: TLayaQuestions; AResults: TLayaResults): Boolean;
    function InputText: string;
    procedure SetQuestions(const Value: TLayaQuestions);
    procedure SetResults(const Value: TLayaResults);
    procedure DoPredictStateAsync(const AStateJSON: string; AQuestions: TLayaQuestions;
      AResults: TLayaResults; AOnDone: TLayaPredictDoneProc; ALinked: Boolean);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { GET HealthPath. Fills ModelName. }
    function CheckHealth: Boolean;

    { GET QuestionsPath. Replaces the questions of Questions (or AQuestions)
      with the ones configured in the server for the loaded model. }
    function LoadQuestions: Boolean; overload;
    function LoadQuestions(AQuestions: TLayaQuestions): Boolean; overload;

    function StateFromText(const AText: string): string;
    class function StateFromFields(const ANames, AValues: array of string): string;
    function BuildRequestBody(const AStateJSON: string; AQuestions: TLayaQuestions): string;

    { Using the linked Questions and Results properties.
      Without text: the text is read from Questions.InTXT }
    function Predict: Boolean; overload;
    procedure PredictAsync(AOnDone: TLayaPredictDoneProc = nil); overload;
    function Predict(const AText: string): Boolean; overload;
    function PredictState(const AStateJSON: string): Boolean; overload;
    procedure PredictAsync(const AText: string;
      AOnDone: TLayaPredictDoneProc = nil); overload;
    procedure PredictStateAsync(const AStateJSON: string;
      AOnDone: TLayaPredictDoneProc = nil); overload;

    { With explicit components (the properties are ignored) }
    function Predict(const AText: string; AQuestions: TLayaQuestions;
      AResults: TLayaResults): Boolean; overload;
    function PredictState(const AStateJSON: string; AQuestions: TLayaQuestions;
      AResults: TLayaResults): Boolean; overload;
    procedure PredictAsync(const AText: string; AQuestions: TLayaQuestions;
      AResults: TLayaResults; AOnDone: TLayaPredictDoneProc = nil); overload;
    procedure PredictStateAsync(const AStateJSON: string; AQuestions: TLayaQuestions;
      AResults: TLayaResults; AOnDone: TLayaPredictDoneProc = nil); overload;

    property LastStatusCode: Integer read FLastStatusCode;
    property LastRequestBody: string read FLastRequestBody;
    property LastResponseBody: string read FLastResponseBody;
    property LastElapsedMs: Int64 read FLastElapsedMs;
    property LastError: string read FLastError;
    property ModelName: string read FModelName;
    property Busy: Boolean read FBusy;
  published
    property BaseURL: string read FBaseURL write FBaseURL;
    property PredictPath: string read FPredictPath write FPredictPath;
    property HealthPath: string read FHealthPath write FHealthPath;
    property QuestionsPath: string read FQuestionsPath write FQuestionsPath;
    property ConnectionTimeout: Integer read FConnectionTimeout write FConnectionTimeout default 5000;
    property ResponseTimeout: Integer read FResponseTimeout write FResponseTimeout default 120000;
    property StateKey: string read FStateKey write FStateKey;
    property Questions: TLayaQuestions read FQuestions write SetQuestions;
    property Results: TLayaResults read FResults write SetResults;
    property OnBeforeRequest: TLayaBeforeRequestEvent read FOnBeforeRequest write FOnBeforeRequest;
    property OnAfterRequest: TLayaAfterRequestEvent read FOnAfterRequest write FOnAfterRequest;
    property OnError: TLayaMessageEvent read FOnError write FOnError;
    property OnLog: TLayaMessageEvent read FOnLog write FOnLog;
  end;

implementation

resourcestring
  SNoQuestionsComponent = 'No se ha indicado el componente de preguntas.';
  SNoResultsComponent = 'No se ha indicado el componente de resultados.';
  SServerBusy = 'El servidor LAYA ya está atendiendo una petición.';
  SInvalidState = 'El estado (state) no es un objeto JSON válido.';
  SFieldsMismatch = 'El número de nombres y de valores del estado no coincide.';
  SConnectionError = 'No se pudo conectar con el servidor LAYA en %s (¿está arrancado?). %s';
  SHTTPError = 'El servidor LAYA respondió HTTP %d: %s';
  SNoInTXT = 'Para usar Predict sin texto, asigna Questions y su propiedad InTXT.';
  SParseError = 'No se pudo interpretar la respuesta del servidor LAYA: %s';
  SNoServerQuestions = 'El servidor LAYA no tiene preguntas configuradas para este modelo ' +
    '(variable LAYA_PREGUNTAS en el .bat de arranque).';
  SInvalidServerQuestions = 'Las preguntas recibidas del servidor no son válidas: %s';

type
  TLayaAlive = class(TInterfacedObject, ILayaAlive)
  private
    FAlive: Boolean;
  public
    constructor Create;
    function IsAlive: Boolean;
    procedure Kill;
  end;

  THTTPResult = record
    StatusCode: Integer;
    Body: string;
    ElapsedMs: Int64;
    Error: string;
  end;

constructor TLayaAlive.Create;
begin
  inherited Create;
  FAlive := True;
end;

function TLayaAlive.IsAlive: Boolean;
begin
  Result := FAlive;
end;

procedure TLayaAlive.Kill;
begin
  FAlive := False;
end;

{ Thread-safe: uses only its parameters }
function DoHTTP(const AMethod, AURL, ABody: string;
  AConnectionTimeout, AResponseTimeout: Integer): THTTPResult;
var
  Http: THTTPClient;
  Src: TStringStream;
  Resp: IHTTPResponse;
  SW: TStopwatch;
begin
  Result.StatusCode := 0;
  Result.Body := '';
  Result.Error := '';
  SW := TStopwatch.StartNew;
  Http := THTTPClient.Create;
  try
    try
      Http.ConnectionTimeout := AConnectionTimeout;
      Http.ResponseTimeout := AResponseTimeout;
      if AMethod = 'GET' then
        Resp := Http.Get(AURL)
      else
      begin
        Src := TStringStream.Create(ABody, TEncoding.UTF8);
        try
          Http.ContentType := 'application/json';
          Resp := Http.Post(AURL, Src);
        finally
          Src.Free;
        end;
      end;
      Result.StatusCode := Resp.StatusCode;
      Result.Body := Resp.ContentAsString(TEncoding.UTF8);
    except
      on E: Exception do
        Result.Error := E.Message;
    end;
  finally
    Http.Free;
    Result.ElapsedMs := SW.ElapsedMilliseconds;
  end;
end;

{ TLayaServer }

constructor TLayaServer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAlive := TLayaAlive.Create;
  FBaseURL := 'http://127.0.0.1:8000';
  FPredictPath := '/predict';
  FHealthPath := '/salud';
  FQuestionsPath := '/preguntas';
  FConnectionTimeout := 5000;
  FResponseTimeout := 120000;
  FStateKey := 'text';
end;

destructor TLayaServer.Destroy;
begin
  FAlive.Kill;   // pending async callbacks will do nothing
  inherited;
end;

procedure TLayaServer.SetQuestions(const Value: TLayaQuestions);
begin
  if FQuestions = Value then
    Exit;
  if FQuestions <> nil then
    FQuestions.RemoveFreeNotification(Self);
  FQuestions := Value;
  if FQuestions <> nil then
    FQuestions.FreeNotification(Self);
end;

procedure TLayaServer.SetResults(const Value: TLayaResults);
begin
  if FResults = Value then
    Exit;
  if FResults <> nil then
    FResults.RemoveFreeNotification(Self);
  FResults := Value;
  if FResults <> nil then
    FResults.FreeNotification(Self);
end;

procedure TLayaServer.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FQuestions then
      FQuestions := nil;
    if AComponent = FResults then
      FResults := nil;
  end;
end;

function TLayaServer.BuildURL(const APath: string): string;
var
  Base, Path: string;
begin
  Base := FBaseURL;
  while Base.EndsWith('/') do
    Base := Base.Substring(0, Base.Length - 1);
  Path := APath;
  if (Path <> '') and not Path.StartsWith('/') then
    Path := '/' + Path;
  Result := Base + Path;
end;

procedure TLayaServer.Log(const AMessage: string);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, AMessage);
end;

procedure TLayaServer.SetError(const AMessage: string);
begin
  FLastError := AMessage;
  Log('ERROR: ' + AMessage);
  if Assigned(FOnError) then
    FOnError(Self, AMessage);
end;

procedure TLayaServer.CheckReady(AQuestions: TLayaQuestions; AResults: TLayaResults);
begin
  if FBusy then
    raise ELayaError.Create(SServerBusy);
  if AQuestions = nil then
    raise ELayaError.Create(SNoQuestionsComponent);
  if AResults = nil then
    raise ELayaError.Create(SNoResultsComponent);
  AQuestions.Validate;
end;

function TLayaServer.StateFromText(const AText: string): string;
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  try
    O.AddPair(FStateKey, AText);
    Result := O.ToJSON;
  finally
    O.Free;
  end;
end;

class function TLayaServer.StateFromFields(const ANames, AValues: array of string): string;
var
  O: TJSONObject;
  I: Integer;
begin
  if Length(ANames) <> Length(AValues) then
    raise ELayaError.Create(SFieldsMismatch);
  O := TJSONObject.Create;
  try
    for I := 0 to High(ANames) do
      O.AddPair(ANames[I], AValues[I]);
    Result := O.ToJSON;
  finally
    O.Free;
  end;
end;

function TLayaServer.BuildRequestBody(const AStateJSON: string;
  AQuestions: TLayaQuestions): string;
var
  Root: TJSONObject;
  State: TJSONValue;
begin
  State := TJSONObject.ParseJSONValue(AStateJSON);
  if not (State is TJSONObject) then
  begin
    State.Free;
    raise ELayaError.Create(SInvalidState);
  end;
  Root := TJSONObject.Create;
  try
    Root.AddPair('state', State);
    Root.AddPair('questions', AQuestions.ToJSON);
    Result := Root.ToJSON;
  finally
    Root.Free;   // also frees State and the questions object
  end;
end;

function TLayaServer.PrepareBody(const AStateJSON: string;
  AQuestions: TLayaQuestions): string;
begin
  Result := BuildRequestBody(AStateJSON, AQuestions);
  if Assigned(FOnBeforeRequest) then
    FOnBeforeRequest(Self, Result);
  FLastRequestBody := Result;
  Log('POST ' + BuildURL(FPredictPath));
end;

function TLayaServer.HandlePredictResult(AStatusCode: Integer;
  const ABody, ATransportError: string; AElapsedMs: Int64;
  AQuestions: TLayaQuestions; AResults: TLayaResults): Boolean;
begin
  Result := False;
  FLastStatusCode := AStatusCode;
  FLastResponseBody := ABody;
  FLastElapsedMs := AElapsedMs;
  FLastError := '';

  if Assigned(FOnAfterRequest) then
    FOnAfterRequest(Self, AStatusCode, ABody, AElapsedMs);

  if ATransportError <> '' then
  begin
    AResults.Clear;
    SetError(Format(SConnectionError, [FBaseURL, ATransportError]));
    Exit;
  end;

  if AStatusCode <> 200 then
  begin
    AResults.Clear;
    SetError(Format(SHTTPError, [AStatusCode, ABody]));
    Exit;
  end;

  try
    AResults.LoadFromJSON(ABody, AQuestions);
    Result := True;
    Log(Format('OK: %d respuestas en %d ms', [AResults.Count, AElapsedMs]));
  except
    on E: Exception do
      SetError(Format(SParseError, [E.Message]));
  end;
end;

function TLayaServer.CheckHealth: Boolean;
var
  R: THTTPResult;
  V, M: TJSONValue;
begin
  Result := False;
  FModelName := '';
  FLastRequestBody := '';
  Log('GET ' + BuildURL(FHealthPath));
  R := DoHTTP('GET', BuildURL(FHealthPath), '', FConnectionTimeout, FResponseTimeout);
  FLastStatusCode := R.StatusCode;
  FLastResponseBody := R.Body;
  FLastElapsedMs := R.ElapsedMs;
  FLastError := '';

  if R.Error <> '' then
  begin
    SetError(Format(SConnectionError, [FBaseURL, R.Error]));
    Exit;
  end;
  if R.StatusCode <> 200 then
  begin
    SetError(Format(SHTTPError, [R.StatusCode, R.Body]));
    Exit;
  end;

  V := TJSONObject.ParseJSONValue(R.Body);
  try
    if V is TJSONObject then
    begin
      M := TJSONObject(V).GetValue('model');
      if M = nil then
        M := TJSONObject(V).GetValue('modelo');
      if M <> nil then
        FModelName := M.Value;
    end;
  finally
    V.Free;
  end;
  Log('Servidor OK. Modelo: ' + FModelName);
  Result := True;
end;

function TLayaServer.LoadQuestions: Boolean;
begin
  Result := LoadQuestions(FQuestions);
end;

function TLayaServer.LoadQuestions(AQuestions: TLayaQuestions): Boolean;
var
  R: THTTPResult;
begin
  Result := False;
  if FBusy then
    raise ELayaError.Create(SServerBusy);
  if AQuestions = nil then
    raise ELayaError.Create(SNoQuestionsComponent);

  FLastRequestBody := '';
  Log('GET ' + BuildURL(FQuestionsPath));
  R := DoHTTP('GET', BuildURL(FQuestionsPath), '', FConnectionTimeout, FResponseTimeout);
  FLastStatusCode := R.StatusCode;
  FLastResponseBody := R.Body;
  FLastElapsedMs := R.ElapsedMs;
  FLastError := '';

  if R.Error <> '' then
  begin
    SetError(Format(SConnectionError, [FBaseURL, R.Error]));
    Exit;
  end;
  if R.StatusCode = 404 then
  begin
    SetError(SNoServerQuestions);
    Exit;
  end;
  if R.StatusCode <> 200 then
  begin
    SetError(Format(SHTTPError, [R.StatusCode, R.Body]));
    Exit;
  end;

  try
    AQuestions.DefinitionsFromJSON(R.Body);
    AQuestions.Validate;
  except
    on E: Exception do
    begin
      SetError(Format(SInvalidServerQuestions, [E.Message]));
      Exit;
    end;
  end;
  Log(Format('Preguntas cargadas del servidor: %d', [AQuestions.Count]));
  Result := True;
end;

function TLayaServer.InputText: string;
begin
  if (FQuestions = nil) or (FQuestions.InTXT = nil) then
    raise ELayaError.Create(SNoInTXT);
  Result := FQuestions.InTXT.Text;
end;

function TLayaServer.Predict: Boolean;
begin
  Result := Predict(InputText);
end;

procedure TLayaServer.PredictAsync(AOnDone: TLayaPredictDoneProc);
begin
  PredictAsync(InputText, AOnDone);
end;

function TLayaServer.Predict(const AText: string): Boolean;
begin
  Result := PredictState(StateFromText(AText), FQuestions, FResults);
end;

function TLayaServer.PredictState(const AStateJSON: string): Boolean;
begin
  Result := PredictState(AStateJSON, FQuestions, FResults);
end;

procedure TLayaServer.PredictAsync(const AText: string; AOnDone: TLayaPredictDoneProc);
begin
  DoPredictStateAsync(StateFromText(AText), FQuestions, FResults, AOnDone, True);
end;

procedure TLayaServer.PredictStateAsync(const AStateJSON: string;
  AOnDone: TLayaPredictDoneProc);
begin
  DoPredictStateAsync(AStateJSON, FQuestions, FResults, AOnDone, True);
end;

function TLayaServer.Predict(const AText: string; AQuestions: TLayaQuestions;
  AResults: TLayaResults): Boolean;
begin
  Result := PredictState(StateFromText(AText), AQuestions, AResults);
end;

function TLayaServer.PredictState(const AStateJSON: string;
  AQuestions: TLayaQuestions; AResults: TLayaResults): Boolean;
var
  Body: string;
  R: THTTPResult;
begin
  CheckReady(AQuestions, AResults);
  Body := PrepareBody(AStateJSON, AQuestions);
  FBusy := True;
  try
    R := DoHTTP('POST', BuildURL(FPredictPath), Body,
      FConnectionTimeout, FResponseTimeout);
  finally
    FBusy := False;
  end;
  Result := HandlePredictResult(R.StatusCode, R.Body, R.Error, R.ElapsedMs,
    AQuestions, AResults);
end;

procedure TLayaServer.PredictAsync(const AText: string; AQuestions: TLayaQuestions;
  AResults: TLayaResults; AOnDone: TLayaPredictDoneProc);
begin
  DoPredictStateAsync(StateFromText(AText), AQuestions, AResults, AOnDone, False);
end;

procedure TLayaServer.PredictStateAsync(const AStateJSON: string;
  AQuestions: TLayaQuestions; AResults: TLayaResults; AOnDone: TLayaPredictDoneProc);
begin
  DoPredictStateAsync(AStateJSON, AQuestions, AResults, AOnDone, False);
end;

(* ALinked: the call used the Questions/Results properties. If one of those
   components is removed or changed while the request is running, the answer
   is discarded. *)
procedure TLayaServer.DoPredictStateAsync(const AStateJSON: string;
  AQuestions: TLayaQuestions; AResults: TLayaResults; AOnDone: TLayaPredictDoneProc;
  ALinked: Boolean);
var
  Body, URL: string;
  ConnTimeout, RespTimeout: Integer;
  Alive: ILayaAlive;
begin
  CheckReady(AQuestions, AResults);
  Body := PrepareBody(AStateJSON, AQuestions);
  URL := BuildURL(FPredictPath);
  ConnTimeout := FConnectionTimeout;
  RespTimeout := FResponseTimeout;
  Alive := FAlive;
  FBusy := True;

  TTask.Run(
    procedure
    var
      R: THTTPResult;
    begin
      R := DoHTTP('POST', URL, Body, ConnTimeout, RespTimeout);
      TThread.Queue(nil,
        procedure
        var
          OK: Boolean;
        begin
          if not Alive.IsAlive then
            Exit;   // the component was destroyed meanwhile
          FBusy := False;
          if ALinked and ((FQuestions <> AQuestions) or (FResults <> AResults)) then
            Exit;   // linked components changed or were removed meanwhile
          OK := HandlePredictResult(R.StatusCode, R.Body, R.Error, R.ElapsedMs,
            AQuestions, AResults);
          if Assigned(AOnDone) then
            AOnDone(OK);
        end);
    end);
end;

end.
