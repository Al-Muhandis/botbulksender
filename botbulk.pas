unit BotBulk;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, tgtypes, tgsendertypes, brooktelegramaction, bulksend_db, tgsenderworker
  ;

type

  { TBotPlgnBulkSender }

  TBotPlgnBulkSender = class
  private
    FAllIsYearsAgo: Integer;
    FBot: TWebhookBot;
    FBulkSenderDB: TBulkSenderDB;
    FDirectory: String;
    FWorker: TBulkSenderThread;
    procedure AddTask(aUsers: TStrings; const aMessage: TTelegramMessageObj);
    procedure BotBulkEdit(const aDataLine: String);
    procedure BotBulkEditMessage(const aDataLine: String);
    procedure BotBulkEditMessage(const aBulkMessageID: Integer; const aField: String = '');
    procedure BotBulkEditMessageBtnHide(aBulkMessageID: Integer);
    procedure BotBulkEditMessageBtnUrl(aBulkMessageID: Integer);
    procedure BotBulkEditMessageDisablePreview(aBulkMessageID: Integer);
    procedure BotBulkEditUserList(const aDataLine: String);
    procedure BotBulkEditUserList(const aUserListID: Integer);
    procedure BotBulkForceSet(const aEntityAlias, aField: String; aID: Integer);
    procedure BotBulkList(const aDataLine: String);
    procedure BotBulkListBulkMessages;
    procedure BotBulkListTaskItems(const aDataLine: String);
    procedure BotBulkListUserLists(const aDataLine: String);
    procedure BotBulkSend;          
    procedure BotBulkNew(const aDataLine: String; const aMessage: TTelegramMessageObj = nil);
    procedure BotBulkNewBulkMessage(aListID: Integer = 0; aMessage: TTelegramMessageObj = nil);
    procedure BotBulkNewUserList(aMessage: TTelegramMessageObj = nil);             
    procedure BotBulkReply(const aDataLine: String; aMessage: TTelegramMessageObj);
    procedure BotBulkRun(const aDataLine: String);
    procedure BotBulkRun(aBulkMessageID: Integer);
    procedure BotBulkSender(const aMessage: String; aUserList: TStrings);
    procedure BotBulkSet(const aDataLine: String; aValue: String = '');
    procedure BotBulkSetBulkMessage(const aField, aValue: String; aBulkMessageID: Integer = 0);
    procedure BotBulkSetUserList(const aField, aValue: String; aUserListID: Integer = 0);     
    procedure BotBulkSetUserListName(const aName: String; aUserListID: Integer = 0);
    procedure BotBulkSetUserListList(aUserListID: Integer; const aUserLines: String = ''); 
    procedure BotBulkUpdateUserListAll(aUserListID: Integer=1);       
    procedure BotCallbackBulkSend({%H-}ASender: TObject; ACallback: TCallbackQueryObj);
    procedure BotCommandBulkSend({%H-}ASender: TObject; const {%H-}ACommand: String;
      {%H-}AMessage: TTelegramMessageObj);              
    procedure BotDeleteMessage(aCallback: TCallbackQueryObj);
    function CreateInKbd4BulkTurn(const aEntityAlias, aField: String; aID: Integer): TInlineKeyboard;  
    procedure ForceBulkMessageNew(aListID: Integer = 0);
    procedure ForceBulkSendAll;
    procedure ForceBulkSend(const aListID: String = '');   
    procedure ForceUserListNew;
    function GetBulkSenderDB: TBulkSenderDB;
    class function GetCommandAlias: String; static;
    function GetListFileName(const ListID: String): String;
    procedure Register;
    procedure SaveList(AStrings: TStrings; out ListID: String);
    procedure SetWorker(AValue: TBulkSenderThread);
  protected
    property BulkSenderDB: TBulkSenderDB read GetBulkSenderDB;
    property Bot: TWebhookBot read FBot;
  public
    function CheckReply(const aFirstLine: String; aMessage: TTelegramMessageObj): Boolean;
    constructor Create(aOwner: TWebhookBot);
    destructor Destroy; override;
    property AllIsYearsAgo: Integer read FAllIsYearsAgo write FAllIsYearsAgo;
    property Directory: String read FDirectory;
    class property CommandAlias: String read GetCommandAlias;      
    property Worker: TBulkSenderThread read FWorker write SetWorker;
  end;

implementation

uses
  StrUtils, opBulkSend, tgutils, DateUtils
  ;

const
  dt_userlist='userlist';
  dt_bulkmessage='bulkmessage';
  dt_hide='hide';     
  dt_url='url';  
  dt_disablepreview='disablepreview';
  dt_bulksend='bulksend'; 
  dt_edit='edit';      
  dt_list='list';  
  dt_taskitem='taskitem'; 
  dt_run='run';   
  dt_set='set'; 
  dt_urltext='urltext';  
  dt_name='name';     
  dt_new='new';    
  dt_update='update'; 
  dt_all='all';
  dt_delete='delete';

  // emoji
  emj_Back='🔙';    
  emj_ArrowUp='⬆️';  
  emj_CheckBox='🗹';

