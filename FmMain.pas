unit FmMain;

interface

uses
  Messages, SysUtils, Classes, Controls, Forms, Windows, Graphics, jpeg,
  StdCtrls, ComCtrls, IniFiles, Dialogs;

type
  TfrmType = class(TForm)
    trckbrSize: TTrackBar;
    trckbrQuality: TTrackBar;
    lblSize: TLabel;
    lblQuality: TLabel;
    lblSizePct: TLabel;
    lblQualityPct: TLabel;
    lblInfo: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure trckbrSizeChange(Sender: TObject);
    procedure trckbrQualityChange(Sender: TObject);
    procedure FormActivate(Sender: TObject);
  private
    procedure WMDropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;
  public
    { Public declarations }
    SelectedFileName: string;
  end;

var
  frmType: TfrmType;
  Processed: Integer;

implementation
    {$R *.dfm}

uses
  ShellAPI, UFileCatcher;

type
  TRGBArray = array[Word] of TRGBTriple;

  pRGBArray = ^TRGBArray;

procedure SmoothResize(Src, Dst: TBitmap);
var
  x, y: Integer;
  xP, yP: Integer;
  xP2, yP2: Integer;
  SrcLine1, SrcLine2: pRGBArray;
  t3: Integer;
  z, z2, iz2: Integer;
  DstLine: pRGBArray;
  DstGap: Integer;
  w1, w2, w3, w4: Integer;
begin
  Src.PixelFormat := pf24Bit;
  Dst.PixelFormat := pf24Bit;
  if (Src.Width = Dst.Width) and (Src.Height = Dst.Height) then
    Dst.Assign(Src)
  else
  begin
    DstLine := Dst.ScanLine[0];
    DstGap := Integer(Dst.ScanLine[1]) - Integer(DstLine);
    xP2 := MulDiv(pred(Src.Width), $10000, Dst.Width);
    yP2 := MulDiv(pred(Src.Height), $10000, Dst.Height);
    yP := 0;
    for y := 0 to pred(Dst.Height) do
    begin
      xP := 0;
      SrcLine1 := Src.ScanLine[yP shr 16];
      if (yP shr 16 < pred(Src.Height)) then
        SrcLine2 := Src.ScanLine[succ(yP shr 16)]
      else
        SrcLine2 := Src.ScanLine[yP shr 16];
      z2 := succ(yP and $FFFF);
      iz2 := succ((not yP) and $FFFF);
      for x := 0 to pred(Dst.Width) do
      begin
        t3 := xP shr 16;
        z := xP and $FFFF;
        w2 := MulDiv(z, iz2, $10000);
        w1 := iz2 - w2;
        w4 := MulDiv(z, z2, $10000);
        w3 := z2 - w4;
        DstLine[x].rgbtRed := (SrcLine1[t3].rgbtRed * w1 + SrcLine1[t3 + 1].rgbtRed * w2 + SrcLine2[t3].rgbtRed * w3 + SrcLine2[t3 + 1].rgbtRed * w4) shr 16;
        DstLine[x].rgbtGreen := (SrcLine1[t3].rgbtGreen * w1 + SrcLine1[t3 + 1].rgbtGreen * w2 + SrcLine2[t3].rgbtGreen * w3 + SrcLine2[t3 + 1].rgbtGreen * w4) shr 16;
        DstLine[x].rgbtBlue := (SrcLine1[t3].rgbtBlue * w1 + SrcLine1[t3 + 1].rgbtBlue * w2 + SrcLine2[t3].rgbtBlue * w3 + SrcLine2[t3 + 1].rgbtBlue * w4) shr 16;
        Inc(xP, xP2);
      end; {for}
      Inc(yP, yP2);
      DstLine := pRGBArray(Integer(DstLine) + DstGap);
    end;
  end;
end;

function LoadJPEGPictureFile(Bitmap: TBitmap; FilePath, FileName: string): Boolean;
var
  JPEGImage: TJPEGImage;
begin
  if (FileName = '') then
    Result := False
  else
  begin
    try
      JPEGImage := TJPEGImage.Create;
      try
        JPEGImage.LoadFromFile(FilePath + FileName);
        Bitmap.Assign(JPEGImage);
      finally
        JPEGImage.Free;
        Result := True;
      end;
    except
      Result := False;
    end;
  end;
end;

function SaveJPEGPictureFile(Bitmap: TBitmap; FilePath, FileName: string; Quality: Integer): Boolean;
begin
  Result := True;
  try
    if ForceDirectories(FilePath) then
    begin
      with TJPegImage.Create do
      begin
        try
          Assign(Bitmap);
          CompressionQuality := Quality;
          SaveToFile(FilePath + FileName);
        finally
          Free;
        end;
      end;
    end;
  except
    raise;
    Result := False;
  end;
