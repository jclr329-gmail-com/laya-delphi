unit Laya.DBEditor;

(* LAYA components - visual configuration of TLayaDBAnalyzer.

  LayaEditDBAnalyzer shows a dialog that reads the fields of DataSetTarget
  and DataSetSource and the questions of the analyzer, and lets you choose
  the text fields, the control fields and the Mappings with drop-down lists.
  "Asignación automática" creates the Mappings by matching question names
  with field names (e.g. baja -> Baja_name, Baja_prct, Baja_dec).

  Used by the IDE (double click on the component) and also available at
  run time. Changes are applied only when the user presses Aceptar. *)

interface

uses
  Laya.DB;

function LayaEditDBAnalyzer(AAnalyzer: TLayaDBAnalyzer): Boolean;

implementation

uses
  System.SysUtils, System.Classes, System.UITypes, Data.DB,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Dialogs,
  Laya.Questions, Laya.Client;

const
  FORMAT_NAMES: array[TLayaAnswerFormat] of string =
    ('Automático', 'Clave', 'Descripción', 'Nivel (número)', 'Puntuación / P(verdadero)');
  WRITE_MODE_NAMES: array[TLayaWriteMode] of string =
    ('Siempre', 'Solo si hay decisión (review = NULL)');
  LINK_MODE_NAMES: array[TLayaLinkMode] of string =
    ('lmSameDataSet - el texto está en el propio registro destino',
     'lmMasterDetail - origen enlazado como detalle del destino',
     'lmFilter - filtrar el origen por la clave del destino');

type
  TLayaDBEditorForm = class(TForm)
  private
    FAnalyzer: TLayaDBAnalyzer;
    FMappings: TLayaFieldMappings;
    FTargetFields: TStringList;
    FSourceFields: TStringList;
    FLoading: Boolean;

    cbLinkMode: TComboBox;
    lblDataSets: TLabel;
    lvSource: TListView;
    cbKeyTarget: TComboBox;
    cbKeySource: TComboBox;
    cbLock: TComboBox;
    cbDate: TComboBox;
    cbModel: TComboBox;
    lvMappings: TListView;
    btnAdd: TButton;
    btnDelete: TButton;
    btnAuto: TButton;
    cbQuestion: TComboBox;
    cbFormat: TComboBox;
    cbAnswer: TComboBox;
    cbWriteMode: TComboBox;
    cbProb: TComboBox;
    cbDecision: TComboBox;
    edTrue: TEdit;
    edFalse: TEdit;

    function Questions: TLayaQuestions;
    function SourceDataSet: TDataSet;
    function AddLabel(AParent: TWinControl; X, Y: Integer; const ACaption: string): TLabel;
    function AddCombo(AParent: TWinControl; X, Y, W: Integer; AEditable: Boolean): TComboBox;
    procedure FillFieldCombo(ACombo: TComboBox; AFields: TStrings);
    procedure BuildUI;
    procedure LoadFields;
    procedure LoadSourceList(const AChecked: string);
    function CheckedSourceFields: string;
    procedure LoadFromAnalyzer;
    procedure ApplyToAnalyzer;
    procedure RefreshMappings(ASelect: Integer);
    procedure UpdateMappingItem(AItem: TListItem; M: TLayaFieldMapping);
    function CurrentMapping: TLayaFieldMapping;
    procedure LoadEditor;
    procedure UpdateEditorState;
    function IsMapped(const AQuestion: string): Boolean;

    procedure LinkModeChange(Sender: TObject);
    procedure MappingSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure EditorChange(Sender: TObject);
    procedure AddClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure AutoClick(Sender: TObject);
    procedure OkClick(Sender: TObject);
  public
    constructor CreateFor(AAnalyzer: TLayaDBAnalyzer);
    destructor Destroy; override;
  end;

function ContainsAny(const S: string; const AParts: array of string): Boolean;
var
  I: Integer;
begin
  for I := Low(AParts) to High(AParts) do
    if Pos(AParts[I], S) > 0 then
      Exit(True);
  Result := False;