resourcestring
  s_HideButton='Hide button';
  s_UrlButton='URL button';   
  s_DisablePreview='Disable web page preview';   
  s_List='List';       
  s_turnedOn='turned on';   
  s_turnedOff='turned off';     
  s_Cancel='Cancel';  
  s_UrlButtonText='Button text'; 
  s_New='New';  
  s_EnterUserList='Send user list';  
  s_SendAll='Send all users';   
  s_UserLists='User lists';     
  s_BulkSend='Bulk message sender to bot user list';


function data_EditBulk(const aEntityAlias: String; aID: Integer; const aField: String = ''): String;
begin
  Result:=dt_bulksend+' '+dt_edit+' '+aEntityAlias;
  if aID=0 then
    Exit;
  Result+=' '+aID.ToString;
  if aField=EmptyStr then
    Exit;
  Result+=' '+aField;
end;

function data_ListBulk(const aEntityAlias: String = ''; aID: Integer = 0): String;
begin
  Result:=dt_bulksend+' '+dt_list;
  if aEntityAlias=EmptyStr then
    Exit;
  Result+=' '+aEntityAlias;
  if aID=0 then
    Exit;
  Result+=' '+aID.ToString;
end;

function data_SetBulk(const aEntityAlias: String; aID: Integer; const aField: String = '';
  const aValue: String=''): String;
begin
  Result:=dt_bulksend+' '+dt_set+' '+aEntityAlias+' '+aID.ToString+' '+aField+' '+aValue;
end;

{ TBotPlgnBulkSender }

procedure TBotPlgnBulkSender.AddTask(aUsers: TStrings; const aMessage: TTelegramMessageObj);
var
  aBulkMessageID: Integer;
begin
  if FWorker.BulkMessageID=0 then
  begin
    BulkSenderDB.AddTask(aUsers, aBulkMessageID, aMessage);
    BotBulkRun(aBulkMessageID);
  end;
end;

procedure TBotPlgnBulkSender.BotBulkSend;
var
  aReplyMarkup: TReplyMarkup;
begin
  if not Bot.CurrentIsAdminUser then
     Exit;
  aReplyMarkup:=TReplyMarkup.Create;
  try
    aReplyMarkup.InlineKeyBoard:=TInlineKeyboard.Create;
    aReplyMarkup.InlineKeyBoard.Add.AddButtons([s_EnterUserList, dt_bulksend+' '+dt_new,
      s_SendAll, dt_bulksend+' '+dt_all]);
    aReplyMarkup.InlineKeyBoard.Add.AddButtons([s_UserLists,
      dt_bulksend+' '+dt_list+' '+dt_userlist]);
    aReplyMarkup.InlineKeyBoard.Add.AddButtons(['Bulk tasks',
      dt_bulksend+' '+dt_list+' '+dt_bulkmessage]);
    Bot.sendMessage(s_BulkSend, pmMarkdown, False, aReplyMarkup);
  finally
    aReplyMarkup.Free;
  end;
end;

procedure TBotPlgnBulkSender.BotBulkNew(const aDataLine: String; const aMessage: TTelegramMessageObj);
var
  s: String;
  aID: LongInt;
begin
  s:=ExtractWord(3, aDataLine, [' ']);
  aID:=StrToIntDef(ExtractWord(4, aDataLine, [' ']), 0);
  case AnsiIndexStr(s, [dt_userlist, dt_bulkmessage, EmptyStr]) of
    0: BotBulkNewUserList(aMessage);
    1: BotBulkNewBulkMessage(aID, aMessage);
    2: ForceBulkSend(dt_new);
  end;
end;

procedure TBotPlgnBulkSender.BotBulkNewBulkMessage(aListID: Integer; aMessage: TTelegramMessageObj);
var
  aBulkMessageID: Integer;
  aText, aMedia: String;
  aContentType: TContentType;
begin
  try
    if Assigned(aMessage) then
    begin
      aContentType:=ContentFromMessage(aMessage, aText, aMedia);
      if not ((aText=EmptyStr) and (aMedia=EmptyStr)) then
      begin
        BulkSenderDB.AddBulkMessage(aListID, aBulkMessageID, aText, aMedia, aContentType);
        BotBulkEditMessage(aBulkMessageID);
        Exit;
      end;
    end;
    ForceBulkMessageNew(aListID);
  except
    on E: Exception do
      Bot.Logger.Error('Error BotBulkNewBulkMessage. BulkMessageID: '+aBulkMessageID.ToString+' '+e.ClassName+': '+e.Message);
  end;
end;

procedure TBotPlgnBulkSender.BotBulkNewUserList(aMessage: TTelegramMessageObj);
var
  aUserListID: Integer;
  aName: String;
