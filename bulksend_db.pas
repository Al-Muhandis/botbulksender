unit bulksend_db;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, dSQLdbBroker, sqlite3conn, opBulkSend, tgsendertypes, tgtypes
  ;


type

  { TBulkSenderDB }

  TBulkSenderDB = class
  public type
    TopBulkMessages = specialize TdGSQLdbEntityOpf<TBulkMessage>;
    TopTaskItems = specialize TdGSQLdbEntityOpf<TTaskItem>;
    TopUserLists = specialize TdGSQLdbEntityOpf<TUserList>;
    TopSubscribers = specialize TdGSQLdbEntityOpf<TSubscriber>;
  private
    FCon: TdSQLdbConnector;
    FBulkMessages: TopBulkMessages.TEntities;
    FDirectory: String;
    FIsWorker: Boolean;
    FLogDebug: Boolean;
    FopSubscribers: TopSubscribers;
    FopUserLists: TopUserLists;
    FTaskItems: TopTaskItems.TEntities;
    FopBulkMessages: TopBulkMessages;
    FopTaskItems: TopTaskItems;
    FQuery: TdSQLdbQuery;
    FSubscribersQuery: TdSQLdbQuery;
    FUserLists: TopUserLists.TEntities;
    procedure CreateDB;
    function GetBulkMessage: TBulkMessage;
    function GetBulkMessages: TopBulkMessages.TEntities;
    function GetopBulkMessages: TopBulkMessages;
    function GetopSubscribers: TopSubscribers;
    function GetopTaskItems: TopTaskItems;
    function GetopUserLists: TopUserLists;
    function GetQuery: TdSQLdbQuery;
    function GetSubscriber: TSubscriber;
    function GetTaskItem: TTaskItem;
    function GetTaskItems: TopTaskItems.TEntities;
    function GetSubscribersQuery: TdSQLdbQuery;
    function GetUserList: TUserList;
    function GetUserLists: TopUserLists.TEntities;
  protected
    property IsWorker: Boolean read FIsWorker;
    property Query: TdSQLdbQuery read GetQuery;
  public
    procedure AddBulkMessage(aUserListID: Integer; out aBulkMessageID: Integer; const aText: String;
      const aMedia: String = ''; aMediaType: opBulkSend.TContentType = ctText; aHideButton: Boolean = True;
      aReplyMarkup: TReplyMarkup = nil);
    procedure AddBulkMessage(aUserListID: Integer; out aBulkMessageID: Integer;
      const aMessage: TTelegramMessageObj; aHideButton: Boolean = True;
      aReplyMarkup: TReplyMarkup = nil);
    procedure AddTask(aUsers: TStrings; out aBulkMessageID: Integer;
      const aMessage: TTelegramMessageObj; aHideButton: Boolean = True;
      aReplyMarkup: TReplyMarkup = nil);
    procedure AddUserList(out aUserListID: Integer; aUsers: TStrings = nil; const aName: String = '');
    procedure AddUsersToList(aUserListID: Integer; aUsers: TStrings);
    procedure Apply;
    function Con: TdSQLdbConnector;
    constructor Create(aIsWorker: Boolean = True);
    destructor Destroy; override;
    function GetBulkMessageByID(aID: Integer): TBulkMessage;
    function GetUserListByID(aID: Integer): TUserList;
    function LastInsertID: Integer;
    function ListBulkMessages: TopBulkMessages.TEntities;
    function ListTaskItems: TopTaskItems.TEntities;
    function ListUserLists: TopUserLists.TEntities;
    function ListTaskItems(aBulkMessageID: Integer; aLimit: Integer = 0;
      aOffset: Integer = 0): TopTaskItems.TEntities;
    procedure SaveBulkMessage;
    property BulkMessage: TBulkMessage read GetBulkMessage;
    property BulkMessages: TopBulkMessages.TEntities read GetBulkMessages;
    property Directory: String read FDirectory write FDirectory;
    property LogDebug: Boolean read FLogDebug write FLogDebug;
    property opBulkMessages: TopBulkMessages read GetopBulkMessages;
    property opSubscribers: TopSubscribers read GetopSubscribers;
    property opTaskItems: TopTaskItems read GetopTaskItems;
    property opUserLists: TopUserLists read GetopUserLists;
    property TaskItem: TTaskItem read GetTaskItem;
    property TaskItems: TopTaskItems.TEntities read GetTaskItems;
    property Subscriber: TSubscriber read GetSubscriber;
    property SubscribersQuery: TdSQLdbQuery read GetSubscribersQuery;
    property UserList: TUserList read GetUserList;
    property UserLists: TopUserLists.TEntities read GetUserLists;
  end;

