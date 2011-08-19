unit Test1Unit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, GoodSplitUnit, ExtCtrls, icControlLabelUnit, Spin, Contnrs,
  ComCtrls;

type
  TVoxelSlice = class
  private
    FMemoryStream: TMemoryStream;
  public
    property MemoryStream: TMemoryStream read FMemoryStream;
    constructor Create(AFileName: string);
    destructor Destroy; override;
  end;

  TVoxelArray = class
  private
    FList: TObjectList;
    FMask: string;
    function GetSlices(Index: Integer): TVoxelSlice;
    function GetPalette(Index: word): TColor;
//    procedure SetPalette(Index: word; const Value: TColor);
    function GetVoxel(x, y, z: integer): word;
  public
    constructor Create(AMask: string);
    destructor Destroy; override;
    property Slices[Index: Integer]: TVoxelSlice read GetSlices;
    procedure DrawXYImage(Z: Integer; Bitmap: TBitmap);
    procedure DrawYZImage(X: Integer; Bitmap: TBitmap);
    procedure DrawXZImage(Y: Integer; Bitmap: TBitmap);
    property Palette[Index: word]: TColor read GetPalette;// write SetPalette;
    property Voxel[x, y, z: integer]: word read GetVoxel;// write SetVoxel;
  end;

  TForm1 = class(TForm)
    pnl1: TPanel;
    pnl2: TPanel;
    spl1: TicSplitter;
    edFileName: TEdit;
    btnR: TButton;
    img: TImage;
    pnlImg: TPanel;
    trckbr: TTrackBar;
    rgAxis: TRadioGroup;
    procedure btnRClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure edNChange(Sender: TObject);
    procedure rgAxisClick(Sender: TObject);
    procedure trckbrChange(Sender: TObject);
  private
    VoxelArray: TVoxelArray;
    procedure DrawImage;
  public
  end;

var
  Form1: TForm1;

implementation
uses AbGzTyp, AbUtils;
{$R *.dfm}

procedure TForm1.btnRClick(Sender: TObject);
begin
  FreeAndNil(VoxelArray);
  VoxelArray := TVoxelArray.Create(edFileName.Text);
  DrawImage;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FreeAndNil(VoxelArray);
end;

procedure TForm1.DrawImage;
begin
  case rgAxis.ItemIndex of
    0: VoxelArray.DrawXYImage(trckbr.Position, img.Picture.Bitmap);
    1: VoxelArray.DrawYZImage(trckbr.Position, img.Picture.Bitmap);
    2: VoxelArray.DrawXZImage(trckbr.Position, img.Picture.Bitmap);
  end;
  pnlImg.Invalidate;
  Application.ProcessMessages;
end;

procedure TForm1.edNChange(Sender: TObject);
begin
  DrawImage;
end;

{ TSlice }

constructor TVoxelSlice.Create(AFileName: string);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  FMemoryStream := TMemoryStream.Create;
  try
    with TAbGzipStreamHelper.Create(Stream) do
      try
        ReadHeader;
        if VerifyHeader(Item.GZHeader) then
          begin
            MemoryStream.Clear;
            ExtractItemData(MemoryStream);
          end
        else
          begin
            Stream.seek(0, soFromBeginning);
            MemoryStream.LoadFromStream(Stream)
          end;
      finally
        Free;
      end;
  finally
    Stream.Free;
  end;
end;

destructor TVoxelSlice.Destroy;
begin
  FreeAndNil(FMemoryStream);
  inherited;
end;

{ TVoxelArray }

constructor TVoxelArray.Create(AMask: string);
var
  z: Integer;
begin
  FMask := AMask;
  FList := TObjectList.Create(True);
  FList.Capacity := 512;
  for z := 0 to 511 do
    FList.Add(nil);
end;

destructor TVoxelArray.Destroy;
begin
  FreeAndNil(FList);
  inherited;
end;

function TVoxelArray.GetSlices(Index: Integer): TVoxelSlice;
begin
  Result := FList[Index] as TVoxelSlice;
  if not Assigned(Result) then
    begin
      Result := TVoxelSlice.Create(StringReplace(FMask, '#Z', Format('%.3d', [Index]), []));
      FList[Index] := Result;
    end;
end;

function TVoxelArray.GetPalette(Index: word): TColor;
var
  c: Byte;
begin
  c := Lo(Index shr 4); // TODO: non linear palette
  Result :=  c + c shl 8 + c shl 16; // TODO: non gray palette
end;

//procedure TVoxelArray.SetPalette(Value: word; const Value: TColor);
//begin
//  
//end;

type
  TLine = array [0..511] of TColor;

procedure TVoxelArray.DrawXYImage(Z: Integer; Bitmap: TBitmap);
var
  i, j: Integer;
  sc: ^TLine;
begin
  Bitmap.Width := 512;
  Bitmap.Height := 512;
  Bitmap.PixelFormat := pf32bit;
  for j := 0 to 511 do
    begin
      sc := Bitmap.ScanLine[j];
      for i := 0 to 511 do
        sc[i] := Palette[Voxel[i, 511-j, z]];
    end;
end;

procedure TVoxelArray.DrawYZImage(X: Integer; Bitmap: TBitmap);
var
  i, j: Integer;
  sc: ^TLine;
begin
  Bitmap.Width := 512;
  Bitmap.Height := 512;
  Bitmap.PixelFormat := pf32bit;
  for j := 0 to 511 do
    begin
      sc := Bitmap.ScanLine[j];
      for i := 0 to 511 do
        sc[i] := Palette[Voxel[x, i, 511-j]];
    end;
end;

procedure TVoxelArray.DrawXZImage(Y: Integer; Bitmap: TBitmap);
var
  i, j: Integer;
  sc: ^TLine;
begin
  Bitmap.Width := 512;
  Bitmap.Height := 512;
  Bitmap.PixelFormat := pf32bit;
  for j := 0 to 511 do
    begin
      sc := Bitmap.ScanLine[j];
      for i := 0 to 511 do
        sc[i] := Palette[Voxel[i, y, 511-j]];
    end;
end;


function TVoxelArray.GetVoxel(x, y, z: integer): word;
type
  TSliceData = array [0..511, 0..511] of word;
  PSliceData = ^TSliceData;
begin
//  Assert(SizeOf(TSliceData) = Slices[Z].MemoryStream.Size);
  Result := PSliceData(Slices[Z].MemoryStream.Memory)[y, x];
end;

procedure TForm1.rgAxisClick(Sender: TObject);
begin
  DrawImage;
end;

procedure TForm1.trckbrChange(Sender: TObject);
begin
  DrawImage;
end;

end.
