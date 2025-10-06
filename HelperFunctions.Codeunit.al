codeunit 9088962 "EVS_WAY_HelperFunctions"
{
    Access = Internal;

    #region Generic Serializer functions.    

    procedure CreateRequest(RequestType: Text; QueryText: Text): JsonObject
    var
        RequestBody: JsonObject;
    begin
        RequestBody.Add('query', QueryText);
        OnCreateRequest(RequestType, RequestBody);
        exit(RequestBody);
    end;

    procedure CreateRequest(RequestType: Text; QueryText: Text; InputObject: JsonObject): JsonObject
    var
        RequestBody: JsonObject;
    begin
        RequestBody.Add('query', QueryText);
        RequestBody.Add('variables', InputObject);
        OnCreateRequest(RequestType, RequestBody);
        exit(RequestBody);
    end;

    procedure GetJsonValueAsText(Object: JsonObject; KeyName: Text; Mandatory: Boolean; MaxLength: Integer): Text
    var
        TokenObject: JsonToken;
        TextVar: Text;

        MissingValueErr: Label 'Key ''%1'' missing from JSON Object.', Comment = '%1 = Key';
    begin
        // Gets a JSON value as text, throws an error if it is not present and
        // the Mandatory parameter is true. Use overload without Mandatory parameter 
        // if this is not required.
        //
        if not Object.Get(KeyName, TokenObject) then
            if not Mandatory then
                exit('')
            else
                Error(MissingValueErr, KeyName);

        if TokenObject.AsValue().IsNull() then
            if not Mandatory then
                exit('')
            else
                Error(MissingValueErr, KeyName);

        TextVar := TokenObject.AsValue().AsText();
        if MaxLength <> 0 then
            TextVar := CopyStr(TextVar, 1, MaxLength);

        exit(TextVar);
    end;

    procedure GetJsonValueAsText(Object: JsonObject; KeyName: Text; MaxLength: Integer): Text
    begin
        // Overload to omit Mandatory parameters.
        //
        exit(GetJsonValueAsText(Object, Keyname, false, 0));
    end;

    procedure GetJsonValueAsText(Object: JsonObject; KeyName: Text; Mandatory: Boolean): Text
    begin
        // Overload to omit MaxLength parameters.
        //
        exit(GetJsonValueAsText(Object, Keyname, Mandatory, 0));
    end;

    procedure GetJsonValueAsText(Object: JsonObject; KeyName: Text): Text
    begin
        // Overload to omit Mandatory/MaxLength parameters.
        //
        exit(GetJsonValueAsText(Object, KeyName, false, 0));
    end;

    procedure GetJsonValueAsInt(Object: JsonObject; KeyName: Text; Mandatory: Boolean): Integer
    var
        TokenObject: JsonToken;
        IntVar: Integer;

        MissingValueErr: Label 'Key ''%1'' missing from JSON Object.', Comment = '%1 = Key';
    begin
        // Gets a JSON value as integer, throws an error if it is not present and
        // the Mandatory parameter is true. Use overload without Mandatory parameter 
        // if this is not required.
        //
        if not Object.Get(KeyName, TokenObject) then
            if not Mandatory then
                exit(0)
            else
                Error(MissingValueErr, KeyName);

        if Evaluate(IntVar, TokenObject.AsValue().AsCode()) then
            exit(IntVar)
        else
            exit(0);
    end;

    procedure GetJsonValueAsInt(Object: JsonObject; KeyName: Text): Integer
    begin
        // Overload to omit Mandatory parameter.
        //
        exit(GetJsonValueAsInt(Object, KeyName, false));
    end;

    #endregion
    #region Isolated Storage functions.

    [NonDebuggable]
    procedure GetIsolatedStorageValue(EnvironmentCode: Code[20]; EVSWAYISKeyType: Enum "EVS_WAY_IsolatedStorageData"): Text
    var
        KeyValue: Text;
    begin
        // Gets a value from Isolated Storage, based upon a key generated from the client ID and the type of data.
        // Non-debuggable to protect the parameters from view, passed variables should also be set as non-debuggable.
        //
        if IsolatedStorage.Contains(GetIsolatedStorageKey(EnvironmentCode, EVSWAYISKeyType), DataScope::Company) then begin
            IsolatedStorage.Get(GetIsolatedStorageKey(EnvironmentCode, EVSWAYISKeyType), DataScope::Company, KeyValue);
            exit(KeyValue);
        end else
            exit('');
    end;

    [NonDebuggable]
    procedure SetIsolatedStorageValue(EnvironmentCode: Code[20]; EVSWAYISKeyType: Enum "EVS_WAY_IsolatedStorageData"; NewValue: Text)
    begin
        // Saves a value in Isolated Storage, based upon a key generated from the client ID and the type of data.
        // Non-debuggable to protect the parameters from view, passed variables should also be set as non-debuggable.
        //
        IsolatedStorage.Set(GetIsolatedStorageKey(EnvironmentCode, EVSWAYISKeyType), NewValue, DataScope::Company);
    end;

    [NonDebuggable]
    procedure IsolatedStorageValueExists(EnvironmentCode: Code[20]; EVSWAYISKeyType: Enum "EVS_WAY_IsolatedStorageData"): Boolean
    begin
        // Checks for the existence of a value in Isolated Storage, based upon a key generated from the client ID 
        // and the type of data.
        //
        exit(IsolatedStorage.Contains(GetIsolatedStorageKey(EnvironmentCode, EVSWAYISKeyType), DataScope::Company));
    end;

    [NonDebuggable]
    local procedure GetIsolatedStorageKey(EnvironmentCode: Code[20]; EVSWAYISKeyType: Enum "EVS_WAY_IsolatedStorageData"): Text
    var
        KeyName: Text;

        SecretTxt: Label 'EVS_WAY_Secret', Comment = '%1 = Suffix', Locked = true;
        TokenTxt: Label 'EVS_WAY_AccessToken', Comment = '%1 = Suffix', Locked = true;
        KeyFormatTxt: Label '%1-%2', Locked = true;
    begin
        // Generates the keys used by isolated storage for storing sensitive data.
        //
        case EVSWAYISKeyType of
            EVSWAYISKeyType::Secret:
                Keyname := SecretTxt;
            EVSWAYISKeyType::Token:
                Keyname := TokenTxt;
        end;

        if EnvironmentCode <> '' then
            exit(StrSubstNo(KeyFormatTxt, KeyName, EnvironmentCode))
        else
            exit(KeyName);
    end;

    #endregion
    #region General functions.

    procedure FormatValue(ValueVariant: Variant) Result: Text
    begin
        if ValueVariant.IsDate() then
            Result := Format(CreateDateTime(ValueVariant, 0T), 0, 9)
        else
            Result := Format(ValueVariant, 0, 9);
    end;

    procedure FormatToInt(Value: Decimal) Result: Text
    begin
        Result := Format(Round(Value, 1, '<'), 0, 9);
    end;

    procedure FormatTimeStamp(Value: DateTime): Text
    var
        TimeStampFormatTok: Label '<Year4><Month,2><Day,2><Hour,2><Minute,2><Seconds,2>', Locked = true;
    begin
        exit(Format(Value, 0, TimeStampFormatTok));
    end;

    procedure GenerateFilename(RequestType: Text; DocumentReference: Text): Text[250]
    var
        FilenameTxt: Label '%1-%2.json', Comment = '%1 = Request Type, %2 = Date/Time Stamp', Locked = true;
        FilenameWithDocumentTxt: Label '%1-%2-%3.json', Comment = '%1 = Request Type, %2 = Date/Time Stamp, %3 = Document Reference,', Locked = true;
    begin
        // Generates the filename assigned to a JSON blob object in data bridge. In this case the 
        // file never actually exists and the filename exists to allow data bridge to give us a sensible 
        // filename if we want to view the contents of the blob.
        //
        if DocumentReference = '' then
            exit(StrSubstNo(FilenameTxt, RequestType, FormatTimeStamp(CurrentDateTime)))
        else
            exit(StrSubstNo(FilenameWithDocumentTxt, RequestType, FormatTimeStamp(CurrentDateTime), DocumentReference));
    end;

    procedure GetContentFromBatch(EVSDBCMessageBatch: Record EVS_DBC_MessageBatch): Text
    var
        TypeHelper: Codeunit "Type Helper";

        InStream: Instream;
    begin
        // Retrieves content as text from the Blob in a Data-Bridge batch.
        //
        EVSDBCMessageBatch.CalcFields(EVS_DBC_ImportExportFile);
        if not EVSDBCMessageBatch.EVS_DBC_ImportExportFile.HasValue() then
            exit('');

        EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateInStream(InStream, TextEncoding::UTF8);
        exit(TypeHelper.ReadAsTextWithSeparator(InStream, TypeHelper.CRLFSeparator()));
    end;

    procedure SaveJsonToTempBlob(ObjectAsText: Text; var TempBlob: Codeunit "Temp Blob")
    var
        OutStream: OutStream;
    begin
        // Saves a JSON object directly into a passed TempBlob.
        //        
        Clear(TempBlob);
        TempBlob.CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(ObjectAsText);
    end;

    procedure SaveJsonToTempBlob(Object: JsonObject; var TempBlob: Codeunit "Temp Blob")
    var
        ObjectText: Text;
    begin
        // Overload to take a JsonObject
        //
        Object.WriteTo(ObjectText);
        SaveJsonToTempBlob(ObjectText, TempBlob);
    end;

    procedure SaveJsonToTempBlob(ArrayObject: JsonArray; var TempBlob: Codeunit "Temp Blob")
    var
        ArrayObjectText: Text;
    begin
        // Overload to take a JsonArray
        //
        ArrayObject.WriteTo(ArrayObjectText);
        SaveJsonToTempBlob(ArrayObjectText, TempBlob);
    end;

    procedure GetShippingSpeedFromName(Name: Text; var ShippingSpeed: Enum EVS_WAY_ShippingSpeed): Boolean
    var
        NameList: List of [Text];
        OrdinalList: List of [Integer];
        ListIndex: Integer;
    begin
        // Find the correct ordinal for a Shipping Speed from its name.
        //
        NameList := EVS_WAY_ShippingSpeed.Names();
        OrdinalList := EVS_WAY_ShippingSpeed.Ordinals();

        if not NameList.Contains(Name) then
            exit(false);

        ListIndex := NameList.IndexOf(Name);
        ShippingSpeed := EVS_WAY_ShippingSpeed.FromInteger(OrdinalList.Get(ListIndex));
        exit(true)
    end;

    procedure GetNameFromShippingSpeed(ShippingSpeed: Enum EVS_WAY_ShippingSpeed): Text
    var
        NameList: List of [Text];
        OrdinalList: List of [Integer];
        ListIndex: Integer;
    begin
        // Find the correct ordinal for a Shipping Speed from its name.
        //
        NameList := EVS_WAY_ShippingSpeed.Names();
        OrdinalList := EVS_WAY_ShippingSpeed.Ordinals();

        ListIndex := OrdinalList.IndexOf(ShippingSpeed.AsInteger());
        exit(NameList.Get(ListIndex))
    end;

    #endregion
    #region Process Link Helpers

    procedure RecreateProcessLinks(EVSWAYSetting: Record EVS_WAY_Setting; Silent: Boolean)
    var
        EVSDBCProcess: Record EVS_DBC_Process;
        EVSDBCProcessLink: Record EVS_DBC_ProcessLink;
        Customer: Record Customer;

        DBLinkSelectionValueTxt: Label 'Data-Bridge';
        ConfirmLinkSelectionValueTxt: Label 'Confirm';
        RecreateProcessLinksQst: Label 'Do you wish to create the suggested %1s for %2 ''%3''?', Comment = '%1 = Table caption, %2 = Environment code field caption, %3 = Environment code';
        CreatedProcessLinksMsg: Label 'Created suggested %1s against %2 %3 ''%4''.', Comment = '%1 = Table caption, %2 = Target Table Caption, %3 = Target Key Field, %4 = Target Key Value';
        CreateProcessLinksErr: Label 'Unable to create %1s for %2 ''%3'', %4 ''%5''.\\Please set up the appropriate processes and try again.', Comment = '%1 = Table caption, %4 = Process type caption, %5 = Process type, %2 = environment code field caption, %3 = environment code';
    begin
        // Attempts to create process links that are suitable for this partner and environment combination.

        // Check the passed settings are appropriate and confirm operation.
        //
        EVSDBCProcess.Get(EVSWAYSetting.EVS_WAY_ProcessCode);
        if EVSDBCProcess.EVS_DBC_ProcessTypeEnum <> EVSDBCProcess.EVS_DBC_ProcessTypeEnum::ImportSalesDocument_I then
            exit;

        EVSWAYSetting.TestField(EVS_WAY_EnvironmentCode);
        EVSWAYSetting.TestField(EVS_WAY_CustomerNo);

        if not Silent then
            if not Confirm(RecreateProcessLinksQst, false, EVSDBCProcessLink.TableCaption(), EVSWAYSetting.FieldCaption(EVS_WAY_EnvironmentCode), EVSWAYSetting.EVS_WAY_EnvironmentCode) then
                exit;

        // Create links.
        //
        if not CreateProcessLink(EVS_DBC_Partner::EVS_WAY_Wayfair, EVSWAYSetting.EVS_WAY_EnvironmentCode, EVS_DBC_ProcessTypeEnum::ExportSalesOrderAcknowledgement_O, DBLinkSelectionValueTxt) then
            Error(CreateProcessLinksErr, EVSDBCProcessLink.TableCaption(), EVSDBCProcess.FieldCaption(EVS_DBC_ProcessType), EVS_DBC_ProcessTypeEnum::ExportSalesOrderAcknowledgement_O, EVSWAYSetting.FieldCaption(EVS_WAY_EnvironmentCode), EVSWAYSetting.EVS_WAY_EnvironmentCode);
        if not CreateProcessLink(EVS_DBC_Partner::EVS_WAY_Wayfair, EVSWAYSetting.EVS_WAY_EnvironmentCode, EVS_DBC_ProcessTypeEnum::ExportAdvancedShippingNotice_O, ConfirmLinkSelectionValueTxt) then
            Error(CreateProcessLinksErr, EVSDBCProcessLink.TableCaption(), EVSDBCProcess.FieldCaption(EVS_DBC_ProcessType), EVS_DBC_ProcessTypeEnum::ExportAdvancedShippingNotice_O, EVSWAYSetting.FieldCaption(EVS_WAY_EnvironmentCode), EVSWAYSetting.EVS_WAY_EnvironmentCode);

        // Generate message or error.
        //
        Message(CreatedProcessLinksMsg, EVSDBCProcessLink.TableCaption(), Customer.TableCaption(), Customer.FieldCaption("No."), EVSWAYSetting.EVS_WAY_CustomerNo);
    end;

    local procedure CreateProcessLink(Partner: Enum EVS_DBC_Partner; EnvironmentCode: Code[20]; LinkToProcessType: Enum EVS_DBC_ProcessTypeEnum; LinkSelectionValue: Text[50]): Boolean
    var
        EVSDBCProcessLink: Record EVS_DBC_ProcessLink;
        EVSWAYSetting: Record EVS_WAY_Setting;

        OrderProcessCode: Code[20];
        LinkToProcessCode: Code[20];
    begin
        // Attempts to create a specific process link from the sales order process to another process (such as shipment or order ack)

        // Find Target Processes.
        //
        OrderProcessCode := FindProcess(Partner, EnvironmentCode, EVS_DBC_ProcessTypeEnum::ImportSalesDocument_I);
        if OrderProcessCode = '' then
            exit(false);

        LinkToProcessCode := FindProcess(Partner, EnvironmentCode, LinkToProcessType);
        if LinkToProcessCode = '' then
            exit(false);

        // Check settings on sales order process.
        //
        EVSWAYSetting.Get(OrderProcessCode);
        EVSWAYSetting.TestField(EVS_WAY_CustomerNo);

        // Delete old links for linked process.
        //
        EVSDBCProcessLink.SetRange(EVS_DBC_Partner, EVS_DBC_Partner::EVS_WAY_Wayfair);
        EVSDBCProcessLink.SetRange(EVS_DBC_ProcessTypeEnum, LinkToProcessType);
        EVSDBCProcessLink.SetRange(EVS_DBC_ProcessCode, LinkToProcessCode);
        EVSDBCProcessLink.DeleteAll(true);

        // Create new link.
        //
        EVSDBCProcessLink.Init();
        EVSDBCProcessLink.Validate(EVS_DBC_TableNo, Database::Customer);
        EVSDBCProcessLink.Validate(EVS_DBC_LinkCode, EVSWAYSetting.EVS_WAY_CustomerNo);
        EVSDBCProcessLink.Validate(EVS_DBC_ProcessTypeEnum, LinkToProcessType);
        EVSDBCProcessLink.Validate(EVS_DBC_ProcessCode, LinkToProcessCode);
        EVSDBCProcessLink.Validate(EVS_DBC_LinkSelectionValue, LinkSelectionValue);
        EVSDBCProcessLink.Insert(true);

        exit(true);
    end;

    local procedure FindProcess(Partner: Enum EVS_DBC_Partner; EnvironmentCode: Code[20]; ProcessType: Enum EVS_DBC_ProcessTypeEnum): Code[20]
    var
        EVSDBCProcess: Record EVS_DBC_Process;
        EVSDBCProcessLink: Record EVS_DBC_ProcessLink;
        EVSWAYSetting: Record EVS_WAY_Setting;

        MultipleErr: Label 'Multiple %1 processes are configured for process ''%2'' using the same environment.\\Please configure %3s manually.', Comment = '%1 = Partner, %2 = Process Type, %3 = table caption.';
    begin
        // Attempt to find a specific type of process, with the right environment within the partner.

        // Mark applicable processes.
        //
        EVSDBCProcess.SetCurrentKey(EVS_DBC_Partner, EVS_DBC_ProcessTypeEnum);
        EVSDBCProcess.SetRange(EVS_DBC_Partner, Partner);
        EVSDBCProcess.SetRange(EVS_DBC_ProcessTypeEnum, ProcessType);
        if EVSDBCProcess.FindSet() then
            repeat
                if not EVSWAYSetting.Get(EVSDBCProcess.EVS_DBC_ProcessCode) then
                    Clear(EVSDBCProcess);

                EVSDBCProcess.Mark(EVSWAYSetting.EVS_WAY_EnvironmentCode = EnvironmentCode);
            until EVSDBCProcess.Next() = 0;

        EVSDBCProcess.MarkedOnly(true);
        if EVSDBCProcess.IsEmpty() then
            exit('');

        // Return the found process if there is only one, otherwise error.
        //
        if EVSDBCProcess.Count() = 1 then begin
            EVSDBCProcess.FindFirst();
            exit(EVSDBCProcess.EVS_DBC_ProcessCode);
        end else
            Error(MultipleErr, EVS_DBC_Partner::EVS_WAY_Wayfair, ProcessType, EVSDBCProcessLink.TableCaption());
    end;

    #endregion
    #region Events

    [IntegrationEvent(false, false)]
    local procedure OnCreateRequest(RequestType: Text; var RequestBody: JsonObject)
    begin
    end;

    #endregion
}