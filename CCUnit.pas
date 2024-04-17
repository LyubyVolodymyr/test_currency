unit CCUnit;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Edit, FMX.ListBox, FMX.Controls.Presentation, REST.Types, REST.Client,
  Data.Bind.Components, Data.Bind.ObjectScope;

const cAppId = 'qwoidasmjei'; // AppId for currency exchage service; !!! now not valid because I am not registered
      cBaseURL = 'https://openexchangerates.org/'; // base URL for exchange service portal

type TReqtype= (trq_CurrencyList,trq_Convert);

type
  TCurrencyConverter = class(TForm)
    Header: TToolBar;
    Footer: TToolBar;
    HeaderLabel: TLabel;
    Panel1: TPanel;
    cbFrom: TComboBox;
    edFrom: TEdit;
    Panel2: TPanel;
    cbTo: TComboBox;
    edTo: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    RESTClient1: TRESTClient;
    RESTRequest1: TRESTRequest;
    RESTResponse1: TRESTResponse;
    procedure FormCreate(Sender: TObject);
    procedure edFromChange(Sender: TObject);
  private
    { Private declarations }
    FCurrencyList : TStringList;
    procedure GetCurrencyList;
    function  ParseCurrencyList:Boolean;
    function  ParseConvertResult:Boolean;
    procedure SetErrorState(aMainText, aHelpText:String);
    procedure SetComboBoxItems(aCB:TComboBox);
    function ExecRequest(aReqType:TReqtype; const aParams:array of String):Boolean;
  public
    { Public declarations }
    destructor Destroy; override;
  end;

var
  CurrencyConverter: TCurrencyConverter;

implementation
uses ULogs, System.JSON;

{$R *.fmx}

procedure TCurrencyConverter.FormCreate(Sender: TObject);
begin
  FCurrencyList := TStringList.Create;
  GetCurrencyList;
end;

destructor TCurrencyConverter.Destroy;
begin
  if Assigned(FCurrencyList) then FreeAndNil(FCurrencyList);
  inherited;
end;

// loading of available currency list at app starting
procedure TCurrencyConverter.GetCurrencyList;
begin
  FCurrencyList.Clear;
  if ExecRequest(trq_CurrencyList,[]) then
  begin
    SetErrorState('',''); // No error
    SetComboBoxItems(cbFrom); // move list of available currencies to ComoBoxes
    SetComboBoxItems(cbTo);
  end else
  begin
    Log(lt_Error,'Get currency list equest error',[]);
    SetErrorState('No connection to internet','Please check network');
  end;

end;


// cheching, parsing of converting result and assignment to result view component
function TCurrencyConverter.ParseConvertResult:boolean;
var
    JV, Resp_value: TJSONValue;
begin
  Result := false;
  try
    JV := RESTResponse1.JSONValue;
    if Assigned(JV) then
    begin
      Resp_value := JV.FindValue('response');
      if Assigned(Resp_value) then
        edTo.Text := Resp_value.Value;
    end;

  except
    on E:Exception do
    begin
      Log(lt_Exception,e.Message,[]);
      Result := false;
    end;
  end;
end;

// parsing of query result of available currency list
function  TCurrencyConverter.ParseCurrencyList():boolean;
var   I: Integer;
      JV: TJSONValue;
      lName, lDescription: String;
begin
  Result := false;
  try
    JV := RESTResponse1.JSONValue;
    if Assigned(JV) then
      with (JV as TJSONObject) do
      begin
        for I := 0 to Count - 1 do
        begin
          lName := Pairs[I].JsonString.Value;
          lDescription := Pairs[I].JsonValue.Value;
          FCurrencyList.AddPair(lName,lDescription);
        end;
        Result := Count>0;
        if not result then
          Log(lt_Error,'Empty answer from rerver',[]);
      end
    else
      Log(lt_Error,'Wrong (non parsable) answer from rerver',[]);
  except
    on E:Exception do
    begin
      Log(lt_Exception,e.Message,[]);
      Result := false;
    end;
  end;
end;

// set error message in the bottom of screen; clear if no errors
procedure TCurrencyConverter.SetErrorState(aMainText, aHelpText:String);
begin
  Label1.Text := aMainText;
  Label2.Text := aHelpText;
  Label1.Visible := aMainText<>'';
  Label2.Visible := aHelpText<>'';
end;

// loading list of available curencies into ComboBoxes
procedure TCurrencyConverter.SetComboBoxItems(aCB:TComboBox);
var
  lIndex, I: Integer;
begin
  aCB.Items.Clear;
  for I := 0 to FCurrencyList.Count-1 do
  begin
    lIndex := aCB.Items.Add(FCurrencyList.Names[I]);
    aCB.ListItems[lIndex].ItemData.Detail :=
      FCurrencyList.Values[FCurrencyList.Names[I]];
  end;
end;

// executing queries
function TCurrencyConverter.ExecRequest(aReqType:TReqtype; const aParams:array of String):Boolean;
begin

  Result := false;
  try
    RESTRequest1.Params.Clear;
    RESTClient1.BaseURL := cBaseURL;
    RESTRequest1.Method := rmGET;

    // prepare query request (params)
    case aReqType of
    trq_CurrencyList:
      RESTRequest1.Resource := 'api/currencies.json';
    trq_Convert:
      begin
        RESTRequest1.Resource := '/api/convert/'+aParams[0]+'/'+aParams[1]+'/'+aParams[2];
        RESTRequest1.Body.ClearBody;
        RESTRequest1.Body.Add('{app_id: '''+cAppId+'''}',ctAPPLICATION_JSON);
      end;
    end;

    RESTRequest1.Execute;
    if RESTResponse1.StatusCode = 200 then
    begin
      case aReqType  of
        trq_CurrencyList : result := ParseCurrencyList;
        trq_Convert : result := ParseConvertResult;
      end;
    end else
      log(lt_Error,'REST request error. HTTP status code:'+IntToStr(RESTResponse1.StatusCode),[]);

  except
    on E:Exception do
    begin
      Log(lt_Exception,e.Message,[]);
      Result := false;
    end;
  end;
end;

procedure TCurrencyConverter.edFromChange(Sender: TObject);
begin
  if (cbFrom.ItemIndex>=0) and // From currency is selected
     (cbTo.ItemIndex>=0) and // To currency is selected
     (edFrom.Text<>'')         // Some value is entered
     then
  begin
    // try to convert; to avoid stucking during process request,
    // we can do this in the separate thread
    TThread.CreateAnonymousThread(
      procedure ()
      var lValue, lFromCurrency, lToCurrency: String;
      begin
        lValue := edFrom.Text;
        lFromCurrency := cbFrom.ListItems[cbFrom.ItemIndex].ItemData.Text;
        lToCurrency   := cbTo.ListItems[cbTo.ItemIndex].ItemData.Text;
        if not ExecRequest(trq_Convert,
          [lValue, lFromCurrency, lToCurrency]) then
        begin
          Log(lt_Error,'Convertion request error',[]);
          SetErrorState('No connection','Please check network');
        end else
        begin
          Log(lt_Info,'Success convertion',[lValue, lFromCurrency, lToCurrency]);
        end;
      end).Resume;
  end;
end;

end.