begin
  if Assigned(aMessage) then
  begin
    aName:=aMessage.Text;
    if aName<>EmptyStr then
    begin
      BulkSenderDB.UserList.name:=aName;
      BulkSenderDB.AddUserList(aUserListID, nil, aName);
      BotBulkEditUserList(aUserListID);
      Exit;
    end;
  end;
  ForceUserListNew;
end;

procedure TBotPlgnBulkSender.BotBulkReply(const aDataLine: String; aMessage: TTelegramMessageObj);
var
  aParamater1, aText: String;
  aUsers: TStringList;
begin
  aParamater1:=ExtractWord(2, aDataLine, [' ']);
  aUsers:=TStringList.Create;
  try
    aText:=aMessage.Text;
    if aParamater1=EmptyStr then
    begin
      aUsers.Text:=aText;
      SaveList(aUsers, aParamater1);
      ForceBulkSend(aParamater1);
    end
    else begin
      case AnsiIndexStr(aParamater1, [dt_new, dt_set]) of
        0: begin BotBulkNew(aDataLine, aMessage); Exit; end;
        1: begin BotBulkSet(aDataLine, aText); Exit; end;
      end;
      aUsers.LoadFromFile(GetListFileName(aParamater1));
      AddTask(aUsers, aMessage);
    end;
  finally
    aUsers.Free;
  end;
end;

function TBotPlgnBulkSender.CheckReply(const aFirstLine: String; aMessage: TTelegramMessageObj): Boolean;
begin
  Result:=False;
  if StartsStr('/'+CommandAlias, aFirstLine) then
    if Bot.CurrentIsSimpleUser then
      Bot.Logger.Error('The user is not a moderator of the bot')
    else begin
      BotBulkReply(aFirstLine, aMessage);
      Result:=True;
    end;
end;

procedure TBotPlgnBulkSender.BotBulkRun(const aDataLine: String);
var
  aBulkMessageID: Longint;
  s: String;
begin
  s:=ExtractWord(4, aDataLine, [' ']);
  if not TryStrToInt(s, aBulkMessageID) then
    Exit;
  BotBulkRun(aBulkMessageID);
end;

procedure TBotPlgnBulkSender.BotBulkRun(aBulkMessageID: Integer);

  procedure Run;
  begin
    if FWorker.BulkMessageID<>0 then
    begin
      Bot.sendMessage('Task #'+aBulkMessageID.ToString+' is currently in progress. Wait for the end');
      Exit;
    end;
    FWorker.BulkMessageID:=aBulkMessageID;
    BulkSenderDB.BulkMessage.BulkState:=bsInProgress;
    BulkSenderDB.SaveBulkMessage;
    FWorker.UnblockWorker;
//    BotBulkEditMessage(aBulkMessageID);
  end;

begin
  case BulkSenderDB.GetBulkMessageByID(aBulkMessageID).BulkState of
    bsReady: Run;
    bsInProgress: Bot.sendMessage('This task is already running');
    bsDone: Bot.sendMessage('Task #'+aBulkMessageID.ToString+' has already been completed');
  end;
end;

procedure TBotPlgnBulkSender.BotBulkSender(const aMessage: String; aUserList: TStrings);
var
  l: TUserList;
  aReplyMarkup: TReplyMarkup;
begin
  if Assigned(aUserList) then
    if aMessage<>EmptyStr then
    begin
      BulkSenderDB.ListUserLists;
      aReplyMarkup:=TReplyMarkup.Create;
      try
        aReplyMarkup.InlineKeyBoard:=TInlineKeyboard.Create;
        for l in BulkSenderDB.UserLists do
          aReplyMarkup.InlineKeyBoard.AddButton(l.name, dt_bulksend+' '+dt_list+' '+dt_userlist+' '
            +l.id.ToString);
      finally
      end;
    end;
end;

procedure TBotPlgnBulkSender.BotBulkSet(const aDataLine: String; aValue: String);
var
  s, aField: String;
  aID: LongInt;
begin
  s:=ExtractWord(3, aDataLine, [' ']);
  aID:=StrToIntDef(ExtractWord(4, aDataLine, [' ']), 0);
  aField:=ExtractWord(5, aDataLine, [' ']);
  if aValue=EmptyStr then
    aValue:=ExtractWord(6, aDataLine, [' ']);
  if aValue=EmptyStr then
    BotBulkForceSet(s, aField, aID);
  case AnsiIndexStr(s, [dt_userlist, dt_bulkmessage]) of
    0: BotBulkSetUserList(aField, aValue, aID);
    1: BotBulkSetBulkMessage(aField, aValue, aID);
  end;
end;

procedure TBotPlgnBulkSender.BotBulkSetBulkMessage(const aField, aValue: String; aBulkMessageID: Integer);
var
  i: Integer;