end;

procedure GetDataSetFields(ADataSet: TDataSet; AList: TStrings);
begin
  AList.Clear;
  if ADataSet = nil then
    Exit;
  try
    ADataSet.GetFieldNames(AList);
  except
    { the dataset cannot give its fields now (e.g. closed at design time
      without connection): the combos stay editable }
    AList.Clear;
  end;
end;

{ TLayaDBEditorForm }

constructor TLayaDBEditorForm.CreateFor(AAnalyzer: TLayaDBAnalyzer);
begin
  inherited CreateNew(nil);
  FAnalyzer := AAnalyzer;
  FMappings := TLayaFieldMappings.Create(nil);
  FTargetFields := TStringList.Create;
  FSourceFields := TStringList.Create;
  BuildUI;
  LoadFromAnalyzer;
end;

destructor TLayaDBEditorForm.Destroy;
begin
  FSourceFields.Free;
  FTargetFields.Free;
  FMappings.Free;
  inherited;
end;

function TLayaDBEditorForm.Questions: TLayaQuestions;
begin
  Result := FAnalyzer.Questions;
  if (Result = nil) and (FAnalyzer.Server <> nil) then
    Result := FAnalyzer.Server.Questions;
end;

function TLayaDBEditorForm.SourceDataSet: TDataSet;
begin
  if TLayaLinkMode(cbLinkMode.ItemIndex) = lmSameDataSet then
    Result := FAnalyzer.DataSetTarget
  else
    Result := FAnalyzer.DataSetSource;
end;

function TLayaDBEditorForm.AddLabel(AParent: TWinControl; X, Y: Integer;
  const ACaption: string): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.Left := X;
  Result.Top := Y;
  Result.Caption := ACaption;
end;

function TLayaDBEditorForm.AddCombo(AParent: TWinControl; X, Y, W: Integer;
  AEditable: Boolean): TComboBox;
begin
  Result := TComboBox.Create(Self);
  Result.Parent := AParent;
  Result.SetBounds(X, Y, W, 23);
  if AEditable then
    Result.Style := csDropDown
  else
    Result.Style := csDropDownList;
  Result.DropDownCount := 20;
end;

procedure TLayaDBEditorForm.FillFieldCombo(ACombo: TComboBox; AFields: TStrings);
var
  S: string;
begin
  S := ACombo.Text;
  ACombo.Items.BeginUpdate;
  try
    ACombo.Items.Clear;
    ACombo.Items.Add('');
    ACombo.Items.AddStrings(AFields);
  finally
    ACombo.Items.EndUpdate;
  end;
  ACombo.Text := S;
end;

procedure TLayaDBEditorForm.BuildUI;
var
  gbSource, gbControl, gbMap: TGroupBox;
  M: TLayaLinkMode;
  F: TLayaAnswerFormat;
  W: TLayaWriteMode;
  L: TLabel;

  function Col(const ACaption: string; AWidth: Integer): TListColumn;
  begin
    Result := lvMappings.Columns.Add;
    Result.Caption := ACaption;
    Result.Width := AWidth;
  end;