function ContentFromMessage(aMessage: TTelegramMessageObj; out aText: String;
  out aMedia: String): opBulkSend.TContentType;

implementation

const
  // sql expressions
  sql_crttbl='CREATE TABLE IF NOT EXISTS %s (%s);';
  sql_blkmsgs='bulkmessages';
  sql_blkmsgs_flds='id INTEGER PRIMARY KEY AUTOINCREMENT, sender BIGINT, text TEXT, '
    +'replymarkup TEXT, userlist INTEGER, state INTEGER DEFAULT (0), media TEXT, mediacode INTEGER DEFAULT (0), '
    +'hidebutton BOOLEAN, buttonurl TEXT, buttonurltext TEXT, disablewebpagepreview BOOLEAN';
  sql_sbscrbrs='subscribers';
  sql_sbscrbrs_flds='userid BIGINT, userlist INTEGER, '+
    'PRIMARY KEY (userid, userlist) ON CONFLICT REPLACE';
  sql_tskitms='taskitems';
  sql_tskitms_flds='id INTEGER PRIMARY KEY AUTOINCREMENT, userid BIGINT, bulkmessage INTEGER, errorcode INTEGER, '
    +'errordescr  TEXT';
  sql_usrlsts='userlists';
  sql_usrlsts_flds='id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR (128), lastupdate DATETIME DEFAULT (0)';


function ContentFromMessage(aMessage: TTelegramMessageObj; out aText: String; out aMedia: String
  ): opBulkSend.TContentType;
begin
  Result:=opBulkSend.ctUnknown;
  aText:=aMessage.Text;
  if aText<>EmptyStr then
    Exit(ctText);
  aText:=aMessage.Caption;
  if Assigned(aMessage.Photo) then if (aMessage.Photo.Count>0) then
  begin
    aMedia:=aMessage.Photo.Last.FileID;
    Exit(ctPhoto);
  end;
  if Assigned(aMessage.Video) then
  begin
    aMedia:=aMessage.Video.FileID;
    Exit(ctVideo);
  end;
  if Assigned(aMessage.Voice) then
  begin
    aMedia:=aMessage.Voice.FileID;
    Exit(ctVoice);
  end;
  if Assigned(aMessage.Audio) then
  begin
    aMedia:=aMessage.Audio.FileID;
    Exit(ctAudio);
  end;
  if Assigned(aMessage.Document) then
  begin
    aMedia:=aMessage.Document.FileID;
    Exit(ctDocument);
  end;
end;


{ TBulkSenderDB }

function TBulkSenderDB.Con: TdSQLdbConnector;
var
  aDir: String;
begin
  if not Assigned(Fcon) then
  begin
    Fcon := TdSQLdbConnector.Create(nil);
    if FDirectory.IsEmpty then
      aDir:='./'
    else
      aDir:=IncludeTrailingPathDelimiter(FDirectory);
    Fcon.Database := aDir+'bulksender.sqlite3';
    Fcon.Driver := 'sqlite3';
    Fcon.Logger.Active := FLogDebug;
    if IsWorker then
      FCon.Logger.FileName:=aDir+'bulksender_sqlite3.log'
    else
      FCon.Logger.FileName := aDir+ClassName+'_sqlite3.log';
    CreateDB;
  end;
  Result := Fcon;
end;

constructor TBulkSenderDB.Create(aIsWorker: Boolean);
begin
  FIsWorker:=aIsWorker;
end;

destructor TBulkSenderDB.Destroy;
begin
  FQuery.Free;
  FopBulkMessages.Free;
  FopSubscribers.Free;
  FopTaskItems.Free;
  FopUserLists.Free;
  FBulkMessages.Free;
  FTaskItems.Free;
  FSubscribersQuery.Free;
  FUserLists.Free;
  FCon.Free;
  inherited Destroy;
end;

function TBulkSenderDB.GetBulkMessageByID(aID: Integer): TBulkMessage;
begin
  if BulkMessage.id<>aID then
  begin
    BulkMessage.id:=aID;
    if not opBulkMessages.Get then
      BulkMessage.Clear;
  end;
  Result:=BulkMessage;
end;

function TBulkSenderDB.GetUserListByID(aID: Integer): TUserList;
begin
  if UserList.id<>aID then
  begin
    UserList.id:=aID;
    if not opUserLists.Get then
      UserList.Clear;
  end;
  Result:=UserList;
end;

