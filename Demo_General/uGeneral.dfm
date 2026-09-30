object fGeneral: TfGeneral
  Left = 551
  Top = 62
  Caption = 'fGeneral'
  ClientHeight = 561
  ClientWidth = 745
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poDesigned
  OnCreate = FormCreate
  TextHeight = 15
  object Panel2: TPanel
    Left = 0
    Top = 0
    Width = 745
    Height = 561
    Align = alClient
    Caption = 'Panel2'
    TabOrder = 0
    object Splitter1: TSplitter
      Left = 1
      Top = 186
      Width = 743
      Height = 8
      Cursor = crVSplit
      Align = alTop
      ExplicitWidth = 711
    end
    object Label17: TLabel
      Left = 1
      Top = 194
      Width = 743
      Height = 15
      Align = alTop
      Caption = 'Respuesta'
      ExplicitWidth = 53
    end
    object Panel1: TPanel
      Left = 1
      Top = 1
      Width = 743
      Height = 185
      Align = alTop
      TabOrder = 0
      object Label18: TLabel
        Left = 1
        Top = 63
        Width = 741
        Height = 15
        Align = alTop
        Caption = 'State. Texto a evaluar'
        ExplicitWidth = 110
      end
      object Memo1: TMemo
        Left = 1
        Top = 78
        Width = 741
        Height = 106
        Align = alClient
        Lines.Strings = (
          'Memo1')
        TabOrder = 0
      end
      object Panel5: TPanel
        Left = 1
        Top = 1
        Width = 741
        Height = 62
        Align = alTop
        TabOrder = 1
        object Label1: TLabel
          Left = 1
          Top = 46
          Width = 739
          Height = 15
          Align = alBottom
          ExplicitWidth = 3
        end
        object Label2: TLabel
          Left = 16
          Top = 8
          Width = 67
          Height = 15
          Caption = 'URL Servidor'
        end
        object btnSalud: TButton
          Left = 89
          Top = 29
          Width = 75
          Height = 25
          Caption = 'Conectar'
          TabOrder = 0
          OnClick = btnSaludClick
        end
        object btnPredic: TButton
          Left = 240
          Top = 31
          Width = 105
          Height = 25
          Caption = 'Predict'
          TabOrder = 1
          OnClick = btnPredicClick
        end
        object RadioButton1: TRadioButton
          Left = 351
          Top = 8
          Width = 113
          Height = 17
          Caption = 'Salida txt'
          TabOrder = 2
          OnClick = RadioButton1Click
        end
        object RadioButton2: TRadioButton
          Left = 351
          Top = 27
          Width = 113
          Height = 17
          Caption = 'Salida JSON'
          TabOrder = 3
          OnClick = RadioButton2Click
        end
        object Edit1: TEdit
          Left = 89
          Top = 5
          Width = 256
          Height = 23
          TabOrder = 4
          Text = 'http://127.0.0.1:8000'
        end
      end
    end
    object Memo2: TMemo
      Left = 1
      Top = 209
      Width = 743
      Height = 351
      Align = alClient
      ScrollBars = ssBoth
      TabOrder = 1
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
    Items = <>
    InTXT = Memo1
    Left = 208
    Top = 256
  end
  object LayaResults1: TLayaResults
    OutTXT = Memo2
    TextAnswer = taKey
    Left = 288
    Top = 304
  end
end