begin
  Caption := 'Configurar ' + FAnalyzer.Name;
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  ClientWidth := 860;
  ClientHeight := 624;
  Font.Name := 'Segoe UI';
  Font.Size := 9;

  { --- Texto a analizar --- }
  gbSource := TGroupBox.Create(Self);
  gbSource.Parent := Self;
  gbSource.SetBounds(8, 8, 420, 304);
  gbSource.Caption := ' Texto a analizar ';

  AddLabel(gbSource, 12, 22, 'Modo de enlace (LinkMode)');
  cbLinkMode := AddCombo(gbSource, 12, 40, 396, False);
  for M := Low(TLayaLinkMode) to High(TLayaLinkMode) do
    cbLinkMode.Items.Add(LINK_MODE_NAMES[M]);
  cbLinkMode.OnChange := LinkModeChange;

  lblDataSets := AddLabel(gbSource, 12, 70, '');

  AddLabel(gbSource, 12, 92, 'Campos con el texto (FieldsSource), marca uno o varios');
  lvSource := TListView.Create(Self);
  lvSource.Parent := gbSource;
  lvSource.SetBounds(12, 110, 396, 126);
  lvSource.ViewStyle := vsReport;
  lvSource.Checkboxes := True;
  lvSource.ShowColumnHeaders := False;
  lvSource.ReadOnly := True;
  lvSource.Columns.Add.Width := 370;

  AddLabel(gbSource, 12, 244, 'Clave destino (FieldKeyTarget)');
  cbKeyTarget := AddCombo(gbSource, 12, 262, 190, True);
  AddLabel(gbSource, 218, 244, 'Clave origen (FieldKeySource)');
  cbKeySource := AddCombo(gbSource, 218, 262, 190, True);

  { --- Control y auditoría --- }
  gbControl := TGroupBox.Create(Self);
  gbControl.Parent := Self;
  gbControl.SetBounds(436, 8, 416, 304);
  gbControl.Caption := ' Control y auditoría (campos de DataSetTarget) ';

  AddLabel(gbControl, 12, 22, 'Registro revisado, no tocar (FieldLock)');
  cbLock := AddCombo(gbControl, 12, 40, 390, True);
  AddLabel(gbControl, 12, 74, 'Fecha del análisis (FieldDate)');
  cbDate := AddCombo(gbControl, 12, 92, 390, True);
  AddLabel(gbControl, 12, 126, 'Modelo usado (FieldModel)');
  cbModel := AddCombo(gbControl, 12, 144, 390, True);

  L := AddLabel(gbControl, 12, 186,
    'Los campos se leen de los datasets. Si la tabla está cerrada y la ' +
    'lista sale vacía, ábrela (Active = True) o escribe el nombre a mano.');
  L.WordWrap := True;
  L.AutoSize := False;
  L.SetBounds(12, 186, 390, 60);

  { --- Asignaciones --- }
  gbMap := TGroupBox.Create(Self);
  gbMap.Parent := Self;
  gbMap.SetBounds(8, 320, 844, 256);
  gbMap.Caption := ' Asignaciones: qué respuesta va a qué campo (Mappings) ';

  lvMappings := TListView.Create(Self);
  lvMappings.Parent := gbMap;
  lvMappings.SetBounds(12, 22, 470, 190);
  lvMappings.ViewStyle := vsReport;
  lvMappings.RowSelect := True;
  lvMappings.ReadOnly := True;
  lvMappings.HideSelection := False;
  lvMappings.GridLines := True;
  Col('Pregunta', 95);
  Col('Respuesta', 110);
  Col('Formato', 85);
  Col('Probabilidad', 90);
  Col('Decisión', 80);
  lvMappings.OnSelectItem := MappingSelect;

  btnAdd := TButton.Create(Self);
  btnAdd.Parent := gbMap;
  btnAdd.SetBounds(12, 220, 90, 26);
  btnAdd.Caption := 'Añadir';
  btnAdd.OnClick := AddClick;

  btnDelete := TButton.Create(Self);
  btnDelete.Parent := gbMap;
  btnDelete.SetBounds(108, 220, 90, 26);
  btnDelete.Caption := 'Eliminar';
  btnDelete.OnClick := DeleteClick;

  btnAuto := TButton.Create(Self);
  btnAuto.Parent := gbMap;
  btnAuto.SetBounds(204, 220, 150, 26);
  btnAuto.Caption := 'Asignación automática';
  btnAuto.OnClick := AutoClick;

  AddLabel(gbMap, 494, 20, 'Pregunta');
  cbQuestion := AddCombo(gbMap, 494, 38, 165, True);
  AddLabel(gbMap, 669, 20, 'Formato de la respuesta');
  cbFormat := AddCombo(gbMap, 669, 38, 165, False);
  for F := Low(TLayaAnswerFormat) to High(TLayaAnswerFormat) do
    cbFormat.Items.Add(FORMAT_NAMES[F]);

  AddLabel(gbMap, 494, 68, 'Campo de la respuesta');
  cbAnswer := AddCombo(gbMap, 494, 86, 165, True);
  AddLabel(gbMap, 669, 68, 'Escritura');
  cbWriteMode := AddCombo(gbMap, 669, 86, 165, False);
  for W := Low(TLayaWriteMode) to High(TLayaWriteMode) do
    cbWriteMode.Items.Add(WRITE_MODE_NAMES[W]);

  AddLabel(gbMap, 494, 116, 'Campo de probabilidad');
  cbProb := AddCombo(gbMap, 494, 134, 165, True);
  AddLabel(gbMap, 669, 116, 'Campo de decisión');
  cbDecision := AddCombo(gbMap, 669, 134, 165, True);

  AddLabel(gbMap, 494, 164, 'Texto si verdadero (noul)');
  edTrue := TEdit.Create(Self);
  edTrue.Parent := gbMap;
  edTrue.SetBounds(494, 182, 165, 23);
  AddLabel(gbMap, 669, 164, 'Texto si falso (noul)');
  edFalse := TEdit.Create(Self);
  edFalse.Parent := gbMap;
  edFalse.SetBounds(669, 182, 165, 23);

  cbQuestion.OnChange := EditorChange;
  cbFormat.OnChange := EditorChange;
  cbAnswer.OnChange := EditorChange;
  cbWriteMode.OnChange := EditorChange;
  cbProb.OnChange := EditorChange;
  cbDecision.OnChange := EditorChange;
  edTrue.OnChange := EditorChange;
  edFalse.OnChange := EditorChange;

  { --- Botones --- }
  with TButton.Create(Self) do
  begin
    Parent := Self;
    SetBounds(676, 588, 85, 28);
    Caption := 'Aceptar';
    Default := True;
    OnClick := OkClick;
  end;
  with TButton.Create(Self) do
  begin
    Parent := Self;
    SetBounds(767, 588, 85, 28);
    Caption := 'Cancelar';
    Cancel := True;
    ModalResult := mrCancel;
  end;
