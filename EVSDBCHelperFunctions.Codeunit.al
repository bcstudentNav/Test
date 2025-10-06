/// <summary>
/// Codeunit 71120137.
/// Holds the helper functions 
/// </summary>
codeunit 71120138 EVS_DBC_HelperFunctions
{
    #region DataFunctions
    /// <summary>
    /// FormatDate.
    /// </summary>
    /// function takes a datestring , date format and remaps the date string to the datemap
    /// <param name="DateString">Text.</param>
    /// <param name="DateFormat">Text.</param>
    /// <param name="FormattedDate">VAR Date.</param>
    /// <returns>Return value of type Text.</returns>
    procedure FormatDate(DateString: Text; DateFormat: Text; var FormattedDate: Date): Text
    var
        DayValue: Integer;
        MonthValue: Integer;
        YearValue: Integer;
        InvalidDateErr: Label 'Supplied Date %1 is not in correct date format %2', Comment = '%1 is Supplied date, %2 is the date format.';
        DateFormatErr: Label 'Supplied Date Format %1 does not contain a %2 node', Comment = '%1 is date format, %2 is the date format part.';
        LengthErr: Label 'Supplied Date Format %1 is longer than the supplied date %2', Comment = '%1 is date format, %2 is the Supplied date';

    begin
        if DateString = '' then
            exit('');

        if StrLen(DateString) < StrLen(DateFormat) then
            exit(StrSubstNo(LengthErr, DateFormat, DateString));

        // look at DateFormat to get days
        DayValue := CalculateDatePart(DateString, 'DD', DateFormat);
        if DayValue = -2 then
            exit(StrSubstNo(DateFormatErr, DateFormat, 'DD'));

        // look at DateFormat to get Months
        MonthValue := CalculateDatePart(DateString, 'MMM', DateFormat);
        if MonthValue = -2 then
            MonthValue := CalculateDatePart(DateString, 'MM', DateFormat);
        if MonthValue = -2 then
            exit(StrSubstNo(DateFormatErr, DateFormat, 'MM'));

        // look at DateFormat to get Years
        YearValue := CalculateDatePart(DateString, 'YYYY', DateFormat);
        if YearValue = -2 then begin
            YearValue := CalculateDatePart(DateString, 'YY', DateFormat);
            if YearValue = -2 then
                exit(StrSubstNo(DateFormatErr, DateFormat, 'YYYY/YY'));
            YearValue += 2000;
        end;
        if (DayValue = -1) or (MonthValue = -1) or (YearValue = -1) then
            exit(StrSubstNo(InvalidDateErr, DateString, DateFormat));

        if not CheckDate(DayValue, MonthValue, YearValue, FormattedDate) then
            exit(StrSubstNo(InvalidDateErr, DateString, DateFormat));

    end;

    [TryFunction]
    local procedure CheckDate(DayValue: Integer; MonthValue: Integer; YearValue: Integer; var FormattedDate: Date)

    begin
        FormattedDate := DMY2Date(DayValue, MonthValue, YearValue);
    end;

    local procedure CalculateDatePart(DateString: Text; DateMatch: Text; DateFormat: Text) FoundValue: Integer
    var
        IndexOfValue: Integer;
        monthsLbl: Label 'jan,feb,mar,apr,may,jun,jul,aug,sep,oct,nov,dec';
        monthText: Text;

    begin

        IndexOfValue := DateFormat.IndexOf(DateMatch);
        if IndexOfValue <> 0 then begin
            // handle MMM differently
            if DateMatch = 'MMM' then begin
                monthText := LowerCase(DateString.Substring(IndexOfValue, StrLen(DateMatch)));
                FoundValue := StrPos(monthsLbl, monthText);
                if FoundValue = 0 then
                    exit(-1);
            end
            else
                if not Evaluate(FoundValue, DateString.Substring(IndexOfValue, StrLen(DateMatch))) then
                    exit(-1);
        end else
            exit(-2);
        exit(FoundValue);
    end;
    #endregion

    #region DataArray
    var

        BigTextFile: BigText;
        CurrentPositionInBigTextFile: Integer;
        FileCreated: Boolean;

    procedure GetDataArrayNextLine(EVSDBCMessageBatch: Record EVS_DBC_MessageBatch;
        FileType: Option Fixed,Variable; FieldSeperator: Text[1]; TextQualifier: Text[1]; RowSeparator: Option LF,CR,CRLF;
     var DataArray: array[1000] of Text): Boolean
    var
        InboundInstream: InStream;
    begin
        if not FileCreated then begin
            EVSDBCMessageBatch.CalcFields(EVS_DBC_ImportExportFile);
            EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateInStream(InboundInstream);
            BigTextFile.Read(InboundInstream);
            CurrentPositionInBigTextFile := 1;
            FileCreated := true;
        end;
        if CurrentPositionInBigTextFile >= BigTextFile.Length then
            exit(false);

        ReadVariableLineToDataArray(BigTextFile, FileType, CurrentPositionInBigTextFile, DataArray, FieldSeperator, TextQualifier, RowSeparator);

        exit(true);
    end;

    // Procedure CreateDataArray(EVSDBCMessageBatch: Record EVS_DBC_MessageBatch; var DataArray: array[10000, 99] of Text; var LineCount: Integer)
    // var
    //     InboundInstream: InStream;
    // begin
    //     EVSDBCMessageBatch.calcfields(EVS_DBC_ImportExportFile);
    //     EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateInStream(InboundInstream);
    //     BigTextFile.Read(InboundInstream);
    //     CurrentPositionInBigTextFile := 1;
    //     Clear(LineCount);
    //     while CurrentPositionInBigTextFile < BigTextFile.Length do begin
    //         LineCount += 1;
    //         ReadLineToDataArray(BigTextFile, CurrentPositionInBigTextFile, DataArray[LineCount]);
    //     end;
    // end;

    local procedure ReadVariableLineToDataArray(var pBigTextFile: BigText; FileType: Option Fixed,Variable; var pCurrentPositionInBigTextFile: Integer;
                var DataArray: array[1000] of Text;
                FieldSeparator: Text[1]; TextQualifier: Text[1]; RowSeparator: Option LF,CR,CRLF)
    var
        EndOfLine: Char;
        EndOfLine2: Char;
        SingleCharacter: Text;
        DoubleCharacter: Text;
        CR: Char;
        LF: Char;
        CurrField: Integer;
        Enclosed: Boolean;
    begin
        Clear(DataArray);
        CurrField := 1;
        CR := 10;
        LF := 13;
        // Set the settings
        if RowSeparator = RowSeparator::LF then
            EndOfLine := LF;
        if RowSeparator = RowSeparator::CR then
            EndOfLine := CR;
        if RowSeparator = RowSeparator::CRLF then begin
            EndOfLine := CR;
            EndOfLine2 := LF;
        end;
        // Get the current values
        pBigTextFile.GetSubText(SingleCharacter, pCurrentPositionInBigTextFile, 1);
        pBigTextFile.GetSubText(DoubleCharacter, pCurrentPositionInBigTextFile + 1, 1);


        while (SingleCharacter[1] <> EndOfLine) do begin
            // FileType
            if FileType = FileType::Variable then
                case SingleCharacter of
                    FieldSeparator:
                        if Enclosed then
                            DataArray[CurrField] := DataArray[CurrField] + SingleCharacter
                        else
                            CurrField := CurrField + 1;
                    TextQualifier:
                        Enclosed := not Enclosed;
                    else
                        DataArray[CurrField] := DataArray[CurrField] + SingleCharacter;
                end
            else
                DataArray[CurrField] := DataArray[CurrField] + SingleCharacter;

            pCurrentPositionInBigTextFile += 1;
            if pCurrentPositionInBigTextFile < pBigTextFile.Length then
                pBigTextFile.GetSubText(SingleCharacter, pCurrentPositionInBigTextFile, 1)
            else
                exit;
        end;

        pCurrentPositionInBigTextFile += 1;
        // need to move on one if CRLF
        if DoubleCharacter[1] = EndOfLine2 then
            pCurrentPositionInBigTextFile += 1;


    end;
    #endregion
    #region MessageHeaderHelpers


    /// <summary>
    /// GetDBMessageHeaderByDocument.
    /// if a data bridge message header record can be found that matches
    /// the supplied table no,TableType, systemID and Processtype. it will be returned in the var EVSDBCMessageHeader object.
    /// A boolean true will also be returned.
    /// If it cannot be found a boolean false will be returned.   /// 
    /// </summary>
    /// <param name="tableNo">integer.</param>
    /// <param name="SystemID">GUID.</param>
    /// <param name="EDIProcessTypeEnum">Enum EVS_DBC_ProcessTypeEnum.</param>
    /// <param name="EVSDBCMessageHeader">VAR record EVS_DBC_MessageHeader.</param>
    /// <returns>Return variable DatabridgeExists of type boolean.</returns>
    procedure GetDBMessageHeaderByDocument(tableNo: Integer; SystemID: Guid; EDIProcessTypeEnum: Enum EVS_DBC_ProcessTypeEnum; var EVSDBCMessageHeader: Record EVS_DBC_MessageHeader) DatabridgeExists: Boolean
    var
        FindEVSDBCMessageHeader: Record EVS_DBC_MessageHeader;
    begin
        FindEVSDBCMessageHeader.SetRange(EVS_DBC_EntityTableNo, tableNo);
        FindEVSDBCMessageHeader.SetRange(EVS_DBC_EntitySystemID, SystemID);
        FindEVSDBCMessageHeader.SetRange(EVS_DBC_ProcessTypeEnum, EDIProcessTypeEnum);
        if FindEVSDBCMessageHeader.FindLast() then begin
            EVSDBCMessageHeader.Get(FindEVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
            exit(true);
        end;
    end;
    /// <summary>
    /// GetDBMessageHeaderByDocumentNo.
    /// </summary>
    /// <param name="tableNo">integer.</param>
    /// <param name="DocumentNo">Code[20].</param>
    /// <param name="DocumentType">integer.</param>
    /// <param name="EDIProcessTypeEnum">Enum EVS_DBC_ProcessTypeEnum.</param>
    /// <param name="EVSDBCMessageHeader">VAR record EVS_DBC_MessageHeader.</param>
    /// <returns>Return variable DatabridgeExists of type boolean.</returns>
    procedure GetDBMessageHeaderByDocumentNo(tableNo: Integer; DocumentNo: Code[20]; DocumentType: Integer; EDIProcessTypeEnum: Enum EVS_DBC_ProcessTypeEnum; var EVSDBCMessageHeader: Record EVS_DBC_MessageHeader) DatabridgeExists: Boolean
    var
        FindEVSDBCMessageHeader: Record EVS_DBC_MessageHeader;
    begin
        FindEVSDBCMessageHeader.SetRange(EVS_DBC_EntityTableNo, tableNo);
        FindEVSDBCMessageHeader.SetRange(EVS_DBC_EntityTableType, DocumentType);
        FindEVSDBCMessageHeader.SetRange(EVS_DBC_EntityDocumentNo, DocumentNo);
        FindEVSDBCMessageHeader.SetRange(EVS_DBC_ProcessTypeEnum, EDIProcessTypeEnum);
        if FindEVSDBCMessageHeader.FindLast() then begin
            EVSDBCMessageHeader.Get(FindEVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
            exit(true);
        end;
    end;
    /// <summary>
    /// GetDBMessageHeaderBySalesHeaderRef.
    /// Matches the data bridge record 
    /// using the supplied header ref will check all 4 header 
    /// </summary>
    /// <param name="AccountCode">Code[20].</param>
    /// <param name="HeaderRef">code[50] var EVSDBCMessageHeader.</param>
    /// <param name="EDIProcessTypeEnum">Enum EVS_DBC_ProcessTypeEnum.</param>
    /// <param name="EVSDBCMessageHeader">VAR record EVS_DBC_MessageHeader.</param>
    /// <returns>Return variable DatabridgeExists of type boolean.</returns>

    procedure GetDBMessageHeaderByRef(AccountCode: Code[20]; HeaderRef: Code[50]; EDIProcessTypeEnum: Enum EVS_DBC_ProcessTypeEnum; var EVSDBCMessageHeader: Record EVS_DBC_MessageHeader) DatabridgeExists: Boolean
    var
        FindEVSDBCMessageHeader: Record EVS_DBC_MessageHeader;
    begin
        FindEVSDBCMessageHeader.SetRange(EVS_DBC_AccountCode, AccountCode);
        FindEVSDBCMessageHeader.SetRange(EVS_DBC_ProcessTypeEnum, EDIProcessTypeEnum);
        FindEVSDBCMessageHeader.SetRange(EVS_DBC_HeaderRef1, HeaderRef);
        if FindEVSDBCMessageHeader.FindLast() then begin
            EVSDBCMessageHeader.Get(FindEVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
            exit(true);
        end else begin
            FindEVSDBCMessageHeader.SetRange(EVS_DBC_HeaderRef1);

            // try header ref 2
            FindEVSDBCMessageHeader.SetRange(EVS_DBC_HeaderRef2, HeaderRef);
            if FindEVSDBCMessageHeader.FindLast() then begin
                EVSDBCMessageHeader.Get(FindEVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
                exit(true);
            end else begin
                FindEVSDBCMessageHeader.SetRange(EVS_DBC_HeaderRef2);

                // try header ref 3
                FindEVSDBCMessageHeader.SetRange(EVS_DBC_HeaderRef3, HeaderRef);
                if FindEVSDBCMessageHeader.FindLast() then begin
                    EVSDBCMessageHeader.Get(FindEVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
                    exit(true);
                end else begin
                    FindEVSDBCMessageHeader.SetRange(EVS_DBC_HeaderRef3);

                    // try header ref 4
                    FindEVSDBCMessageHeader.SetRange(EVS_DBC_HeaderRef4, HeaderRef);
                    if FindEVSDBCMessageHeader.FindLast() then begin
                        EVSDBCMessageHeader.Get(FindEVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
                        exit(true);
                    end;
                end;
            end;
        end;
    end;
    #endregion

    /// <summary>
    /// CreateCommentLine.
    /// Procedure will create comment lines linked to the remote header
    /// </summary>
    /// <param name="MessageHeaderID">integer.</param>
    /// <param name="MessageLineID">Integer.</param>
    /// <param name="PassedComment">Text.</param>/// 
    procedure CreateCommentLine(MessageHeaderID: Integer; MessageLineID: Integer; PassedComment: Text)
        SalesCommentLine: Record "Sales Comment Line"
    begin
        exit(CreateCommentLine(MessageHeaderID, MessageLineID, PassedComment, false, false, false));
    end;

    /// <summary>
    /// CreateCommentLine.
    /// Procedure will create comment lines linked to the remote header
    /// </summary>
    /// <param name="MessageHeaderID">integer.</param>
    /// <param name="MessageLineID">Integer.</param>
    /// <param name="PassedComment">Text.</param>/// 
    /// <param name="ShowOnDocument">Boolean.</param>
    /// <param name="ShowOnDispatchNote">boolean.</param>
    /// <param name="ShowOnPickNote">boolean.</param>
    procedure CreateCommentLine(MessageHeaderID: Integer; MessageLineID: Integer; PassedComment: Text; ShowOnDocument: Boolean; ShowOnDispatchNote: Boolean; ShowOnPickNote: Boolean)
        SalesCommentLine: Record "Sales Comment Line"
    var
        MaxSalesCommentLine: Record "Sales Comment Line";
        CommentLineNo: Integer;
        CommentText: Text;
    begin
        // Get the max comment line NO
        MaxSalesCommentLine.SetRange("Document Type", SalesCommentLine."Document Type"::"EVS_DBC_Data-Bridge");
        MaxSalesCommentLine.SetRange("No.", Format(MessageHeaderID));
        MaxSalesCommentLine.SetRange("Document Line No.", MessageLineID);
        if MaxSalesCommentLine.FindLast() then
            CommentLineNo := MaxSalesCommentLine."Line No.";

        CommentLineNo += 10000;


        Clear(SalesCommentLine);
        SalesCommentLine.Init();
        SalesCommentLine."Document Type" := SalesCommentLine."Document Type"::"EVS_DBC_Data-Bridge";
        SalesCommentLine."No." := Format(MessageHeaderID);
        SalesCommentLine."Document Line No." := MessageLineID;
        SalesCommentLine.Date := Today;

        CommentText := CopyStr(PassedComment, 1, MaxStrLen(SalesCommentLine.Comment));
        PassedComment := CopyStr(PassedComment, MaxStrLen(SalesCommentLine.Comment) + 1);
        while CommentText <> '' do begin
            SalesCommentLine."Line No." := CommentLineNo;
            SalesCommentLine.Comment := CopyStr(CommentText, 1, MaxStrLen(SalesCommentLine.Comment));
            OnCreateCommentLine_OnBeforeInsertSalesCommentLine(SalesCommentLine, MessageHeaderID, MessageLineID, CommentText, ShowOnDocument, ShowOnDispatchNote, ShowOnPickNote);

            SalesCommentLine.Insert(true);
            CommentLineNo := CommentLineNo + 10000;

            CommentText := CopyStr(PassedComment, 1, MaxStrLen(SalesCommentLine.Comment));
            PassedComment := CopyStr(PassedComment, MaxStrLen(SalesCommentLine.Comment) + 1);
        end;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnCreateCommentLine_OnBeforeInsertSalesCommentLine(var SalesCommentLine: Record "Sales Comment Line"; MessageHeaderID: Integer; MessageLineID: Integer; PassedComment: Text; ShowOnDocument: Boolean; ShowOnDispatchNote: Boolean; ShowOnPickNote: Boolean)
    begin
    end;

    /// <summary>
    /// GetItemNo.
    /// gets the item number based on the entered details
    /// </summary>
    /// <param name="CustomerNo">code[20].</param>
    /// <param name="ItemRef">text[50].</param>
    /// <param name="ItemNo">var Code[20].</param>
    /// <returns>Return value of type text.</returns>
    internal procedure GetItemNo(CustomerNo: Code[20]; ItemRef: Text[50]; var ItemNo: Code[20]): Text
    var
        ErrorMessage: Text;
    begin
        // if itemno exits then leave.
        if ItemNo <> '' then
            exit('');

        Clear(ErrorMessage);
        OnGetItemNo_TryGetItemNo(CustomerNo, ItemRef, ItemNo, ErrorMessage);
        if ItemNo <> '' then
            exit('');

        if ErrorMessage <> '' then
            exit(ErrorMessage);
        exit('');
    end;

    [IntegrationEvent(false, false)]
    local procedure OnGetItemNo_TryGetItemNo(var CustomerNo: Code[20]; var ItemRef: Text[50]; var ItemNo: Code[20]; var ErrorMessage: Text)
    begin

    end;



    internal procedure ConvertBooleanToInt(Bool: Boolean): Integer
    begin
        if Bool then
            exit(1);
        exit(0);
    end;

    procedure ProcessOneProcess(ProcessCode: Code[20])
    var
        Process: Record EVS_DBC_Process;
        MessageMgmt: Codeunit EVS_DBC_MessageMgmt;

    begin
        if Process.Get(ProcessCode) then
            MessageMgmt.HandleOne(Process);
    end;

}
