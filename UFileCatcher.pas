unit UFileCatcher;

interface

uses
  Windows, ShellAPI;

type
  TFileCatcher = class(TObject)
  private
    fDropHandle: HDROP;
    function GetFile(Idx: Integer): string;
    function GetFileCount: Integer;
    function GetPoint: TPoint;
  public
    constructor Create(DropHandle: HDROP);
    destructor Destroy; override;
    property FileCount: Integer read GetFileCount;
    property Files[Idx: Integer]: string read GetFile;
    property DropPoint: TPoint read GetPoint;
  end;

implementation

{ TFileCatcher }

constructor TFileCatcher.Create(DropHandle: HDROP);
begin
  inherited Create;
  fDropHandle := DropHandle;
end;

destructor TFileCatcher.Destroy;
begin
  DragFinish(fDropHandle);
  inherited;
end;

function TFileCatcher.GetFile(Idx: Integer): string;
var
  FileNameLength: Integer;
begin
  FileNameLength := DragQueryFile(fDropHandle, Idx, nil, 0);
  SetLength(Result, FileNameLength);
  DragQueryFile(fDropHandle, Idx, PChar(Result), FileNameLength + 1);
end;

function TFileCatcher.GetFileCount: Integer;
begin
  Result := DragQueryFile(fDropHandle, $FFFFFFFF, nil, 0);
end;

function TFileCatcher.GetPoint: TPoint;
begin
  DragQueryPoint(fDropHandle, Result);
end;

end.