begin
  i:=AnsiIndexStr(aField, [dt_hide, dt_url, dt_urltext, dt_disablepreview]);
  with BulkSenderDB.GetBulkMessageByID(aBulkMessageID) do
    case i of
      0: HideButton:=StrToBoolDef(aValue, True);
      1: ButtonUrl:=aValue;
      2: ButtonUrlText:=aValue;
      3: DisableWebPagePreview:=StrToBoolDef(aValue, True);
    end;
  BulkSenderDB.SaveBulkMessage;
  case i of
    0: BotBulkEditMessageBtnHide(aBulkMessageID);
    1..2: BotBulkEditMessageBtnUrl(aBulkMessageID);
    3: BotBulkEditMessageDisablePreview(aBulkMessageID);
  end;
end;

procedure TBotPlgnBulkSender.BotBulkSetUserList(const aField, aValue: String; aUserListID: Integer);
begin
  case AnsiIndexStr(aField, [dt_name, dt_list, dt_update]) of
    0: BotBulkSetUserListName(aValue, aUserListID);
    1: BotBulkSetUserListList(aUserListID, aValue);
    2: BotBulkUpdateUserListAll(aUserListID);
  end;
end;

procedure TBotPlgnBulkSender.BotBulkSetUserListName(const aName: String; aUserListID: Integer);
begin
  if aUserListID<>0 then
    BulkSenderDB.GetUserListByID(aUserListID);
  BulkSenderDB.UserList.name:=aName;
  if aUserListID<>0 then
    BulkSenderDB.opUserLists.Modify
  else
    BulkSenderDB.opUserLists.Add;
  BulkSenderDB.opUserLists.Apply;
end;

procedure TBotPlgnBulkSender.BotBulkSetUserListList(aUserListID: Integer; const aUserLines: String);
var
  aUsers: TStringList;
begin
  aUsers:=TStringList.Create;
  try
    aUsers.Text:=aUserLines;
    BulkSenderDB.AddUsersToList(aUserListID, aUsers);
  finally
    aUsers.Free;
  end;
end;

procedure TBotPlgnBulkSender.BotBulkUpdateUserListAll(aUserListID: Integer);
var
  aUpdated: TDateTime;
  aUsers, aEvents: Integer;
  aIDs: TStrings;
begin
  aUpdated:=BulkSenderDB.GetUserListByID(aUserListID).LastUpdate;
  if aUpdated=0 then
    aUpdated:=Now-2000;
  aIDs:=TStringList.Create;
  try
    Bot.CalculateStat(aUpdated, Now, aUsers, aEvents, aIDs);
    BulkSenderDB.AddUsersToList(aUserListID, aIDs);
  except
    aIDs.Free;
  end;
end;

procedure TBotPlgnBulkSender.BotCallbackBulkSend(ASender: TObject; ACallback: TCallbackQueryObj);
var
  s: String;
begin
  s:=ExtractWord(2, ACallback.Data, [' ']);
  if not Bot.CurrentIsAdminUser and (s<>dt_delete) then
    Exit;
  case s of
    dt_list:   BotBulkList(ACallback.Data);
    dt_edit:   BotBulkEdit(ACallback.Data);
    dt_new:    BotBulkNew(ACallback.Data);
    dt_run:    BotBulkRun(ACallback.Data);
    dt_set:    BotBulkSet(ACallback.Data);
    dt_delete: BotDeleteMessage(ACallback);
  else
    ForceBulkSend(s);
  end;
end;

procedure TBotPlgnBulkSender.BotCommandBulkSend(ASender: TObject; const ACommand: String; AMessage: TTelegramMessageObj
  );
begin
  BotBulkSend;
  Bot.UpdateProcessed:=True;
end;

procedure TBotPlgnBulkSender.BotDeleteMessage(aCallback: TCallbackQueryObj);
begin
  Bot.deleteMessage(aCallback.Message.MessageId);
end;

function TBotPlgnBulkSender.CreateInKbd4BulkTurn(const aEntityAlias, aField: String; aID: Integer): TInlineKeyboard;
begin
  Result:=TInlineKeyboard.Create;
  Result.AddButton(s_turnedOn,   data_SetBulk(aEntityAlias, aID, aField, BoolToStr(True)),  2);
  Result.AddButton(s_turnedOff,  data_SetBulk(aEntityAlias, aID, aField, BoolToStr(False)), 2);
  Result.Add.AddButton(emj_ArrowUp+' '+s_Cancel, data_EditBulk(aEntityAlias, aID));
end;

procedure TBotPlgnBulkSender.ForceBulkMessageNew(aListID: Integer);
var
  aReplyMarkup: TReplyMarkup;
  aData: String;
begin
  if Bot.CurrentIsSimpleUser then
  begin
    Bot.Logger.Error('You are not a moderator of the bot');
    Exit;
  end;
  aReplyMarkup:=TReplyMarkup.Create;
  try
    aReplyMarkup.ForceReply:=True;
    aData:='/'+dt_bulksend+' '+dt_new+' '+dt_bulkmessage;
    if aListID<>0 then
      aData+=' '+aListID.ToString;
    Bot.sendMessage(aData+LineEnding+'Please enter bulk message text:', pmMarkdown, True,
      aReplyMarkup)
  finally
    aReplyMarkup.Free;
  end;