end;

procedure TLayaDBEditorForm.LoadFields;
var
  Q: TLayaQuestions;
  I: Integer;
  TN, SN: string;
begin
  GetDataSetFields(FAnalyzer.DataSetTarget, FTargetFields);
  GetDataSetFields(SourceDataSet, FSourceFields);

  if FAnalyzer.DataSetTarget <> nil then
    TN := FAnalyzer.DataSetTarget.Name
  else
    TN := '(sin asignar)';
  if FAnalyzer.DataSetSource <> nil then
    SN := FAnalyzer.DataSetSource.Name
  else
    SN := '(sin asignar)';
  lblDataSets.Caption := Format('Destino: %s  (%d campos)     Origen: %s',
    [TN, FTargetFields.Count, SN]);

  FillFieldCombo(cbKeyTarget, FTargetFields);
  FillFieldCombo(cbKeySource, FSourceFields);
  FillFieldCombo(cbLock, FTargetFields);
  FillFieldCombo(cbDate, FTargetFields);
  FillFieldCombo(cbModel, FTargetFields);
  FillFieldCombo(cbAnswer, FTargetFields);
  FillFieldCombo(cbProb, FTargetFields);
  FillFieldCombo(cbDecision, FTargetFields);

  cbQuestion.Items.Clear;
  Q := Questions;
  if Q <> nil then
    for I := 0 to Q.Count - 1 do
      if Q[I].Enabled then
        cbQuestion.Items.Add(Q[I].Name);
end;

procedure TLayaDBEditorForm.LoadSourceList(const AChecked: string);
var
  Names: TArray<string>;
  I: Integer;
  Item: TListItem;
  N: string;
