object Test_Revisor: TTest_Revisor
  Left = 511
  Top = 83
  Caption = 'Test Revisor'
  ClientHeight = 521
  ClientWidth = 812
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poDesigned
  OnCreate = FormCreate
  TextHeight = 15
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 812
    Height = 161
    Align = alTop
    TabOrder = 0
    object Panel2: TPanel
      Left = 1
      Top = 1
      Width = 810
      Height = 56
      Align = alTop
      TabOrder = 0
      object Label1: TLabel
        Left = 1
        Top = 40
        Width = 808
        Height = 15
        Align = alBottom
        ExplicitWidth = 3
      end
      object btnMedir: TButton
        Left = 24
        Top = 16
        Width = 75
        Height = 25
        Caption = 'Evaluar'
        TabOrder = 0
        OnClick = btnMedirClick
      end
      object btnExportar: TButton
        Left = 161
        Top = 16
        Width = 144
        Height = 25
        Caption = 'Exportar Evaluacion'
        TabOrder = 1
        OnClick = btnExportarClick
      end
    end
    object Memo1: TMemo
      Left = 1
      Top = 57
      Width = 810
      Height = 103
      Align = alClient
      TabOrder = 1
    end
  end
  object Panel3: TPanel
    Left = 0
    Top = 161
    Width = 812
    Height = 56
    Align = alTop
    TabOrder = 1
  end
  object Panel4: TPanel
    Left = 0
    Top = 217
    Width = 812
    Height = 304
    Align = alClient
    Caption = 'Panel4'
    TabOrder = 2
    object Splitter1: TSplitter
      Left = 1
      Top = 152
      Width = 810
      Height = 8
      Cursor = crVSplit
      Align = alTop
      ExplicitTop = 157
      ExplicitWidth = 1125
    end
    object DBGrid1: TDBGrid
      Left = 1
      Top = 1
      Width = 810
      Height = 151
      Align = alTop
      DataSource = DataSource1
      ReadOnly = True
      TabOrder = 0
      TitleFont.Charset = DEFAULT_CHARSET
      TitleFont.Color = clWindowText
      TitleFont.Height = -12
      TitleFont.Name = 'Segoe UI'
      TitleFont.Style = []
      Columns = <
        item
          Expanded = False
          FieldName = 'id'
          Width = 47
          Visible = True
        end
        item
          Expanded = False
          FieldName = 'Articulo'
          Width = 177
          Visible = True
        end
        item
          Expanded = False
          FieldName = 'Particion'
          Visible = True
        end
        item
          Expanded = False
          FieldName = 'Codigos'
          Width = 282
          Visible = True
        end
        item
          Expanded = False
          FieldName = 'Diabetes'
          Visible = True
        end
        item
          Expanded = False
          FieldName = 'Hipertension'
          Visible = True
        end
        item
          Expanded = False
          FieldName = 'Cancer'
          Visible = True
        end
        item
          Expanded = False
          FieldName = 'Insuf_renal'
          Visible = True
        end
        item
          Expanded = False
          FieldName = 'Tabaco'
          Width = 101
          Visible = True
        end
        item
          Expanded = False
          FieldName = 'Revisado'
          Visible = True
        end
        item
          Expanded = False
          FieldName = 'Fecha_analisis'
          Width = 82
          Visible = True
        end
        item
          Expanded = False
          FieldName = 'Modelo'
          Width = 149
          Visible = True
        end>
    end
    object DBMemo1: TDBMemo
      Left = 1
      Top = 160
      Width = 810
      Height = 143
      Align = alClient
      DataField = 'Texto'
      DataSource = DataSource1
      ReadOnly = True
      TabOrder = 1
    end
  end
  object LayaEvaluator1: TLayaEvaluator
    Analyzer = LayaDBAnalyzer1
    OutTXT = Memo1
    TargetPrecision = 0.980000000000000000
    OnFinish = LayaEvaluator1Finish
    Left = 552
    Top = 56
  end
  object LayaTrainingExporter1: TLayaTrainingExporter
    Analyzer = LayaDBAnalyzer1
    FileName = 'C:\Apps\LAYA\Evaluaciones\codiesp_v2.jsonl'
    Workflow = 'codiesp'
    LabelSmoothing = 0.050000000000000000
    FieldSplit = 'Particion'
    Left = 648
    Top = 64
  end
  object LayaServer1: TLayaServer
    BaseURL = 'http://127.0.0.1:8000'
    PredictPath = '/predict'
    HealthPath = '/salud'
    StateKey = 'text'
    Questions = LayaQuestions1
    Results = LayaResults1
    Left = 67
    Top = 50
  end
  object LayaQuestions1: TLayaQuestions
    Items = <
      item
        Name = 'diabetes'
        Instructions = 
          #191'El paciente tiene diabetes mellitus (tipo 1, tipo 2 u otro tipo' +
          ')?'
        Options = <>
        AcceptThreshold = 0.800000000000000000
        RejectThreshold = 0.200000000000000000
      end
      item
        Name = 'hipertension'
        Instructions = 
          #191'El paciente tiene hipertensi'#243'n arterial sist'#233'mica? La hipertens' +
          'i'#243'n pulmonar no cuenta.'
        Options = <>
        AcceptThreshold = 0.800000000000000000
        RejectThreshold = 0.200000000000000000
      end
      item
        Name = 'cancer'
        Instructions = #191'El paciente tiene o ha tenido un c'#225'ncer o tumor maligno?'
        Options = <>
        AcceptThreshold = 0.800000000000000000
        RejectThreshold = 0.200000000000000000
      end
      item
        Name = 'insuf_renal'
        Instructions = #191'El paciente tiene insuficiencia renal, aguda o cr'#243'nica?'
        Options = <>
        AcceptThreshold = 0.800000000000000000
        RejectThreshold = 0.200000000000000000
      end
      item
        Name = 'tabaco'
        Kind = qkChoice
        Instructions = #191'Cu'#225'l es el h'#225'bito tab'#225'quico del paciente seg'#250'n el texto?'
        Options = <
          item
            Key = 'fumador'
            Description = 'fuma actualmente'
          end
          item
            Key = 'exfumador'
            Description = 'fumaba pero lo ha dejado'
          end
          item
            Key = 'no_consta'
            Description = 'el texto no dice que fume ni que haya fumado'
          end>
        AcceptThreshold = 0.700000000000000000
        RejectThreshold = 0.200000000000000000
      end>
    Left = 65
    Top = 102
  end
  object LayaResults1: TLayaResults
    Left = 160
    Top = 117
  end
  object FDConnection1: TFDConnection
    Params.Strings = (
      'Database=C:\Apps\LAYA\Database\codiesp.sdb'
      'DriverID=SQLite')
    Connected = True
    LoginPrompt = False
    Left = 249
    Top = 56
  end
  object DataSource1: TDataSource
    DataSet = FDTable1
    Left = 337
    Top = 120
  end
  object LayaDBAnalyzer1: TLayaDBAnalyzer
    Server = LayaServer1
    Questions = LayaQuestions1
    Results = LayaResults1
    DataSetTarget = FDTable1
    FieldKeyTarget = 'Articulo'
    DataSetSource = FDTable1
    FieldsSource = 'Texto'
    ChunkSize = 8000
    Mappings = <
      item
        QuestionName = 'diabetes'
        FieldAnswer = 'Diabetes'
        TrueValue = 'S'
        FalseValue = 'N'
      end
      item
        QuestionName = 'hipertension'
        FieldAnswer = 'Hipertension'
        TrueValue = 'S'
        FalseValue = 'N'
      end
      item
        QuestionName = 'cancer'
        FieldAnswer = 'Cancer'
        TrueValue = 'S'
        FalseValue = 'N'
      end
      item
        QuestionName = 'insuf_renal'
        FieldAnswer = 'Insuf_renal'
        TrueValue = 'S'
        FalseValue = 'N'
      end
      item
        QuestionName = 'tabaco'
        FieldAnswer = 'Tabaco'
        TrueValue = 'S'
        FalseValue = 'N'
      end>
    FieldLock = 'Revisado'
    FieldDate = 'Fecha_analisis'
    FieldModel = 'Modelo'
    OnProgress = LayaDBAnalyzer1Progress
    OnFinish = LayaDBAnalyzer1Finish
    Left = 432
    Top = 48
  end
  object FDTable1: TFDTable
    Active = True
    IndexFieldNames = 'id'
    Connection = FDConnection1
    ResourceOptions.AssignedValues = [rvEscapeExpand]
    TableName = 'Casos'
    Left = 248
    Top = 112
  end
end