end;

procedure TBotPlgnBulkSender.ForceBulkSendAll;
var
  Msg: String;
  aListID: String;
  aEvents, aUsers: Integer;
  aIDs: TStringList;
  aToDate, aFromDate: TDateTime;
begin
  aToDate:=Date;
  aFromDate:=IncYear(aToDate, -FAllIsYearsAgo);
  aUsers:=0;
  aEvents:=0;
  Msg:=EmptyStr;
  aIDs:=TStringList.Create;
  try
    Bot.CalculateStat(aFromDate, aToDate, aUsers, aEvents, aIDs);
    Msg+=LineEnding+'Users for bulk send: '+IntToStr(aUsers);
    SaveList(aIDs, aListID);
    ForceBulkSend(aListID);
  finally
    aIDs.Free;
  end;
end;

procedure TBotPlgnBulkSender.ForceBulkSend(const aListID: String);
var
  ReplyMarkup: TReplyMarkup;
begin
  if Bot.CurrentIsSimpleUser then
  begin
    Bot.Logger.Error('The user is not a moderator of the bot');
    Exit;
  end;
  ReplyMarkup:=TReplyMarkup.Create;
  try
    ReplyMarkup.ForceReply:=True;
    case AnsiIndexStr(aListID, [EmptyStr, dt_all, dt_new]) of
      0: BotBulkSend;
      1: ForceBulkSendAll;
      2: Bot.sendMessage('/'+dt_bulksend+LineEnding+'Please enter user id list (one user per line):',
        pmMarkdown, True, ReplyMarkup);
    else
      Bot.sendMessage('/'+dt_bulksend+' '+aListID+LineEnding+
        'Please enter text for bulk sending (Markdown markup):', pmMarkdown, True, ReplyMarkup);
    end;
  finally
    ReplyMarkup.Free;
  end;
end;

procedure TBotPlgnBulkSender.ForceUserListNew;
var
  aReplyMarkup: TReplyMarkup;
begin
  if Bot.CurrentIsSimpleUser then
  begin
    Bot.Logger.Error('The user is not a moderator of the bot');
    Exit;
  end;
  aReplyMarkup:=TReplyMarkup.Create;
  try
    aReplyMarkup.ForceReply:=True;
    Bot.sendMessage('/'+dt_bulksend+' '+dt_new+' '+dt_userlist+LineEnding+
      'Please enter user list name:', pmMarkdown, True, aReplyMarkup)
  finally
    aReplyMarkup.Free;
  end;
end;

function TBotPlgnBulkSender.GetBulkSenderDB: TBulkSenderDB;
begin
  if not Assigned(FBulkSenderDB) then
  begin
    FBulkSenderDB:=TBulkSenderDB.Create(False);
    FBulkSenderDB.Directory:=Directory;
    FBulkSenderDB.LogDebug:=Bot.LogDebug;
  end;
  Result:=FBulkSenderDB;
end;

class function TBotPlgnBulkSender.GetCommandAlias: String;
begin
  Result:=dt_bulksend;
end;

function TBotPlgnBulkSender.GetListFileName(const ListID: String): String;
begin
  Result:=Worker.TmpDirectory+'~'+Bot.CurrentChatId.ToString+'_'+ListID+'.lst';
end;

procedure TBotPlgnBulkSender.Register;
begin
  Bot.CommandHandlers['/'+CommandAlias]:=@BotCommandBulkSend;
  Bot.CallbackHandlers[CommandAlias]:=@BotCallbackBulkSend;
end;

procedure TBotPlgnBulkSender.SaveList(AStrings: TStrings; out ListID: String);
var
  D: LongInt;
  AFileName: String;
begin
  try
    D:=DateTimeToFileDate(Now);
    repeat
      Inc(D);
      ListID:=D.ToString;
      AFileName:=GetListFileName(ListID);
    until not FileExists(AFileName);
    AStrings.SaveToFile(AFileName);
  except
    on E: Exception do
      Bot.Logger.Error('Can''t save '+AFileName+' with ListID '+ListID+'. '+E.ClassName+': '+E.Message);
  end;
end;

procedure TBotPlgnBulkSender.SetWorker(AValue: TBulkSenderThread);
begin
  if FWorker=AValue then Exit;
  FWorker:=AValue;
  FDirectory:=AValue.Directory;
end;

procedure TBotPlgnBulkSender.BotBulkEdit(const aDataLine: String);
var
  s: String;
begin
  s:=ExtractWord(3, aDataLine, [' ']);
  case AnsiIndexStr(s, [dt_userlist, dt_bulkmessage]) of
    0: BotBulkEditUserList(aDataLine);
    1: BotBulkEditMessage(aDataLine);
  end;
end;

procedure TBotPlgnBulkSender.BotBulkEditMessage(const aDataLine: String);
var
  s, aField: String;
  aBlkMsgID: Longint;
