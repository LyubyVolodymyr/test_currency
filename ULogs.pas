unit ULogs;
// logger unit. one procedure that use one singleton object to write log file.
// Thread safe.

interface

type tLogType = (lt_Info, lt_Error, lt_Exception, lt_DebugInfo);

procedure Log(aLogType:TLogType; aLogMessage:String; const aAddInfo: array of string);

implementation

uses System.SysUtils, System.DateUtils, System.SyncObjs, System.IOUtils;

const cLogTypeText:array [tLogType] of string = ('Info','Error','Exception', 'DebugInfo');

const cLogFileName:String='App.log'; // just for example, can be changed according to software name, execution time or other parameters

// logger object is singleton
type
  TLogger = class(TObject)
    protected
      F_CS : TCriticalSection;

  public
    constructor Create;
    destructor Destroy; override;
    procedure Log(aLogType:TLogType; aLogMessage:String; const aAddInfo: array of string);
    procedure DBLog(aLogType:TLogType; aLogMessage:String; const aAddInfo: array of string);
  end;

var Global_Logger : TLogger = nil;

constructor TLogger.Create;
begin
  if Global_Logger <> nil then
    Abort
  else
    begin
      inherited Create;
      Global_Logger := Self;
      F_CS := TCriticalSection.Create;
    end;
end;

destructor TLogger.Destroy;
begin
  if Global_Logger = Self then
    Global_Logger := nil;
  FreeAndNil(F_CS);
  inherited Destroy;
end;



procedure TLogger.Log(aLogType:TLogType; aLogMessage:String; const aAddInfo: array of string);
var f:system.Text;
    lFileName : String;
    lStr : String;
  I: Integer;
begin
  F_CS.Enter;
  try
    lFileName := TPath.Combine(TPath.getDocumentsPath,cLogFileName);
    AssignFile(f,lFileName);
    try
        if FileExists(lFileName)
          then Append(f)
          else Rewrite(f);
      // one log event - one string with XML-style structure
      lStr :=
        '<TIME>'+DateToISO8601(Now,false)+'</TIME>'+
        '<EVENT_TYPE>'+cLogTypeText[aLogType]+'</EVENT_TYPE>'+
        '<MESSAGE>'+aLogMessage+'</MESSAGE>';
      for I := Low(aAddInfo) to High(aAddInfo) do
        lStr := lStr+ '<PARAM'+IntToStr(I)+'>'+aAddInfo[i]+'</PARAM'+IntToStr(I)+'>';
      Writeln(f, lStr);
    finally
      CloseFile(f);
    end;
  finally
    F_CS.Leave;
  end;
end;

procedure TLogger.DBLog(aLogType:TLogType; aLogMessage:String; const aAddInfo: array of string);
begin
  (*
   From the description of the task, I did not quite understand what should be stored in the database,
   and especially how/where other CRUD operations should be implemented except for inserting.
   I also don't have time to create a database, write the code for reading the configuration in the
   application (login/password/name of the database, etc.). Therefore, the principle actions for adding
   a record to the database will be presented here in a simplified form used FireDAC.


   // creating access objects and connection to the database
   lDatabase := TFDConnection.Create....
   lTransaction := TFDTransaction.Create;
   lQuery := TFDQuery.create;
   try
      try
        // connecting to the database
        lDatabase.Open(... parameters of connection)

        // staring transaction;
        lTransaction.StartTransaction;

        // inserting query; I assume that generation of IDs for records provided by triggers inside the database
        lQuery.SQL.text := 'insert into LOG_TABLE (event_type,event_str,event_add_info) values (:event_type,:event_str,:event_add_info)';
        lQuery.ParamByName('EventType').asInteger := Integer(aLogtype);
        .....
        lQuery.ExecSQL;

        // if all ok, no exception was raise, transaction must be commited
        lTransaction.Commit;
      except
        lTransaction.Rollback;
       // ..... other connection or operation exception handling
      end
   finally
     lDatabase.Free;
     lTransaction.Free;
     lQuery.Free;
   end;


  *)
end;


procedure Log(aLogType:TLogType; aLogMessage:String; const aAddInfo: array of string);
begin
  if not Assigned(Global_Logger) then TLogger.Create; // assignment is inside constructor of this singlton
  Global_Logger.Log(aLogType,aLogMessage,aAddInfo);
  if aLogType = lt_Info then // success convertion should be stored in the database
    Global_Logger.DBLog(aLogType,aLogMessage,aAddInfo);
end;



end.
