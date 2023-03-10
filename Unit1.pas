unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Memo.Types, FMX.StdCtrls, FMX.Layouts,
  FMX.Controls.Presentation,
  FMX.ScrollBox, FMX.Memo,
  rd.OpenAI.ChatGpt.ViewModel,
  rd.OpenAI.ChatGpt.Model,
  System.Json,
  Rest.Json,
  System.Generics.Collections,
  Rest.JsonReflect,
  DW.AppUpdate, FMX.Edit, FMX.ListBox, DW.TextToSpeech;

const
  URL_API_KEY = 'https://platform.openai.com/account/api-keys';

type
  TForm1 = class(TForm)
    Memo: TMemo;
    ButtonsLayout: TLayout;
    CheckUpdateButton: TButton;
    UpdateButton: TButton;
    uAsk: TButton;
    RDChatGpt1: TRDChatGpt;
    Edit1: TEdit;
    UseExampleCheckBox: TCheckBox;
    GenApiK: TButton;
    uApiK: TButton;
    procedure CheckUpdateButtonClick(Sender: TObject);
    procedure UpdateButtonClick(Sender: TObject);
    procedure uAskClick(Sender: TObject);
    procedure Edit1KeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure Edit1Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure RDChatGpt1Answer(Sender: TObject; AMessage: string);
    procedure RDChatGpt1CompletionsLoaded(Sender: TObject; AType: TCompletions);
    procedure RDChatGpt1Error(Sender: TObject; AMessage: string);
    procedure RDChatGpt1ModelsLoaded(Sender: TObject; AType: TModels);
    procedure GenApiKClick(Sender: TObject);
    procedure uApiKClick(Sender: TObject);
  private
    FApiKey: string;
    FSpeaker: TTextToSpeech;
    FAppUpdate: TAppUpdate;
    procedure SpeakerCheckDataCompleteHandler(Sender: TObject);
    procedure SpeakerSpeechStartedHandler(Sender: TObject);
    procedure SpeakerSpeechFinishedHandler(Sender: TObject);
    procedure AppUpdateInfoHandler(Sender: TObject; const AInfo: TAppUpdateInfo);
    procedure AppUpdateResultHandler(Sender: TObject; const AUpdateResult: TAppUpdateResult);
    procedure AppUpdateStartedFlowHandler(Sender: TObject; const AStarted: Boolean);
  public
    uToken : string;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}
{$R *.LgXhdpiTb.fmx ANDROID}
{$R *.LgXhdpiPh.fmx ANDROID}

uses
  System.TypInfo,System.IOUtils, FMX.DialogService,
  {$IFDEF ANDROID}
  Androidapi.Helpers, Androidapi.JNI.GraphicsContentViewText,
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  ShellAPI,
  {$ENDIF}
  FMX.Ani, IniFiles, System.Math;


{ TForm1 }

procedure OpenUrl(const URL: string);
begin
  TAndroidHelper.Context.startActivity(
    TJIntent.JavaClass.init(TJIntent.JavaClass.ACTION_VIEW, StrToJURI(URL)));
end;

constructor TForm1.Create(AOwner: TComponent);
begin
try
  inherited;
  FAppUpdate := TAppUpdate.Create;
  FAppUpdate.OnAppUpdateInfo := AppUpdateInfoHandler;
  FAppUpdate.OnAppUpdateStartedFlow := AppUpdateStartedFlowHandler;
  FAppUpdate.OnAppUpdateResult := AppUpdateResultHandler;
  FSpeaker := TTextToSpeech.Create;
  FSpeaker.OnSpeechStarted := SpeakerSpeechStartedHandler;
  FSpeaker.OnSpeechFinished := SpeakerSpeechFinishedHandler;
  FSpeaker.OnCheckDataComplete := SpeakerCheckDataCompleteHandler;
  if not FSpeaker.CheckData then Memo.Lines.Add('Cannot check available data');
except
  Exit;
end;
end;

destructor TForm1.Destroy;
begin
try
  FAppUpdate.Free;
  FSpeaker.Free;
  inherited;
except
  Exit;
end;
end;


procedure TForm1.SpeakerCheckDataCompleteHandler(Sender: TObject);
var
  LVoice: string;
begin
try
  if Length(FSpeaker.AvailableVoices) > 0 then
  begin
    Memo.Lines.Add('Available voices:');
    for LVoice in FSpeaker.AvailableVoices do
      Memo.Lines.Add(LVoice);
  end;
  if Length(FSpeaker.UnavailableVoices) > 0 then
  begin
    Memo.Lines.Add('Unavailable voices:');
    for LVoice in FSpeaker.UnavailableVoices do
      Memo.Lines.Add(LVoice);
  end;
except
  Exit;
end;
end;

procedure TForm1.SpeakerSpeechFinishedHandler(Sender: TObject);
begin
  Memo.Lines.Add('Speaking finished');
end;

procedure TForm1.SpeakerSpeechStartedHandler(Sender: TObject);
begin
  Memo.Lines.Add('Speaking started');
end;

procedure TForm1.Edit1Change(Sender: TObject);
begin
  uAsk.Enabled := Edit1.Text.Trim <> '';
end;

procedure TForm1.Edit1KeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
try
  if Key = vkReturn then
  begin
    Key := 0;
    uAskClick(nil);
  end;
except
  Exit;
end;
end;