begin
  s:=ExtractWord(4, aDataLine, [' ']);
  aField:=ExtractWord(5, aDataLine, [' ']);
  if TryStrToInt(S, aBlkMsgID) then
    BotBulkEditMessage(aBlkMsgID, aField);
end;

procedure TBotPlgnBulkSender.BotBulkEditMessage(const aBulkMessageID: Integer; const aField: String);
var
  aReplyMarkup: TReplyMarkup;
  aMsg: String;
  aBulkMessage: TBulkMessage;
  aUserList: TUserList;
begin
  if aField<>EmptyStr then
  begin
    case AnsiIndexStr(aField, [dt_hide, dt_url, dt_disablepreview]) of
      0: BotBulkEditMessageBtnHide(aBulkMessageID);
      1: BotBulkEditMessageBtnUrl(aBulkMessageID);
      2: BotBulkEditMessageDisablePreview(aBulkMessageID);
    end;
    Exit;
  end;
  aReplyMarkup:=TReplyMarkup.Create;
  try
    aReplyMarkup.InlineKeyBoard:=TInlineKeyboard.Create;
    aReplyMarkup.InlineKeyBoard.Add.AddButtons([
      s_HideButton, data_EditBulk(dt_bulkmessage, aBulkMessageID, dt_hide),
      s_UrlButton, data_EditBulk(dt_bulkmessage, aBulkMessageID, dt_url),
      s_DisablePreview, data_EditBulk(dt_bulkmessage, aBulkMessageID, dt_disablepreview)]);
    aReplyMarkup.InlineKeyBoard.Add.AddButtons([
      'Update', data_EditBulk(dt_bulkmessage, aBulkMessageID),
      'Report', data_ListBulk(dt_taskitem, aBulkMessageID)]);
    aReplyMarkup.InlineKeyBoard.Add.AddButton('Run',
      dt_bulksend+' '+dt_run+' '+dt_bulkmessage+' '+aBulkMessageID.ToString);
    aReplyMarkup.InlineKeyBoard.Add.AddButton(emj_Back+' '+s_List,
      data_ListBulk(dt_bulkmessage, aBulkMessageID));
    with BulkSenderDB do
    begin
      aBulkMessage:=GetBulkMessageByID(aBulkMessageID);
      aUserList:=GetUserListByID(aBulkMessage.UserList);
    end;
    aMsg:='Bulk task state: '+BulkStateToString(aBulkMessage.BulkState)+LineEnding+'Bulk task #'+
      aBulkMessageID.ToString+', user list #'+aUserList.ID.ToString;
    if aUserList.name<>EmptyStr then
      aMsg+=' "'+MarkdownEscape(aUserList.name)+'"';
    if aBulkMessage.HideButton then
      aMsg+=LineEnding+s_HideButton+': '+s_turnedOn;
    if aBulkMessage.DisableWebPagePreview then
      aMsg+=LineEnding+s_DisablePreview+': '+s_turnedOn;
    aMsg+=LineEnding+'Current active task: #'+Worker.BulkMessageID.ToString+
      LineEnding+LineEnding+'Message:'+LineEnding+BulkSenderDB.GetBulkMessageByID(aBulkMessageID).Text;
    Bot.EditOrSendMessage(aMsg, pmMarkdown, aReplyMarkup, True);
  finally
   aReplyMarkup.Free;
  end;
end;

procedure TBotPlgnBulkSender.BotBulkEditMessageBtnHide(aBulkMessageID: Integer);
var
  aReplyMarkup: TReplyMarkup;
  aTurnedOn: Boolean;
begin
  aReplyMarkup:=TReplyMarkup.Create;
  try
    BulkSenderDB.GetBulkMessageByID(aBulkMessageID);
    aTurnedOn:=BulkSenderDB.BulkMessage.HideButton;
    aReplyMarkup.InlineKeyBoard:=CreateInKbd4BulkTurn(dt_bulkmessage, dt_hide, aBulkMessageID);
    Bot.EditOrSendMessage(emj_CheckBox+' '+s_HideButton+': *'+
      BoolToStr(aTurnedOn, s_turnedOn, s_turnedOff)+'*'+LineEnding, pmMarkdown, aReplyMarkup, True);
  finally
    aReplyMarkup.Free;
  end;
end;

procedure TBotPlgnBulkSender.BotBulkEditMessageBtnUrl(aBulkMessageID: Integer);
var
  aReplyMarkup: TReplyMarkup;
  aUrl: String;
