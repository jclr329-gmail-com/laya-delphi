object FTestPredict: TFTestPredict
  Left = 368
  Top = 104
  Caption = 'FTestPredict'
  ClientHeight = 598
  ClientWidth = 1098
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poDesigned
  OnCreate = FormCreate
  TextHeight = 15
  object Splitter2: TSplitter
    Left = 601
    Top = 0
    Width = 8
    Height = 598
    ExplicitLeft = 713
    ExplicitHeight = 441
  end
  object Panel2: TPanel
    Left = 0
    Top = 0
    Width = 601
    Height = 598
    Align = alLeft
    Caption = 'Panel2'
    TabOrder = 0
    object Splitter1: TSplitter
      Left = 1
      Top = 186
      Width = 599
      Height = 8
      Cursor = crVSplit
      Align = alTop
      ExplicitWidth = 711
    end
    object Label16: TLabel
      Left = 1
      Top = 473
      Width = 599
      Height = 15
      Align = alBottom
      Caption = 'Resultados Analizar'
      ExplicitWidth = 102
    end
    object Label17: TLabel
      Left = 1
      Top = 194
      Width = 599
      Height = 15
      Align = alTop
      Caption = 'Respuesta'
      ExplicitWidth = 53
    end
    object Splitter3: TSplitter
      Left = 1
      Top = 465
      Width = 599
      Height = 8
      Cursor = crVSplit
      Align = alBottom
      ExplicitLeft = 4
      ExplicitTop = 382
    end
    object Panel1: TPanel
      Left = 1
      Top = 1
      Width = 599
      Height = 185
      Align = alTop
      TabOrder = 0
      object Label18: TLabel
        Left = 1
        Top = 63
        Width = 597
        Height = 15
        Align = alTop
        Caption = 'State. Texto a evaluar'
        ExplicitWidth = 110
      end
      object Memo1: TMemo
        Left = 1
        Top = 78
        Width = 597
        Height = 106
        Align = alClient
        Lines.Strings = (
          'Memo1')
        TabOrder = 0
      end
      object Panel5: TPanel
        Left = 1
        Top = 1
        Width = 597
        Height = 62
        Align = alTop
        TabOrder = 1
        object Label1: TLabel
          Left = 1
          Top = 46
          Width = 595
          Height = 15
          Align = alBottom
          ExplicitWidth = 3
        end
        object Button1: TButton
          Left = 16
          Top = 5
          Width = 75
          Height = 25
          Caption = 'Salud'
          TabOrder = 0
          OnClick = Button1Click
        end
        object Button2: TButton
          Left = 155
          Top = 5
          Width = 105
          Height = 25
          Caption = 'Predict txt'
          TabOrder = 1
          OnClick = Button2Click
        end
        object Button3: TButton
          Left = 272
          Top = 5
          Width = 105
          Height = 25
          Caption = 'Predict memo'
          TabOrder = 2
          OnClick = Button3Click
        end
        object RadioButton1: TRadioButton
          Left = 400
          Top = 4
          Width = 113
          Height = 17
          Caption = 'Salida txt'
          TabOrder = 3
          OnClick = RadioButton1Click
        end
        object RadioButton2: TRadioButton
          Left = 400
          Top = 23
          Width = 113
          Height = 17
          Caption = 'Salida JSON'
          TabOrder = 4
          OnClick = RadioButton2Click
        end
      end
    end
    object Memo2: TMemo
      Left = 1
      Top = 209
      Width = 599
      Height = 256
      Align = alClient
      ScrollBars = ssBoth
      TabOrder = 1
    end
    object Memo3: TMemo
      Left = 1
      Top = 488
      Width = 599
      Height = 109
      Align = alBottom
      ScrollBars = ssBoth
      TabOrder = 2
    end
  end
  object Panel3: TPanel
    Left = 609
    Top = 0
    Width = 489
    Height = 598
    Align = alClient
    TabOrder = 1
    object Label2: TLabel
      Left = 6
      Top = 49
      Width = 48
      Height = 15
      Caption = 'Pregunta'
      FocusControl = DBMemo1
    end
    object Label3: TLabel
      Left = 6
      Top = 139
      Width = 100
      Height = 15
      Caption = 'Departamento_text'
      FocusControl = DBEdit1
    end
    object Label4: TLabel
      Left = 4
      Top = 169
      Width = 102
      Height = 15
      Caption = 'Departamento_prct'
      FocusControl = DBEdit2
    end
    object Label5: TLabel
      Left = 6
      Top = 199
      Width = 100
      Height = 15
      Caption = 'Departamento_dec'
      FocusControl = DBEdit3
    end
    object Label6: TLabel
      Left = 36
      Top = 230
      Width = 70
      Height = 15
      Caption = 'Urgencia_key'
      FocusControl = DBEdit4
    end
    object Label7: TLabel
      Left = 24
      Top = 260
      Width = 82
      Height = 15
      Caption = 'Urgencia_name'
      FocusControl = DBEdit5
    end
    object Label8: TLabel
      Left = 33
      Top = 290
      Width = 73
      Height = 15
      Caption = 'Urgencia_prct'
      FocusControl = DBEdit6
    end
    object Label9: TLabel
      Left = 49
      Top = 321
      Width = 57
      Height = 15
      Caption = 'Baja_name'
      FocusControl = DBEdit7
    end
    object Label10: TLabel
      Left = 58
      Top = 351
      Width = 48
      Height = 15
      Caption = 'Baja_prct'
      FocusControl = DBEdit8
    end
    object Label11: TLabel
      Left = 60
      Top = 381
      Width = 46
      Height = 15
      Caption = 'Baja_dec'
      FocusControl = DBEdit9
    end
    object Label12: TLabel
      Left = 59
      Top = 412
      Width = 47
      Height = 15
      Caption = 'Revisado'
      FocusControl = DBEdit10
    end
    object Label13: TLabel
      Left = 32
      Top = 442
      Width = 74
      Height = 15
      Caption = 'Fecha_analisis'
      FocusControl = DBEdit11
    end
    object Label14: TLabel
      Left = 65
      Top = 473
      Width = 41
      Height = 15
      Caption = 'Modelo'
      FocusControl = DBEdit12
    end
    object Label15: TLabel
      Left = 336
      Top = 44
      Width = 10
      Height = 15
      Caption = 'id'
      FocusControl = DBEdit13
    end
    object DBNavigator1: TDBNavigator
      Left = 6
      Top = 4
      Width = 240
      Height = 25
      DataSource = DataSource1
      TabOrder = 0
    end
    object DBMemo1: TDBMemo
      Left = 6
      Top = 65
      Width = 411
      Height = 65
      DataField = 'Pregunta'
      DataSource = DataSource1
      TabOrder = 1
    end
    object DBEdit1: TDBEdit
      Left = 112
      Top = 136
      Width = 304
      Height = 23
      DataField = 'Departamento_text'
      DataSource = DataSource1
      TabOrder = 2
    end
    object DBEdit2: TDBEdit
      Left = 112
      Top = 166
      Width = 154
      Height = 23
      DataField = 'Departamento_prct'
      DataSource = DataSource1
      TabOrder = 3
    end
    object DBEdit3: TDBEdit
      Left = 112
      Top = 196
      Width = 154
      Height = 23
      DataField = 'Departamento_dec'
      DataSource = DataSource1
      TabOrder = 4
    end
    object DBEdit4: TDBEdit
      Left = 112
      Top = 227
      Width = 154
      Height = 23
      DataField = 'Urgencia_key'
      DataSource = DataSource1
      TabOrder = 5
    end
    object DBEdit5: TDBEdit
      Left = 112
      Top = 257
      Width = 304
      Height = 23
      DataField = 'Urgencia_name'
      DataSource = DataSource1
      TabOrder = 6
    end
    object DBEdit6: TDBEdit
      Left = 112
      Top = 287
      Width = 154
      Height = 23
      DataField = 'Urgencia_prct'
      DataSource = DataSource1
      TabOrder = 7
    end
    object DBEdit7: TDBEdit
      Left = 112
      Top = 318
      Width = 34
      Height = 23
      DataField = 'Baja_name'
      DataSource = DataSource1
      TabOrder = 8
    end
    object DBEdit8: TDBEdit
      Left = 112
      Top = 348
      Width = 154
      Height = 23
      DataField = 'Baja_prct'
      DataSource = DataSource1
      TabOrder = 9
    end
    object DBEdit9: TDBEdit
      Left = 112
      Top = 378
      Width = 154
      Height = 23
      DataField = 'Baja_dec'
      DataSource = DataSource1
      TabOrder = 10
    end
    object DBEdit10: TDBEdit
      Left = 112
      Top = 409
      Width = 154
      Height = 23
      DataField = 'Revisado'
      DataSource = DataSource1
      TabOrder = 11
    end
    object DBEdit11: TDBEdit
      Left = 112
      Top = 439
      Width = 153
      Height = 23
      DataField = 'Fecha_analisis'
      DataSource = DataSource1
      TabOrder = 12
    end
    object DBEdit12: TDBEdit
      Left = 112
      Top = 470
      Width = 300
      Height = 23
      DataField = 'Modelo'
      DataSource = DataSource1
      TabOrder = 13
    end
    object DBEdit13: TDBEdit
      Left = 359
      Top = 36
      Width = 57
      Height = 23
      DataField = 'id'
      DataSource = DataSource1
      ReadOnly = True
      TabOrder = 14
    end
    object Panel4: TPanel
      Left = 1
      Top = 556
      Width = 487
      Height = 41
      Align = alBottom
      TabOrder = 15
      object btnEste: TButton
        Left = 32
        Top = 8
        Width = 89
        Height = 25
        Caption = 'Analiza uno'
        TabOrder = 0
        OnClick = btnEsteClick
      end
      object btnAnalizar: TButton
        Left = 152
        Top = 8
        Width = 97
        Height = 25
        Caption = 'Analizar todos'
        TabOrder = 1
        OnClick = btnAnalizarClick
      end
      object CheckBox1: TCheckBox
        Left = 259
        Top = 12
        Width = 158
        Height = 17
        Caption = 'Deshabilitar Controles'
        Checked = True
        State = cbChecked
        TabOrder = 2
        OnClick = CheckBox1Click
      end
    end
  end
  object LayaServer1: TLayaServer
    BaseURL = 'http://127.0.0.1:8000'
    PredictPath = '/predict'
    HealthPath = '/salud'
    QuestionsPath = '/preguntas'
    StateKey = 'text'
    Questions = LayaQuestions1
    Results = LayaResults1
    Left = 136
    Top = 224
  end
  object LayaQuestions1: TLayaQuestions
    Items = <
      item
        Name = 'departamento'
        Kind = qkChoice
        Instructions = #191'Qu'#233' departamento debe atender esto?'
        Options = <
          item
            Key = 'facturacion'
            Description = 'pagos, reembolsos, facturas'
          end
          item
            Key = 'soporte'
            Description = 'ayuda t'#233'cnica y errores'
          end
          item
            Key = 'ventas'
            Description = 'nuevas compras'
          end>
        AcceptThreshold = 0.600000000000000000
        RejectThreshold = 0.200000000000000000
        Aggregation = agFirst
      end
      item
        Name = 'urgencia'
        Kind = qkScore
        Instructions = #191'Qu'#233' urgencia tiene esto?'
        Options = <
          item
            Key = '0'
            Description = 'no urgente'
          end
          item
            Key = '1'
            Description = 'pronto'
          end
          item
            Key = '2'
            Description = 'bloqueante'
          end>
        AcceptThreshold = 0.600000000000000000
        RejectThreshold = 0.200000000000000000
      end
      item
        Name = 'baja'
        Instructions = #191'Amenaza el usuario con darse de baja o cancelar el servicio?'
        Options = <>
        AcceptThreshold = 0.700000000000000000
        RejectThreshold = 0.300000000000000000
      end>
    InTXT = Memo1
    Left = 208
    Top = 256
  end
  object LayaResults1: TLayaResults
    OutTXT = Memo2
    TextAnswer = taKey
    OnChange = LayaResults1Change
    Left = 288
    Top = 304
  end
  object FDConnection1: TFDConnection
    Params.Strings = (
      'Database=C:\Apps\LAYA\Database\Clientes.sdb'
      'DriverID=SQLite')
    LoginPrompt = False
    Left = 393
    Top = 72
  end
  object FDTable1: TFDTable
    IndexFieldNames = 'id'
    Connection = FDConnection1
    ResourceOptions.AssignedValues = [rvEscapeExpand]
    TableName = 'Clientes'
    Left = 385
    Top = 136
    object FDTable1id: TFDAutoIncField
      FieldName = 'id'
      Origin = 'id'
      ProviderFlags = [pfInWhere, pfInKey]
      ReadOnly = False
    end
    object FDTable1Pregunta: TWideMemoField
      FieldName = 'Pregunta'
      Origin = 'Pregunta'
      BlobType = ftWideMemo
    end
    object FDTable1Departamento_text: TStringField
      FieldName = 'Departamento_text'
      Origin = 'Departamento_text'
    end
    object FDTable1Departamento_prct: TFloatField
      FieldName = 'Departamento_prct'
      Origin = 'Departamento_prct'
    end
    object FDTable1Departamento_dec: TStringField
      FieldName = 'Departamento_dec'
      Origin = 'Departamento_dec'
      Size = 10
    end
    object FDTable1Urgencia_key: TIntegerField
      FieldName = 'Urgencia_key'
      Origin = 'Urgencia_key'
    end
    object FDTable1Urgencia_name: TStringField
      FieldName = 'Urgencia_name'
      Origin = 'Urgencia_name'
    end
    object FDTable1Urgencia_prct: TFloatField
      FieldName = 'Urgencia_prct'
      Origin = 'Urgencia_prct'
    end
    object FDTable1Baja_name: TStringField
      FieldName = 'Baja_name'
      Origin = 'Baja_name'
      Size = 2
    end
    object FDTable1Baja_prct: TFloatField
      FieldName = 'Baja_prct'
      Origin = 'Baja_prct'
    end
    object FDTable1Baja_dec: TStringField
      FieldName = 'Baja_dec'
      Origin = 'Baja_dec'
      Size = 10
    end
    object FDTable1Revisado: TIntegerField
      FieldName = 'Revisado'
      Origin = 'Revisado'
    end
    object FDTable1Fecha_analisis: TDateTimeField
      FieldName = 'Fecha_analisis'
      Origin = 'Fecha_analisis'
    end
    object FDTable1Modelo: TStringField
      FieldName = 'Modelo'
      Origin = 'Modelo'
      Size = 100
    end
  end
  object DataSource1: TDataSource
    DataSet = FDTable1
    Left = 473
    Top = 176
  end
  object LayaDBAnalyzer1: TLayaDBAnalyzer
    Server = LayaServer1
    Questions = LayaQuestions1
    Results = LayaResults1
    DataSetTarget = FDTable1
    FieldsSource = 'Pregunta'
    Mappings = <
      item
        QuestionName = 'departamento'
        FieldAnswer = 'Departamento_text'
        FieldProbability = 'Departamento_prct'
        FieldDecision = 'Departamento_dec'
        TrueValue = 'S'
        FalseValue = 'N'
      end
      item
        QuestionName = 'urgencia'
        FieldAnswer = 'Urgencia_key'
        FieldProbability = 'Urgencia_prct'
        TrueValue = 'S'
        FalseValue = 'N'
      end
      item
        QuestionName = 'urgencia'
        FieldAnswer = 'Urgencia_name'
        AnswerFormat = afCaption
        TrueValue = 'S'
        FalseValue = 'N'
      end
      item
        QuestionName = 'baja'
        FieldAnswer = 'Baja_name'
        FieldProbability = 'Baja_prct'
        FieldDecision = 'Baja_dec'
        TrueValue = 'S'
        FalseValue = 'N'
      end>
    FieldLock = 'Revisado'
    FieldDate = 'Fecha_analisis'
    FieldModel = 'Modelo'
    OnProgress = LayaDBAnalyzer1Progress
    OnFinish = LayaDBAnalyzer1Finish
    Left = 376
    Top = 232
  end
end
