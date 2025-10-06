codeunit 60002 "CLE002_DTCHelperFunctions"
{
    #region Generic Serializer functions.    

    procedure CreateRequest(RequestType: Text; QueryText: Text): JsonObject
    var
        RequestBody: JsonObject;
    begin
        RequestBody.Add('query', QueryText);
        exit(RequestBody);
    end;

    procedure CreateRequest(RequestType: Text; QueryText: Text; InputObject: JsonObject): JsonObject
    var
        RequestBody: JsonObject;
    begin
        RequestBody.Add('query', QueryText);
        RequestBody.Add('variables', InputObject);
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
        exit(GetJsonValueAsText(Object, KeyName, false, 0));
    end;

    procedure GetJsonValueAsText(Object: JsonObject; KeyName: Text; Mandatory: Boolean): Text
    begin
        // Overload to omit MaxLength parameters.
        //
        exit(GetJsonValueAsText(Object, KeyName, Mandatory, 0));
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

    procedure GetIsolatedStorageValue(EnvironmentCode: Code[20]; CLE002DTCISKeyType: Enum CLE002_DTCIsolatedStorageData): Text
    var
        KeyValue: Text;
    begin
        // Gets a value from Isolated Storage, based upon a key generated from the client ID and the type of data.
        // Non-debuggable to protect the parameters from view, passed variables should also be set as non-debuggable.
        //
        if IsolatedStorage.Contains(GetIsolatedStorageKey(EnvironmentCode, CLE002DTCISKeyType), DataScope::Company) then begin
            IsolatedStorage.Get(GetIsolatedStorageKey(EnvironmentCode, CLE002DTCISKeyType), DataScope::Company, KeyValue);
            exit(KeyValue);
        end else
            exit('');
    end;

    [NonDebuggable]
    procedure SetIsolatedStorageValue(EnvironmentCode: Code[20]; CLE002DTCISKeyType: Enum CLE002_DTCIsolatedStorageData; NewValue: Text)
    begin
        // Saves a value in Isolated Storage, based upon a key generated from the client ID and the type of data.
        // Non-debuggable to protect the parameters from view, passed variables should also be set as non-debuggable.
        //
        IsolatedStorage.Set(GetIsolatedStorageKey(EnvironmentCode, CLE002DTCISKeyType), NewValue, DataScope::Company);
    end;

    [NonDebuggable]
    procedure IsolatedStorageValueExists(EnvironmentCode: Code[20]; CLE002DTCISKeyType: Enum CLE002_DTCIsolatedStorageData): Boolean
    begin
        // Checks for the existence of a value in Isolated Storage, based upon a key generated from the client ID 
        // and the type of data.
        //
        exit(IsolatedStorage.Contains(GetIsolatedStorageKey(EnvironmentCode, CLE002DTCISKeyType), DataScope::Company));
    end;

    [NonDebuggable]
    local procedure GetIsolatedStorageKey(EnvironmentCode: Code[20]; CLE002DTCISKeyType: Enum CLE002_DTCIsolatedStorageData): Text
    var
        KeyName: Text;

        SecretTxt: Label 'CLE_DTC_Secret', Comment = '%1 = Suffix', Locked = true;
        TokenTxt: Label 'CLE_DTC_AccessToken', Comment = '%1 = Suffix', Locked = true;
        StaticTokenTxt: Label 'CLE_DTC_StaticToken', Comment = '%1 = Suffix', Locked = true;
        KeyFormatTxt: Label '%1-%2', Locked = true;
    begin
        // Generates the keys used by isolated storage for storing sensitive data.
        //
        case CLE002DTCISKeyType of
            CLE002DTCISKeyType::Secret:
                KeyName := SecretTxt;
            CLE002DTCISKeyType::Token:
                KeyName := TokenTxt;
            CLE002DTCISKeyType::StaticToken:
                KeyName := StaticTokenTxt;
        end;

        if EnvironmentCode <> '' then
            exit(StrSubstNo(KeyFormatTxt, KeyName, EnvironmentCode))
        else
            exit(KeyName);
    end;

    #endregion
    #region General Functions
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

    procedure GetContentFromBatch(EVSDBCMessageBatch: Record EVS_DBC_MessageBatch): Text
    var
        TypeHelper: Codeunit "Type Helper";

        InStream: InStream;
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
    #endregion 
}