function TBulkSenderDB.GetBulkMessages: TopBulkMessages.TEntities;
begin
  if not Assigned(FBulkMessages) then
    FBulkMessages:=TopBulkMessages.TEntities.Create;
  Result:=FBulkMessages;
end;

procedure TBulkSenderDB.CreateDB;
var
  aQuery: TdSQLdbQuery;
begin
  aQuery:=TdSQLdbQuery.Create(Con);
  try
    aQuery.SQL.Add(Format(sql_crttbl, [sql_blkmsgs, sql_blkmsgs_flds]));
    aQuery.Execute;
    aQuery.SQL.Clear;
    aQuery.SQL.Add(Format(sql_crttbl, [sql_sbscrbrs, sql_sbscrbrs_flds]));
    aQuery.Execute; 
    aQuery.SQL.Clear;
    aQuery.SQL.Add(Format(sql_crttbl, [sql_tskitms, sql_tskitms_flds]));
    aQuery.Execute; 
    aQuery.SQL.Clear;
    aQuery.SQL.Add(Format(sql_crttbl, [sql_usrlsts, sql_usrlsts_flds]));
    aQuery.Execute;
    aQuery.Apply;
    aQuery.Close;
  finally
    aQuery.Free;
  end;
end;

function TBulkSenderDB.GetBulkMessage: TBulkMessage;
begin
  Result:=opBulkMessages.Entity;
end;

function TBulkSenderDB.GetopBulkMessages: TopBulkMessages;
begin
  if not Assigned(FopBulkMessages) then
  begin
    FopBulkMessages:=TopBulkMessages.Create(Con, 'bulkmessages');
    FopBulkMessages.Table.PrimaryKeys.Text:='id';
  end;
  Result:=FopBulkMessages;
end;

function TBulkSenderDB.GetopSubscribers: TopSubscribers;
begin
  if not Assigned(FopSubscribers) then
  begin
    FopSubscribers:=TopSubscribers.Create(Con, 'subscribers');
    FopSubscribers.Table.PrimaryKeys.Text:='id';
  end;
  Result:=FopSubscribers;
end;

function TBulkSenderDB.GetopTaskItems: TopTaskItems;
begin
  if not Assigned(FopTaskItems) then
  begin
    FopTaskItems:=TopTaskItems.Create(Con, 'taskitems');
    FopTaskItems.Table.PrimaryKeys.Text:='id';
  end;
  Result:=FopTaskItems;
end;

function TBulkSenderDB.GetopUserLists: TopUserLists;
begin
  if not Assigned(FopUserLists) then
  begin
    FopUserLists:=TopUserLists.Create(Con, 'userlists');
    FopUserLists.Table.PrimaryKeys.Text:='id';
  end;
  Result:=FopUserLists;
end;

function TBulkSenderDB.GetQuery: TdSQLdbQuery;
begin
  if not Assigned(FQuery) then
    FQuery:=TdSQLdbQuery.Create(Con);
  Result:=FQuery;
end;

function TBulkSenderDB.GetSubscriber: TSubscriber;
begin
  Result:=opSubscribers.Entity;
end;

function TBulkSenderDB.GetTaskItem: TTaskItem;
begin
  Result:=opTaskItems.Entity;
end;

function TBulkSenderDB.GetTaskItems: TopTaskItems.TEntities;
begin
  if not Assigned(FTaskItems) then
    FTaskItems:=TopTaskItems.TEntities.Create;
  Result:=FTaskItems;
end;

function TBulkSenderDB.GetSubscribersQuery: TdSQLdbQuery;
begin
  if not Assigned(FSubscribersQuery) then
    FSubscribersQuery:=TdSQLdbQuery.Create(Con);
  Result:=FSubscribersQuery;
end;

function TBulkSenderDB.GetUserList: TUserList;
begin
  Result:=opUserLists.Entity;
end;

function TBulkSenderDB.GetUserLists: TopUserLists.TEntities;
begin
  if not Assigned(FUserLists) then
    FUserLists:=TopUserLists.TEntities.Create;
  Result:=FUserLists;
end;

procedure TBulkSenderDB.AddBulkMessage(aUserListID: Integer; out aBulkMessageID: Integer; const aText: String;
  const aMedia: String; aMediaType: opBulkSend.TContentType; aHideButton: Boolean; aReplyMarkup: TReplyMarkup);