begin
  Names := AChecked.Split([';', ','], TStringSplitOptions.ExcludeEmpty);
  lvSource.Items.BeginUpdate;
  try
    lvSource.Items.Clear;
    for I := 0 to FSourceFields.Count - 1 do
    begin
      Item := lvSource.Items.Add;
      Item.Caption := FSourceFields[I];
    end;
    { mark the chosen fields; add those that the dataset did not report }
    for N in Names do
    begin
      Item := lvSource.FindCaption(0, Trim(N), False, True, False);
      if Item = nil then
      begin
        Item := lvSource.Items.Add;
        Item.Caption := Trim(N);
      end;
      Item.Checked := True;
    end;
  finally
    lvSource.Items.EndUpdate;
  end;
end;

function TLayaDBEditorForm.CheckedSourceFields: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to lvSource.Items.Count - 1 do
    if lvSource.Items[I].Checked then
    begin
      if Result <> '' then
        Result := Result + ';';
      Result := Result + lvSource.Items[I].Caption;
    end;
end;

procedure TLayaDBEditorForm.LoadFromAnalyzer;
begin
  FLoading := True;
  try
    cbLinkMode.ItemIndex := Ord(FAnalyzer.LinkMode);
    LoadFields;
    LoadSourceList(FAnalyzer.FieldsSource);
    cbKeyTarget.Text := FAnalyzer.FieldKeyTarget;
    cbKeySource.Text := FAnalyzer.FieldKeySource;
    cbLock.Text := FAnalyzer.FieldLock;
    cbDate.Text := FAnalyzer.FieldDate;
    cbModel.Text := FAnalyzer.FieldModel;
    FMappings.Assign(FAnalyzer.Mappings);
  finally
    FLoading := False;
  end;
  RefreshMappings(0);
  UpdateEditorState;
end;

procedure TLayaDBEditorForm.ApplyToAnalyzer;
begin
  FAnalyzer.LinkMode := TLayaLinkMode(cbLinkMode.ItemIndex);
  FAnalyzer.FieldsSource := CheckedSourceFields;
  FAnalyzer.FieldKeyTarget := Trim(cbKeyTarget.Text);
  FAnalyzer.FieldKeySource := Trim(cbKeySource.Text);
  FAnalyzer.FieldLock := Trim(cbLock.Text);
  FAnalyzer.FieldDate := Trim(cbDate.Text);
  FAnalyzer.FieldModel := Trim(cbModel.Text);
  FAnalyzer.Mappings.Assign(FMappings);
end;

procedure TLayaDBEditorForm.UpdateMappingItem(AItem: TListItem; M: TLayaFieldMapping);
begin
  AItem.Caption := M.QuestionName;
  AItem.SubItems.Clear;
  AItem.SubItems.Add(M.FieldAnswer);
  AItem.SubItems.Add(FORMAT_NAMES[M.AnswerFormat]);
  AItem.SubItems.Add(M.FieldProbability);
  AItem.SubItems.Add(M.FieldDecision);
end;

procedure TLayaDBEditorForm.RefreshMappings(ASelect: Integer);
var
  I: Integer;
begin
  lvMappings.Items.BeginUpdate;
  try
    lvMappings.Items.Clear;
    for I := 0 to FMappings.Count - 1 do
      UpdateMappingItem(lvMappings.Items.Add, FMappings[I]);
  finally
    lvMappings.Items.EndUpdate;
  end;
  if ASelect >= FMappings.Count then
    ASelect := FMappings.Count - 1;
  if ASelect >= 0 then
    lvMappings.Items[ASelect].Selected := True;
  LoadEditor;
end;

function TLayaDBEditorForm.CurrentMapping: TLayaFieldMapping;
begin
  if (lvMappings.Selected <> nil) and (lvMappings.Selected.Index < FMappings.Count) then
    Result := FMappings[lvMappings.Selected.Index]
  else
    Result := nil;
end;

procedure TLayaDBEditorForm.LoadEditor;
var
  M: TLayaFieldMapping;
