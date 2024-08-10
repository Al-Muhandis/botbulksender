unit opBulkSend;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, tgsendertypes;

type

  { TBulkObject }

  TBulkObject = class
  public
    procedure Clear; virtual; abstract;
  end;

  { TBulkAutoInc }

  TBulkAutoInc = class(TBulkObject)
  private
    FID: Integer;
  published
    property ID: Integer read FID write FID;
  end;

  { TUserList }

  TUserList = class(TBulkAutoInc)
  private
    FLastUpdate: TDateTime;
    FName: String;
  public
    procedure Clear; override;
  published
    property name: String read FName write FName;
    property LastUpdate: TDateTime read FLastUpdate write FLastUpdate;
  end;

  { TSubscriber }

  TSubscriber = class(TBulkObject)
  private
    FUserID: Int64;
    FUserList: Integer;
  public
    procedure Clear; override;
  published
    property UserID: Int64 read FUserID write FUserID;
    property UserList: Integer read FUserList write FUserList;
  end;

  { TTaskItem }

  TTaskItem = class(TBulkAutoInc)
  private
    FBulkMessage: Integer;
    FErrorCode: Integer;
    FErrorDescr: String;
    FUserID: Int64;
  public
    procedure Clear; override;
  published
    property UserID: Int64 read FUserID write FUserID;
    property BulkMessage: Integer read FBulkMessage write FBulkMessage;
    property ErrorCode: Integer read FErrorCode write FErrorCode;
    property ErrorDescr: String read FErrorDescr write FErrorDescr;
  end;

  TBulkState = (bsReady, bsInProgress, bsDone);
  TContentType = (ctText, ctPhoto, ctVideo, ctAudio, ctVoice, ctDocument, ctUnknown);

  { TBulkMessage }

  TBulkMessage = class(TBulkAutoInc)
  private
    FButtonUrl: String;
    FButtonUrlText: String;
    FDisableWebPagePreview: Boolean;
    FHideButton: Boolean;
    FMedia: String;
    FMediaCode: Integer;
    FReplyMarkup: String;
    FSender: Int64;
    FState: Integer;
    FText: String;
    FUserList: Integer;
    function GetBulkState: TBulkState;
    function GetMediaType: TContentType;
    procedure SetBulkState(AValue: TBulkState);
    procedure SetMediaType(AValue: TContentType);
  public
    procedure Clear; override;
    property BulkState: TBulkState read GetBulkState write SetBulkState;
    property MediaType: TContentType read GetMediaType write SetMediaType;
  published
    property Sender: Int64 read FSender write FSender;
    property Text: String read FText write FText;
    property Media: String read FMedia write FMedia;
    property MediaCode: Integer read FMediaCode write FMediaCode;
    property ReplyMarkup: String read FReplyMarkup write FReplyMarkup;
    property UserList: Integer read FUserList write FUserList;
    property State: Integer read FState write FState;
    property HideButton: Boolean read FHideButton write FHideButton;
    property ButtonUrl: String read FButtonUrl write FButtonUrl;
    property ButtonUrlText: String read FButtonUrlText write FButtonUrlText;
    property DisableWebPagePreview: Boolean read FDisableWebPagePreview write FDisableWebPagePreview;
  end;

function BulkStateToString(aBulkState: TBulkState): String;
procedure SendEntityContent(aBot: TTelegramSender; aChatID: Int64; const aText, aMedia: String;
  aMediaType: TContentType; aParseMode: TParseMode; aDisableWebPagePreview: Boolean;
  aReplyMarkup: TReplyMarkup);

implementation

resourcestring
  s_TaskIsReady='Task is ready';
  s_TaskInProgress='Task in progress';
  s_TaskIsDone='Task is done';

function BulkStateToString(aBulkState: TBulkState): String;
begin
  case aBulkState of
    bsReady:      Result:=s_TaskIsReady;
    bsInProgress: Result:=s_TaskInProgress;
    bsDone:       Result:=s_TaskIsDone;
  else
    Result:=EmptyStr;
  end;
end;

procedure SendEntityContent(aBot: TTelegramSender; aChatID: Int64; const aText,
  aMedia: String; aMediaType: TContentType; aParseMode: TParseMode; aDisableWebPagePreview: Boolean;
  aReplyMarkup: TReplyMarkup);
begin
  case aMediaType of
    ctText:  aBot.sendMessage(aChatID, aText, aParseMode, aDisableWebPagePreview, aReplyMarkup);
    ctPhoto: aBot.sendPhoto(aChatID, aMedia, aText, aParseMode, aReplyMarkup);
    ctAudio: aBot.SendAudio(aChatID, aMedia, aText, aParseMode, 0, False, 0, EmptyStr, EmptyStr,
      aReplyMarkup);
    ctVideo: aBot.sendVideo(aChatID, aMedia, aText, aParseMode, aReplyMarkup);
    ctVoice: aBot.sendVoice(aChatID, aMedia, aText, aParseMode, 0, False, 0, aReplyMarkup);
    ctDocument: aBot.sendDocument(aChatID, aMedia, aText, aParseMode, False, 0, aReplyMarkup);
  end;
end;

{ TBulkMessage }

function TBulkMessage.GetBulkState: TBulkState;
begin
  Result:=TBulkState(FState);
end;

function TBulkMessage.GetMediaType: TContentType;
begin
  Result:=TContentType(FMediaCode);
end;

procedure TBulkMessage.SetBulkState(AValue: TBulkState);
begin
  FState:=Ord(AValue);
end;

procedure TBulkMessage.SetMediaType(AValue: TContentType);
begin
  FMediaCode:=Ord(AValue);
end;

procedure TBulkMessage.Clear;
begin
  FUserList:=0;
  FReplyMarkup:=EmptyStr;
  FText:=EmptyStr;
  FMedia:=EmptyStr;
  FSender:=0;
  BulkState:=bsReady;
  MediaType:=ctText;
  FHideButton:=True;
  FButtonUrl:=EmptyStr;
  FButtonUrlText:='Go to';
  FDisableWebPagePreview:=False;
end;

{ TTaskItem }

procedure TTaskItem.Clear;
begin
  FUserID:=0;
  FBulkMessage:=0;
  FErrorCode:=0;
  FErrorDescr:=EmptyStr;
end;

{ TSubscriber }

procedure TSubscriber.Clear;
begin
  FUserID:=0;
  FUserList:=0;
end;

{ TUserList }

procedure TUserList.Clear;
begin
  FName:=EmptyStr;
  FLastUpdate:=0;
end;

end.

