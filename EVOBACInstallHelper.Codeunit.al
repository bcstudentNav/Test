codeunit 71129973 EVO_BAC_InstallHelper
{
    // Installation Helper functions for BACS Payment Exports
    //
    // Various helper functions used during installations (both core and expansions) to allow setting 
    // up various aspects of Data Exchange Definitions easily.

    var
        UnableToCreateRecordErr: Label 'Unable to create/modify %1 for %2.', Comment = '%1 = Table Caption, %2 = Data. Exch. Definition Code.';
        UnableToModifyRecordErr: Label 'Unable to modify %1 for Data Exchange Definition %2, Line Def. Code %3.', Comment = '%1 = Table Caption, %2 = Data Exch. Definition Code, %3 = Line Def. Code.';

    #region Helper methods    

    /// <summary>
    /// Creates a new Payment Method.
    /// </summary>    
    /// <param name="NewCode">The code for the new payment method.</param>
    /// <param name="NewName">The name for the new payment method.</param>
    /// <param name="DataExchDefLineCode">The code for the Data Exchange Definition line. This will be repeated for each transaction on the journal during the export.</param>

    procedure CreatePaymentMethod(NewCode: Code[10]; NewName: Text[100]; DataExchDefLineCode: Code[20])
    var
        PaymentMethod: Record "Payment Method";
    begin
        if PaymentMethod.Get(NewCode) then
            exit;

        PaymentMethod.Init();
        PaymentMethod.Validate(Code, NewCode);
        PaymentMethod.Validate(Description, NewName);
        PaymentMethod.Validate("Pmt. Export Line Definition", DataExchDefLineCode);

        if not PaymentMethod.Insert(true) then
            Error(UnableToCreateRecordErr, PaymentMethod.TableCaption(), NewCode);
    end;

    /// <summary>
    /// Creates a new Bank Export/Import Setup.
    /// </summary>    
    /// <param name="NewCode">The code for the new bank export/import setup.</param>
    /// <param name="NewName">The name for the new bank export/import setup.</param>
    /// <param name="DataExchDefCode">The code for the Data Exchange Definition associated with the format.</param>    
    /// <param name="ProcessingCodeunit">The ID of the processing codeunit for the format.</param>    
    /// <param name="PaymentExportNoSeries">The code for a number series, if one is required for the format.</param>    
    /// <param name="EVOEFFBACSFormat">The enum value identifying the format.</param>    
    /// <param name="Info">Module info for the application creating the format. This data will be recorded against the bank export/import setup.</param>    

    procedure CreateBankExportImportSetup(NewCode: Code[20]; NewName: Text[100]; DataExchDefCode: Text[20]; ProcessingCodeunit: Integer; PaymentExportNoSeries: Code[20]; EVOEFFBACSFormat: Enum EVO_BAC_Format; Info: ModuleInfo)
    var
        BankExportImportSetup: Record "Bank Export/Import Setup";
        DataExchDef: Record "Data Exch. Def";
        InstallHelper: Codeunit EVO_BAC_InstallHelper;
    begin
        if BankExportImportSetup.Get(NewCode) then
            exit;

        BankExportImportSetup.Init();
        BankExportImportSetup.Validate(Code, NewCode);
        BankExportImportSetup.Validate(Name, NewName);
        BankExportImportSetup.Validate(Direction, BankExportImportSetup.Direction::Export);
        BankExportImportSetup.Validate("Processing Codeunit ID", ProcessingCodeunit);
        BankExportImportSetup.Validate("Data Exch. Def. Code", DataExchDefCode);
        BankExportImportSetup.Validate(EVO_BAC_PaymentExportNos, PaymentExportNoSeries);
        BankExportImportSetup.Validate(EVO_BAC_Format, EVOEFFBACSFormat);
        BankExportImportSetup.Validate(EVO_BAC_FormatAppVersion, InstallHelper.FormatAppVersion(Info.AppVersion));
        BankExportImportSetup.Validate(EVO_BAC_FormatActiveDate, Today());
        BankExportImportSetup.Validate(EVO_BAC_FormatSetupID, TransformGuid(Info.Id, false));
        BankExportImportSetup.Validate(EVO_BAC_FormatActivationType, BankExportImportSetup.EVO_BAC_FormatActivationType::DataExchange);

        if not BankExportImportSetup.Insert(true) then
            Error(UnableToCreateRecordErr, BankExportImportSetup.TableCaption(), NewCode);

        DataExchDef.Get(DataExchDefCode);
        DataExchDef.Validate(EVO_BAC_Format, BankExportImportSetup.EVO_BAC_Format);
        DataExchDef.Validate(EVO_BAC_FormatSetupID, BankExportImportSetup.EVO_BAC_FormatSetupID);
        DataExchDef.Modify(true);
    end;

    /// <summary>
    /// Creates a new Bank Export/Import Setup.
    /// </summary>    
    /// <param name="NewCode">The code for the new bank export/import setup.</param>
    /// <param name="NewName">The name for the new bank export/import setup.</param>
    /// <param name="ProcessingCodeunit">The ID of the processing codeunit for the format.</param>    
    /// <param name="ProcessingXMLPort">The ID of the processing XMLport for the format.</param>    
    /// <param name="CheckExportCodeunit">The ID of the check export codeunit for the format.</param> 
    /// <param name="PaymentExportNoSeries">The code for a number series, if one is required for the format.</param>       
    /// <param name="EVOEFFBACSFormat">The enum value identifying the format.</param>    
    /// <param name="Info">Module info for the application creating the format. This data will be recorded against the bank export/import setup.</param>    

    procedure CreateBankExportImportSetup(NewCode: Code[20]; NewName: Text[100]; ProcessingCodeunit: Integer; ProcessingXMLPort: Integer; CheckExportCodeunit: Integer; PaymentExportNoSeries: Code[20]; EVOEFFBACSFormat: Enum EVO_BAC_Format; Info: ModuleInfo)
    var
        BankExportImportSetup: Record "Bank Export/Import Setup";
        InstallHelper: Codeunit EVO_BAC_InstallHelper;
    begin
        if BankExportImportSetup.Get(NewCode) then
            exit;

        BankExportImportSetup.Init();
        BankExportImportSetup.Validate(Code, NewCode);
        BankExportImportSetup.Validate(Name, NewName);
        BankExportImportSetup.Validate(Direction, BankExportImportSetup.Direction::Export);
        BankExportImportSetup.Validate("Processing Codeunit ID", ProcessingCodeunit);
        BankExportImportSetup.Validate("Processing XMLport ID", ProcessingXMLPort);
        BankExportImportSetup.Validate("Check Export Codeunit", CheckExportCodeunit);
        BankExportImportSetup.Validate(EVO_BAC_PaymentExportNos, PaymentExportNoSeries);
        BankExportImportSetup.Validate(EVO_BAC_Format, EVOEFFBACSFormat);
        BankExportImportSetup.Validate(EVO_BAC_FormatAppVersion, InstallHelper.FormatAppVersion(Info.AppVersion));
        BankExportImportSetup.Validate(EVO_BAC_FormatActiveDate, Today());
        BankExportImportSetup.Validate(EVO_BAC_FormatSetupID, TransformGuid(Info.Id, false));
        BankExportImportSetup.Validate(EVO_BAC_FormatActivationType, BankExportImportSetup.EVO_BAC_FormatActivationType::XMLPort);
        BankExportImportSetup.Validate("Preserve Non-Latin Characters", false);

        if not BankExportImportSetup.Insert(true) then
            Error(UnableToCreateRecordErr, BankExportImportSetup.TableCaption(), NewCode);
    end;

    /// <summary>
    /// Creates a new No. Series.
    /// </summary>    
    /// <param name="NewCode">The code for the new number series.</param>
    /// <param name="NewDescription">The description for the new number series.</param>
    /// <param name="StartingNo">The starting number for the new number series.</param>    
    /// <param name="EndingNo">The ending number for the new number series.</param>    
    /// <param name="WarningNo">The warning number for the new number series.</param> 

    procedure CreateNoSeries(NewCode: Code[20]; NewDescription: Text[100]; StartingNo: Code[20]; EndingNo: Code[20]; WarningNo: Code[20])
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        if NoSeries.Get(NewCode) then
            exit;

        NoSeries.Init();
        NoSeries.Validate(Code, NewCode);
        NoSeries.Validate(Description, NewDescription);
        NoSeries.Validate("Default Nos.", true);
        NoSeries.Insert(true);

        NoSeriesLine.Init();
        NoSeriesLine.Validate("Series Code", NewCode);
        NoSeriesLine.Validate("Line No.", 10000);
        NoSeriesLine.Validate("Starting No.", StartingNo);
        NoSeriesLine.Validate("Ending No.", EndingNo);
        NoSeriesLine.Validate("Warning No.", WarningNo);
        NoSeriesLine.Insert(true)
    end;

    /// <summary>
    /// Sets various additional fields on a Data Exchange Definition.
    /// </summary>    
    /// <param name="DataExchDefCode">The code for the data exchange definition.</param>
    /// <param name="DataHandlingCodeunit">The ID for the data handling codeunit for the format.</param>
    /// <param name="ValidationCodeunit">The ID for the validation codeunit for the format.</param>    
    /// <param name="ReadingWritingCodeunit">The ID for the reading/writing codeunit for the format.</param>    
    /// <param name="ExtDataHandlingCodeunit">The ID for the ext. data handling codeunit for the format.</param> 
    /// <param name="UserFeedbackCodeunit">The ID for the user feedback codeunit for the format.</param> 

    procedure SetDataExchDefSettings(DataExchDefCode: Code[20]; DataHandlingCodeunit: Integer; ValidationCodeunit: Integer; ReadingWritingCodeunit: Integer; ExtDataHandlingCodeunit: Integer; UserFeedbackCodeunit: Integer)
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        if not DataExchDef.Get(DataExchDefCode) then
            Error(UnableToCreateRecordErr, DataExchDef.TableCaption(), DataExchDefCode);

        DataExchDef.Validate("Data Handling Codeunit", DataHandlingCodeunit);
        DataExchDef.Validate("Validation Codeunit", ValidationCodeunit);
        DataExchDef.Validate("Reading/Writing Codeunit", ReadingWritingCodeunit);
        DataExchDef.Validate("Ext. Data Handling Codeunit", ExtDataHandlingCodeunit);
        DataExchDef.Validate("User Feedback Codeunit", UserFeedbackCodeunit);
        DataExchDef.Modify(true);
    end;

    /// <summary>
    /// Sets various additional fields on a Data Exchange Definition Line.
    /// </summary>    
    /// <param name="DataExchDefCode">The code for the data exchange definition.</param>
    /// <param name="DataExchLineDefCode">The code for the data exchange definition line.</param>
    /// <param name="NewLineType">The line type to apply to the data exchange definition line.</param>    

    procedure SetDataExchLineDefSettings(DataExchDefCode: Code[20]; DataExchLineDefCode: Code[20]; NewLineType: Option Detail,Header,Footer)
    var
        DataExchLineDef: Record "Data Exch. Line Def";
    begin
        if not DataExchLineDef.Get(DataExchDefCode, DataExchLineDefCode) then
            Error(UnableToModifyRecordErr, DataExchLineDef.TableCaption(), DataExchDefCode, DataExchLineDefCode);

        DataExchLineDef.Validate("Line Type", NewLineType);
        DataExchLineDef.Modify(true);
    end;

    /// <summary>
    /// Sets various additional fields on a Data Exchange Definition Column.
    /// </summary>    
    /// <param name="DataExchDefCode">The code for the data exchange definition.</param>
    /// <param name="DataExchLineDefCode">The code for the data exchange definition line.</param>
    /// <param name="ColumnNo">The number of the data exchange definition column.</param>    
    /// <param name="TextPaddingRequired">The value to apply to text padding required on the data exchange definition column.</param>    
    /// <param name="PadCharacter">The pad character to apply to the data exchange definition column.</param>    
    /// <param name="Justification">The justification type to apply to the data exchange definition column.</param>    

    procedure SetDataExchColumnDefSettings(DataExchDefCode: Code[20]; DataExchLineDefCode: Code[20]; ColumnNo: Integer; TextPaddingRequired: Boolean; PadCharacter: Text[1]; Justification: Option Right,Left)
    var
        DataExchColumnDef: Record "Data Exch. Column Def";
    begin
        if not DataExchColumnDef.Get(DataExchDefCode, DataExchLineDefCode, ColumnNo) then
            Error(UnableToModifyRecordErr, DataExchColumnDef.TableCaption(), DataExchDefCode, DataExchLineDefCode);

        DataExchColumnDef.Validate("Text Padding Required", TextPaddingRequired);
        DataExchColumnDef.Validate("Pad Character", PadCharacter);
        DataExchColumnDef.Validate(Justification, Justification);
        DataExchColumnDef.Modify(true);
    end;

    /// <summary>
    /// Sets various additional fields on a Data Exchange Definition Mapping.
    /// </summary>    
    /// <param name="DataExchDefCode">The code for the data exchange definition.</param>
    /// <param name="DataExchLineDefCode">The code for the data exchange definition line.</param>
    /// <param name="TableID">The ID of the table for the data exchange definition mapping.</param>    
    /// <param name="PreMappingCodeunit">The ID for the pre mapping codeunit for the format.</param>    
    /// <param name="PostMappingCodeunit">The ID for the post mapping codeunit for the format.</param>    

    procedure SetDataExchMappingSettings(DataExchDefCode: Code[20]; DataExchLineDefCode: Code[20]; TableID: Integer; PreMappingCodeunit: Integer; PostMappingCodeunit: Integer)
    var
        DataExchMapping: Record "Data Exch. Mapping";
    begin
        if not DataExchMapping.Get(DataExchDefCode, DataExchLineDefCode, TableID) then
            Error(UnableToModifyRecordErr, DataExchMapping.TableCaption(), DataExchDefCode, DataExchLineDefCode);

        DataExchMapping.Validate("Pre-Mapping Codeunit", PreMappingCodeunit);
        DataExchMapping.Validate("Post-Mapping Codeunit", PostMappingCodeunit);
        DataExchMapping.Modify(true);
    end;

    /// <summary>
    /// Sets various additional fields on a Data Exchange Definition Field Mapping.
    /// </summary>    
    /// <param name="DataExchDefCode">The code for the data exchange definition.</param>
    /// <param name="DataExchLineDefCode">The code for the data exchange definition line.</param>
    /// <param name="TableID">The ID of the table for the data exchange definition mapping.</param>    
    /// <param name="ColumnID">The number of the data exchange definition column.</param>    
    /// <param name="FieldID">The number of the field for the data exchange definition mapping.</param>    
    /// <param name="Optional">The value to apply to the optional pad character on the data exchange definition field mapping.</param>    
    /// <param name="TransformationRuleCode">The code for the transformation rule to apply to the data exchange definition field mapping.</param>    

    procedure SetDataExchFieldMappingSettings(DataExchDefCode: Code[20]; DataExchLineDefCode: Code[20]; TableID: Integer; ColumnID: Integer; FieldID: Integer; Optional: Boolean; TransformationRuleCode: Code[20])
    var
        DataExchFieldMapping: Record "Data Exch. Field Mapping";
    begin
        if not DataExchFieldMapping.Get(DataExchDefCode, DataExchLineDefCode, TableID, ColumnID, FieldID) then
            Error(UnableToModifyRecordErr, DataExchFieldMapping.TableCaption(), DataExchDefCode, DataExchLineDefCode);

        DataExchFieldMapping.Validate(Optional, Optional);
        DataExchFieldMapping.Validate("Transformation Rule", TransformationRuleCode);
        DataExchFieldMapping.Modify(true);
    end;

    #endregion
    #region Management UI methods

    /// <summary>
    /// Checks if a format code is in use on a payment method, data exchange definition or bank export/import setup.
    /// </summary>    
    /// <param name="FormatCode">The format code to check.</param>    
    /// <returns>Boolean value indicating whether or not the the format code is already in use.</returns>

    internal procedure IsFormatCodeUsed(FormatCode: Code[10]): Boolean
    var
        PaymentMethod: Record "Payment Method";
        BankExportImportSetup: Record "Bank Export/Import Setup";
        DataExchDef: Record "Data Exch. Def";
    begin
        PaymentMethod.SetRange(Code, FormatCode);
        if not PaymentMethod.IsEmpty() then
            exit(true);

        BankExportImportSetup.SetRange(Code, FormatCode);
        if not BankExportImportSetup.IsEmpty() then
            exit(true);

        DataExchDef.SetRange(Code, FormatCode);
        if not DataExchDef.IsEmpty() then
            exit(true);

        exit(false);
    end;

    /// <summary>
    /// Activates a format after prompting for a format code to use.
    /// </summary>    
    /// <param name="Format">The enum of the format to activate.</param>    

    internal procedure ActivateFormat(Format: Enum EVO_BAC_Format)
    var
        BankExportImportSetup: Record "Bank Export/Import Setup";
        ActivateBACSFormat: Page EVO_BAC_ActivateBACSFormat;
        FormatInterface: Interface EVO_BAC_Format;
        FormatCode: Code[10];

        CatchAllErr: Label 'Unable to activate ''%1''. Please check that the application is properly installed.', Comment = '%1 = Format';
    begin
        Clear(ActivateBACSFormat);
        ActivateBACSFormat.LookupMode(true);
        if not (ActivateBACSFormat.RunModal() in [Action::OK, Action::LookupOK]) then
            exit;
        if ActivateBACSFormat.GetInputValue() = '' then
            exit;

        FormatInterface := Format;
        FormatCode := ActivateBACSFormat.GetInputValue();
        FormatInterface.CreateFormat(FormatCode);

        // Catch all check.
        //
        if not BankExportImportSetup.Get(FormatCode) then
            Error(CatchAllErr, Format);
    end;

    /// <summary>
    /// Removes an activated format from the system, deleting the payment method, data exchange definition and bank export/import setup, as needed.
    /// </summary>    
    /// <param name="FormatCode">The format code to check.</param>    

    internal procedure DeactivateFormat(FormatCode: Code[10])
    begin
        DeactivateFormat(FormatCode, true);
    end;

    /// <summary>
    /// Removes an activated format from the system, deleting the payment method, data exchange definition and bank export/import setup, as needed.
    /// </summary>    
    /// <param name="FormatCode">The format code to check.</param>    
    /// <param name="CheckDependencies">Specifies whether to check for bank accounts or customers using the format.</param>    

    internal procedure DeactivateFormat(FormatCode: Code[10]; CheckDependencies: Boolean)
    var
        PaymentMethod: Record "Payment Method";
        BankExportImportSetup: Record "Bank Export/Import Setup";
        DataExchDef: Record "Data Exch. Def";
        Customer: Record Customer;
        BankAccount: Record "Bank Account";
        ActivationType: Enum EVO_BAC_ActivationType;

        CannotDeleteErr: Label 'Cannot delete %1 because it is in use on at least one %2.', Comment = '%1 = Table caption, %2 = Table caption in use.';
    begin
        BankExportImportSetup.Get(FormatCode);
        ActivationType := BankExportImportSetup.EVO_BAC_FormatActivationType;

        // Delete Bank Export/Import Setup.
        //
        if CheckDependencies then begin
            BankAccount.SetRange("Payment Export Format", FormatCode);
            if not BankAccount.IsEmpty() then
                Error(CannotDeleteErr, BankExportImportSetup.TableCaption(), BankAccount.TableCaption());
        end;

        BankExportImportSetup.Delete(true);

        case ActivationType of
            ActivationType::DataExchange:
                begin
                    // Delete Payment Method.
                    //
                    if PaymentMethod.Get(FormatCode) then begin
                        if CheckDependencies then begin
                            Customer.SetRange("Payment Method Code", FormatCode);
                            if not Customer.IsEmpty() then
                                Error(CannotDeleteErr, PaymentMethod.TableCaption(), Customer.TableCaption());
                        end;

                        PaymentMethod.Delete(true);
                    end;

                    // Delete Data. Exch. Def.
                    //
                    DataExchDef.SetRange(Code, FormatCode);
                    DataExchDef.DeleteAll(true);
                end;
        end;
    end;

    /// <summary>
    /// Reactivates the format, recreating the payment method, bank export/import setup and data exchange definitions, as needed. 
    /// </summary>    
    /// <param name="Format">The enum of the format to activate.</param>    
    /// <param name="FormatCode">The format code to check.</param>    
    /// <param name="Upgrade">Indicates whether the reactivation should be treated as an upgrade.</param>    

    internal procedure ReactivateFormat(Format: Enum EVO_BAC_Format; FormatCode: Code[10]; Upgrade: Boolean)
    var
        FormatInterface: Interface EVO_BAC_Format;
        ConfirmationText: Text;

        UpgradeQst: Label 'The application containing the format is newer than the current configuration. If the configuration is not up to date, then unexpected behaviour may occur.\\Upgrading the format will recreate the payment method, bank export/import setup and data exchange definitions, as needed. All values will be returned to default settings. If there is a number series associated with this format, it will be preserved.\\Are you sure you wish to proceed?';
        ReactivateQst: Label 'Reactivating the format will recreate the payment method, bank export/import setup and data exchange definitions, as needed. All values will be returned to default settings. If there is a number series associated with this format, it will be preserved.\\Are you sure you wish to proceed?';
    begin
        if Upgrade then
            ConfirmationText := UpgradeQst
        else
            ConfirmationText := ReactivateQst;

        if not Confirm(ConfirmationText, false) then
            exit;

        DeactivateFormat(FormatCode, false);
        FormatInterface := Format;
        FormatInterface.CreateFormat(FormatCode);
    end;

    /// <summary>
    /// Builds a list of formats installed, requests other applications to register themselves via the RegisterBACSFormat event.
    /// </summary>    
    /// <param name="TempFormat">A temporary instance of the EVO_BAC_Format record, which will be returned with a list of formats populated within it.</param>    

    internal procedure RegisterFormats(var TempFormat: Record EVO_BAC_Format temporary)
    var
        BankExportImportSetup: Record "Bank Export/Import Setup";
    begin
        TempFormat.DeleteAll();

        // Allow expansions to register themselves.
        //
        RegisterBACSFormat(TempFormat);

        // Match up Bank Export/Import Setup with expansions, log missing formats.
        //
        BankExportImportSetup.SetFilter(EVO_BAC_Format, '<>%1', Enum::EVO_BAC_Format::None);
        if BankExportImportSetup.FindSet() then
            repeat
                if TempFormat.Get(BankExportImportSetup.EVO_BAC_Format) then begin
                    TempFormat.Validate(EVO_BAC_PmtExportFormat, BankExportImportSetup.Code);
                    TempFormat.Validate(EVO_BAC_ActiveFormatVersion, BankExportImportSetup.EVO_BAC_FormatAppVersion);
                    TempFormat.Validate(EVO_BAC_FormatActiveDate, BankExportImportSetup.EVO_BAC_FormatActiveDate);
                    TempFormat.Validate(EVO_BAC_FormatActivationType, BankExportImportSetup.EVO_BAC_FormatActivationType);
                    TempFormat.Modify(true);
                end else
                    TempFormat.RegisterMissingFormat(BankExportImportSetup.EVO_BAC_Format, BankExportImportSetup);
            until BankExportImportSetup.Next() = 0;
    end;

    // Obsoleted methods
    //
    [Obsolete('Changed to internal IsFormatCodeUsed() method.', '25.0')]
    procedure IsFormatCodeInUse(FormatCode: Code[20]): Boolean
    begin
    end;

    [Obsolete('Changed to internal DeactivateFormat() method.', '25.0')]
    procedure DisablePaymentExportFormat(FormatCode: Code[20])
    begin
    end;

    [Obsolete('Changed to internal RegisterFormats() method.', '25.0')]
    procedure RegisterBACSFormats(var TempEVOEFFBACSFormat: Record EVO_BAC_Format temporary)
    begin
    end;

    [Obsolete('Changed to internal FormatAppVersion() method.', '25.0')]
    procedure FormatVersion(AppVersion: Version): Text
    begin
    end;

    #endregion
    #region Misc. methods    

    [Obsolete('Changed to internal IsCoreLicensed() and IsFormatLicensed() methods.', '25.0')]
    procedure IsLicensed(BACSFormat: Enum EVO_BAC_Format; FormatSetupID: Guid): Boolean
    begin
        exit(IsFormatLicensed(BACSFormat, FormatSetupID));
    end;

    /// <summary>
    /// Checks if the core application is licensed.
    /// </summary>    
    /// <returns>Boolean value indicating whether the core application is licensed.</returns>

    [NonDebuggable]
    internal procedure IsCoreLicensed(): Boolean
    var
        EVOELMLicenseManagement: Codeunit EVO_ELM_LicenseManagement;

        CoreInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(CoreInfo);

        if not EVOELMLicenseManagement.IsLicensed(CoreInfo.Id) then
            exit(false);

        exit(true);
    end;

    /// <summary>
    /// Checks if the core application and the format are licensed.
    /// </summary>    
    /// <param name="Format">The enum of the format to activate.</param>    
    /// <param name="FormatSetupID">The setup GUID that was generated during activation of the format.</param>    
    /// <returns>Boolean value indicating whether the core application and the format are licensed.</returns>

    [NonDebuggable]
    procedure IsFormatLicensed(Format: Enum EVO_BAC_Format; FormatSetupID: Guid): Boolean
    var
        EVOBACFormat: Record EVO_BAC_Format;
        EVOELMLicenseManagement: Codeunit EVO_ELM_LicenseManagement;

        CoreInfo: ModuleInfo;
        FormatInfo: ModuleInfo;
        FormatAppID: Guid;

        UnknownFormatErr: Label 'The format specified does not appear to be a valid format for use with BCN BACS. Please check the application is properly installed.';
        ExtensionUninstalledErr: Label 'The %1 with the app ID ''%2'' has been uninstalled. Please check the application is properly installed.', Comment = '%1 = Table caption, %2 = App ID';
    begin
        NavApp.GetCurrentModuleInfo(CoreInfo);

        if not EVOELMLicenseManagement.IsLicensed(CoreInfo.Id) then
            exit(false);

        if (Format = Format::None) or (IsNullGuid(FormatSetupID)) then begin
            Message(UnknownFormatErr);
            exit(false);
        end;

        FormatAppID := TransformGuid(FormatSetupID, true);
        if FormatAppID <> CoreInfo.Id then begin
            if not NavApp.GetModuleInfo(FormatAppID, FormatInfo) then begin
                Message(ExtensionUninstalledErr, EVOBACFormat.TableCaption(), FormatAppID);
                exit(false);
            end;

            if not EVOELMLicenseManagement.IsLicensed(FormatInfo.Id) then
                exit(false);
        end;

        exit(true);
    end;

    /// <summary>
    /// Transforms a guid from a setup ID into a application guid.
    /// </summary>    
    /// <param name="SourceGuid">The source GUID to convert.</param>    
    /// <param name="Undo">The direction to convert the GUID.</param>    
    /// <returns>A GUID containing the transformed result.</returns>

    [NonDebuggable]
    local procedure TransformGuid(SourceGuid: Guid; Undo: Boolean) Result: Guid
    var
        FromMap: Text;
        ToMap: Text;
        SourceText: Text;
        ResultText: Text;
        I: Integer;
        Pos: Integer;

        NewMapTxt: Label 'BA35FCED42081796', Locked = true;
        OriginalMapTxt: Label '1234567890ABCDEF', Locked = true;
        InvalidGuidErr: Label 'An error occurred processing the application GUID.';
    begin
        // Get the Application ID.
        //
        SourceText := Format(SourceGuid, 0, 3);

        // Setup transformation.
        //
        if not Undo then begin
            FromMap := OriginalMapTxt;
            ToMap := NewMapTxt;
        end else begin
            FromMap := NewMapTxt;
            ToMap := OriginalMapTxt;
        end;

        // Apply transformation.
        //
        for I := 1 to StrLen(SourceText) do begin
            Pos := StrPos(FromMap, CopyStr(SourceText, I, 1));
            ResultText += CopyStr(ToMap, Pos, 1);
        end;

        // Return Result.
        //
        if not Evaluate(Result, ResultText) then
            Error(InvalidGuidErr);
    end;

    /// <summary>
    /// Formats a version object to a text string.
    /// </summary>    
    /// <param name="AppVersion">A version object representing the version of the object to format.</param>        
    /// <returns>A text value containing the formatted version number.</returns>

    internal procedure FormatAppVersion(AppVersion: Version): Text
    var
        VersionTxt: Label 'v. %1.%2.%3.%4', Comment = '%1 = Major version, %2 = Minor version, %3 = Build, %4 = Revision';
    begin
        exit(StrSubstNo(VersionTxt, AppVersion.Major, AppVersion.Minor, AppVersion.Build, AppVersion.Revision));
    end;

    #endregion
    #region Event Publishers

    [IntegrationEvent(false, false)]
    local procedure RegisterBACSFormat(var TempEVOEFFBACSFormat: Record EVO_BAC_Format temporary)
    begin
    end;

    #endregion
}