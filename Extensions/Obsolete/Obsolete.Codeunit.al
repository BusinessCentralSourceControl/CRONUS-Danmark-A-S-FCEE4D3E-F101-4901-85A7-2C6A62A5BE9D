codeunit 60000 Obsolete
{
    trigger OnRun()
    var
        language: Record Language;
        contact: Record Contact;
        cust: Record Customer;
        InStr: InStream;
    begin
        language.GetLanguageId('');
        contact.Picture.CreateInStream(InStr);
        contact.ChooseCustomerTemplate();
        with contact do begin
            Picture.CreateInStream(InStr);
        end;
    end;

    var
        myInt: Integer;
}