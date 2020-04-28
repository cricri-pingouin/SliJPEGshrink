Program jpgshrnk;

Uses
  Forms,
  FmMain In 'FmMain.pas' {frmType},
  UFileCatcher In 'UFileCatcher.pas';

{$R *.res}
{$SetPEFlags 1}

Begin
  Application.Initialize;
  Application.Title := 'JPEG shrink';
  Application.CreateForm(TfrmType, frmType);
  Application.Run;
End.