begin
  aReplyMarkup:=TReplyMarkup.Create;
  try
    BulkSenderDB.GetBulkMessageByID(aBulkMessageID);
    aUrl:=BulkSenderDB.BulkMessage.ButtonUrl;
    aReplyMarkup.InlineKeyBoard:=TInlineKeyboard.Create;
    aReplyMarkup.InlineKeyBoard.Add.AddButtons([
      'Set URL', data_SetBulk(dt_bulkmessage, aBulkMessageID, dt_url),
      'Set caption', data_SetBulk(dt_bulkmessage, aBulkMessageID, dt_urltext)]);
    aReplyMarkup.InlineKeyBoard.Add.AddButton(emj_Back+' '+s_Cancel, data_EditBulk(dt_bulkmessage,
      aBulkMessageID));
    Bot.EditOrSendMessage(s_UrlButton+': *'+aUrl+'*'+LineEnding+s_UrlButtonText+': '+
      '*'+BulkSenderDB.BulkMessage.ButtonUrlText+'*', pmMarkdown,
      aReplyMarkup, True);
  finally
    aReplyMarkup.Free;
  end;
end;

procedure TBotPlgnBulkSender.BotBulkEditMessageDisablePreview(aBulkMessageID: Integer);
var
  aReplyMarkup: TReplyMarkup;
  aTurnedOn: Boolean;
begin
  aReplyMarkup:=TReplyMarkup.Create;
  try
    BulkSenderDB.GetBulkMessageByID(aBulkMessageID);
    aTurnedOn:=BulkSenderDB.BulkMessage.DisableWebPagePreview;
    aReplyMarkup.InlineKeyBoard:=CreateInKbd4BulkTurn(dt_bulkmessage, dt_disablepreview, aBulkMessageID);
    Bot.EditOrSendMessage(emj_CheckBox+' '+s_DisablePreview+': *'+
      BoolToStr(aTurnedOn, s_turnedOn, s_turnedOff)+'*'+LineEnding, pmMarkdown, aReplyMarkup, True);
  finally
    aReplyMarkup.Free;
  end;
end;

procedure TBotPlgnBulkSender.BotBulkEditUserList(const aDataLine: String);
var
  s: String;
  aBlkMsgID: Longint;
begin
  s:=ExtractWord(4, aDataLine, [' ']);
  if TryStrToInt(S, aBlkMsgID) then
    BotBulkEditUserList(aBlkMsgID);
end;

procedure TBotPlgnBulkSender.BotBulkEditUserList(const aUserListID: Integer);
var
  aReplyMarkup: TReplyMarkup;
begin
  aReplyMarkup:=TReplyMarkup.Create;
  try
    aReplyMarkup.InlineKeyBoard:=TInlineKeyboard.Create;
    aReplyMarkup.InlineKeyBoard.Add.AddButtons(['Edit name',
      dt_bulksend+' '+dt_set+' '+dt_userlist+' '+aUserListID.ToString+' '+dt_name,
      'New bulk message', dt_bulksend+' '+dt_new+' '+dt_bulkmessage+' '+aUserListID.ToString]);
    aReplyMarkup.InlineKeyBoard.Add.AddButtons(['Set users',
      dt_bulksend+' '+dt_set+' '+dt_userlist+' '+aUserListID.ToString+' '+dt_list]);
    if aUserListID=1 then
      aReplyMarkup.InlineKeyBoard.Add.AddButtons(['Update list',
        dt_bulksend+' '+dt_set+' '+dt_userlist+' '+aUserListID.ToString+' '+dt_update+' '+BoolToStr(True)]);
    aReplyMarkup.InlineKeyBoard.Add.AddButton(emj_Back+' '+s_List, data_ListBulk(dt_userlist));
    Bot.EditOrSendMessage('User list with name: '+
      MarkdownEscape(BulkSenderDB.GetUserListByID(aUserListID).Name)+'. #'+aUserListID.ToString+
      LineEnding, pmMarkdown, aReplyMarkup, True);
  finally
    aReplyMarkup.Free;
  end;
end;

procedure TBotPlgnBulkSender.BotBulkForceSet(const aEntityAlias, aField: String; aID: Integer);
var
  aReplyMarkup: TReplyMarkup;
begin
  aReplyMarkup:=TReplyMarkup.Create;
  try
    aReplyMarkup.ForceReply:=True;
    Bot.sendMessage('/'+data_SetBulk(aEntityAlias, aID, aField)+
      LineEnding+'Please enter '+aField+' value:', pmMarkdown, True, aReplyMarkup);
  finally
    aReplyMarkup.Free;
  end;
end;

procedure TBotPlgnBulkSender.BotBulkList(const aDataLine: String);
var
  s: String;
begin
  s:=ExtractWord(3, aDataLine, [' ']);
  case AnsiIndexStr(s, [dt_userlist, dt_taskitem, dt_bulkmessage]) of
    0: BotBulkListUserLists(aDataLine);
    1: BotBulkListTaskItems(aDataLine);
    2: BotBulkListBulkMessages;
  end;
end;

procedure TBotPlgnBulkSender.BotBulkListBulkMessages;
var
  aMsg: String;
  i: TBulkMessage;
  aReplyMarkup: TReplyMarkup;
