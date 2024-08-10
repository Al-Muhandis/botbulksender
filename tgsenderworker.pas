unit tgsenderworker;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, eventlog, tgsendertypes, fpjson, bulksend_db, opBulkSend
  ;

type

  { TBulkSenderThread }

  TBulkSenderThread = class(TThread)
  private
    FBot: TTelegramSender;
    FBulkMessageID: Integer;
    FBulkSenderDB: TBulkSenderDB;
    FDir: String;
    FTmpDirectory: String;
    FLogger: TEventLog;
    FPaused: Boolean;
    FUnblockEvent: pRTLEvent;  // or defrosting and terminating while the thread is pending tasks
    FTerminateEvent: pRTLEvent;   // for terminating while the thread is delayed
    function GetBulkSenderDB: TBulkSenderDB;
    procedure SetPaused(AValue: Boolean);
    procedure SendMessage(aTask: TTaskItem; aMessage: TBulkMessage);
    function WaitingDelay(ADelay: Integer): Boolean;
    function WaitingForTask: Boolean;
  protected
    property BulkSenderDB: TBulkSenderDB read GetBulkSenderDB;
  public
    constructor Create;
    constructor Create(const aTelegramToken, aDirectory: String);
    destructor Destroy; override;
    procedure Execute; override;
    procedure TerminateWorker;
    procedure UnblockWorker;
    property Paused: Boolean read FPaused write SetPaused;
    property Bot: TTelegramSender read FBot;
    property BulkMessageID: Integer read FBulkMessageID write FBulkMessageID;
    property TmpDirectory: String read FTmpDirectory write FTmpDirectory;
    property Logger: TEventLog read FLogger;
    property Directory: String read FDir write FDir;
  end;

//function DefaultBulkWorker(const aTelegramToken: String): TBulkSenderThread;

implementation

uses
  dateutils, LConvEncoding, dUtils, jsonparser, jsonscanner
  ;

resourcestring
  s_hide='👁 Скрыть / Hide';
  s_Goto='Go to';

var
  AppDir: String;

const
  _cmdDltMsg='bulksend delete'; // deptecated: 'delete message'

  //_BulkWorker: TBulkSenderThread;
{
function DefaultBulkWorker(const aTelegramToken: String): TBulkSenderThread;
begin
  if not Assigned(_BulkWorker) then
  begin
    _BulkWorker:=TBulkSenderThread.Create;
    _BulkWorker.Start;
    _BulkWorker.Bot.Token:=aTelegramToken;
    _BulkWorker.TmpDirectory:=AppDir+'tmp'+PathDelim;
    _BulkWorker.Bot.Logger.Info('Start bulk worker');
  end;
  Result:=_BulkWorker;
end;   }

{ TBulkSenderThread }

procedure TBulkSenderThread.SetPaused(AValue: Boolean);
begin
  if FPaused=AValue then Exit;
  FPaused:=AValue;
end;

procedure TBulkSenderThread.SendMessage(aTask: TTaskItem; aMessage: TBulkMessage
  );
var
  aReplyMarkup: TReplyMarkup;
  aCaption: String;
begin
  if aMessage.ReplyMarkup=EmptyStr then
  begin
    aReplyMarkup:=TReplyMarkup.Create;
    aReplyMarkup.InlineKeyBoard:=TInlineKeyboard.Create;
    if aMessage.HideButton then
      aReplyMarkup.InlineKeyBoard.Add.AddButton(s_Hide, _cmdDltMsg);
    if Trim(aMessage.ButtonUrl)<>EmptyStr then
    begin
      aCaption:=aMessage.ButtonUrlText;
      if aCaption=EmptyStr then
        aCaption:=s_Goto;
      aReplyMarkup.InlineKeyBoard.Add.AddButtonUrl(aCaption, aMessage.ButtonUrl);
    end
  end
  else
    aReplyMarkup:=TReplyMarkup.CreateFromString(aMessage.ReplyMarkup);
  try
    SendEntityContent(Bot, aTask.UserID, aMessage.Text, aMessage.Media, aMessage.MediaType,
      pmMarkdown, aMessage.DisableWebPagePreview, aReplyMarkup);
    aTask.ErrorCode:=FBot.LastErrorCode;
    aTask.ErrorDescr:=FBot.LastErrorDescription;
  finally
    aReplyMarkup.Free;
  end;
