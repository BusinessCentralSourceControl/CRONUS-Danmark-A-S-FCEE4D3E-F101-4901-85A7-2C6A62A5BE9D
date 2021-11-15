Table 84650 "New Custom Report Layout"
{
    Caption = 'Custom Report Layout';
    DataPerCompany = false;
    DrillDownPageID = "Custom Report Layouts";
    LookupPageID = "Custom Report Layouts";
    Permissions = TableData "New Custom Report Layout" = rimd;

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
        }
        field(2; "Report ID"; Integer)
        {
            Caption = 'Report ID';
            TableRelation = AllObjWithCaption."Object ID" where("Object Type" = const(Report));
        }
        field(3; "Report Name"; Text[80])
        {
            CalcFormula = lookup(AllObjWithCaption."Object Caption" where("Object Type" = const(Report),
                                                                           "Object ID" = field("Report ID")));
            Caption = 'Report Name';
            Editable = false;
            FieldClass = FlowField;
        }
        field(4; "Company Name"; Text[30])
        {
            Caption = 'Company Name';
            TableRelation = Company;
        }
        field(6; Type; Option)
        {
            Caption = 'Type';
            InitValue = Word;
            OptionCaption = 'RDLC,Word';
            OptionMembers = RDLC,Word;
        }
        field(7; "Layout"; Blob)
        {
            Caption = 'Layout';
        }
        field(8; "Last Modified"; DateTime)
        {
            Caption = 'Last Modified';
            Editable = false;
        }
        field(9; "Last Modified by User"; Code[50])
        {
            Caption = 'Last Modified by User';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
            TableRelation = User."User Name";
            ValidateTableRelation = false;

            trigger OnLookup()
            var
                UserMgt: Codeunit "User Management";
            begin
                UserMgt.LookupUserID("Last Modified by User");
            end;
        }
        field(10; "File Extension"; Text[30])
        {
            Caption = 'File Extension';
            Editable = false;
        }
        field(11; Description; Text[250])
        {
            Caption = 'Description';
        }
        field(12; "Custom XML Part"; Blob)
        {
            Caption = 'Custom XML Part';
        }
        field(13; "App ID"; Guid)
        {
            Caption = 'App ID';
            Editable = false;
        }
        field(14; "Built-In"; Boolean)
        {
            Caption = 'Built-In';
            Editable = false;
        }
        field(15; "Layout Last Updated"; DateTime)
        {
            Caption = 'Last Modified';
            Editable = false;
        }
    }

    keys
    {
        key(Key1; "Code")
        {
            Clustered = true;
        }
        key(Key2; "Report ID", "Company Name", Type)
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Description)
        {
        }
    }

    trigger OnDelete()
    begin
        if "Built-In" then
            Error(DeleteBuiltInLayoutErr);
    end;

    trigger OnInsert()
    begin
        TestField("Report ID");
        if Code = '' then
            Code := GetDefaultCode("Report ID");
        SetUpdated;
    end;

    trigger OnModify()
    begin
        TestField("Report ID");
        SetUpdated;
    end;

    var
        ImportWordTxt: label 'Import Word Document';
        ImportRdlcTxt: label 'Import Report Layout';
        FileFilterWordTxt: label 'Word Files (*.docx)|*.docx', Comment = '{Split=r''\|''}{Locked=s''1''}';
        FileFilterRdlcTxt: label 'SQL Report Builder (*.rdl;*.rdlc)|*.rdl;*.rdlc', Comment = '{Split=r''\|''}{Locked=s''1''}';
        NoRecordsErr: label 'There is no record in the list.';
        BuiltInTxt: label 'Built-in layout';
        CopyOfTxt: label 'Copy of %1';
        NewLayoutTxt: label 'New layout';
        ErrorInLayoutErr: label 'The following issue has been found in the layout %1 for report ID  %2:\%3.', Comment = '%1=a name, %2=a number, %3=a sentence/error description.';
        TemplateValidationQst: label 'The RDLC layout does not comply with the current report design (for example, fields are missing or the report ID is wrong).\The following errors were detected during the layout validation:\%1\Do you want to continue?', Comment = '%1 = an error message.';
        TemplateValidationErr: label 'The RDLC layout does not comply with the current report design (for example, fields are missing or the report ID is wrong).\The following errors were detected during the document validation:\%1\You must update the layout to match the current report design.';
        AbortWithValidationErr: label 'The RDLC layout action has been canceled because of validation errors.';
        ModifyBuiltInLayoutQst: label 'This is a built-in custom report layout, and it cannot be modified.\\Do you want to modify a copy of the custom report layout instead?';
        NoLayoutSelectedMsg: label 'You must specify if you want to insert a Word layout or an RDLC layout for the report.';
        DeleteBuiltInLayoutErr: label 'This is a built-in custom report layout, and it cannot be deleted.';
        ModifyBuiltInLayoutErr: label 'This is a built-in custom report layout, and it cannot be modified.';

    local procedure SetUpdated()
    begin
        "Last Modified" := RoundDatetime(CurrentDatetime);
        "Last Modified by User" := UserId;
    end;


    procedure InitBuiltInLayout(ReportID: Integer; LayoutType: Option): Code[20]
    var
        CustomReportLayout: Record "Custom Report Layout";
        TempBlob: Record TempBlob;
        DocumentReportMgt: Codeunit "Document Report Mgt.";
        InStr: InStream;
        OutStr: OutStream;
    begin
        if ReportID = 0 then
            exit;

        CustomReportLayout.Init;
        CustomReportLayout."Report ID" := ReportID;
        CustomReportLayout.Type := LayoutType;
        CustomReportLayout.Description := CopyStr(StrSubstNo(CopyOfTxt, BuiltInTxt), 1, MaxStrLen(Description));
        CustomReportLayout."Built-In" := false;
        CustomReportLayout.Code := GetDefaultCode(ReportID);
        CustomReportLayout.Insert(true);

        case LayoutType of
            CustomReportLayout.Type::Word:
                begin
                    TempBlob.Blob.CreateOutstream(OutStr);
                    if not Report.WordLayout(ReportID, InStr) then begin
                        DocumentReportMgt.NewWordLayout(ReportID, OutStr);
                        CustomReportLayout.Description := CopyStr(NewLayoutTxt, 1, MaxStrLen(Description));
                    end else
                        CopyStream(OutStr, InStr);
                    CustomReportLayout.SetLayoutBlob(TempBlob);
                end;
            CustomReportLayout.Type::RDLC:
                if Report.RdlcLayout(ReportID, InStr) then begin
                    TempBlob.Blob.CreateOutstream(OutStr);
                    CopyStream(OutStr, InStr);
                    CustomReportLayout.SetLayoutBlob(TempBlob);
                end;
            else
                OnInitBuiltInLayout(CustomReportLayout, ReportID, LayoutType);
        end;

        CustomReportLayout.SetDefaultCustomXmlPart;
        CustomReportLayout.SetLayoutLastUpdated;

        exit(CustomReportLayout.Code);
    end;


    procedure CopyBuiltInLayout()
    var
        ReportLayoutLookup: Page "Report Layout Lookup";
        ReportID: Integer;
    begin
        FilterGroup(4);
        if GetFilter("Report ID") = '' then
            FilterGroup(0);
        if GetFilter("Report ID") <> '' then
            if Evaluate(ReportID, GetFilter("Report ID")) then
                ReportLayoutLookup.SetReportID(ReportID);
        FilterGroup(0);
        if ReportLayoutLookup.RunModal = Action::OK then begin
            if not ReportLayoutLookup.SelectedAddWordLayot and not ReportLayoutLookup.SelectedAddRdlcLayot then begin
                Message(NoLayoutSelectedMsg);
                exit;
            end;

            if ReportLayoutLookup.SelectedAddWordLayot then
                InitBuiltInLayout(ReportLayoutLookup.SelectedReportID, Type::Word);
            if ReportLayoutLookup.SelectedAddRdlcLayot then
                InitBuiltInLayout(ReportLayoutLookup.SelectedReportID, Type::RDLC);
        end;
    end;


    procedure GetCustomRdlc(ReportID: Integer) RdlcTxt: Text
    var
        ReportLayoutSelection: Record "Report Layout Selection";
        InStream: InStream;
        CustomLayoutCode: Code[20];
    begin
        // Temporarily selected layout for Design-time report execution?
        if ReportLayoutSelection.GetTempLayoutSelected <> '' then
            CustomLayoutCode := ReportLayoutSelection.GetTempLayoutSelected
        else  // Normal selection
            if ReportLayoutSelection.HasCustomLayout(ReportID) = 1 then
                CustomLayoutCode := ReportLayoutSelection."Custom Report Layout Code";

        if (CustomLayoutCode <> '') and Get(CustomLayoutCode) then begin
            TestField(Type, Type::RDLC);
            if UpdateLayout(true, false) then
                Commit; // Save the updated layout
            RdlcTxt := GetLayout;
        end else begin
            Report.RdlcLayout(ReportID, InStream);
            InStream.Read(RdlcTxt);
        end;

        OnAfterReportGetCustomRdlc(ReportID, RdlcTxt);
    end;


    procedure CopyRecord(): Code[20]
    var
        CustomReportLayout: Record "New Custom Report Layout";
        TempBlob: Record TempBlob;
    begin
        if IsEmpty then
            Error(NoRecordsErr);

        CalcFields(Layout, "Custom XML Part");
        CustomReportLayout := Rec;

        Description := CopyStr(StrSubstNo(CopyOfTxt, Description), 1, MaxStrLen(Description));
        Code := GetDefaultCode("Report ID");
        "Built-In" := false;
        //        OnCopyRecordOnBeforeInsertLayout(Rec,CustomReportLayout);
        Insert(true);

        if CustomReportLayout."Built-In" then begin
            CustomReportLayout.GetLayoutBlob(TempBlob);
            SetLayoutBlob(TempBlob);
        end;

        if not HasCustomXmlPart then
            SetDefaultCustomXmlPart;

        exit(Code);
    end;


    procedure ImportLayout(DefaultFileName: Text)
    var
        TempBlob: Record TempBlob;
        FileMgt: Codeunit "File Management";
        FileName: Text;
        FileFilterTxt: Text;
        ImportTxt: Text;
    begin
        if IsEmpty then
            Error(NoRecordsErr);

        if not CanBeModified then
            exit;

        case Type of
            Type::Word:
                begin
                    ImportTxt := ImportWordTxt;
                    FileFilterTxt := FileFilterWordTxt;
                end;
            Type::RDLC:
                begin
                    ImportTxt := ImportRdlcTxt;
                    FileFilterTxt := FileFilterRdlcTxt;
                end;
        end;

        //OnImportLayoutSetFileFilter(Rec,FileFilterTxt);
        FileName := FileMgt.BLOBImportWithFilter(TempBlob, ImportTxt, DefaultFileName, FileFilterTxt, FileFilterTxt);
        if FileName = '' then
            exit;

        ImportLayoutBlob(TempBlob, UpperCase(FileMgt.GetExtension(FileName)));
    end;


    procedure ImportLayoutBlob(var TempBlob: Record TempBlob; FileExtension: Text[30])
    var
        OutputTempBlob: Record TempBlob;
        DocumentReportMgt: Codeunit "Document Report Mgt.";
        DocumentInStream: InStream;
        DocumentOutStream: OutStream;
        ErrorMessage: Text;
        XmlPart: Text;
    begin
        // Layout is stored in the DocumentInStream (RDLC requires UTF8 encoding for which reason is stream is created in the case block.
        // Result is stored in the DocumentOutStream (..)
        TestField("Report ID");
        OutputTempBlob.Blob.CreateOutstream(DocumentOutStream);
        XmlPart := GetWordXmlPart("Report ID");

        case Type of
            Type::Word:
                begin
                    // Run update
                    TempBlob.Blob.CreateInstream(DocumentInStream);
                    ErrorMessage := DocumentReportMgt.TryUpdateWordLayout(DocumentInStream, DocumentOutStream, '', XmlPart);
                    // Validate the Word document layout against the layout of the current report
                    if ErrorMessage = '' then begin
                        CopyStream(DocumentOutStream, DocumentInStream);
                        DocumentReportMgt.ValidateWordLayout("Report ID", DocumentInStream, true, true);
                    end;
                end;
            Type::RDLC:
                begin
                    // Update the Rdlc document layout against the layout of the current report
                    TempBlob.Blob.CreateInstream(DocumentInStream, Textencoding::UTF8);
                    ErrorMessage := DocumentReportMgt.TryUpdateRdlcLayout("Report ID", DocumentInStream, DocumentOutStream, '', XmlPart, false);
                end;
        end;

        //OnImportLayoutBlob(Rec,TempBlob,FileExtension,XmlPart,DocumentOutStream);

        SetLayoutBlob(OutputTempBlob);

        if FileExtension <> '' then
            "File Extension" := FileExtension;
        SetDefaultCustomXmlPart;
        Modify(true);
        SetLayoutLastUpdated;
        Commit;

        if ErrorMessage <> '' then
            Message(ErrorMessage);
    end;


    procedure ExportLayout(DefaultFileName: Text; ShowFileDialog: Boolean): Text
    var
        TempBlob: Record TempBlob;
        FileMgt: Codeunit "File Management";
    begin
        // Update is needed in case of report layout mismatches word layout
        // Do not update build-in layout as it is read only
        if not "Built-In" then
            UpdateLayout(true, false); // Don't block on errors (return false) as we in all cases want to have an export file to edit.

        GetLayoutBlob(TempBlob);
        if not TempBlob.Blob.Hasvalue then
            exit('');

        if DefaultFileName = '' then
            DefaultFileName := '*.' + GetFileExtension;

        exit(FileMgt.BLOBExport(TempBlob, DefaultFileName, ShowFileDialog));
    end;


    procedure ValidateLayout(useConfirm: Boolean; UpdateContext: Boolean): Boolean
    var
        TempBlob: Record TempBlob;
        DocumentReportMgt: Codeunit "Document Report Mgt.";
        DocumentInStream: InStream;
        ValidationErrorFormat: Text;
    begin
        TestField("Report ID");
        GetLayoutBlob(TempBlob);
        if not TempBlob.Blob.Hasvalue then
            exit;

        TempBlob.Blob.CreateInstream(DocumentInStream);

        case Type of
            Type::Word:
                exit(DocumentReportMgt.ValidateWordLayout("Report ID", DocumentInStream, useConfirm, UpdateContext));
            Type::RDLC:
                if false then begin
                    if useConfirm then begin
                        if not Confirm(TemplateValidationQst, false, GetLastErrorText) then
                            Error(AbortWithValidationErr);
                    end else begin
                        ValidationErrorFormat := TemplateValidationErr;
                        Error(ValidationErrorFormat, GetLastErrorText);
                    end;
                    exit(false);
                end;
        end;

        exit(true);
    end;


    procedure UpdateLayout(ContinueOnError: Boolean; IgnoreDelete: Boolean): Boolean
    var
        ErrorMessage: Text;
    begin
        ErrorMessage := TryUpdateLayout(IgnoreDelete);

        if ErrorMessage = '' then begin
            if Type = Type::Word then
                exit(ValidateLayout(true, true));
            exit(true); // We have no validate for RDLC
        end;

        ErrorMessage := StrSubstNo(ErrorInLayoutErr, Description, "Report ID", ErrorMessage);
        if ContinueOnError then begin
            Message(ErrorMessage);
            exit(true);
        end;

        Error(ErrorMessage);
    end;


    procedure TryUpdateLayout(IgnoreDelete: Boolean): Text
    var
        InTempBlob: Record TempBlob;
        OutTempBlob: Record TempBlob;
        DocumentReportMgt: Codeunit "Document Report Mgt.";
        DocumentInStream: InStream;
        DocumentOutStream: OutStream;
        CurrentCustomXmlPart: Text;
        StoredCustomXmlPart: Text;
        ErrorMessage: Text;
    begin
        TestCustomXmlPart;
        TestField("Report ID");
        CurrentCustomXmlPart := GetWordXmlPart("Report ID");
        StoredCustomXmlPart := GetCustomXmlPart;

        if "Layout Last Updated" > "Last Modified" then
            if CurrentCustomXmlPart = StoredCustomXmlPart then
                exit('');

        if not InTempBlob.Blob.Hasvalue then
            exit('');

        InTempBlob.Blob.CreateInstream(DocumentInStream);

        case Type of
            Type::Word:
                begin
                    OutTempBlob.Blob.CreateOutstream(DocumentOutStream);
                    ErrorMessage := DocumentReportMgt.TryUpdateWordLayout(
                        DocumentInStream, DocumentOutStream, StoredCustomXmlPart, CurrentCustomXmlPart);
                end;
            Type::RDLC:
                begin
                    OutTempBlob.Blob.CreateOutstream(DocumentOutStream, Textencoding::UTF8);
                    ErrorMessage := DocumentReportMgt.TryUpdateRdlcLayout(
                        "Report ID", DocumentInStream, DocumentOutStream, StoredCustomXmlPart, CurrentCustomXmlPart, IgnoreDelete);
                end;
        end;

        SetCustomXmlPart(CurrentCustomXmlPart);

        if OutTempBlob.Blob.Hasvalue then
            SetLayoutBlob(OutTempBlob);

        SetLayoutLastUpdated;
        exit(ErrorMessage);
    end;

    local procedure GetWordXML(var TempBlob: Record TempBlob)
    var
        OutStr: OutStream;
    begin
        TestField("Report ID");
        TempBlob.Blob.CreateOutstream(OutStr, Textencoding::UTF16);
        OutStr.WriteText(Report.WordXmlPart("Report ID"));
    end;


    procedure ExportSchema(DefaultFileName: Text; ShowFileDialog: Boolean): Text
    var
        TempBlob: Record TempBlob;
        FileMgt: Codeunit "File Management";
    begin
        TestField(Type, Type::Word);

        if DefaultFileName = '' then
            DefaultFileName := '*.xml';

        GetWordXML(TempBlob);
        if TempBlob.Blob.Hasvalue then
            exit(FileMgt.BLOBExport(TempBlob, DefaultFileName, ShowFileDialog));
    end;


    procedure EditLayout()
    begin
        if CanBeModified then begin
            UpdateLayout(true, true); // Don't block on errors (return false) as we in all cases want to have an export file to edit.

            case Type of
                Type::Word:
                    Codeunit.Run(Codeunit::"Edit MS Word Report Layout", Rec);
                Type::RDLC:
                    Codeunit.Run(Codeunit::"Edit RDLC Report Layout", Rec);
            end;
        end;
    end;

    local procedure GetFileExtension() FileExt: Text[4]
    begin
        case Type of
            Type::Word:
                FileExt := 'docx';
            Type::RDLC:
                FileExt := 'rdl';
        //else
        //OnGetFileExtension(Rec,FileExt);
        end;
    end;

    procedure GetWordXmlPart(ReportID: Integer): Text
    var
        WordXmlPart: Text;
    begin
        // Store the current design as an extended WordXmlPart. This data is used for later updates / refactorings.
        WordXmlPart := Report.WordXmlPart(ReportID, true);
        exit(WordXmlPart);
    end;

    procedure RunCustomReport()
    var
        ReportLayoutSelection: Record "Report Layout Selection";
    begin
        if "Report ID" = 0 then
            exit;

        ReportLayoutSelection.SetTempLayoutSelected(Code);
        Report.RunModal("Report ID");
        ReportLayoutSelection.SetTempLayoutSelected('');
    end;



    local procedure FilterOnReport(ReportID: Integer)
    begin
        Reset;
        SetCurrentkey("Report ID", "Company Name", Type);
        SetFilter("Company Name", '%1|%2', '', StrSubstNo('@%1', COMPANYNAME));
        SetRange("Report ID", ReportID);
    end;

    procedure LookupLayoutOK(ReportID: Integer): Boolean
    begin
        FilterOnReport(ReportID);
        //OnLookupLayoutOKOnBeforePageRun(Rec);
        exit(Page.RunModal(Page::"Custom Report Layouts", Rec) = Action::LookupOK);
    end;

    procedure GetDefaultCode(ReportID: Integer): Code[20]
    var
        CustomReportLayout: Record "Custom Report Layout";
        NewCode: Code[20];
    begin
        CustomReportLayout.SetRange("Report ID", ReportID);
        CustomReportLayout.SetFilter(Code, StrSubstNo('%1-*', ReportID));
        if CustomReportLayout.FindLast then
            NewCode := IncStr(CustomReportLayout.Code)
        else
            NewCode := StrSubstNo('%1-000001', ReportID);

        exit(NewCode);
    end;


    procedure CanBeModified(): Boolean
    begin
        if not "Built-In" then
            exit(true);

        if not Confirm(ModifyBuiltInLayoutQst) then
            exit(false);

        CopyRecord;
        exit(true);
    end;



    procedure HasLayout(): Boolean
    begin
        if "Built-In" then
            exit(HasBuiltInLayout);
        exit(HasNonBuiltInLayout);
    end;

    procedure HasCustomXmlPart(): Boolean
    begin
        if "Built-In" then
            exit(HasBuiltInCustomXmlPart);
        exit(HasNonBuiltInCustomXmlPart);
    end;

    procedure GetLayout(): Text
    begin
        if "Built-In" then
            exit(GetBuiltInLayout);
        exit(GetNonBuiltInLayout);
    end;

    procedure GetCustomXmlPart(): Text
    begin
        if "Built-In" then
            exit(GetBuiltInCustomXmlPart);
        exit(GetNonBuiltInCustomXmlPart);
    end;

    procedure GetLayoutBlob(var TempBlob: Record TempBlob)
    var
        ReportLayout: Record "Report Layout";
    begin
        TempBlob.Init;
        if not "Built-In" then begin
            CalcFields(Layout);
            TempBlob.Blob := Layout;
        end else begin
            ReportLayout.Get(Code);
            ReportLayout.CalcFields(Layout);
            TempBlob.Blob := ReportLayout.Layout;
        end;
    end;

    procedure ClearLayout()
    begin
        if "Built-In" then
            Error(ModifyBuiltInLayoutErr);
        SetNonBuiltInLayout('');
    end;

    procedure ClearCustomXmlPart()
    begin
        if "Built-In" then
            Error(ModifyBuiltInLayoutErr);
        SetNonBuiltInCustomXmlPart('');
    end;

    local procedure CanModify(): Boolean
    var
        User: Record User;
    begin
        if not WritePermission then
            exit(false);
        if not User.Get(UserSecurityId) then
            exit(true);
        exit(User."License Type" <> User."license type"::"Limited User");
    end;

    procedure TestLayout()
    var
        ReportLayout: Record "Report Layout";
    begin
        if not "Built-In" then begin
            CalcFields(Layout);
            TestField(Layout);
            exit;
        end;
        ReportLayout.Get(Code);
        ReportLayout.CalcFields(Layout);
        ReportLayout.TestField(Layout);
    end;

    procedure TestCustomXmlPart()
    var
        ReportLayout: Record "Report Layout";
    begin
        if not "Built-In" then begin
            CalcFields("Custom XML Part");
            TestField("Custom XML Part");
            exit;
        end;
        ReportLayout.Get(Code);
        ReportLayout.CalcFields("Custom XML Part");
        ReportLayout.TestField("Custom XML Part");
    end;

    procedure SetLayout(Content: Text)
    begin
        if "Built-In" then
            Error(ModifyBuiltInLayoutErr);
        SetNonBuiltInLayout(Content);
    end;

    procedure SetCustomXmlPart(Content: Text)
    begin
        if "Built-In" then
            Error(ModifyBuiltInLayoutErr);
        SetNonBuiltInCustomXmlPart(Content);
    end;

    procedure SetDefaultCustomXmlPart()
    begin
        SetCustomXmlPart(GetWordXmlPart("Report ID"));
    end;

    procedure SetLayoutBlob(var TempBlob: Record TempBlob)
    begin
        if "Built-In" then
            Error(ModifyBuiltInLayoutErr);
        Clear(Layout);
        if TempBlob.Blob.Hasvalue then
            Layout := TempBlob.Blob;
        if CanModify then
            Modify;
    end;

    local procedure HasNonBuiltInLayout(): Boolean
    begin
        CalcFields(Layout);
        exit(Layout.Hasvalue);
    end;

    local procedure HasNonBuiltInCustomXmlPart(): Boolean
    begin
        CalcFields("Custom XML Part");
        exit("Custom XML Part".Hasvalue);
    end;

    local procedure HasBuiltInLayout(): Boolean
    var
        ReportLayout: Record "Report Layout";
    begin
        if not ReportLayout.Get(Code) then
            exit(false);

        ReportLayout.CalcFields(Layout);
        exit(ReportLayout.Layout.Hasvalue);
    end;

    local procedure HasBuiltInCustomXmlPart(): Boolean
    var
        ReportLayout: Record "Report Layout";
    begin
        if not ReportLayout.Get(Code) then
            exit(false);

        ReportLayout.CalcFields("Custom XML Part");
        exit(ReportLayout."Custom XML Part".Hasvalue);
    end;

    local procedure GetNonBuiltInLayout(): Text
    var
        InStr: InStream;
        Content: Text;
    begin
        CalcFields(Layout);
        if not Layout.Hasvalue then
            exit('');

        case Type of
            Type::RDLC:
                Layout.CreateInstream(InStr, Textencoding::UTF8);
            Type::Word:
                Layout.CreateInstream(InStr);
        // else
        //   OnGetNonBuiltInLayout(Rec,InStr);
        end;

        InStr.Read(Content);
        exit(Content);
    end;

    local procedure GetNonBuiltInCustomXmlPart(): Text
    var
        InStr: InStream;
        Content: Text;
    begin
        CalcFields("Custom XML Part");
        if not "Custom XML Part".Hasvalue then
            exit('');

        "Custom XML Part".CreateInstream(InStr, Textencoding::UTF16);
        InStr.Read(Content);
        exit(Content);
    end;

    local procedure GetBuiltInLayout(): Text
    var
        ReportLayout: Record "Report Layout";
        InStr: InStream;
        Content: Text;
    begin
        if not ReportLayout.Get(Code) then
            exit('');

        ReportLayout.CalcFields(Layout);
        if not ReportLayout.Layout.Hasvalue then
            exit('');

        if Type = Type::RDLC then
            ReportLayout.Layout.CreateInstream(InStr, Textencoding::UTF8)
        else
            ReportLayout.Layout.CreateInstream(InStr);

        InStr.Read(Content);
        exit(Content);
    end;

    local procedure GetBuiltInCustomXmlPart(): Text
    var
        ReportLayout: Record "Report Layout";
        InStr: InStream;
        Content: Text;
    begin
        if not ReportLayout.Get(Code) then
            exit('');

        ReportLayout.CalcFields("Custom XML Part");
        if not ReportLayout."Custom XML Part".Hasvalue then
            exit('');

        ReportLayout."Custom XML Part".CreateInstream(InStr, Textencoding::UTF16);
        InStr.Read(Content);
        exit(Content);
    end;

    local procedure SetNonBuiltInLayout(Content: Text)
    var
        OutStr: OutStream;
    begin
        Clear(Layout);
        if Content <> '' then begin
            if Type = Type::RDLC then
                Layout.CreateOutstream(OutStr, Textencoding::UTF8)
            else
                Layout.CreateOutstream(OutStr);
            OutStr.Write(Content);
        end;
        if CanModify then
            Modify;
    end;

    local procedure SetNonBuiltInCustomXmlPart(Content: Text)
    var
        OutStr: OutStream;
    begin
        Clear("Custom XML Part");
        if Content <> '' then begin
            "Custom XML Part".CreateOutstream(OutStr, Textencoding::UTF16);
            OutStr.Write(Content);
        end;
        if CanModify then
            Modify;
    end;


    procedure SetLayoutLastUpdated()
    begin
        "Layout Last Updated" := RoundDatetime(CurrentDatetime);

        if CanModify then
            Modify;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterReportGetCustomRdlc(ReportId: Integer; var RdlcText: Text)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnCopyRecordOnBeforeInsertLayout(var ToCustomReportLayout: Record "Custom Report Layout"; FromCustomReportLayout: Record "Custom Report Layout")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnGetNonBuiltInLayout(CustomReportLayout: Record "Custom Report Layout"; var InStream: InStream)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnGetFileExtension(CustomReportLayout: Record "Custom Report Layout"; var FileExt: Text[4])
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnImportLayoutBlob(CustomReportLayout: Record "Custom Report Layout"; var TempBlob: Record TempBlob temporary; FileExtension: Text[30]; XmlPart: Text; DocumentOutStream: OutStream)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnImportLayoutSetFileFilter(CustomReportLayout: Record "Custom Report Layout"; var FileFilterTxt: Text)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnInitBuiltInLayout(var CustomReportLayout: Record "Custom Report Layout"; ReportID: Integer; LayoutType: Option)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnLookupLayoutOKOnBeforePageRun(var CustomReportLayout: Record "Custom Report Layout")
    begin
    end;
}