end;

procedure ResizeImage(FileName: string; SizePct, Quality: Integer);
var
  OldBitmap, NewBitmap: TBitmap;
  OldWidth, NewWidth: Integer;
  TempFileName: string;
begin
  OldBitmap := TBitmap.Create;
  try
    if LoadJPEGPictureFile(OldBitmap, ExtractFilePath(FileName), ExtractFileName(FileName)) then
    begin
      OldWidth := OldBitmap.Width;
      NewWidth := Round(OldWidth * SizePct / 100);
      NewBitmap := TBitmap.Create;
      try
        TempFileName := ChangeFileExt(FileName, '.$$$');
        NewBitmap.Width := NewWidth;
        NewBitmap.Height := MulDiv(NewWidth, OldBitmap.Height, OldWidth);
        SmoothResize(OldBitmap, NewBitmap);
        RenameFile(FileName, TempFileName);
        if SaveJPEGPictureFile(NewBitmap, ExtractFilePath(FileName), ExtractFileName(FileName), Quality) then
          DeleteFile(PChar(TempFileName))  //* see explanation below
        else
          RenameFile(TempFileName, FileName);
        Inc(Processed);
      finally
        NewBitmap.Free;
      end;
    end;
  finally
    OldBitmap.Free;
  end;
  //* why it needs PChar: http://www.delphigroups.info/2/83/78626.html
  // There are two DeleteFiles.  One in the Windows unit and one in the SysUtils
  // unit.  The default one depends on the ordering of units in your uses clause.
  // You can force the Delphi version by calling:
  // SysUtils.DeleteFile(f);
end;

procedure TfrmType.FormActivate(Sender: TObject);
var
  i: Integer;
begin
  //Passed files?
  if ParamCount = 0 then
    Exit;
  Processed := 0;
  try
    for i := 1 to ParamCount do  //-1 due to base 0
      ResizeImage(ParamStr(i), trckbrSize.Position, trckbrQuality.Position);
  finally
    ShowMessage('JPEG pictures processed: ' + IntToStr(Processed) + sLineBreak + 'Invalid JPEG files skipped: ' + inttostr(ParamCount - Processed));
  end;
end;

procedure TfrmType.FormCreate(Sender: TObject);
var
  myINI: TINIFile;
begin
  //Initialise options from INI file
  myINI := TINIFile.Create(ExtractFilePath(Application.EXEName) + 'jpgshrnk.ini');
  trckbrSize.Position := myINI.ReadInteger('Settings', 'Size', 50);
  trckbrQuality.Position := myINI.ReadInteger('Settings', 'Quality', 75);
  myINI.Free;
  lblSizePct.Caption := IntToStr(trckbrSize.Position) + '%';
  lblQualityPct.Caption := IntToStr(trckbrQuality.Position) + '%';
  // Tell windows we accept file drops
  DragAcceptFiles(Self.Handle, True);
end;

procedure TfrmType.FormDestroy(Sender: TObject);
var
  myINI: TIniFile;
begin
  // Cancel acceptance of file drops
  DragAcceptFiles(Self.Handle, False);
  //Save settings to INI file
  myINI := TINIFile.Create(ExtractFilePath(Application.EXEName) + 'jpgshrnk.ini');
  myINI.WriteInteger('Settings', 'Size', trckbrSize.Position);
  myINI.WriteInteger('Settings', 'Quality', trckbrQuality.Position);
  myINI.Free;
end;

procedure TfrmType.trckbrSizeChange(Sender: TObject);
begin
  lblSizePct.Caption := IntToStr(trckbrSize.Position) + '%';
end;

procedure TfrmType.trckbrQualityChange(Sender: TObject);
begin
  lblQualityPct.Caption := IntToStr(trckbrQuality.Position) + '%';
end;

procedure TfrmType.WMDropFiles(var Msg: TWMDropFiles);
var
  i, FileCount: Integer;
  Catcher: TFileCatcher; //File catcher class
  FullName: string;
begin
  inherited;
  // Create file catcher object to hide all messy details
  Catcher := TFileCatcher.Create(Msg.Drop);
  FileCount := Pred(Catcher.FileCount) + 1; //Not sure why +1 needed
  Processed := 0;
  try
    for i := 0 to FileCount - 1 do  //-1 due to base 0
    begin
      //Get file properties
      FullName := Catcher.Files[i];
      ResizeImage(FullName, trckbrSize.Position, trckbrQuality.Position);
    end;
  finally    // Notify Windows we handled message
    Msg.Result := 0;
    Catcher.Free;
    ShowMessage('JPEG pictures processed: ' + IntToStr(Processed) + sLineBreak + 'Invalid JPEG files skipped: ' + inttostr(FileCount - Processed));
  end;
end;

end.

