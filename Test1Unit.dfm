object MainForm: TMainForm
  Left = 427
  Top = 236
  Caption = 'GalileosVoxelViewer'
  ClientHeight = 579
  ClientWidth = 1006
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object spl1: TSplitter
    Left = 165
    Top = 37
    Width = 4
    Height = 542
  end
  object pnl1: TPanel
    Left = 0
    Top = 0
    Width = 1006
    Height = 37
    Align = alTop
    TabOrder = 0
    DesignSize = (
      1006
      37)
    object edFileName: TComboBox
      Left = 4
      Top = 8
      Width = 911
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 0
      Text = 
        '..\data\2018.11.01\cfeb5feb6d2247e5abacca4f032fb85ecfeb5feb6d22_' +
        'vol_0.gwg'
      Items.Strings = (
        
          '..\data\2011.08.09\10210000000000000000000000000000000004b245c0_' +
          'vol_0.gwg'
        
          '..\data\2018.08.28\c378a0e168b148b881fdb05856d3e90fc378a0e168b1_' +
          'vol_0.gwg'
        
          '..\data\2018.11.01\cfeb5feb6d2247e5abacca4f032fb85ecfeb5feb6d22_' +
          'vol_0.gwg')
    end
    object btnR: TButton
      Left = 921
      Top = 8
      Width = 85
      Height = 21
      Anchors = [akTop, akRight]
      Caption = #1047#1072#1075#1088#1091#1079#1080#1090#1100
      Default = True
      TabOrder = 1
      OnClick = btnRClick
    end
  end
  object pnl2: TPanel
    Left = 0
    Top = 37
    Width = 165
    Height = 542
    Align = alLeft
    TabOrder = 1
    DesignSize = (
      165
      542)
    object lbl1: TLabel
      Left = 56
      Top = 288
      Width = 55
      Height = 13
      Caption = #1055#1086#1076#1089#1074#1077#1090#1082#1072
    end
    object tbLayer: TTrackBar
      Left = 8
      Top = 4
      Width = 28
      Height = 497
      Anchors = [akLeft, akTop, akBottom]
      Max = 511
      Orientation = trVertical
      PageSize = 16
      Frequency = 16
      Position = 255
      TabOrder = 0
      TickMarks = tmTopLeft
      OnChange = tbLayerChange
    end
    object rgAxis: TRadioGroup
      Left = 52
      Top = 12
      Width = 81
      Height = 89
      Caption = #1057#1088#1077#1079
      ItemIndex = 0
      Items.Strings = (
        'XY'
        'YZ'
        'XZ')
      TabOrder = 1
      OnClick = rgAxisClick
    end
    object edDeep: TSpinEdit
      Left = 60
      Top = 208
      Width = 53
      Height = 22
      MaxValue = 512
      MinValue = 0
      TabOrder = 2
      Value = 10
      OnChange = PaletteModeChanged
    end
    object cbUp: TCheckBox
      Left = 60
      Top = 236
      Width = 81
      Height = 17
      Caption = #1042#1087#1077#1088#1105#1076
      TabOrder = 3
      OnClick = DrawModeChanged
    end
    object edLayer: TSpinEdit
      Left = 8
      Top = 504
      Width = 53
      Height = 22
      Anchors = [akLeft, akBottom]
      MaxValue = 512
      MinValue = 0
      TabOrder = 4
      Value = 10
      OnChange = edLayerChange
    end
    object edMultiplier: TSpinEdit
      Left = 64
      Top = 308
      Width = 53
      Height = 22
      MaxValue = 512
      MinValue = 0
      TabOrder = 5
      Value = 10
      OnChange = PaletteModeChanged
    end
    object btnInverse: TButton
      Left = 56
      Top = 256
      Width = 101
      Height = 25
      Caption = 'C '#1076#1088#1091#1075#1086#1081' '#1089#1090#1086#1088#1086#1085#1099
      TabOrder = 6
      OnClick = btnInverseClick
    end
    object rgDrawingMode: TRadioGroup
      Left = 48
      Top = 108
      Width = 101
      Height = 89
      Caption = #1056#1077#1078#1080#1084
      ItemIndex = 0
      Items.Strings = (
        #1054#1076#1080#1085
        #1057#1091#1084#1084#1072
        #1047#1072#1090#1091#1093#1072#1085#1080#1077)
      TabOrder = 7
      OnClick = PaletteModeChanged
    end
    object chkDoubleZoom: TCheckBox
      Left = 42
      Top = 356
      Width = 117
      Height = 17
      Caption = #1044#1074#1086#1081#1085#1086#1081' '#1088#1072#1079#1084#1077#1088
      TabOrder = 8
      OnClick = DrawModeChanged
    end
  end
  object pnlImg: TPanel
    Left = 169
    Top = 37
    Width = 837
    Height = 542
    Align = alClient
    BevelOuter = bvNone
    FullRepaint = False
    ParentBackground = False
    TabOrder = 2
    OnResize = pnlImgResize
    object img: TImage
      Left = 0
      Top = 0
      Width = 746
      Height = 542
      Align = alClient
    end
    object imgPalette: TImage
      Left = 756
      Top = 0
      Width = 81
      Height = 542
      Align = alRight
    end
    object imgPaletteIndicator: TImage
      Left = 746
      Top = 0
      Width = 10
      Height = 542
      Align = alRight
    end
    object pbOverlay: TPaintBox
      Left = 47
      Top = 40
      Width = 742
      Height = 459
      OnMouseDown = pbOverlayMouseDown
      OnMouseMove = pbOverlayMouseMove
      OnPaint = pbOverlayPaint
    end
  end
  object ApplicationEvents: TApplicationEvents
    OnIdle = ApplicationEventsIdle
    Left = 496
    Top = 296
  end
end