end;

function TBulkSenderThread.GetBulkSenderDB: TBulkSenderDB;
begin
  if not Assigned(FBulkSenderDB) then
  begin
    FBulkSenderDB:=TBulkSenderDB.Create;
    FBulkSenderDB.Directory:=FDir;
    FBulkSenderDB.LogDebug:=Bot.LogDebug;
  end;
  Result:=FBulkSenderDB;
end;

function TBulkSenderThread.WaitingDelay(ADelay: Integer): Boolean;
begin
  RTLeventWaitFor(FTerminateEvent, ADelay);
  Result:=not Terminated;
end;

function TBulkSenderThread.WaitingForTask: Boolean;
begin
  RTLeventWaitFor(FUnblockEvent);
  RTLeventResetEvent(FUnblockEvent);
  Result:=not Terminated;
end;

constructor TBulkSenderThread.Create;
begin
  inherited Create(True);
  FLogger:=TEventLog.Create(nil);
  FLogger.LogType:=ltFile;
  if FDir.IsEmpty then
    FLogger.FileName:=AppDir+ClassName+'.log'
  else
    FLogger.FileName:=FDir+ClassName+'.log';
  FLogger.AppendContent:=True;
  FLogger.Active:=True;
  FreeOnTerminate:=False;
  FUnblockEvent:=RTLEventCreate;
  FTerminateEvent:=RTLEventCreate;
  FBot:=TTelegramSender.Create(EmptyStr);
  FBot.Logger:=Logger;
end;

constructor TBulkSenderThread.Create(const aTelegramToken, aDirectory: String);
begin
  FDir:=aDirectory;
  Create;
  Bot.Token:=aTelegramToken;
  TmpDirectory:=IncludeTrailingPathDelimiter(aDirectory)+'tmp'+PathDelim;
end;

destructor TBulkSenderThread.Destroy;
begin
  FBot.Free;
  RTLeventdestroy(FTerminateEvent);
  RTLeventdestroy(FUnblockEvent);
  FBulkSenderDB.Free;
  FLogger.Free;
  inherited Destroy;
end;

procedure TBulkSenderThread.Execute;
begin
  while not Terminated do
    with BulkSenderDB do
    try
      if not WaitingForTask then
        Exit;
      BulkMessage.id:=FBulkMessageID;
      opBulkMessages.Get;
      SubscribersQuery.SQL.Text:='SELECT * FROM subscribers WHERE userlist='+BulkMessage.UserList.ToString;
      SubscribersQuery.Open;
      SubscribersQuery.First;
      if not SubscribersQuery.EOF then
        repeat
          dUtils.dGetFields(Subscriber, SubscribersQuery.Fields);
          TaskItem.UserID:=Subscriber.UserID;
          TaskItem.BulkMessage:=BulkMessage.id;
          if not WaitingDelay(200) then
            Exit;
          SendMessage(TaskItem, BulkMessage);
          opTaskItems.Add;
          SubscribersQuery.Next;
        until SubscribersQuery.EOF;
      opTaskItems.Apply;
      GetBulkMessageByID(FBulkMessageID).BulkState:=bsDone;
      SaveBulkMessage;
      FBulkMessageID:=0;
    except
      on E: Exception do
        Logger.Error('['+UnitName+'.'+ClassName+'] '+e.ClassName+': '+e.Message);
    end;
end;

procedure TBulkSenderThread.TerminateWorker;
begin
  Terminate;
  RTLeventSetEvent(FUnblockEvent);
  RTLeventSetEvent(FTerminateEvent);
end;

procedure TBulkSenderThread.UnblockWorker;
begin
  RTLeventSetEvent(FUnblockEvent);
end;

initialization
  AppDir:=IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0)));

finalization    {
  if Assigned(_BulkWorker) then
    _BulkWorker.TerminateWorker;
  _BulkWorker.Free; }

end.