procedure SaveSettingString(Section, Name, Value: string);
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(System.IOUtils.TPath.GetDocumentsPath + System.SysUtils.PathDelim + 'config.ini');
  try
    ini.WriteString(Section, Name, Value);
  finally
    ini.Free;
  end;
end;

function LoadSettingString(Section, Name, Value: string): string;
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(System.IOUtils.TPath.GetDocumentsPath + System.SysUtils.PathDelim + 'config.ini');
  try
    Result := ini.ReadString(Section, Name, Value);
  finally
    ini.Free;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
if FileExists(System.IOUtils.TPath.GetDocumentsPath + System.SysUtils.PathDelim + 'config.ini') then
   uToken := LoadSettingString('Setting','Token','')
else
   uToken := '';
   if Length(uToken) < 13 then uToken := '';
   ReportMemoryLeaksOnShutdown := True;
end;

procedure TForm1.RDChatGpt1Answer(Sender: TObject; AMessage: string);
begin
try
  Edit1.Text := '';
  Memo.Lines.Add(AMessage);
  if UseExampleCheckBox.IsChecked then
     FSpeaker.Speak(Memo.Text);
except
  Exit;
end;
end;

procedure TForm1.RDChatGpt1CompletionsLoaded(Sender: TObject;
  AType: TCompletions);
begin
try
  Caption := AType.Model;
except
  Exit;
end;
end;

procedure TForm1.RDChatGpt1Error(Sender: TObject; AMessage: string);
begin
try
  Memo.Lines.Add('Error: ' + AMessage);
except
  Exit;
end;
end;

procedure TForm1.RDChatGpt1ModelsLoaded(Sender: TObject; AType: TModels);
begin
try
  Assert(AType <> nil);
except
  Exit;
end;
end;

procedure TForm1.AppUpdateInfoHandler(Sender: TObject; const AInfo: TAppUpdateInfo);
begin
try
  Memo.Lines.Add('Available: ' + BoolToStr(AInfo.Available, True));
  if AInfo.Available then
  begin
    Memo.Lines.Add('Total Bytes: ' + AInfo.TotalBytesToDownload.ToString);
    Memo.Lines.Add('Priority: ' + AInfo.Priority.ToString);
    Memo.Lines.Add('Immediate: ' + BoolToStr(AInfo.Immediate, True));
    Memo.Lines.Add('Flexible: ' + BoolToStr(AInfo.Flexible, True));
    if AInfo.Flexible then Memo.Lines.Add('Staleness Days: ' + AInfo.StalenessDays.ToString);
  end;
except
  Exit;
end;
end;

procedure TForm1.AppUpdateResultHandler(Sender: TObject; const AUpdateResult: TAppUpdateResult);
begin
try
  Memo.Lines.Add('Update result: ' + GetEnumName(TypeInfo(TAppUpdateResult), Ord(AUpdateResult)));
except
  Exit;
end;
end;

procedure TForm1.AppUpdateStartedFlowHandler(Sender: TObject; const AStarted: Boolean);
begin
try
  Memo.Lines.Add('Flow started: ' + BoolToStr(AStarted, True));
except
  Exit;
end;
end;

procedure TForm1.GenApiKClick(Sender: TObject);
begin
try
  OpenUrl(URL_API_KEY);
except
TDialogService.MessageDialog(('Error opening ApiKey generation site!'), system.UITypes.TMsgDlgType.mtConfirmation,
[system.UITypes.TMsgDlgBtn.mbYes, system.UITypes.TMsgDlgBtn.mbNo], system.UITypes.TMsgDlgBtn.mbYes,0,
procedure (const AResult: System.UITypes.TModalResult)
begin
  case AResult of
    mrYES:
    begin
       Exit;
    end;
  end;
end
);
end;
end;

procedure TForm1.uApiKClick(Sender: TObject);
begin
try
 TDialogservice.InputQuery('Attention', ['Please enter your APIKey:'], [''],
    procedure(const AResult: TModalResult; const AValues: array of string)
      begin
        case AResult of
          mrOk:
            begin
              uToken:=AValues[0];
              SaveSettingString('Setting','Token',uToken);
            end;
          mrCancel:
            begin
              uToken:='';
            end;
        end;
      end
    );
except
  Exit;
end;
end;

procedure TForm1.uAskClick(Sender: TObject);
begin
  if Length(uToken) = 0 then
   TDialogservice.InputQuery('Attention', ['Please enter your APIKey:'], [''],
    procedure(const AResult: TModalResult; const AValues: array of string)
      begin
        case AResult of
          mrOk:
            begin
              uToken:=AValues[0];
            end;
          mrCancel:
            begin
              uToken:='';
            end;
        end;
      end
    );
  if Length(uToken) = 0 then Exit;
try
  SaveSettingString('Setting','Token',uToken);
  RDChatGpt1.Cancel;
  RDChatGpt1.ApiKey := uToken;
  RDChatGpt1.Question := Edit1.Text;
  RDChatGpt1.Ask;
  Edit1.SetFocus;
except
  Exit;
end;
end;

procedure TForm1.CheckUpdateButtonClick(Sender: TObject);
begin
try
  FAppUpdate.CheckForUpdate;
except
  Exit;
end;
end;

procedure TForm1.UpdateButtonClick(Sender: TObject);
begin
try
  FAppUpdate.StartUpdate(TAppUpdateType.Immediate);
except
  Exit;
end;
end;

end.
