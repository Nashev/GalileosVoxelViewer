object Form1: TForm1
  Left = 427
  Top = 236
  Width = 1022
  Height = 618
  Caption = 'Form1'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object pnl1: TPanel
    Left = 0
    Top = 0
    Width = 1014
    Height = 37
    Align = alTop
    TabOrder = 0
    DesignSize = (
      1014
      37)
    object edFileName: TEdit
      Left = 4
      Top = 8
      Width = 981
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 0
      Text = 
        'D:\Garbage\Photos\Galileos tomography\10210000000000000000000000' +
        '000000000004b245c0_vol_0\10210000000000000000000000000000000004b' +
        '245c0_vol_0_#Z'
    end
    object btnR: TButton
      Left = 989
      Top = 8
      Width = 21
      Height = 21
      Anchors = [akTop, akRight]
      Caption = 'R'
      Default = True
      TabOrder = 1
      OnClick = btnRClick
    end
  end
  object pnl2: TPanel
    Left = 0
    Top = 37
    Width = 185
    Height = 547
    Align = alLeft
    TabOrder = 1
    object trckbr: TTrackBar
      Left = 8
      Top = 4
      Width = 45
      Height = 533
      Max = 511
      Orientation = trVertical
      Frequency = 1
      Position = 255
      SelEnd = 0
      SelStart = 0
      TabOrder = 0
      TickMarks = tmBottomRight
      TickStyle = tsAuto
      OnChange = trckbrChange
    end
    object rgAxis: TRadioGroup
      Left = 68
      Top = 12
      Width = 73
      Height = 105
      Caption = #1057#1088#1077#1079
      ItemIndex = 0
      Items.Strings = (
        'XY'
        'YZ'
        'XZ')
      TabOrder = 1
      OnClick = rgAxisClick
    end
  end
  object spl1: TicSplitter
    Left = 185
    Top = 37
    Width = 4
    Height = 547
    Cursor = crHSplit
    TabOrder = 2
    Control = pnl2
  end
  object pnlImg: TPanel
    Left = 216
    Top = 52
    Width = 512
    Height = 512
    BevelOuter = bvNone
    FullRepaint = False
    TabOrder = 3
    object img: TImage
      Left = 0
      Top = 0
      Width = 512
      Height = 512
    end
  end
end