begin
  aReplyMarkup:=TReplyMarkup.Create;
  aReplyMarkup.InlineKeyBoard:=TInlineKeyboard.Create;
  try
    aMsg:='Recent list of bulk message tasks';
    BulkSenderDB.ListBulkMessages;
    //aReplyMarkup.InlineKeyBoard.AddButton(s_New, dt_bulksend+' '+dt_new+' '+dt_userlist);
    for i in BulkSenderDB.BulkMessages do
      aReplyMarkup.InlineKeyBoard.AddButton('#'+i.ID.ToString, dt_bulksend+' '+dt_edit+' '+
        dt_bulkmessage+' '+i.id.ToString, 5);
    aReplyMarkup.InlineKeyBoard.Add.AddButton(emj_Back+' '+'Bulk sending main menu', dt_bulksend);
    Bot.EditOrSendMessage(aMsg, pmMarkdown, aReplyMarkup, True);
  finally
    aReplyMarkup.Free;
  end;
end;

procedure TBotPlgnBulkSender.BotBulkListTaskItems(const aDataLine: String);
var
  aBulkMessageID: Longint;
  aTaskItem: TTaskItem;
  aCSV, aMsg: String;
  aReplyMarkup: TReplyMarkup;
  aStream: TStringStream;
begin
  if not TryStrToInt(ExtractWord(4, aDataLine, [' ']), aBulkMessageID) then
    Exit;
  if ExtractWord(5, aDataLine, [' '])='csv' then
  begin
    aCSV:=EmptyStr;
    for aTaskItem in BulkSenderDB.ListTaskItems(aBulkMessageID) do
      aCSV+=aTaskItem.UserID.ToString+'; '+aTaskItem.ErrorCode.ToString+'; "'+aTaskItem.ErrorDescr+'"'+LineEnding;
    aMsg:='Report of recipient list'+LineEnding+aCSV;
    aStream:=TStringStream.Create(aMsg);
    try
      Bot.sendDocumentStream(Bot.CurrentChatId, 'report.csv', aStream, 'CSV table');
    finally
      aStream.Free;
    end;
    Exit;
  end;
  aReplyMarkup:=TReplyMarkup.Create;
  aReplyMarkup.InlineKeyBoard:=TInlineKeyboard.Create;
  try
    aCSV:=EmptyStr;
    aReplyMarkup.InlineKeyBoard.Add.AddButton('As CSV file',
      data_ListBulk(dt_taskitem, aBulkMessageID)+' '+'csv');
    for aTaskItem in BulkSenderDB.ListTaskItems(aBulkMessageID, 50) do
      aCSV+='['+aTaskItem.UserID.ToString+'](tg://user?id='+aTaskItem.UserID.ToString+')  '+
        mdCode+aTaskItem.ErrorCode.ToString+mdCode+'  "'+aTaskItem.ErrorDescr+'"'+LineEnding;
    aMsg:='Report of recipient list'+LineEnding+aCSV;
    Bot.EditOrSendMessage(aMsg, pmMarkdown, aReplyMarkup, True);
  finally
    aReplyMarkup.Free;
  end;
end;

procedure TBotPlgnBulkSender.BotBulkListUserLists(const aDataLine: String);
var
  s, aMsg: String;
  aReplyMarkup: TReplyMarkup;

  procedure List();
  var
    l: TUserList;
  begin
    aMsg:='List of bot user subscriptions (user lists)';
    BulkSenderDB.ListUserLists;
    aReplyMarkup.InlineKeyBoard.AddButton(s_New, dt_bulksend+' '+dt_new+' '+dt_userlist);
    for l in BulkSenderDB.UserLists do
      aReplyMarkup.InlineKeyBoard.AddButton(l.name, dt_bulksend+' '+dt_edit+' '+dt_userlist+' '+
        l.id.ToString, 1);
    aReplyMarkup.InlineKeyBoard.Add.AddButton(emj_Back+' '+'Bulk sending main menu', dt_bulksend);
  end;

  procedure Item;
  var
    aID: Longint;
  begin
    if TryStrToInt(S, aID) then
    begin
      BulkSenderDB.UserList.id:=aID;
      BulkSenderDB.opUserLists.Get;
      aMsg:='User list: '+MarkdownEscape(BulkSenderDB.UserList.name);
    end;
  end;

  procedure new;
  begin
    ForceBulkSend(dt_new);
  end;

begin
  s:=ExtractWord(4, aDataLine, [' ']);
  aReplyMarkup:=TReplyMarkup.Create;
  aReplyMarkup.InlineKeyBoard:=TInlineKeyboard.Create;
  try
    case AnsiIndexStr(s, [EmptyStr, dt_new]) of
      0: List;
      1: New;
    else
      Item;
    end;
    Bot.EditOrSendMessage(aMsg, pmMarkdown, aReplyMarkup, True);
  finally
    aReplyMarkup.Free;
  end;
end;

constructor TBotPlgnBulkSender.Create(aOwner: TWebhookBot);
begin
  FBot:=aOwner;
  AllIsYearsAgo:=7;
  Register;
end;

destructor TBotPlgnBulkSender.Destroy;
begin
  FBulkSenderDB.Free;
  inherited Destroy;
end;

end.