begin
  M := CurrentMapping;
  FLoading := True;
  try
    if M = nil then
    begin
      cbQuestion.Text := '';
      cbAnswer.Text := '';
      cbProb.Text := '';
      cbDecision.Text := '';
      cbFormat.ItemIndex := -1;
      cbWriteMode.ItemIndex := -1;
      edTrue.Text := '';
      edFalse.Text := '';
    end
    else
    begin
      cbQuestion.Text := M.QuestionName;
      cbAnswer.Text := M.FieldAnswer;
      cbProb.Text := M.FieldProbability;
      cbDecision.Text := M.FieldDecision;
      cbFormat.ItemIndex := Ord(M.AnswerFormat);
      cbWriteMode.ItemIndex := Ord(M.WriteMode);
      edTrue.Text := M.TrueValue;
      edFalse.Text := M.FalseValue;
    end;
  finally
    FLoading := False;
  end;
  UpdateEditorState;
end;

procedure TLayaDBEditorForm.UpdateEditorState;
var
  HasSel, IsFilter: Boolean;
begin
  HasSel := CurrentMapping <> nil;
  cbQuestion.Enabled := HasSel;
  cbFormat.Enabled := HasSel;
  cbAnswer.Enabled := HasSel;
  cbWriteMode.Enabled := HasSel;
  cbProb.Enabled := HasSel;
  cbDecision.Enabled := HasSel;
  edTrue.Enabled := HasSel;
  edFalse.Enabled := HasSel;
  btnDelete.Enabled := HasSel;

  IsFilter := TLayaLinkMode(cbLinkMode.ItemIndex) = lmFilter;
  cbKeyTarget.Enabled := IsFilter;
  cbKeySource.Enabled := IsFilter;
end;