begin
  BulkMessage.Text:=aText;
  if Assigned(aReplyMarkup) then
    BulkMessage.ReplyMarkup:=aReplyMarkup.AsJSON
  else
    BulkMessage.ReplyMarkup:=EmptyStr;
  BulkMessage.HideButton:=aHideButton;
  BulkMessage.Media:=aMedia;
  BulkMessage.MediaType:=aMediaType;
  BulkMessage.UserList:=aUserListID;
  BulkMessage.BulkState:=bsReady;
  opBulkMessages.Add;
  aBulkMessageID:=LastInsertID;
  opBulkMessages.Apply;
end;

procedure TBulkSenderDB.AddBulkMessage(aUserListID: Integer; out
  aBulkMessageID: Integer; const aMessage: TTelegramMessageObj;
  aHideButton: Boolean; aReplyMarkup: TReplyMarkup);
var
  aMediaType: opBulkSend.TContentType;
  aText, aMedia: String;
begin
  aMediaType:=ContentFromMessage(aMessage, aText, aMedia);
  AddBulkMessage(aUserListID, aBulkMessageID, aText, aMedia, aMediaType, aHideButton, aReplyMarkup);
end;

procedure TBulkSenderDB.AddTask(aUsers: TStrings; out aBulkMessageID: Integer;
  const aMessage: TTelegramMessageObj; aHideButton: Boolean;
  aReplyMarkup: TReplyMarkup);
var
  aUserList: Integer;
begin
  AddUserList(aUserList, aUsers);
  AddBulkMessage(aUserList, aBulkMessageID, aMessage, aHideButton, aReplyMarkup);
end;

procedure TBulkSenderDB.AddUserList(out aUserListID: Integer; aUsers: TStrings;
  const aName: String);
var
  s: String;
  aUserID: int64;
begin
  UserList.name:=aName;
  UserList.LastUpdate:=Now;
  opUserLists.Add;
  aUserListID:=LastInsertID;
  opUserLists.Apply;
  if not Assigned(aUsers) then
    Exit;
  for s in aUsers do
  begin
    if TryStrToInt64(s, aUserID) then
    begin
      Subscriber.UserID:=aUserID;
      Subscriber.UserList:=aUserListID;
      opSubscribers.Add;
    end;
  end;
  opSubscribers.Apply;
end;

procedure TBulkSenderDB.AddUsersToList(aUserListID: Integer; aUsers: TStrings);
var
  s: String;
  aUserID: int64;
begin
  for s in aUsers do
  begin
    if TryStrToInt64(s, aUserID) then
    begin
      Subscriber.UserID:=aUserID;
      Subscriber.UserList:=aUserListID;
      opSubscribers.Add();
    end;
  end;
  opSubscribers.Apply;
  GetUserListByID(aUserListID).LastUpdate:=Now;
  opUserLists.Modify;
  opUserLists.Apply;
end;

procedure TBulkSenderDB.Apply;
begin
  FopBulkMessages.Apply;
  FopTaskItems.Apply;
end;

function TBulkSenderDB.LastInsertID: Integer;
begin
  Query.SQL.Text:='SELECT last_insert_rowid();';
  FQuery.Open;
  Result:=FQuery.Fields.Fields[0].AsInteger;
  FQuery.Close;
end;

function TBulkSenderDB.ListBulkMessages: TopBulkMessages.TEntities;
begin
  BulkMessages.Clear;
  opBulkMessages.List(FBulkMessages, nil, 'SELECT * FROM bulkmessages ORDER BY id DESC LIMIT 100');
  Result:=FBulkMessages;
end;

function TBulkSenderDB.ListTaskItems: TopTaskItems.TEntities;
begin
  TaskItems.Clear;
  opTaskItems.List(FTaskItems);
  Result:=FTaskItems;
end;

function TBulkSenderDB.ListUserLists: TopUserLists.TEntities;
begin
  UserLists.Clear;
  opUserLists.List(FUserLists, nil, 'SELECT * FROM userlists WHERE name<>""');
  Result:=FUserLists;
end;

function TBulkSenderDB.ListTaskItems(aBulkMessageID: Integer; aLimit: Integer;
  aOffset: Integer): TopTaskItems.TEntities;
var
  aSQL: String;
begin
  TaskItems.Clear;
  aSQL:='SELECT * FROM taskitems WHERE bulkmessage='+aBulkMessageID.ToString;
  if aLimit<>0 then
    aSQL+=' LIMIT '+aLimit.ToString;
  if aOffset<>0 then
    aSQL+=' OFFSET '+aOffset.ToString;
  opTaskItems.List(TaskItems, nil, aSQL);
  Result:=FTaskItems;
end;

procedure TBulkSenderDB.SaveBulkMessage;
begin
  opBulkMessages.Modify;
  opBulkMessages.Apply;
end;

end.

