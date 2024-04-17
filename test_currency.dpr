program test_currency;

uses
  System.StartUpCopy,
  FMX.Forms,
  CCUnit in 'CCUnit.pas' {CurrencyConverter},
  ULogs in 'ULogs.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TCurrencyConverter, CurrencyConverter);
  Application.Run;
end.