function TLayaDBEditorForm.IsMapped(const AQuestion: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to FMappings.Count - 1 do
    if SameText(FMappings[I].QuestionName, AQuestion) then
      Exit(True);
  Result := False;
end;

procedure TLayaDBEditorForm.LinkModeChange(Sender: TObject);
var
  Checked: string;
begin
  if FLoading then
    Exit;
  Checked := CheckedSourceFields;
  LoadFields;
  LoadSourceList(Checked);
  UpdateEditorState;
end;

procedure TLayaDBEditorForm.MappingSelect(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
  if Selected then
    LoadEditor
  else
    UpdateEditorState;
end;

procedure TLayaDBEditorForm.EditorChange(Sender: TObject);
var
  M: TLayaFieldMapping;
begin
  if FLoading then
    Exit;
  M := CurrentMapping;
  if M = nil then
    Exit;
  M.QuestionName := Trim(cbQuestion.Text);
  M.FieldAnswer := Trim(cbAnswer.Text);
  M.FieldProbability := Trim(cbProb.Text);
  M.FieldDecision := Trim(cbDecision.Text);
  if cbFormat.ItemIndex >= 0 then
    M.AnswerFormat := TLayaAnswerFormat(cbFormat.ItemIndex);
  if cbWriteMode.ItemIndex >= 0 then
    M.WriteMode := TLayaWriteMode(cbWriteMode.ItemIndex);
  M.TrueValue := edTrue.Text;
  M.FalseValue := edFalse.Text;
  UpdateMappingItem(lvMappings.Selected, M);
end;

procedure TLayaDBEditorForm.AddClick(Sender: TObject);
var
  M: TLayaFieldMapping;
begin
  M := FMappings.Add;
  if cbQuestion.Items.Count > 0 then
    M.QuestionName := cbQuestion.Items[0];
  RefreshMappings(FMappings.Count - 1);
  cbQuestion.SetFocus;
end;

procedure TLayaDBEditorForm.DeleteClick(Sender: TObject);
var
  I: Integer;
begin
  if lvMappings.Selected = nil then
    Exit;
  I := lvMappings.Selected.Index;
  FMappings.Delete(I);
  RefreshMappings(I);
end;

procedure TLayaDBEditorForm.AutoClick(Sender: TObject);
var
  Q: TLayaQuestions;
  QI: TLayaQuestion;
  I, J, Added: Integer;
  QN, FN, Prob, Dec: string;
  Answers: TStringList;
  M: TLayaFieldMapping;
begin
  Q := Questions;
  if Q = nil then
  begin
    MessageDlg('El analizador no tiene preguntas (Questions o Server.Questions).',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  if FTargetFields.Count = 0 then
  begin
    MessageDlg('No se han podido leer los campos de DataSetTarget. ' +
      'Abre la tabla (Active = True) y vuelve a abrir esta ventana.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  Added := 0;
  Answers := TStringList.Create;
  try
    for I := 0 to Q.Count - 1 do
    begin
      QI := Q[I];
      if not QI.Enabled or IsMapped(QI.Name) then
        Continue;
      QN := LowerCase(QI.Name);
      Prob := '';
      Dec := '';
      Answers.Clear;
      for J := 0 to FTargetFields.Count - 1 do
      begin
        FN := LowerCase(FTargetFields[J]);
        if Pos(QN, FN) = 0 then
          Continue;
        if ContainsAny(FN, ['prct', 'prob', 'pct', 'porc']) then
          Prob := FTargetFields[J]
        else if ContainsAny(FN, ['_dec', 'decis']) then
          Dec := FTargetFields[J]
        else
          Answers.Add(FTargetFields[J]);
      end;
      if (Answers.Count = 0) and (Prob = '') and (Dec = '') then
        Continue;
      if Answers.Count = 0 then
        Answers.Add('');

      for J := 0 to Answers.Count - 1 do
      begin
        M := FMappings.Add;
        M.QuestionName := QI.Name;
        M.FieldAnswer := Answers[J];
        { a score written into a "name/text" field gets the readable label }
        if (QI.Kind = qkScore) and
           ContainsAny(LowerCase(Answers[J]), ['name', 'nombre', 'text', 'desc', 'caption']) then
          M.AnswerFormat := afCaption;
        if J = 0 then
        begin
          M.FieldProbability := Prob;
          M.FieldDecision := Dec;
        end;
        Inc(Added);
      end;
    end;
  finally
    Answers.Free;
  end;

  RefreshMappings(0);
  if Added = 0 then
    MessageDlg('No se ha creado ninguna asignación: no hay campos cuyo nombre ' +
      'contenga el nombre de una pregunta sin asignar.', mtInformation, [mbOK], 0)
  else
    MessageDlg(Format('Se han creado %d asignaciones. Revísalas antes de aceptar.',
      [Added]), mtInformation, [mbOK], 0);
end;

procedure TLayaDBEditorForm.OkClick(Sender: TObject);
var
  I: Integer;
  M: TLayaFieldMapping;
  Q: TLayaQuestions;
begin
  if CheckedSourceFields = '' then
  begin
    MessageDlg('Marca al menos un campo con el texto a analizar.', mtWarning, [mbOK], 0);
    Exit;
  end;
  Q := Questions;
  for I := 0 to FMappings.Count - 1 do
  begin
    M := FMappings[I];
    if (M.QuestionName = '') or ((Q <> nil) and (Q.FindQuestion(M.QuestionName) = nil)) then
    begin
      MessageDlg(Format('La asignación nº %d tiene una pregunta vacía o que no existe.',
        [I + 1]), mtWarning, [mbOK], 0);
      lvMappings.Items[I].Selected := True;
      Exit;
    end;
    if (M.FieldAnswer = '') and (M.FieldProbability = '') and (M.FieldDecision = '') then
    begin
      MessageDlg(Format('La asignación nº %d (%s) no escribe en ningún campo.',
        [I + 1, M.QuestionName]), mtWarning, [mbOK], 0);
      lvMappings.Items[I].Selected := True;
      Exit;
    end;
  end;
  ApplyToAnalyzer;
  ModalResult := mrOk;
end;

function LayaEditDBAnalyzer(AAnalyzer: TLayaDBAnalyzer): Boolean;
var
  F: TLayaDBEditorForm;
begin
  F := TLayaDBEditorForm.CreateFor(AAnalyzer);
  try
    Result := F.ShowModal = mrOk;
  finally
    F.Free;
  end;
end;

end.
