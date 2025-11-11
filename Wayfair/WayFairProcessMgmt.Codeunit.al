codeunit 50551 DAR_PWF_WayfairProcessMgmt
{
    var
        WayfairManagement: Codeunit DAR_PWF_WayfairManagement;
        ErrorArray: array[1000] of Text[100];
        ErrorCount: Integer;
        ErrorsFound: Boolean;

    procedure ImportOrders(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        WayfairFileBuffer: Record DAR_PWF_WayfairFileBuffer;
        TxtInstream: InStream;
        LineArray: array[15] of Text;
        FullLine: Text;
        Line: Text;
        i: Integer;
        i2: Integer;
        ValueNo: Integer;
        EntryNo: Integer;
        ApostropheLbl: Label '''';
    begin
        //Get the stream
        EVSDBCMessageBatch.CalcFields(EVS_DBC_ImportExportFile);
        if not EVSDBCMessageBatch.EVS_DBC_ImportExportFile.HasValue() then
            exit;

        //read the file
        EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateInStream(TxtInstream);
        TxtInstream.Read(FullLine);

        WayfairFileBuffer.DeleteAll();
        for i := 1 to StrLen(FullLine) do
            if Format(FullLine[i]) <> ApostropheLbl then
                Line += Format(FullLine[i])
            else begin
                //process the line
                EntryNo += 1;
                WayfairFileBuffer.Init();
                WayfairFileBuffer.DAR_PWF_EntryNo := EntryNo;
                WayfairFileBuffer.DAR_PWF_LineType := CopyStr(Line, 1, 3);

                ValueNo := 1;
                for i2 := 5 to StrLen(Line) do
                    if not (Line[i2] in ['+', ':']) then
                        LineArray[ValueNo] += Format(Line[i2])
                    else
                        ValueNo += 1;

                //separate the line into columns - cannot compress or will show different columns each time where blanks!!!
                //COMPRESSARRAY(LineArray);

                for i2 := 1 to 14 do
                    if Format(LineArray[i2]) <> '' then
                        case i2 of
                            1:
                                WayfairFileBuffer.DAR_PWF_Value1 := Format(LineArray[i2]);
                            2:
                                WayfairFileBuffer.DAR_PWF_Value2 := Format(LineArray[i2]);
                            3:
                                WayfairFileBuffer.DAR_PWF_Value3 := Format(LineArray[i2]);
                            4:
                                WayfairFileBuffer.DAR_PWF_Value4 := Format(LineArray[i2]);
                            5:
                                WayfairFileBuffer.DAR_PWF_Value5 := Format(LineArray[i2]);
                            6:
                                WayfairFileBuffer.DAR_PWF_Value6 := Format(LineArray[i2]);
                            7:
                                WayfairFileBuffer.DAR_PWF_Value7 := Format(LineArray[i2]);
                            8:
                                WayfairFileBuffer.DAR_PWF_Value8 := Format(LineArray[i2]);
                            9:
                                WayfairFileBuffer.DAR_PWF_Value9 := Format(LineArray[i2]);
                            10:
                                WayfairFileBuffer.DAR_PWF_Value10 := Format(LineArray[i2]);
                            11:
                                WayfairFileBuffer.DAR_PWF_Value11 := Format(LineArray[i2]);
                            12:
                                WayfairFileBuffer.DAR_PWF_Value12 := Format(LineArray[i2]);
                            13:
                                WayfairFileBuffer.DAR_PWF_Value13 := Format(LineArray[i2]);
                            14:
                                WayfairFileBuffer.DAR_PWF_Value14 := Format(LineArray[i2]);
                            15:
                                WayfairFileBuffer.DAR_PWF_Value15 := Format(LineArray[i2]);
                        end;

                WayfairFileBuffer.Insert(true);
                Line := '';
                Clear(LineArray);
            end;

        SeparateOrders();
        ProcessIntoRemoteOrders(EVSDBCMessageBatch);
    end;

    local procedure SeparateOrders()
    var
        WayfairFileBuffer: Record DAR_PWF_WayfairFileBuffer;
        WayfairFileBufferOrders: Record DAR_PWF_WayfairFileBuffer;
        WayfairFileBufferLines: Record DAR_PWF_WayfairFileBuffer;
        WayfairFileBufferDetails: Record DAR_PWF_WayfairFileBuffer;
        NewLineNo: Integer;
    begin
        //>>Loop Through Imported lines & Copy Order No
        WayfairFileBuffer.Reset();
        WayfairFileBuffer.SetFilter(DAR_PWF_LineType, '%1', 'BGM');
        if WayfairFileBuffer.FindSet() then
            repeat
                WayfairFileBuffer.DAR_PWF_OrderNo := WayfairFileBuffer.DAR_PWF_OrderNo;
                WayfairFileBuffer.Modify(false);
                //>>Separate Orders & Stamp Order No
                WayfairFileBufferOrders.Reset();
                WayfairFileBufferOrders.SetFilter(DAR_PWF_EntryNo, '>%1', WayfairFileBuffer.DAR_PWF_EntryNo);
                WayfairFileBufferOrders.SetFilter(DAR_PWF_LineType, '<>%1', 'UNZ');
                if WayfairFileBufferOrders.FindSet() then
                    repeat
                        WayfairFileBufferOrders.DAR_PWF_OrderNo := WayfairFileBuffer.DAR_PWF_OrderNo;
                        WayfairFileBufferOrders.Modify(false);
                        //>>Stamp LIN lines with order line no
                        WayfairFileBufferLines.Reset();
                        WayfairFileBufferLines.SetFilter(DAR_PWF_LineType, '%1', 'LIN');
                        WayfairFileBufferLines.SetRange(DAR_PWF_OrderNo, WayfairFileBufferOrders.DAR_PWF_OrderNo);
                        if WayfairFileBufferLines.FindSet() then begin
                            NewLineNo := 0;
                            repeat
                                NewLineNo += 10000;
                                WayfairFileBufferLines.DAR_PWF_OrderLineNo := NewLineNo;
                                WayfairFileBufferLines.Modify(false);
                                //>>Copy order line no to corresponding Item lines
                                WayfairFileBufferDetails.Reset();
                                WayfairFileBufferDetails.SetFilter(DAR_PWF_EntryNo, '>%1', WayfairFileBufferLines.DAR_PWF_EntryNo);
                                if WayfairFileBufferDetails.FindSet() then
                                    repeat
                                        WayfairFileBufferDetails.DAR_PWF_OrderLineNo := WayfairFileBufferLines.DAR_PWF_OrderLineNo;
                                        WayfairFileBufferDetails.Modify(false);
                                    until (WayfairFileBufferDetails.Next() = 0) or ((WayfairFileBufferDetails.DAR_PWF_LineType = 'LIN') or (WayfairFileBufferDetails.DAR_PWF_LineType = 'UNS'));
                            //<<Copy order line no to corresponding Item lines
                            until (WayfairFileBufferLines.Next() = 0);
                        end;
                    //<<Stamp LIN lines with order line no
                    until (WayfairFileBufferOrders.Next() = 0) or (WayfairFileBufferOrders.DAR_PWF_LineType = 'UNT');
            //<<Separate Orders & Stamp Order No
            until WayfairFileBuffer.Next() = 0;
        //<<Loop Through Imported lines & Copy Order No
    end;

    local procedure ProcessIntoRemoteOrders(EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        WayfairFileBuffer: Record DAR_PWF_WayfairFileBuffer;
        EVSDBCMessageHeader: Record EVS_DBC_MessageHeader;
        EVSDBCMessageLine: Record EVS_DBC_MessageLine;
        GeneralLedgerSetup: Record "General Ledger Setup";
        Setting: Record DAR_PWF_Setting;
        TempCurrencyCode: Code[10];
        DTMDate: Text;
        StringLength: Integer;
        String: Text;
    begin
        Setting := Setting.GetSettings(EVSDBCMessageBatch.EVS_DBC_ProcessCode);

        // Need to check if the data has not been imported before.
        WayfairFileBuffer.Reset();
        if WayfairFileBuffer.FindSet() then
            repeat
                case WayfairFileBuffer.DAR_PWF_LineType of
                    'BGM':
                        begin
                            // Create a messageheader
                            EVSDBCMessageHeader.Init();
                            EVSDBCMessageHeader.Validate(EVS_DBC_MessageBatchID, EVSDBCMessageBatch.EVS_DBC_MessageBatchID);
                            EVSDBCMessageHeader.Validate(EVS_DBC_EntityTableNo, Database::"Sales Header");
                            EVSDBCMessageHeader.Validate(EVS_DBC_EntityTableType, 1);
                            EVSDBCMessageHeader.Validate(EVS_DBC_AccountCode, Setting.DAR_PWF_CustomerNo);
                            EVSDBCMessageHeader.Insert(true);

                            EVSDBCMessageHeader.Validate(EVS_DBC_HeaderRef1, WayfairFileBuffer.DAR_PWF_Value2);
                            EVSDBCMessageHeader.Validate(EVS_DBC_ExternalDocumentNo, WayfairFileBuffer.DAR_PWF_Value2);
                            EVSDBCMessageHeader.Validate(EVS_DBC_AddressCode, Setting.DAR_PWF_ShiptoCode);
                            EVSDBCMessageHeader.Validate(EVS_DBC_CreatedBy, UserId);
                            EVSDBCMessageHeader.Validate(EVS_DBC_ValidatedBy, 'SYSTEM');
                            EVSDBCMessageHeader.Modify(true);
                        end;
                    'DTM':
                        begin
                            DTMDate := WayfairFileBuffer.DAR_PWF_Value2;
                            DTMDate := CopyStr(DTMDate, 7, 2) + CopyStr(DTMDate, 5, 2) + CopyStr(DTMDate, 3, 2);
                            if WayfairFileBuffer.DAR_PWF_Value2 = '137' then begin
                                EVSDBCMessageHeader.Validate(EVS_DBC_RemoteOrderDate, DTMDate);
                                EVSDBCMessageHeader.Modify(true);
                            end;
                            if WayfairFileBuffer.DAR_PWF_Value1 = '85' then begin
                                EVSDBCMessageHeader.Validate(EVS_DBC_RemoteReqDeliveryDate, DTMDate);
                                EVSDBCMessageHeader.Modify(true);
                            end;
                        end;
                    'RFF':
                        if WayfairFileBuffer.DAR_PWF_Value1 = 'VA' then begin
                            EVSDBCMessageHeader.Validate(EVS_DBC_Text1, WayfairFileBuffer.DAR_PWF_Value2);
                            EVSDBCMessageHeader.Modify(true);
                        end;
                    'NAD':
                        if WayfairFileBuffer.DAR_PWF_Value1 = 'ST' then begin
                            EVSDBCMessageHeader.Validate(EVS_DBC_UseAddress, true);
                            EVSDBCMessageHeader.Validate(EVS_DBC_AddressName, CopyStr(WayfairFileBuffer.DAR_PWF_Value3, 1, 50));
                            EVSDBCMessageHeader.Validate(EVS_DBC_AddressName2, CopyStr(WayfairFileBuffer.DAR_PWF_Value4, 1, 50));
                            EVSDBCMessageHeader.Validate(EVS_DBC_Address, CopyStr(WayfairFileBuffer.DAR_PWF_Value5, 1, 50));
                            StringLength := StrLen(WayfairFileBuffer.DAR_PWF_Value6);
                            if StringLength > 30 then
                                EVSDBCMessageHeader.Validate(EVS_DBC_Address2, CopyStr(WayfairFileBuffer.DAR_PWF_Value6, 1, 50))
                            else
                                // Problem with : in the addresses being split, Need to check if from the end
                                if WayfairFileBuffer.DAR_PWF_Value10 <> '' then begin
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddressCity, CopyStr(WayfairFileBuffer.DAR_PWF_Value7, 1, 30));
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddressCounty, CopyStr(WayfairFileBuffer.DAR_PWF_Value8, 1, 30));
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddressPostcode, CopyStr(WayfairFileBuffer.DAR_PWF_Value9, 1, 20));
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddCountryRegionCode, CopyStr(WayfairFileBuffer.DAR_PWF_Value10, 1, 10));
                                end else begin
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddressCity, CopyStr(WayfairFileBuffer.DAR_PWF_Value6, 1, 30));
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddressCounty, CopyStr(WayfairFileBuffer.DAR_PWF_Value7, 1, 30));
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddressPostcode, CopyStr(WayfairFileBuffer.DAR_PWF_Value8, 1, 20));
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddCountryRegionCode, CopyStr(WayfairFileBuffer.DAR_PWF_Value9, 1, 10));
                                end;
                            EVSDBCMessageHeader.Modify(true);
                        end;
                    'COM':
                        begin
                            if WayfairFileBuffer.DAR_PWF_Value2 = 'TE' then begin
                                EVSDBCMessageHeader.Validate(EVS_DBC_ContactTelephone, CopyStr(WayfairFileBuffer.DAR_PWF_Value1, 1, 30));
                                EVSDBCMessageHeader.Modify(true);
                            end;
                            if WayfairFileBuffer.DAR_PWF_Value1 = 'https?' then begin
                                String := StrSubstNo('%1:%2', WayfairFileBuffer.DAR_PWF_Value1, WayfairFileBuffer.DAR_PWF_Value2);
                                String := String.Replace('https?://', '');
                                EVSDBCMessageHeader.EVS_DBC_TrackingURL := CopyStr(String.Replace('??', '?'), 1, 250);

                                EVSDBCMessageHeader.Modify(true);
                            end;
                        end;
                    'CUX':
                        begin
                            GeneralLedgerSetup.Get();
                            TempCurrencyCode := CopyStr(WayfairFileBuffer.DAR_PWF_Value2, 1, 10);
                            if WayfairFileBuffer.DAR_PWF_Value2 = GeneralLedgerSetup."LCY Code" then
                                TempCurrencyCode := '';
                            EVSDBCMessageHeader.Validate(EVS_DBC_RemoteCurrencyCode, TempCurrencyCode);
                            EVSDBCMessageHeader.Modify(true);
                        end;
                    'LIN':
                        begin
                            EVSDBCMessageLine.Init();
                            EVSDBCMessageLine.EVS_DBC_MessageLineID := 0;
                            EVSDBCMessageLine.Validate(EVS_DBC_MessageHeaderID, EVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
                            EVSDBCMessageLine.Validate(EVS_DBC_RemoteLineNumber, Format(WayfairFileBuffer.DAR_PWF_OrderLineNo));
                            EVSDBCMessageLine.Validate(EVS_DBC_LineRef1, Format(WayfairFileBuffer.DAR_PWF_OrderLineNo));
                            EVSDBCMessageLine.Validate(EVS_DBC_RemoteItemIDentifier, WayfairFileBuffer.DAR_PWF_Value3);
                            EVSDBCMessageLine.Insert(true);
                        end;
                    'IMD':
                        begin
                            EVSDBCMessageLine.Reset();
                            EVSDBCMessageLine.SetRange(EVS_DBC_MessageHeaderID, EVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
                            EVSDBCMessageLine.SetRange(EVS_DBC_RemoteLineNumber, Format(WayfairFileBuffer.DAR_PWF_OrderLineNo));
                            if EVSDBCMessageLine.FindFirst() then begin
                                EVSDBCMessageLine.Validate(EVS_DBC_Text2, WayfairFileBuffer.DAR_PWF_Value6);
                                EVSDBCMessageLine.Modify(true);
                            end;
                        end;
                    'QTY':
                        begin
                            EVSDBCMessageLine.Reset();
                            EVSDBCMessageLine.SetRange(EVS_DBC_MessageHeaderID, EVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
                            EVSDBCMessageLine.SetRange(EVS_DBC_RemoteLineNumber, Format(WayfairFileBuffer.DAR_PWF_OrderLineNo));
                            if EVSDBCMessageLine.FindFirst() then begin
                                EVSDBCMessageLine.Validate(EVS_DBC_RemoteQuantity, WayfairFileBuffer.DAR_PWF_Value2);
                                EVSDBCMessageLine.Modify(true);
                            end;
                        end;
                    'PRI':
                        begin
                            EVSDBCMessageLine.Reset();
                            EVSDBCMessageLine.SetRange(EVS_DBC_MessageHeaderID, EVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
                            EVSDBCMessageLine.SetRange(EVS_DBC_RemoteLineNumber, Format(WayfairFileBuffer.DAR_PWF_OrderLineNo));
                            if EVSDBCMessageLine.FindFirst() then begin
                                EVSDBCMessageLine.Validate(EVS_DBC_RemoteItemPrice, WayfairFileBuffer.DAR_PWF_Value2);
                                EVSDBCMessageLine.Modify(true);
                            end;
                        end;
                    'TDT':
                        begin
                            //for DAR, they use the normal Shipping Agent Code and Shipping Agent Service Code to direct picking
                            //therefore, two new fields were created to hold the "final destination" carrier information
                            EVSDBCMessageHeader.Validate(EVS_DBC_Code2, WayfairFileBuffer.DAR_PWF_Value5);
                            EVSDBCMessageHeader.Validate(EVS_DBC_Code3, WayfairFileBuffer.DAR_PWF_Value8);
                            EVSDBCMessageHeader.Modify(false);
                        end;
                end;
            until WayfairFileBuffer.Next() = 0;
    end;

    /*procedure ImportCancellations(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        WayfairFileBuffer: Record DAR_PWF_WayfairFileBuffer;
        TxtInstream: InStream;
        LineArray: array[15] of Text;
        FullLine: Text;
        Line: Text;
        i: Integer;
        i2: Integer;
        ValueNo: Integer;
        EntryNo: Integer;
        ApostropheLbl: label '''';
    begin
        //Get the stream
        EVSDBCMessageBatch.CalcFields(EVS_DBC_ImportExportFile);
        if not EVSDBCMessageBatch.EVS_DBC_ImportExportFile.HasValue() then
            exit;

        //read the file
        EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateInStream(TxtInstream);
        TxtInstream.Read(FullLine);

        WayfairFileBuffer.LockTable();
        WayfairFileBuffer.DeleteAll();

        for i := 1 to StrLen(FullLine) do
            if Format(FullLine[i]) <> ApostropheLbl then
                Line += Format(FullLine[i])
            else begin
                //process the line
                EntryNo += 1;
                WayfairFileBuffer.Init();
                WayfairFileBuffer.DAR_PWF_EntryNo := EntryNo;
                WayfairFileBuffer.DAR_PWF_LineType := CopyStr(Line, 1, 3);

                ValueNo := 1;
                for i2 := 5 to StrLen(Line) do
                    if not (Line[i2] in ['+', ':']) then
                        LineArray[ValueNo] += Format(Line[i2])
                    else
                        ValueNo += 1;

                //separate the line into columns - cannot compress or will show different columns each time where blanks!!!
                for i2 := 1 to 14 do
                    if Format(LineArray[i2]) <> '' then
                        case i2 of
                            1:
                                WayfairFileBuffer.DAR_PWF_Value1 := Format(LineArray[i2]);
                            2:
                                WayfairFileBuffer.DAR_PWF_Value2 := Format(LineArray[i2]);
                            3:
                                WayfairFileBuffer.DAR_PWF_Value3 := Format(LineArray[i2]);
                            4:
                                WayfairFileBuffer.DAR_PWF_Value4 := Format(LineArray[i2]);
                            5:
                                WayfairFileBuffer.DAR_PWF_Value5 := Format(LineArray[i2]);
                            6:
                                WayfairFileBuffer.DAR_PWF_Value6 := Format(LineArray[i2]);
                            7:
                                WayfairFileBuffer.DAR_PWF_Value7 := Format(LineArray[i2]);
                            8:
                                WayfairFileBuffer.DAR_PWF_Value8 := Format(LineArray[i2]);
                            9:
                                WayfairFileBuffer.DAR_PWF_Value9 := Format(LineArray[i2]);
                            10:
                                WayfairFileBuffer.DAR_PWF_Value10 := Format(LineArray[i2]);
                            11:
                                WayfairFileBuffer.DAR_PWF_Value11 := Format(LineArray[i2]);
                            12:
                                WayfairFileBuffer.DAR_PWF_Value12 := Format(LineArray[i2]);
                            13:
                                WayfairFileBuffer.DAR_PWF_Value13 := Format(LineArray[i2]);
                            14:
                                WayfairFileBuffer.DAR_PWF_Value14 := Format(LineArray[i2]);
                            15:
                                WayfairFileBuffer.DAR_PWF_Value15 := Format(LineArray[i2]);
                        end;

                WayfairFileBuffer.Insert(true);
                Line := '';
                Clear(LineArray);
            end;


        if WayfairFileBuffer.Count = 0 then begin
            CaptureError('No Records found ');
            exit;
        end;

        ProcessOrder(EVSDBCMessageBatch);
    end;

    local procedure ProcessOrder(var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        WayfairFileBuffer: Record DAR_PWF_WayfairFileBuffer;
        SalesHeader: Record "Sales Header";
        WayfairCancellationLog: Record DAR_PWF_WayfairCancellationLog;
        SalesHeaderArchive: Record "Sales Header Archive";
        Setting: Record DAR_PWF_Setting;
        WayfairCustomerNav: Code[20];
        WayfairOrderNumber: Text[30];
        ItemNumber: Text[20];
        DTMDate: Text[20];
        DateShipped: Date;
        ItemsFound: Integer;
        ItemsCount: Integer;
        QtyToCancel: Integer;
        FullLine: Boolean;
        FullOrder: Boolean;
        Accepted: Boolean;
        OriginalQty: Integer;
        EntryNo: Integer;
    begin
        Setting := Setting.GetSettings(EVSDBCMessageBatch.EVS_DBC_ProcessCode);
        WayfairCustomerNav := Setting.DAR_PWF_OrderCancel;

        //Process all orders in file
        WayfairCancellationLog.Reset();
        if WayfairCancellationLog.FindLast() then
            EntryNo := WayfairCancellationLog.DAR_PWF_EntryNo + 1
        else
            EntryNo := 1;
        WayfairFileBuffer.Reset();
        if WayfairFileBuffer.FindSet() then begin
            WayfairCancellationLog.Init();
            WayfairCancellationLog.DAR_PWF_EntryNo := EntryNo;
            repeat
                case WayfairFileBuffer.DAR_PWF_LineType of
                    'BGM':
                        begin
                            WayfairOrderNumber := '';
                            if (WayfairFileBuffer.DAR_PWF_Value2 = '') then begin
                                CaptureError('Missing Order No.');
                                exit;
                            end;
                            WayfairOrderNumber := CopyStr(WayfairFileBuffer.DAR_PWF_Value2, 1, 20);
                            WayfairCancellationLog.DAR_PWF_WayfairOrderNo := CopyStr(WayfairOrderNumber, 1, 30);
                            Clear(FullOrder);
                            if WayfairFileBuffer.DAR_PWF_Value3 = '1' then
                                FullOrder := true;
                            Clear(SalesHeader);
                            DateShipped := 0D;
                            ItemsCount := 0;
                            ItemsFound := 0;
                        end;
                    'DTM':
                        if (WayfairOrderNumber <> '') and (WayfairFileBuffer.DAR_PWF_Value1 = '137') and (WayfairFileBuffer.DAR_PWF_Value2 <> '') then begin
                            DTMDate := CopyStr(WayfairFileBuffer.DAR_PWF_Value2, 1, 20);
                            DTMDate := CopyStr(DTMDate, 7, 2) + CopyStr(DTMDate, 5, 2) + CopyStr(DTMDate, 3, 2);
                            Evaluate(DateShipped, DTMDate);
                        end;
                    'RFF':
                        if (WayfairOrderNumber <> '') and (WayfairFileBuffer.DAR_PWF_Value1 = 'IA') then begin
                            SalesHeader.Reset();
                            SalesHeader.SetCurrentkey("Sell-to Customer No.", "External Document No.");
                            SalesHeader.SetRange("Sell-to Customer No.", WayfairCustomerNav);
                            SalesHeader.SetRange("External Document No.", WayfairOrderNumber);
                            SalesHeader.SetRange("Document Type", SalesHeader."document type"::Order);
                            if not SalesHeader.FindFirst() then begin
                                //Check Posted Sales Orders in the event the Sales Order has already been posted
                                SalesHeaderArchive.Reset();
                                SalesHeaderArchive.SetRange("Document Type", SalesHeaderArchive."document type"::Order);
                                SalesHeaderArchive.SetCurrentkey("Document Type", "Sell-to Customer No.");
                                SalesHeaderArchive.SetRange("Sell-to Customer No.", WayfairCustomerNav);
                                SalesHeaderArchive.SetRange("External Document No.", WayfairOrderNumber);
                                if not SalesHeaderArchive.FindFirst() then begin
                                    CaptureError('Order not found : ' + WayfairOrderNumber);
                                    Accepted := false;
                                    exit;
                                end else begin
                                    Accepted := false;
                                    WayfairCancellationLog.DAR_PWF_Rejected := true;
                                    WayfairCancellationLog.Insert();
                                    //SendCancellationResponseArchive(SalesHeaderArchive, Accepted); //send rejection TO REVISIT
                                    exit;
                                end;
                            end else begin
                                WayfairCancellationLog.DAR_PWF_OrderNo := SalesHeader."No.";
                                if FullOrder then begin
                                    SalesHeader."Shipment Date" := DateShipped;
                                    if not CancelFullOrder(EVSDBCMessageBatch, SalesHeader) then begin
                                        Accepted := false;
                                        WayfairCancellationLog.DAR_PWF_Rejected := true;
                                        WayfairCancellationLog.Insert();
                                        SendCancellationResponse(SalesHeader, Accepted); //send rejection
                                        exit;
                                    end else begin
                                        Accepted := true;
                                        WayfairCancellationLog.DAR_PWF_Accepted := true;
                                        WayfairCancellationLog.Insert();
                                        SendCancellationResponse(SalesHeader, Accepted); //send acceptance
                                        exit;
                                    end;
                                end;
                            end;
                        end;
                    'LIN':
                        begin
                            ItemNumber := '';
                            if (SalesHeader."No." <> '') then begin
                                Clear(FullLine);
                                if WayfairFileBuffer.DAR_PWF_Value2 = '2' then
                                    FullLine := true;
                                if WayfairFileBuffer.DAR_PWF_Value2 = '3' then
                                    FullLine := false;
                                if WayfairFileBuffer.DAR_PWF_Value3 <> '' then begin
                                    ItemNumber := CopyStr(WayfairFileBuffer.DAR_PWF_Value3, 1, 20);
                                    WayfairCancellationLog.DAR_PWF_ItemNo := ItemNumber;
                                end else begin
                                    CaptureError('Item Number missing');
                                    exit;
                                end;
                            end;
                        end;
                    'QTY':
                        if (SalesHeader."No." <> '') then
                            //Cancel Line - if part cancel remove entire line, correct SO and let committer recreate shipment so delete full whse shipment line
                            if (WayfairFileBuffer.DAR_PWF_Value1 = '113') and (not FullOrder) then begin
                                Clear(QtyToCancel);
                                Evaluate(QtyToCancel, WayfairFileBuffer.DAR_PWF_Value2);
                                WayfairCancellationLog.DAR_PWF_QtytoCancel := QtyToCancel;
                                if not CancelLine(EVSDBCMessageBatch, SalesHeader, ItemNumber, QtyToCancel, FullLine) then begin
                                    Accepted := false;
                                    WayfairCancellationLog.DAR_PWF_Rejected := true;
                                    WayfairCancellationLog.Insert();
                                    SendCancellationResponse(SalesHeader, Accepted); //send rejection
                                    exit;
                                end else
                                    Accepted := true;
                            end else
                                if (WayfairFileBuffer.DAR_PWF_Value1 = '21') and (not FullOrder) then begin
                                    Clear(OriginalQty);
                                    Evaluate(OriginalQty, WayfairFileBuffer.DAR_PWF_Value2);
                                    WayfairCancellationLog.DAR_PWF_OriginalQty := OriginalQty;
                                end;
                    'CNT':
                        if (SalesHeader."No." <> '') then begin
                            if WayfairFileBuffer.DAR_PWF_Value2 <> '' then
                                Evaluate(ItemsCount, CopyStr(WayfairFileBuffer.DAR_PWF_Value2, 1, 10))
                            else begin
                                CaptureError('Item Count missing');
                                exit;
                            end;

                            if ItemsCount <> ItemsFound then begin
                                CaptureError('Items Count differs from Items Found');
                                exit;
                            end;
                        end;
                end;
            until WayfairFileBuffer.Next() = 0;
            WayfairCancellationLog.DAR_PWF_Accepted := true;
            WayfairCancellationLog.Insert();
            SendCancellationResponse(SalesHeader, Accepted);
        end;
    end;

    local procedure CaptureError(ErrorMessage: Text)
    begin
        ErrorCount += 1;
        ErrorArray[ErrorCount] := CopyStr(ErrorMessage, 1, 100);

        //EDIProcess."Error String" := ErrorMessage;
        //EDIProcess."Error DateTime" := CurrentDatetime;
    end;

    local procedure CancelLine(EVSDBCMessageBatch: Record EVS_DBC_MessageBatch; p_SalesHeader: Record "Sales Header"; p_ItemNumber: Text[20]; p_QtyToCancel: Integer; FullLine: Boolean): Boolean
    var
        SalesLine: Record "Sales Line";
        WarehouseShipmentLine: Record "Warehouse Shipment Line";
        WarehouseShipmentHeader: Record "Warehouse Shipment Header";
        WarehouseShipmentLine2: Record "Warehouse Shipment Line";
        WarehouseShipmentHeader2: Record "Warehouse Shipment Header";
        Setting: Record DAR_PWF_Setting;
        WhseShipmentRelease: Codeunit "Whse.-Shipment Release";
        SalesLineManagement: Codeunit EVS_ESF_CancellationMgt;
        QtytoCancel: Decimal;
    begin
        //Get Setting
        Setting := Setting.GetSettings(EVSDBCMessageBatch.EVS_DBC_ProcessCode);
        QtytoCancel := 0;

        SalesLine.Reset();
        SalesLine.SetRange("Document Type", p_SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", p_SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter("No.", p_ItemNumber);
        SalesLine.SetFilter("Quantity Shipped", '=%1', 0);
        if SalesLine.FindSet() then begin
            repeat
                SalesLine.CalcFields("Whse. Outstanding Qty.");
                if SalesLine."Whse. Outstanding Qty." > 0 then begin
                    //Qtys are on shipments, check for stock transfers and picks
                    WarehouseShipmentLine.SetRange("Source Type", Database::"Sales Line");
                    WarehouseShipmentLine.SetRange("Source No.", p_SalesHeader."No.");
                    WarehouseShipmentLine.SetFilter("Item No.", p_ItemNumber);
                    if WarehouseShipmentLine.FindSet() then
                        repeat
                            WarehouseShipmentLine.CalcFields("Pick Qty.");
                            if WarehouseShipmentLine.DAR_COR_TransferReqExists or WarehouseShipmentLine.DAR_COR_TransReqOrderExists or
                              (WarehouseShipmentLine."Pick Qty." > 0) or (WarehouseShipmentLine."Qty. Picked" > 0) then
                                exit(false);
                            WarehouseShipmentHeader.Get(WarehouseShipmentLine."No.");
                            WarehouseShipmentLine.SuspendStatusCheck(true);
                            WarehouseShipmentLine.Delete(true);
                            //if the warehouse shipment is now empty - delete it
                            WarehouseShipmentLine2.Reset();
                            WarehouseShipmentLine2.SetRange("No.", WarehouseShipmentHeader."No.");
                            if WarehouseShipmentLine2.IsEmpty then begin
                                WarehouseShipmentHeader.Get(WarehouseShipmentHeader."No."); //refresh
                                WhseShipmentRelease.Reopen(WarehouseShipmentHeader);
                                WarehouseShipmentHeader2.Get(WarehouseShipmentHeader."No.");
                                WarehouseShipmentHeader2.Delete(true);
                            end;
                        until WarehouseShipmentLine.Next() = 0;
                end;
                //Nothing on Shipment so can cancel order
                if not FullLine then
                    QtytoCancel := (SalesLine.Quantity - p_QtyToCancel);

                SalesLineManagement.CancelSalesLine(SalesLine, 'Reason', QtytoCancel);
                SalesLine.Modify(); // no modify() in the above function
            until SalesLine.Next() = 0;
            exit(true);
        end;
        exit(false);
    end;

    local procedure CancelFullOrder(EVSDBCMessageBatch: Record EVS_DBC_MessageBatch; p_SalesHeader: Record "Sales Header"): Boolean
    var
        SalesLine: Record "Sales Line";
        WarehouseShipmentLine: Record "Warehouse Shipment Line";
        WarehouseShipmentHeader: Record "Warehouse Shipment Header";
        WarehouseShipmentLine2: Record "Warehouse Shipment Line";
        WarehouseShipmentHeader2: Record "Warehouse Shipment Header";
        SalesHeader: Record "Sales Header";
        Setting: Record DAR_PWF_Setting;
        TempWhseShipmentLine: Record "Warehouse Shipment Line" temporary;
        WhseShipmentRelease: Codeunit "Whse.-Shipment Release";
        SalesHeaderManagement: Codeunit EVS_ESF_CancellationMgt;
    begin
        //Get Setting
        Setting := Setting.GetSettings(EVSDBCMessageBatch.EVS_DBC_ProcessCode);

        SalesLine.Reset();
        SalesLine.SetRange("Document Type", p_SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", p_SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        if SalesLine.FindSet() then begin
            repeat
                if (SalesLine."Quantity Shipped" <> 0) then
                    exit(false);
                SalesLine.CalcFields("Whse. Outstanding Qty.");
                if SalesLine."Whse. Outstanding Qty." > 0 then begin
                    //Qtys are on shipments, check for stock transfers and picks
                    WarehouseShipmentLine.SetRange("Source Type", Database::"Sales Line");
                    WarehouseShipmentLine.SetRange("Source Subtype", SalesLine."Document Type");
                    WarehouseShipmentLine.SetRange("Source No.", SalesLine."Document No.");
                    WarehouseShipmentLine.SetRange("Source Line No.", SalesLine."Line No.");
                    if WarehouseShipmentLine.FindSet() then begin
                        TempWhseShipmentLine.DeleteAll();
                        repeat
                            WarehouseShipmentLine.CalcFields("Pick Qty.");
                            if WarehouseShipmentLine.DAR_COR_TransferReqExists or WarehouseShipmentLine.DAR_COR_TransReqOrderExists or
                              (WarehouseShipmentLine."Pick Qty." <> 0) or (WarehouseShipmentLine."Qty. Picked" <> 0) then
                                exit(false);
                            //build a temp table or lines that can be deleted.
                            TempWhseShipmentLine := WarehouseShipmentLine;
                            TempWhseShipmentLine.Insert();
                        until WarehouseShipmentLine.Next() = 0;
                    end;
                end;
            until SalesLine.Next() = 0;

            if TempWhseShipmentLine.FindSet() then
                repeat
                    //delete the warehouse shipment lines
                    WarehouseShipmentLine.Get(TempWhseShipmentLine."No.", TempWhseShipmentLine."Line No.");
                    WarehouseShipmentLine.SuspendStatusCheck(true);
                    WarehouseShipmentLine.Delete(true);
                    //check to see if the warehouse shipment needs removing
                    WarehouseShipmentLine2.Reset();
                    WarehouseShipmentLine2.SetRange("No.", WarehouseShipmentLine."No.");
                    if WarehouseShipmentLine2.IsEmpty then begin
                        WarehouseShipmentHeader.Get(WarehouseShipmentLine."No.");
                        WhseShipmentRelease.Reopen(WarehouseShipmentHeader);
                        WarehouseShipmentHeader2.Get(WarehouseShipmentHeader."No.");
                        WarehouseShipmentHeader2.Delete(true);
                    end;
                until TempWhseShipmentLine.Next() = 0;


            SalesHeader.Get(p_SalesHeader."Document Type", p_SalesHeader."No.");
            SalesHeaderManagement.CancelSalesHeader(SalesHeader, Setting.DAR_PWF_CancelReason);
            SalesHeader.Modify();
            exit(true);
        end else
            exit(false);
    end;

    local procedure SendCancellationResponse(var p_SalesHeader: Record "Sales Header"; Accepted: Boolean)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        //TempVATAmountLine: Record "VAT Amount Line" temporary;
        PreviousOrderNo: Text;
        NoOfLineItems: Integer;
        SegmentCount: Integer;
        SeparatorCount: Integer;
        DocCount: Integer;
    begin
        NoOfLineItems := 0;
        SeparatorCount := 0;

        SalesHeader.SetRange(SalesHeader."Document Type", p_SalesHeader."Document Type");
        SalesHeader.SetRange(SalesHeader."No.", p_SalesHeader."No.");
        if SalesHeader.FindSet() then begin
            PreviousOrderNo := '';
            //InvoiceCreateExportFile(Accepted); TO REVISIT
            // *** Envelope Header ***
            //InsertInvoiceEnvelopeHeader(DocCount, 'ORDRSP'); //CUSTOM ENVELOPE HEADER TO REVISIT
            // Loop through the rows
            repeat
                // *** Header ***
                //InvoiceAddFileHeader(SalesHeader, 'ORDRSP', Accepted); //+-GL0869 added separator count, doc type TO REVISIT

                // *** Lines ***
                SalesLine.Reset();
                SalesLine.SetRange("Document Type", SalesHeader."Document Type");
                SalesLine.SetRange("Document No.", SalesHeader."No.");
                SalesLine.SetRange(Type, SalesLine.Type::Item);
                if SalesLine.FindSet() then
                    repeat
                        NoOfLineItems += 1;
                    //InvoiceAddLineLoop(SalesLine, NoOfLineItems, SegmentCount)TO REVISIT;
                    //*<<Calc no of orders per invoice TO Revisit
                    until SalesLine.Next() = 0;

            //InvoiceAddMidSection(SalesHeader, TempVATAmountLine, NoOfLineItems, SegmentCount); TO REVISIT

            //InsertInvoiceExportSeparator(SegmentCount, SeparatorCount)TO REVISIT;     //CUSTOM INVOICE SEPARATOR was segmentcount 05/07/2019 changed doc count to separator count 26/07/2019

            until SalesHeader.Next() = 0;
            //InsertInvoiceEnvelopeFooter(DocCount, 'INVOIC');     //CUSTOM ENVELOPE FOOTER TO REVISIT
            //WayfairExportFile.Close(); TO REVISIT
        end;

    end;

    local procedure InvoiceCreateExportFile(Accepted: Boolean)
    var
        EDIProcessCodeunit: Codeunit UnknownCodeunit50150;
        NextNoSeries: Code[20];
        FilePath: Text;
        FileNameStart: Text;
        DateTimeString: Text;
        FileLocation: Text;
    begin

        FileNameStart := EDIProcess.GetSettingsText('WAYFAIR CANCEL FILENAME');
        if Accepted then
            FileLocation := EDIProcess.GetSettingsText('ACCEPTED FILE LOCATION')
        else
            FileLocation := EDIProcess.GetSettingsText('REJECTED FILE LOCATION');
        DateTimeString := Format(Today, 8, DateFormat) + Format(Time, 4, TimeFormathhmm);  //GL0033 changed TODAY,6 to TODAY,8
        WayfairExportFile.Create(FileLocation + FileNameStart + DateTimeString + EDIProcess."File extension");
        WayfairExportFile.CreateOutstream(WayfairOutstream);
    end;

    local procedure InvoiceAddFileHeader(SalesHeader: Record "Sales Header"; pDocType: Text; Accepted: Boolean)
    var
        CompanyInformation: Record "Company Information";
        GeneralLedgerSetup: Record "General Ledger Setup";
        PaymentTerms: Record "Payment Terms";
        EDIProcessCodeunit: Codeunit UnknownCodeunit50150;
        TempCurrencyCode: Code[20];
        ShipToCountryCode: Code[10];
        BillToCountryCode: Code[10];
    begin
        CompanyInformation.Get;
        GeneralLedgerSetup.Get;

        Clear(TempCurrencyCode);
        Clear(ShipToCountryCode);
        Clear(BillToCountryCode);

        begin
            InsertNewLine('UNH+' + '+' + pDocType + ':D:96A:UN:EAN008', true);  //+-GL0869 26/07/2019 add UNH section per invoice accumulating counter plus doc type
            if Accepted then
                InsertNewLine('BGM+230+' + SalesHeader."No." + '+29', true) //Accepted
            else
                InsertNewLine('BGM+230+' + SalesHeader."No." + '+27', true); //Rejected
            InsertNewLine('DTM+137:' + Format(SalesHeader."Document Date", 8, DateFormat) + ':102', true);
            InsertNewLine('RFF+ON:' + SalesHeader."External Document No.", true);
            InsertNewLine('DTM+171:' + Format(SalesHeader."Document Date", 8, DateFormat) + ':102', true);
            InsertNewLine('RFF+IA:' + EDIProcess.GetSettingsText('DAR SUPPLIER ID'), true);    //SUPPLIERID
            InsertNewLine('RFF+VA:' + SalesHeader."VAT Registration No.", true); //* GB922944513 FOR GB, DE260823026 FOR GERMANY, IE9685420B FOR IRELAND, ATU69924415 FOR AUSTRIA - Expect these to come through from order  but NOT CURRENTLY USING ACCORDING TO DAR/
            if SalesHeader."Ship-to Country/Region Code" = '' then
                ShipToCountryCode := EDIProcess.GetSettingsText('WAYFAIR LOCAL COUNTRY CODE')
            else
                ShipToCountryCode := SalesHeader."Ship-to Country/Region Code";                                                                          //+-GL0869 cut to 9 char
            InsertNewLine('NAD+ST++' + SalesHeader."Ship-to Name" + '++' + SalesHeader."Ship-to Address" + ':' + SalesHeader."Ship-to Address 2" + '+' + SalesHeader."Ship-to City" + '+' + CopyStr(SalesHeader."Ship-to County", 1, 9) + '+' + SalesHeader."Ship-to Post Code" + '+' + ShipToCountryCode, true);
        end;

    end;

    local procedure InvoiceAddLineLoop(SalesLine: Record "Sales Line"; NoOfLineItems: Integer; var SegmentCount: Integer)
    var
        UnitPrice: Text;
        DotPos: Integer;
        AutoFormatType: Option ,Amount,UnitAmount,Other;
    begin
        begin
            if SalesLine.Type <> SalesLine.Type::Item then
                exit;
            InsertNewLine('LIN+' + Format(NoOfLineItems) + '++' + SalesLine."No." + ':GB', true);
            InsertNewLine('IMD+F++:::' + CopyStr(SalesLine.Description, 1, 35), true);  //+-GL0033
            InsertNewLine('QTY+12:' + Format(SalesLine.Quantity), true);
            if SalesLine.Quantity <> 0 then
                UnitPrice := FormatAmt(ROUND(SalesLine.Amount / SalesLine.Quantity, 0.01, '='), SalesLine."Currency Code", Autoformattype::UnitAmount)
            else
                UnitPrice := FormatAmt(ROUND(SalesLine.Amount, 0.01, '='), SalesLine."Currency Code", Autoformattype::UnitAmount);
            DotPos := StrPos(UnitPrice, '.');
            if DotPos = 0 then
                UnitPrice += '.00'
            else
                if DotPos = StrLen(UnitPrice) - 1 then
                    UnitPrice += '.0';
            if UnitPrice <> '' then
                InsertNewLine('MOA+146:' + UnitPrice, true)
            else
                InsertNewLine('MOA+146:' + Format(SalesLine."Unit Price"), true);  //-GL1022
        end;

        SegmentCount += 4;
    end;

    local procedure InvoiceAddMidSection(SalesHeader: Record "Sales Header"; TempVATAmountLine: Record "VAT Amount Line" temporary; NoOfLineItems: Integer; var SegmentCount: Integer)
    var
        CompanyInformation: Record "Company Information";
    begin
        CompanyInformation.Get;

        InsertNewLine('UNS+S', true);
        InsertNewLine('CNT+2:' + Format(NoOfLineItems), true);

        InsertNewLine('MOA+86:' + Format(TempVATAmountLine."Amount Including VAT", 0, '<Sign><Integer><Decimals>'), true);
        InsertNewLine('MOA+79:' + Format(TempVATAmountLine."Line Amount", 0, '<Sign><Integer><Decimals>'), true);
        InsertNewLine('TAX+7+VAT+++:::' + Format(TempVATAmountLine."VAT %") + '++' + CompanyInformation."VAT Registration No.", true);
        InsertNewLine('MOA+124:' + Format(TempVATAmountLine."VAT Amount", 0, '<Sign><Integer><Decimals>'), true);
        InsertNewLine('MOA+125:' + Format(TempVATAmountLine."VAT Base", 0, '<Sign><Integer><Decimals>'), true);
        SegmentCount += 7;
    end;

    local procedure InsertInvoiceEnvelopeHeader(DocCount: Integer; DocType: Text)
    var
        LeadChar: Text[1];
    begin
        LeadChar := '';
        LeadChar := '0';
        InsertNewLine('UNA:+.?', true);
        InsertNewLine('UNB+UNOA:3+35128000003:14+112084681:1+' + Format(Today, 6, DateFormatyymmdd) + ':' + LeadChar + Format(Time, 3, TimeFormathhmm) + '+943000001++', true)
    end;

    local procedure InsertInvoiceExportSeparator(NoOfSegments: Integer; DocCount: Integer)
    begin
        InsertNewLine('UNT+' + Format(NoOfSegments + 2) + '+' + Format(DocCount), true);
        //+-GL0869 11/07/2019 added '+2'
    end;

    local procedure InsertInvoiceEnvelopeFooter(DocCount: Integer; DocType: Text)
    begin
        InsertNewLine('UNZ+' + Format(DocCount) + '+943000001', true);
    end;

    local procedure InsertNewLine(Passed_Text: Text; Complete_Line: Boolean)
    var
        LineSeparator: label '''';
    begin
        WayfairOutstream.WriteText(Passed_Text);
        if Complete_Line then
            WayfairOutstream.WriteText(LineSeparator);
    end;

    local procedure FormatAmt(Amount: Decimal; AutoFormatExpr: Text[80]; AutoFormatType: Option ,Amount,UnitAmount,Other): Text[80]
    var
        ApplicationMgt: Codeunit ApplicationManagement;
        FormatStr: Text[80];
    begin
        FormatStr := ApplicationMgt.AutoFormatTranslate(AutoFormatType, AutoFormatExpr);
        exit(Format(Amount, 0, FormatStr));
    end;

    local procedure SendCancellationResponseArchive(var p_SalesHeaderArchive: Record "Sales Header Archive"; var Accepted: Boolean)
    var
        SalesHeaderArchive: Record "Sales Header Archive";
        SalesInvoiceHeader2: Record "Sales Invoice Header";
        SalesLineArchive: Record "Sales Line Archive";
        TempVATAmountLine: Record "VAT Amount Line" temporary;
        PreviousOrderNo: Text;
        NoOfLineItems: Integer;
        SegmentCount: Integer;
        SeparatorCount: Integer;
        DocCount: Integer;
    begin
        NoOfLineItems := 0;
        SeparatorCount := 0; //+-GL0869 26/07/2019

        begin
            SalesHeaderArchive.SetRange(SalesHeaderArchive."Document Type", p_SalesHeaderArchive."Document Type");
            SalesHeaderArchive.SetRange(SalesHeaderArchive."No.", p_SalesHeaderArchive."No.");
            if SalesHeaderArchive.FindSet then begin
                PreviousOrderNo := '';
                InvoiceCreateExportFile(Accepted);
                // *** Envelope Header ***
                InsertInvoiceEnvelopeHeader(DocCount, 'ORDRSP'); //CUSTOM ENVELOPE HEADER
                                                                 // Loop through the rows
                repeat
                    // *** Header ***
                    InvoiceAddFileHeaderArchive(SalesHeaderArchive, 'ORDRSP', Accepted); //+-GL0869 added separator count, doc type

                    // *** Lines ***
                    SalesLineArchive.Reset;
                    SalesLineArchive.SetRange("Document Type", SalesHeaderArchive."Document Type");
                    SalesLineArchive.SetRange("Document No.", SalesHeaderArchive."No.");
                    SalesLineArchive.SetRange("Version No.", SalesHeaderArchive."Version No.");
                    SalesLineArchive.SetRange(Type, SalesLineArchive.Type::Item);
                    if SalesLineArchive.FindSet then begin
                        repeat
                            NoOfLineItems += 1;
                            InvoiceAddLineLoopArchive(SalesLineArchive, NoOfLineItems, SegmentCount);
                        //*<<Calc no of orders per invoice/
                        until SalesLineArchive.Next = 0;
                    end;
                    InvoiceAddMidSectionArchive(SalesHeaderArchive, TempVATAmountLine, NoOfLineItems, SegmentCount);

                    InsertInvoiceExportSeparator(SegmentCount, SeparatorCount);     //CUSTOM INVOICE SEPARATOR was segmentcount 05/07/2019 changed doc count to separator count 26/07/2019

                until SalesHeaderArchive.Next = 0;
                InsertInvoiceEnvelopeFooter(DocCount, 'INVOIC');     //CUSTOM ENVELOPE FOOTER
                WayfairExportFile.Close;
            end;
        end;

    end;

    local procedure InvoiceAddFileHeaderArchive(SalesHeaderArchive: Record "Sales Header Archive"; pDocType: Text; Accepted: Boolean)
    var
        CompanyInformation: Record "Company Information";
        GeneralLedgerSetup: Record "General Ledger Setup";
        PaymentTerms: Record "Payment Terms";
        EDIProcessCodeunit: Codeunit UnknownCodeunit50150;
        TempCurrencyCode: Code[20];
        ShipToCountryCode: Code[10];
        BillToCountryCode: Code[10];
    begin
        CompanyInformation.Get;
        GeneralLedgerSetup.Get;

        Clear(TempCurrencyCode);
        Clear(ShipToCountryCode);
        Clear(BillToCountryCode);

        begin
            InsertNewLine('UNH+' + '+' + pDocType + ':D:96A:UN:EAN008', true);  //+-GL0869 26/07/2019 add UNH section per invoice accumulating counter plus doc type
            if Accepted then
                InsertNewLine('BGM+230+' + SalesHeaderArchive."No." + '+29', true) //Accepted
            else
                InsertNewLine('BGM+230+' + SalesHeaderArchive."No." + '+27', true); //Rejected
            InsertNewLine('DTM+137:' + Format(SalesHeaderArchive."Document Date", 8, DateFormat) + ':102', true);
            InsertNewLine('RFF+ON:' + SalesHeaderArchive."External Document No.", true);
            InsertNewLine('DTM+171:' + Format(SalesHeaderArchive."Document Date", 8, DateFormat) + ':102', true);
            InsertNewLine('RFF+IA:' + EDIProcess.GetSettingsText('DAR SUPPLIER ID'), true);    //SUPPLIERID
            InsertNewLine('RFF+VA:' + SalesHeaderArchive."VAT Registration No.", true); //* GB922944513 FOR GB, DE260823026 FOR GERMANY, IE9685420B FOR IRELAND, ATU69924415 FOR AUSTRIA - Expect these to come through from order  but NOT CURRENTLY USING ACCORDING TO DAR/
            if SalesHeaderArchive."Ship-to Country/Region Code" = '' then
                ShipToCountryCode := EDIProcess.GetSettingsText('WAYFAIR LOCAL COUNTRY CODE')
            else
                ShipToCountryCode := SalesHeaderArchive."Ship-to Country/Region Code";                                                                          //+-GL0869 cut to 9 char
            InsertNewLine('NAD+ST++' + SalesHeaderArchive."Ship-to Name" + '++' + SalesHeaderArchive."Ship-to Address" + ':' + SalesHeaderArchive."Ship-to Address 2" + '+' + SalesHeaderArchive."Ship-to City" + '+' + CopyStr(SalesHeaderArchive."Ship-to County", 1, 9) + '+' + SalesHeaderArchive."Ship-to Post Code" + '+' + ShipToCountryCode, true);
        end;

    end;

    local procedure InvoiceAddLineLoopArchive(SalesLineArchive: Record "Sales Line Archive"; NoOfLineItems: Integer; var SegmentCount: Integer)
    var
        UnitPrice: Text;
        DotPos: Integer;
        AutoFormatType: Option ,Amount,UnitAmount,Other;
    begin
        begin
            if SalesLineArchive.Type <> SalesLineArchive.Type::Item then
                exit;
            InsertNewLine('LIN+' + Format(NoOfLineItems) + '++' + SalesLineArchive."No." + ':GB', true);
            InsertNewLine('IMD+F++:::' + CopyStr(SalesLineArchive.Description, 1, 35), true);  //+-GL0033
            InsertNewLine('QTY+12:' + Format(SalesLineArchive.Quantity), true);
            if SalesLineArchive.Quantity <> 0 then
                UnitPrice := FormatAmt(ROUND(SalesLineArchive.Amount / SalesLineArchive.Quantity, 0.01, '='), SalesLineArchive."Currency Code", Autoformattype::UnitAmount)
            else
                UnitPrice := FormatAmt(ROUND(SalesLineArchive.Amount, 0.01, '='), SalesLineArchive."Currency Code", Autoformattype::UnitAmount);
            DotPos := StrPos(UnitPrice, '.');
            if DotPos = 0 then
                UnitPrice += '.00'
            else
                if DotPos = StrLen(UnitPrice) - 1 then
                    UnitPrice += '.0';
            if UnitPrice <> '' then
                InsertNewLine('MOA+146:' + UnitPrice, true)
            else
                InsertNewLine('MOA+146:' + Format(SalesLineArchive."Unit Price"), true);  //-GL1022
        end;

        SegmentCount += 4;
    end;

    local procedure InvoiceAddMidSectionArchive(SalesHeaderArchive: Record "Sales Header Archive"; TempVATAmountLine: Record "VAT Amount Line" temporary; NoOfLineItems: Integer; var SegmentCount: Integer)
    var
        CompanyInformation: Record "Company Information";
    begin
        CompanyInformation.Get();

        InsertNewLine('UNS+S', true);
        InsertNewLine('CNT+2:' + Format(NoOfLineItems), true);

        InsertNewLine('MOA+86:' + Format(TempVATAmountLine."Amount Including VAT", 0, '<Sign><Integer><Decimals>'), true);
        InsertNewLine('MOA+79:' + Format(TempVATAmountLine."Line Amount", 0, '<Sign><Integer><Decimals>'), true);
        InsertNewLine('TAX+7+VAT+++:::' + Format(TempVATAmountLine."VAT %") + '++' + CompanyInformation."VAT Registration No.", true);
        InsertNewLine('MOA+124:' + Format(TempVATAmountLine."VAT Amount", 0, '<Sign><Integer><Decimals>'), true);
        InsertNewLine('MOA+125:' + Format(TempVATAmountLine."VAT Base", 0, '<Sign><Integer><Decimals>'), true);
        SegmentCount += 7;
    end;*/
    internal procedure StockFeed(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        MessageHeader: Record EVS_DBC_MessageHeader;
        Setting: Record DAR_PWF_Setting;
        CustStockFeed: XmlPort DAR_PWF_CustStockFeed;
        XMLOutStream: OutStream;
        XMLFileName: Text[250];
    begin
        Setting := Setting.GetSettings(EVSDBCProcess.EVS_DBC_ProcessCode);
        //Create Message Header
        MessageHeader.Init();
        MessageHeader.Validate(EVS_DBC_MessageBatchID, EVSDBCMessageBatch.EVS_DBC_MessageBatchID);
        MessageHeader.Insert(true);

        //get the Stream
        EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateOutStream(XMLOutStream);

        // Need to create the File Name
        XMLFileName := CopyStr(Format(CurrentDateTime, 0, '<Day,2><Month,2><Year><Hours24,2><Minutes,2>') + '_' + Setting.DAR_PWF_FileName + '.txt', 1, 250);
        CustStockFeed.SetDestination(XMLOutStream);
        CustStockFeed.setMessageHeaderID(MessageHeader.EVS_DBC_MessageHeaderID);
        CustStockFeed.Export();

        //Save Batch
        EVSDBCMessageBatch.EVS_DBC_ImportExportFileName := XMLFileName;
        EVSDBCMessageBatch.EVS_DBC_MessageStatus := EVS_DBC_MessageStatus::Exported;
        EVSDBCMessageBatch.Modify(true);
    end;

    procedure SendSalesShipments(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesShipmentLine: Record "Sales Shipment Line";
        Setting: Record DAR_PWF_Setting;
        EVSDBCMessageHeader: Record EVS_DBC_MessageHeader;
        TextOutStream: OutStream;
        PreviousOrderNo, FileName : Text;
        NoOfLineItems: Integer;
        ShipCount: Integer;
        SegmentCount: Integer;
        SeparatorCount: Integer;
        RepeatFromDate, RepeatToDate : Date;
        FindTrue: Boolean;
    begin
        //Get Settings
        Setting := Setting.GetSettings(EVSDBCProcess.EVS_DBC_ProcessCode);

        RepeatFromDate := Setting.DAR_PWF_ResendFromDate;
        RepeatToDate := Setting.DAR_PWF_ResendToDate;

        ShipCount := 0;
        NoOfLineItems := 0;

        // Loop through the headers in batch
        EVSDBCMessageHeader.Reset();
        EVSDBCMessageHeader.SetCurrentKey(EVS_DBC_MessageBatchID, EVS_DBC_AccountCode);
        EVSDBCMessageHeader.SetRange(EVS_DBC_MessageBatchID, EVSDBCMessageBatch.EVS_DBC_MessageBatchID);
        if EVSDBCMessageHeader.FindSet() then
            repeat
                FindTrue := true;
                SalesShipmentHeader.GetBySystemId(EVSDBCMessageHeader.EVS_DBC_EntitySystemID);
                if (RepeatFromDate <> 0D) and (RepeatToDate <> 0D) then
                    if (SalesShipmentHeader."Posting Date" >= RepeatFromDate) and (SalesShipmentHeader."Posting Date" <= RepeatToDate) then
                        FindTrue := true
                    else
                        FindTrue := false;
                if FindTrue then begin
                    PreviousOrderNo := '';
                    ShipCount += 1;  //dependent on file per shipment - remove this line if that changes
                    FileName := Format(CurrentDateTime, 0, '<Day,2><Month,2><Year><Hours24,2><Minutes,2>') + '_' + CopyStr(Setting.DAR_PWF_FileName + SalesShipmentHeader."No." + Setting.DAR_PWF_FileExtension, 1, 250);
                    EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateOutStream(TextOutStream);

                    InsertShipmentEnvelopeHeader(ShipCount, 'DESADV', TextOutStream); //CUSTOM ENVELOPE HEADER

                    SeparatorCount := 0;    /*No of documents*/
                    SegmentCount := 2;      /*No of segments per doc*/ // Starting at 2 as Header segments need to be included

                    // *** File Header ***
                    ShipmentAddFileHeader(SalesShipmentHeader, SegmentCount, EVSDBCMessageBatch, TextOutStream);
                    SalesShipmentLine.Reset();
                    SalesShipmentLine.SetRange("Document No.", SalesShipmentHeader."No.");
                    SalesShipmentLine.SetFilter(Quantity, '>%1', 0);
                    SalesShipmentLine.SetRange(Type, SalesShipmentLine.Type::Item);
                    if SalesShipmentLine.FindSet() then
                        repeat
                            NoOfLineItems += 1;

                            // *** Line Header ***
                            ShipmentAddLineLoop(SalesShipmentLine."No.", CopyStr(SalesShipmentLine.Description, 1, 50), SalesShipmentLine.Quantity, NoOfLineItems, SegmentCount, TextOutStream);

                            /*Calc no of orders per invoice>>*/
                            if PreviousOrderNo <> SalesShipmentLine."Document No." then begin
                                PreviousOrderNo := SalesShipmentLine."Document No.";
                                SeparatorCount += 1;
                            end;
                        /*<<Calc no of orders per invoice*/
                        until SalesShipmentLine.Next() = 0;

                    // *** File Header ***
                    ShipmentAddMidSection(NoOfLineItems, SegmentCount, TextOutStream);

                    //  SeparatorCount += 1;
                    InsertShipmentExportSeparator(SegmentCount, SeparatorCount, TextOutStream);     //CUSTOM INVOICE SEPARATOR

                    InsertShipmentEnvelopeFooter(ShipCount, TextOutStream);     //CUSTOM ENVELOPE FOOTER

                    //Save Batch
                    EVSDBCMessageBatch.EVS_DBC_ImportExportFileName := CopyStr(FileName, 1, 250);
                    EVSDBCMessageBatch.EVS_DBC_MessageStatus := EVS_DBC_MessageStatus::Exported;
                    EVSDBCMessageBatch.Modify(true);
                    ShipCount := 0; //dependent on shipment per file - remove if this changes
                end;
            until EVSDBCMessageHeader.Next() = 0;
    end;

    local procedure ShipmentAddFileHeader(SalesShipmentHeader: Record "Sales Shipment Header"; var SegmentCount: Integer; EVSDBCMessageBatch: Record EVS_DBC_MessageBatch; var TextOutStream: OutStream)
    var
        CompanyInformation: Record "Company Information";
        GeneralLedgerSetup: Record "General Ledger Setup";
        PostedWhseShipmentHeader: Record "Posted Whse. Shipment Header";
        Setting: Record DAR_PWF_Setting;
        DateFormatTxt: Label '<Year4><Month,2><Day,2>';
        TempCurrencyCode: Code[20];
        ShipToCountryCode: Code[10];
        CompanyCountryCode: Code[10];
    begin
        Setting := Setting.GetSettings(EVSDBCMessageBatch.EVS_DBC_ProcessCode);
        CompanyInformation.Get();

        GeneralLedgerSetup.Get();

        Clear(TempCurrencyCode);
        Clear(ShipToCountryCode);
        Clear(CompanyCountryCode);

        PostedWhseShipmentHeader.SetRange(EVS_EWF_SourceDocumentNo, SalesShipmentHeader."Order No.");
        if PostedWhseShipmentHeader.FindLast() then;

        InsertNewLine('BGM+351::9+' + SalesShipmentHeader."No." + '+9', true, TextOutStream);
        InsertNewLine('DTM+137:' + Format(SalesShipmentHeader."Document Date", 8, DateFormatTxt) + ':102', true, TextOutStream);
        InsertNewLine('DTM+111:' + Format(SalesShipmentHeader."Shipment Date", 8, DateFormatTxt) + ':102', true, TextOutStream);
        PostedWhseShipmentHeader.CalcFields(EVS_EWF_TotalNetWeight);
        InsertNewLine('MEA+WT+G+KGM:' + Format(PostedWhseShipmentHeader.EVS_EWF_TotalNetWeight), true, TextOutStream);
        InsertNewLine('RFF+ON:' + SalesShipmentHeader."External Document No.", true, TextOutStream);
        InsertNewLine('RFF+IA:' + Setting.DAR_PWF_SupplierIDCode, true, TextOutStream);    //SUPPLIERID
        if CompanyInformation."Country/Region Code" = '' then
            CompanyCountryCode := Setting.DAR_PWF_LocalCountryCode
        else
            CompanyCountryCode := CompanyInformation."Country/Region Code";
        InsertNewLine('NAD+SF++' + ConvertStr(CompanyInformation.Name, 'ä', 'a') + '++' + CompanyInformation.Address + ':' + CompanyInformation."Address 2" + '+' + CompanyInformation.City + '+' + CopyStr(CompanyInformation.County, 1, 9), false, TextOutStream);
        InsertNewLine('+' + CompanyInformation."Post Code" + '+' + CompanyCountryCode, true, TextOutStream);
        if SalesShipmentHeader."Ship-to Country/Region Code" = '' then
            ShipToCountryCode := CompanyCountryCode
        else
            ShipToCountryCode := SalesShipmentHeader."Ship-to Country/Region Code";                                                                           //+-GL0869 cut to 9 char
        InsertNewLine('NAD+ST++' + SalesShipmentHeader."Ship-to Name" + '++' + SalesShipmentHeader."Ship-to Address" + ':' + SalesShipmentHeader."Ship-to Address 2" + '+' + SalesShipmentHeader."Ship-to City" + '+' + CopyStr(SalesShipmentHeader."Ship-to County", 1, 9) + '+' + SalesShipmentHeader."Ship-to Post Code" + '+' + ShipToCountryCode, true, TextOutStream);
        InsertNewLine('TDT+20++++' + SalesShipmentHeader.DAR_PWF_SCAC + ':' + '172' + '::' + '2D', true, TextOutStream);                  //NEED TO COMMUNICATE WITH DAR HOW THESE WILL BE STORED IN NAV/ APPARENTLY ALWAYS 2D For ShipSpeed
        InsertNewLine('CPS+1', true, TextOutStream);
        InsertNewLine('PAC+' + Format(PostedWhseShipmentHeader.EVS_EWF_NoCartons + PostedWhseShipmentHeader.EVS_EWF_NoPallets) + '++CT', true, TextOutStream);
        InsertNewLine('PCI+24', true, TextOutStream);
        InsertNewLine('GIN+BJ+' + SalesShipmentHeader."Package Tracking No.", true, TextOutStream);

        SegmentCount += 13;

    end;

    local procedure ShipmentAddLineLoop(ItemNo: Code[20]; Description: Text[50]; Quantity: Decimal; NoOfLineItems: Integer; var SegmentCount: Integer; var TextOutStream: OutStream)
    begin
        InsertNewLine('LIN+' + Format(NoOfLineItems) + '++' + ItemNo + ':GB', true, TextOutStream);
        InsertNewLine('IMD+F++:::' + CopyStr(Description, 1, 35), true, TextOutStream);
        InsertNewLine('QTY+12:' + Format(Quantity) + ':EA', true, TextOutStream);

        SegmentCount += 3;
    end;

    local procedure ShipmentAddMidSection(NoOfLineItems: Integer; var SegmentCount: Integer; var TextOutStream: OutStream)
    begin
        InsertNewLine('CNT+2:' + Format(NoOfLineItems), true, TextOutStream);

        SegmentCount += 1;
    end;

    local procedure InsertShipmentEnvelopeHeader(DocCount: Integer; DocType: Text; var TextOutStream: OutStream)
    var
        DateFormatyymmddTxt: Label '<Year><Month,2><Day,2>';
        TimeFormathhmmTxt: Label '<hours24><minutes,2>';
        LeadChar: Text[1];
    begin
        LeadChar := '';
        if Time < 100000T then begin
            LeadChar := '0';
            InsertNewLine('UNB+UNOC:2+35128000003:14+112084681:1+' + Format(Today, 6, DateFormatyymmddTxt) + ':' + LeadChar + Format(Time, 3, TimeFormathhmmTxt) + '+668++++1', true, TextOutStream);
        end else
            InsertNewLine('UNB+UNOC:2+35128000003:14+112084681:1+' + Format(Today, 6, DateFormatyymmddTxt) + ':' + Format(Time, 4, TimeFormathhmmTxt) + '+668++++1', true, TextOutStream);

        InsertNewLine('UNH+' + Format(DocCount) + '+' + DocType + ':D:96A:UN', true, TextOutStream);
    end;

    local procedure InsertShipmentExportSeparator(NoOfSegments: Integer; DocCount: Integer; var TextOutStream: OutStream)
    begin
        InsertNewLine('UNT+' + Format(NoOfSegments) + '+' + Format(DocCount), true, TextOutStream);
    end;

    local procedure InsertShipmentEnvelopeFooter(DocCount: Integer; var TextOutStream: OutStream)
    begin
        InsertNewLine('UNZ+' + Format(DocCount) + '+668', true, TextOutStream);
    end;

    local procedure InsertNewLine(Passed_Text: Text; Complete_Line: Boolean; var WayfairOutStream: OutStream)
    var
        LineSeparatorLbl: Label '''';
    begin
        WayfairOutStream.WriteText(Passed_Text);
        if Complete_Line then
            WayfairOutStream.WriteText(LineSeparatorLbl);
    end;

    procedure SendInvoices(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        TempVATAmountLine: Record "VAT Amount Line" temporary;
        EVSDBCMessageHeader: Record EVS_DBC_MessageHeader;
        Setting: Record DAR_PWF_Setting;
        DateFormatTxt: Label '<Year4><Month,2><Day,2>';
        TimeFormathhmmTxt: Label '<hours24><minutes,2>';
        TextOutStream: OutStream;
        PreviousOrderNo, DateTimeString : Text;
        FileName: Text[250];
        NoOfLineItems: Integer;
        InvCount: Integer;
        InvCountT: Integer;
        SegmentCount: Integer;
        SeparatorCount: Integer;
        RepeatFromDate, RepeatToDate : Date;
    begin
        Setting := Setting.GetSettings(EVSDBCProcess.EVS_DBC_ProcessCode);
        InvCount := 0;
        NoOfLineItems := 0;
        SeparatorCount := 0;

        RepeatFromDate := Setting.DAR_PWF_ResendFromDate;
        RepeatToDate := Setting.DAR_PWF_ResendToDate;

        // Loop through the headers in batch
        EVSDBCMessageHeader.Reset();
        EVSDBCMessageHeader.SetCurrentKey(EVS_DBC_MessageBatchID, EVS_DBC_AccountCode, EVS_DBC_ShipmentDate);
        EVSDBCMessageHeader.SetRange(EVS_DBC_MessageBatchID, EVSDBCMessageBatch.EVS_DBC_MessageBatchID);
        if (RepeatFromDate <> 0D) and (RepeatToDate <> 0D) then
            EVSDBCMessageHeader.SetRange(EVS_DBC_ShipmentDate, RepeatFromDate, RepeatToDate);
        if EVSDBCMessageHeader.FindSet() then begin
            PreviousOrderNo := '';

            DateTimeString := Format(Today, 8, DateFormatTxt) + Format(Time, 4, TimeFormathhmmTxt);
            FileName := Format(CurrentDateTime, 0, '<Day,2><Month,2><Year><Hours24,2><Minutes,2>') + '_' + Setting.DAR_PWF_FileName + DateTimeString + Setting.DAR_PWF_FileExtension;

            EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateOutStream(TextOutStream);

            InvCount := EVSDBCMessageHeader.Count;     /*Total No Of Docs*/
            InvCountT := EVSDBCMessageHeader.Count;     /*Total No Of Docs*/ //+-GL0869

            // *** Envelope Header ***
            InsertInvoiceEnvelopeHeader('INVOIC', TextOutStream); //CUSTOM ENVELOPE HEADER                                                 // Loop through the rows
            repeat
                SalesInvoiceHeader.GetBySystemId(EVSDBCMessageHeader.EVS_DBC_EntitySystemID);

                SegmentCount := 0;      /*No of segments per doc*/
                SeparatorCount += 1;
                // *** Header ***
                InvoiceAddFileHeader(SalesInvoiceHeader, SegmentCount, SeparatorCount, 'INVOIC', EVSDBCMessageHeader, TextOutStream);

                // *** Lines ***
                SalesInvoiceLine.Reset();
                SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
                SalesInvoiceLine.SetRange(Type, SalesInvoiceLine.Type::Item);
                if SalesInvoiceLine.FindSet() then
                    repeat
                        NoOfLineItems += 1;
                        InvoiceAddLineLoop(SalesInvoiceLine, NoOfLineItems, SegmentCount, TextOutStream);
                        /*Calc no of orders per invoice>>*/
                        if PreviousOrderNo <> SalesInvoiceLine."Order No." then
                            PreviousOrderNo := SalesInvoiceLine."Order No.";
                    /*<<Calc no of orders per invoice*/
                    until SalesInvoiceLine.Next() = 0;

                // *** VAT on the lines ***
                SalesInvoiceLine.CalcVATAmountLines(SalesInvoiceHeader, TempVATAmountLine);
                InvoiceAddMidSection(TempVATAmountLine, NoOfLineItems, SegmentCount, TextOutStream);

                InsertInvoiceExportSeparator(SegmentCount, SeparatorCount, TextOutStream);     //CUSTOM INVOICE SEPARATOR was segmentcount 05/07/2019 changed doc count to separator count 26/07/2019
            until EVSDBCMessageHeader.Next() = 0;
            InsertInvoiceEnvelopeFooter(InvCount, TextOutStream);     //CUSTOM ENVELOPE FOOTER
            //Save Batch
            EVSDBCMessageBatch.EVS_DBC_ImportExportFileName := CopyStr(FileName, 1, 250);
            EVSDBCMessageBatch.EVS_DBC_MessageStatus := EVS_DBC_MessageStatus::Exported;
            EVSDBCMessageBatch.Modify(true);
        end;
    end;

    local procedure InvoiceAddFileHeader(SalesInvoiceHeader: Record "Sales Invoice Header"; var SegmentCount: Integer; pSeparatorCount: Integer; pDocType: Text; EVSDBCMessageHeader: Record EVS_DBC_MessageHeader; var TextOutStream: OutStream)
    var
        CompanyInformation: Record "Company Information";
        GeneralLedgerSetup: Record "General Ledger Setup";
        PaymentTerms: Record "Payment Terms";
        Setting: Record DAR_PWF_Setting;
        TempCurrencyCode: Code[20];
        ShipToCountryCode: Code[10];
        BillToCountryCode: Code[10];
        DateFormatTxt: Label '<Year4><Month,2><Day,2>';
    begin
        Setting := Setting.GetSettings(EVSDBCMessageHeader.EVS_DBC_ProcessCode);
        CompanyInformation.Get();
        GeneralLedgerSetup.Get();

        Clear(TempCurrencyCode);
        Clear(ShipToCountryCode);
        Clear(BillToCountryCode);

        InsertNewLine('UNH+' + Format(pSeparatorCount) + '+' + pDocType + ':D:96A:UN:EAN008', true, TextOutStream); //add UNH section per invoice accumulating counter plus doc type
        InsertNewLine('BGM+380+' + SalesInvoiceHeader."No." + '+9', true, TextOutStream);
        InsertNewLine('DTM+137:' + Format(SalesInvoiceHeader."Document Date", 8, DateFormatTxt) + ':102', true, TextOutStream);
        InsertNewLine('DTM+11:' + Format(SalesInvoiceHeader."Shipment Date", 8, DateFormatTxt) + ':102', true, TextOutStream);
        InsertNewLine('RFF+ON:' + SalesInvoiceHeader."External Document No.", true, TextOutStream);

        if StrLen(Setting.DAR_PWF_SupplierIDCode) > 0 then
            InsertNewLine('RFF+IA:' + Setting.DAR_PWF_SupplierIDCode, true, TextOutStream)    //SUPPLIERID
        else
            InsertNewLine('RFF+IA:' + CopyStr(SalesInvoiceHeader."Your Reference", 1, 10), true, TextOutStream);
        InsertNewLine('NAD+SU++' + (ConvertStr(CompanyInformation.Name, 'ä', 'a')) + '++' + CompanyInformation.Address + ':' + CompanyInformation."Address 2" + '+' + CompanyInformation.City + '+' + CopyStr(CompanyInformation.County, 1, 9), false, TextOutStream);
        InsertNewLine('+' + CompanyInformation."Post Code" + '+' + CompanyInformation."Country/Region Code", true, TextOutStream);
        if SalesInvoiceHeader."Ship-to Country/Region Code" = '' then
            ShipToCountryCode := Setting.DAR_PWF_LocalCountryCode
        else
            ShipToCountryCode := SalesInvoiceHeader."Ship-to Country/Region Code";                                                                          //+-GL0869 cut to 9 char
        InsertNewLine('NAD+ST++' + SalesInvoiceHeader."Ship-to Name" + '++' + SalesInvoiceHeader."Ship-to Address" + ':' + SalesInvoiceHeader."Ship-to Address 2" + '+' + SalesInvoiceHeader."Ship-to City" + '+' + CopyStr(SalesInvoiceHeader."Ship-to County", 1, 9) + '+' + SalesInvoiceHeader."Ship-to Post Code" + '+' + ShipToCountryCode, true, TextOutStream);

        if SalesInvoiceHeader."Currency Code" = '' then
            TempCurrencyCode := GeneralLedgerSetup."LCY Code"
        else
            TempCurrencyCode := SalesInvoiceHeader."Currency Code";
        InsertNewLine('CUX+2:' + TempCurrencyCode + ':9', true, TextOutStream);
        // Get the description
        if PaymentTerms.Get(SalesInvoiceHeader."Payment Terms Code") then
            InsertNewLine('PAT+1+6:::' + PaymentTerms.Description, true, TextOutStream)
        else
            InsertNewLine('PAT+1+6:::' + SalesInvoiceHeader."Payment Terms Code", true, TextOutStream);

        SegmentCount += 9;
    end;

    local procedure InvoiceAddLineLoop(SalesInvoiceLine: Record "Sales Invoice Line"; NoOfLineItems: Integer; var SegmentCount: Integer; var TextOutStream: OutStream)
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        UnitPrice: Text;
        DotPos: Integer;
        AutoFormatType: Enum "Auto Format";
    begin
        if SalesInvoiceLine.Type <> SalesInvoiceLine.Type::Item then
            exit;

        SalesInvoiceHeader.Get(SalesInvoiceLine."Document No.");
        InsertNewLine('LIN+' + Format(NoOfLineItems) + '++' + SalesInvoiceLine."No." + ':GB', true, TextOutStream);
        InsertNewLine('IMD+F++:::' + CopyStr(SalesInvoiceLine.Description, 1, 35), true, TextOutStream);
        InsertNewLine('QTY+12:' + Format(SalesInvoiceLine.Quantity), true, TextOutStream);

        if SalesInvoiceLine.Quantity <> 0 then
            UnitPrice := FormatAmt(Round(SalesInvoiceLine.Amount / SalesInvoiceLine.Quantity, 0.01, '='), SalesInvoiceHeader."Currency Code", AutoFormatType::UnitAmountFormat)
        else
            UnitPrice := FormatAmt(Round(SalesInvoiceLine.Amount, 0.01, '='), SalesInvoiceHeader."Currency Code", AutoFormatType::UnitAmountFormat);

        DotPos := StrPos(UnitPrice, '.');
        if DotPos = 0 then
            UnitPrice += '.00'
        else
            if DotPos = StrLen(UnitPrice) - 1 then
                UnitPrice += '.0';
        if UnitPrice <> '' then
            InsertNewLine('MOA+146:' + UnitPrice, true, TextOutStream)
        else
            InsertNewLine('MOA+146:' + Format(SalesInvoiceLine."Unit Price"), true, TextOutStream);
        SegmentCount += 4;
    end;

    local procedure InvoiceAddMidSection(TempVATAmountLine: Record "VAT Amount Line" temporary; NoOfLineItems: Integer; var SegmentCount: Integer; var TextOutStream: OutStream)
    var
        CompanyInformation: Record "Company Information";
    begin
        CompanyInformation.Get();

        InsertNewLine('UNS+S', true, TextOutStream);
        InsertNewLine('CNT+2:' + Format(NoOfLineItems), true, TextOutStream);

        InsertNewLine('MOA+86:' + Format(TempVATAmountLine."Amount Including VAT", 0, '<Sign><Integer><Decimals>'), true, TextOutStream);
        InsertNewLine('MOA+79:' + Format(TempVATAmountLine."Line Amount", 0, '<Sign><Integer><Decimals>'), true, TextOutStream);
        InsertNewLine('TAX+7+VAT+++:::' + Format(TempVATAmountLine."VAT %") + '++' + GetLocalVATRegistrationNo(), true, TextOutStream);

        InsertNewLine('MOA+124:' + Format(TempVATAmountLine."VAT Amount", 0, '<Sign><Integer><Decimals>'), true, TextOutStream);
        InsertNewLine('MOA+125:' + Format(TempVATAmountLine."VAT Base", 0, '<Sign><Integer><Decimals>'), true, TextOutStream);

        SegmentCount += 7;
    end;

    local procedure InsertInvoiceEnvelopeHeader(DocType: Text; var TextOutStream: OutStream)
    var
        LeadChar: Text[1];
        DateFormatyymmddTxt: Label '<Year><Month,2><Day,2>';
        TimeFormathhmmTxt: Label '<hours24><minutes,2>';
    begin
        LeadChar := '';
        if Time < 100000T then begin
            LeadChar := '0';
            InsertNewLine('UNB+UNOC:2+35128000003:14+112084681:1+' + Format(Today, 6, DateFormatyymmddTxt) + ':' + LeadChar + Format(Time, 3, TimeFormathhmmTxt) + '+943000001++' + DocType, true, TextOutStream)
        end else
            InsertNewLine('UNB+UNOC:2+35128000003:14+112084681:1+' + Format(Today, 6, DateFormatyymmddTxt) + ':' + Format(Time, 4, TimeFormathhmmTxt) + '+943000001++' + DocType, true, TextOutStream);
    end;

    local procedure InsertInvoiceExportSeparator(NoOfSegments: Integer; DocCount: Integer; var TextOutStream: OutStream)
    begin
        InsertNewLine('UNT+' + Format(NoOfSegments + 2) + '+' + Format(DocCount), true, TextOutStream);
    end;

    local procedure InsertInvoiceEnvelopeFooter(DocCount: Integer; var TextOutStream: OutStream)
    begin
        InsertNewLine('UNZ+' + Format(DocCount) +/* '+' + DocType +*/'+943000001', true, TextOutStream);
    end;

    local procedure FormatAmt(Amount: Decimal; AutoFormatExpr: Text[80]; AutoFormatType: Enum "Auto Format"): Text[80]
    var
        AutoFormat: Codeunit "Auto Format";
        FormatStr: Text[80];
    begin
        FormatStr := AutoFormat.ResolveAutoFormat(AutoFormatType, AutoFormatExpr);
        exit(Format(Amount, 0, FormatStr));
    end;

    local procedure GetLocalVATRegistrationNo(): Text
    var
        CompanyInformation: Record "Company Information";
    begin
        //Go to the Order Archive to get the posted remote order no. and wayfair despatch warehouse.
        CompanyInformation.Get();
        exit(CompanyInformation."VAT Registration No.");
    end;

    procedure SendCSNInvoices(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        TempVATAmountLine: Record "VAT Amount Line" temporary;
        EVSDBCMessageHeader: Record EVS_DBC_MessageHeader;
        Setting: Record DAR_PWF_Setting;
        DateFormatTxt: Label '<Year4><Month,2><Day,2>';
        TimeFormathhmmTxt: Label '<hours24><minutes,2>';
        TextOutStream: OutStream;
        PreviousOrderNo, DateTimeString : Text;
        FileName: Text[250];
        NoOfLineItems: Integer;
        InvCount: Integer;
        InvCountT: Integer;
        SegmentCount: Integer;
        SeparatorCount: Integer;
        RepeatFromDate, RepeatToDate : Date;
    begin
        Setting := Setting.GetSettings(EVSDBCProcess.EVS_DBC_ProcessCode);
        InvCount := 0;
        NoOfLineItems := 0;
        SeparatorCount := 0;

        RepeatFromDate := Setting.DAR_PWF_ResendFromDate;
        RepeatToDate := Setting.DAR_PWF_ResendToDate;

        // Loop through the headers in batch
        EVSDBCMessageHeader.Reset();
        EVSDBCMessageHeader.SetCurrentKey(EVS_DBC_MessageBatchID, EVS_DBC_AccountCode, EVS_DBC_ShipmentDate);
        EVSDBCMessageHeader.SetRange(EVS_DBC_MessageBatchID, EVSDBCMessageBatch.EVS_DBC_MessageBatchID);
        if (RepeatFromDate <> 0D) and (RepeatToDate <> 0D) then
            EVSDBCMessageHeader.SetRange(EVS_DBC_ShipmentDate, RepeatFromDate, RepeatToDate);
        if EVSDBCMessageHeader.FindSet() then begin
            PreviousOrderNo := '';

            DateTimeString := Format(Today, 8, DateFormatTxt) + Format(Time, 4, TimeFormathhmmTxt);
            FileName := Format(CurrentDateTime, 0, '<Day,2><Month,2><Year><Hours24,2><Minutes,2>') + '_' + Setting.DAR_PWF_FileName + DateTimeString + Setting.DAR_PWF_FileExtension;

            EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateOutStream(TextOutStream);

            SalesInvoiceHeader.GetBySystemId(EVSDBCMessageHeader.EVS_DBC_EntitySystemID);
            InvCount := SalesInvoiceHeader.Count;     /*Total No Of Docs*/
            InvCountT := SalesInvoiceHeader.Count;     /*Total No Of Docs*/ //+-GL0869

            // *** Envelope Header ***
            InsertCSNInvoiceEnvelopeHeader('INVOIC', TextOutStream); //CUSTOM ENVELOPE HEADER                                                 // Loop through the rows
            repeat
                SegmentCount := 0;      /*No of segments per doc*/
                SeparatorCount += 1;
                // *** Header ***
                CSNInvoiceAddFileHeader(SalesInvoiceHeader, SegmentCount, SeparatorCount, 'INVOIC', EVSDBCMessageHeader, TextOutStream);

                // *** Lines ***
                SalesInvoiceLine.Reset();
                SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
                SalesInvoiceLine.SetRange(Type, SalesInvoiceLine.Type::Item);
                if SalesInvoiceLine.FindSet() then
                    repeat
                        NoOfLineItems += 1;
                        CSNInvoiceAddLineLoop(SalesInvoiceLine, NoOfLineItems, SegmentCount, TextOutStream);
                        /*Calc no of orders per invoice>>*/
                        if PreviousOrderNo <> SalesInvoiceLine."Order No." then
                            PreviousOrderNo := SalesInvoiceLine."Order No.";
                    /*<<Calc no of orders per invoice*/
                    until SalesInvoiceLine.Next() = 0;

                // *** VAT on the lines ***
                SalesInvoiceLine.CalcVATAmountLines(SalesInvoiceHeader, TempVATAmountLine);
                CSNInvoiceAddMidSection(/*SalesInvoiceHeader*/ TempVATAmountLine, NoOfLineItems, SegmentCount, TextOutStream);

                InsertCSNInvoiceExportSeparator(SegmentCount, SeparatorCount, TextOutStream);     //CUSTOM INVOICE SEPARATOR was segmentcount 05/07/2019 changed doc count to separator count 26/07/2019
            until EVSDBCMessageHeader.Next() = 0;
            InsertCSNInvoiceEnvelopeFooter(InvCount, TextOutStream);     //CUSTOM ENVELOPE FOOTER
            //Save Batch
            EVSDBCMessageBatch.EVS_DBC_ImportExportFileName := CopyStr(FileName, 1, 250);
            EVSDBCMessageBatch.EVS_DBC_MessageStatus := EVS_DBC_MessageStatus::Exported;
            EVSDBCMessageBatch.Modify(true);
        end;
    end;

    local procedure CSNInvoiceAddFileHeader(SalesInvoiceHeader: Record "Sales Invoice Header"; var SegmentCount: Integer; pSeparatorCount: Integer; pDocType: Text; EVSDBCMessageHeader: Record EVS_DBC_MessageHeader; var TextOutStream: OutStream)
    var
        CompanyInformation: Record "Company Information";
        GeneralLedgerSetup: Record "General Ledger Setup";
        PaymentTerms: Record "Payment Terms";
        Setting: Record DAR_PWF_Setting;
        TempCurrencyCode: Code[20];
        ShipToCountryCode: Code[10];
        BillToCountryCode: Code[10];
        DateFormatTxt: Label '<Year4><Month,2><Day,2>';
    begin
        Setting := Setting.GetSettings(EVSDBCMessageHeader.EVS_DBC_ProcessCode);
        CompanyInformation.Get();
        GeneralLedgerSetup.Get();

        Clear(TempCurrencyCode);
        Clear(ShipToCountryCode);
        Clear(BillToCountryCode);

        InsertNewLine('UNH+' + Format(pSeparatorCount) + '+' + pDocType + ':D:96A:UN:EAN008', true, TextOutStream); //add UNH section per invoice accumulating counter plus doc type
        InsertNewLine('BGM+380+' + SalesInvoiceHeader."No." + '+9', true, TextOutStream);
        InsertNewLine('DTM+137:' + Format(SalesInvoiceHeader."Document Date", 8, DateFormatTxt) + ':102', true, TextOutStream);
        InsertNewLine('DTM+11:' + Format(SalesInvoiceHeader."Shipment Date", 8, DateFormatTxt) + ':102', true, TextOutStream);
        InsertNewLine('RFF+ON:' + SalesInvoiceHeader."External Document No.", true, TextOutStream);

        if StrLen(Setting.DAR_PWF_SupplierIDCode) > 0 then
            InsertNewLine('RFF+IA:' + Setting.DAR_PWF_SupplierIDCode, true, TextOutStream)    //SUPPLIERID
        else
            InsertNewLine('RFF+IA:' + CopyStr(SalesInvoiceHeader."Your Reference", 1, 10), true, TextOutStream);
        InsertNewLine('NAD+SU++' + (ConvertStr(CompanyInformation.Name, 'ä', 'a')) + '++' + CompanyInformation.Address + ':' + CompanyInformation."Address 2" + '+' + CompanyInformation.City + '+' + CopyStr(CompanyInformation.County, 1, 9), false, TextOutStream);
        InsertNewLine('+' + CompanyInformation."Post Code" + '+' + CompanyInformation."Country/Region Code", true, TextOutStream);
        if SalesInvoiceHeader."Ship-to Country/Region Code" = '' then
            ShipToCountryCode := Setting.DAR_PWF_LocalCountryCode
        else
            ShipToCountryCode := SalesInvoiceHeader."Ship-to Country/Region Code";                                                                          //+-GL0869 cut to 9 char
        InsertNewLine('NAD+ST++' + SalesInvoiceHeader."Ship-to Name" + '++' + SalesInvoiceHeader."Ship-to Address" + ':' + SalesInvoiceHeader."Ship-to Address 2" + '+' + SalesInvoiceHeader."Ship-to City" + '+' + CopyStr(SalesInvoiceHeader."Ship-to County", 1, 9) + '+' + SalesInvoiceHeader."Ship-to Post Code" + '+' + ShipToCountryCode, true, TextOutStream);

        if SalesInvoiceHeader."Currency Code" = '' then
            TempCurrencyCode := GeneralLedgerSetup."LCY Code"
        else
            TempCurrencyCode := SalesInvoiceHeader."Currency Code";
        InsertNewLine('CUX+2:' + TempCurrencyCode + ':9', true, TextOutStream);
        // Get the description
        if PaymentTerms.Get(SalesInvoiceHeader."Payment Terms Code") then
            InsertNewLine('PAT+1+6:::' + PaymentTerms.Description, true, TextOutStream)
        else
            InsertNewLine('PAT+1+6:::' + SalesInvoiceHeader."Payment Terms Code", true, TextOutStream);

        SegmentCount += 9;
    end;

    local procedure CSNInvoiceAddLineLoop(SalesInvoiceLine: Record "Sales Invoice Line"; NoOfLineItems: Integer; var SegmentCount: Integer; var TextOutStream: OutStream)
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        UnitPrice: Text;
        DotPos: Integer;
        AutoFormatType: Enum "Auto Format";
    begin
        if SalesInvoiceLine.Type <> SalesInvoiceLine.Type::Item then
            exit;

        SalesInvoiceHeader.Get(SalesInvoiceLine."Document No.");
        InsertNewLine('LIN+' + Format(NoOfLineItems) + '++' + SalesInvoiceLine."No." + ':GB', true, TextOutStream);
        InsertNewLine('IMD+F++:::' + CopyStr(SalesInvoiceLine.Description, 1, 35), true, TextOutStream);
        InsertNewLine('QTY+12:' + Format(SalesInvoiceLine.Quantity), true, TextOutStream);

        if SalesInvoiceLine.Quantity <> 0 then
            UnitPrice := FormatAmt(Round(SalesInvoiceLine.Amount / SalesInvoiceLine.Quantity, 0.01, '='), SalesInvoiceHeader."Currency Code", AutoFormatType::UnitAmountFormat)
        else
            UnitPrice := FormatAmt(Round(SalesInvoiceLine.Amount, 0.01, '='), SalesInvoiceHeader."Currency Code", AutoFormatType::UnitAmountFormat);

        DotPos := StrPos(UnitPrice, '.');
        if DotPos = 0 then
            UnitPrice += '.00'
        else
            if DotPos = StrLen(UnitPrice) - 1 then
                UnitPrice += '.0';
        if UnitPrice <> '' then
            InsertNewLine('MOA+146:' + UnitPrice, true, TextOutStream)
        else
            InsertNewLine('MOA+146:' + Format(SalesInvoiceLine."Unit Price"), true, TextOutStream);
        SegmentCount += 4;
    end;

    local procedure CSNInvoiceAddMidSection(TempVATAmountLine: Record "VAT Amount Line" temporary; NoOfLineItems: Integer; var SegmentCount: Integer; var TextOutStream: OutStream)
    var
        CompanyInformation: Record "Company Information";
    begin
        CompanyInformation.Get();

        InsertNewLine('UNS+S', true, TextOutStream);
        InsertNewLine('CNT+2:' + Format(NoOfLineItems), true, TextOutStream);

        InsertNewLine('MOA+86:' + Format(TempVATAmountLine."Amount Including VAT", 0, '<Sign><Integer><Decimals>'), true, TextOutStream);
        InsertNewLine('MOA+79:' + Format(TempVATAmountLine."Line Amount", 0, '<Sign><Integer><Decimals>'), true, TextOutStream);
        InsertNewLine('TAX+7+VAT+++:::' + Format(TempVATAmountLine."VAT %") + '++' + GetLocalVATRegistrationNo(/*SalesInvoiceHeader*/), true, TextOutStream);

        InsertNewLine('MOA+124:' + Format(TempVATAmountLine."VAT Amount", 0, '<Sign><Integer><Decimals>'), true, TextOutStream);
        InsertNewLine('MOA+125:' + Format(TempVATAmountLine."VAT Base", 0, '<Sign><Integer><Decimals>'), true, TextOutStream);

        SegmentCount += 7;
    end;

    local procedure InsertCSNInvoiceEnvelopeHeader(DocType: Text; var TextOutStream: OutStream)
    var
        LeadChar: Text[1];
        DateFormatyymmddTxt: Label '<Year><Month,2><Day,2>';
        TimeFormathhmmTxt: Label '<hours24><minutes,2>';
    begin
        LeadChar := '';
        if Time < 100000T then begin
            LeadChar := '0';
            InsertNewLine('UNB+UNOC:2+35128000003:14+112084681:1+' + Format(Today, 6, DateFormatyymmddTxt) + ':' + LeadChar + Format(Time, 3, TimeFormathhmmTxt) + '+943000001++' + DocType, true, TextOutStream)
        end else
            InsertNewLine('UNB+UNOC:2+35128000003:14+112084681:1+' + Format(Today, 6, DateFormatyymmddTxt) + ':' + Format(Time, 4, TimeFormathhmmTxt) + '+943000001++' + DocType, true, TextOutStream);
    end;

    local procedure InsertCSNInvoiceExportSeparator(NoOfSegments: Integer; DocCount: Integer; var TextOutStream: OutStream)
    begin
        InsertNewLine('UNT+' + Format(NoOfSegments + 2) + '+' + Format(DocCount), true, TextOutStream);
    end;

    local procedure InsertCSNInvoiceEnvelopeFooter(DocCount: Integer; var TextOutStream: OutStream)
    begin
        InsertNewLine('UNZ+' + Format(DocCount) +/* '+' + DocType +*/'+943000001', true, TextOutStream);
    end;

    procedure ImportCSNOrders(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        WayfairFileBuffer: Record DAR_PWF_WayfairFileBuffer;
        TxtInstream: InStream;
        LineArray: array[15] of Text;
        FullLine: Text;
        Line: Text;
        i: Integer;
        i2: Integer;
        ValueNo: Integer;
        EntryNo: Integer;
        ApostropheLbl: Label '''';
    begin
        //Get the stream
        EVSDBCMessageBatch.CalcFields(EVS_DBC_ImportExportFile);
        if not EVSDBCMessageBatch.EVS_DBC_ImportExportFile.HasValue() then
            exit;

        //read the file
        EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateInStream(TxtInstream);
        TxtInstream.Read(FullLine);

        WayfairFileBuffer.DeleteAll();
        for i := 1 to StrLen(FullLine) do
            if Format(FullLine[i]) <> ApostropheLbl then
                Line += Format(FullLine[i])
            else begin
                //process the line
                EntryNo += 1;
                WayfairFileBuffer.Init();
                WayfairFileBuffer.DAR_PWF_EntryNo := EntryNo;
                WayfairFileBuffer.DAR_PWF_LineType := CopyStr(Line, 1, 3);

                ValueNo := 1;
                for i2 := 5 to StrLen(Line) do
                    if not (Line[i2] in ['+', ':']) then
                        LineArray[ValueNo] += Format(Line[i2])
                    else
                        ValueNo += 1;

                //separate the line into columns - cannot compress or will show different columns each time where blanks!!!

                for i2 := 1 to 14 do
                    if Format(LineArray[i2]) <> '' then
                        case i2 of
                            1:
                                WayfairFileBuffer.DAR_PWF_Value1 := Format(LineArray[i2]);
                            2:
                                WayfairFileBuffer.DAR_PWF_Value2 := Format(LineArray[i2]);
                            3:
                                WayfairFileBuffer.DAR_PWF_Value3 := Format(LineArray[i2]);
                            4:
                                WayfairFileBuffer.DAR_PWF_Value4 := Format(LineArray[i2]);
                            5:
                                WayfairFileBuffer.DAR_PWF_Value5 := Format(LineArray[i2]);
                            6:
                                WayfairFileBuffer.DAR_PWF_Value6 := Format(LineArray[i2]);
                            7:
                                WayfairFileBuffer.DAR_PWF_Value7 := Format(LineArray[i2]);
                            8:
                                WayfairFileBuffer.DAR_PWF_Value8 := Format(LineArray[i2]);
                            9:
                                WayfairFileBuffer.DAR_PWF_Value9 := Format(LineArray[i2]);
                            10:
                                WayfairFileBuffer.DAR_PWF_Value10 := Format(LineArray[i2]);
                            11:
                                WayfairFileBuffer.DAR_PWF_Value11 := Format(LineArray[i2]);
                            12:
                                WayfairFileBuffer.DAR_PWF_Value12 := Format(LineArray[i2]);
                            13:
                                WayfairFileBuffer.DAR_PWF_Value13 := Format(LineArray[i2]);
                            14:
                                WayfairFileBuffer.DAR_PWF_Value14 := Format(LineArray[i2]);
                            15:
                                WayfairFileBuffer.DAR_PWF_Value15 := Format(LineArray[i2]);
                        end;

                WayfairFileBuffer.Insert(true);
                Line := '';
                Clear(LineArray);
            end;

        SeparateCSNOrders();
        ProcessIntoCSNOrders(EVSDBCMessageBatch);
    end;

    local procedure SeparateCSNOrders()
    var
        WayfairFileBuffer: Record DAR_PWF_WayfairFileBuffer;
        WayfairFileBufferOrders: Record DAR_PWF_WayfairFileBuffer;
        WayfairFileBufferLines: Record DAR_PWF_WayfairFileBuffer;
        WayfairFileBufferDetails: Record DAR_PWF_WayfairFileBuffer;
        NewLineNo: Integer;
        WayfairWhse: Text;
        StartPos: Integer;
        Length: Integer;
    begin
        //Find Shipping Warehouse Location - 1 per file
        Clear(WayfairWhse);
        Clear(StartPos);
        Clear(Length);
        WayfairFileBuffer.Reset();
        WayfairFileBuffer.SetFilter(DAR_PWF_LineType, 'UNB');
        if WayfairFileBuffer.FindFirst() then begin
            StartPos := StrPos(WayfairFileBuffer.DAR_PWF_Value5, 'WH');
            Length := StrLen(WayfairFileBuffer.DAR_PWF_Value5);
            WayfairWhse := CopyStr(WayfairFileBuffer.DAR_PWF_Value5, StartPos, (Length - (StartPos - 1)));
        end;

        //>>Loop Through Imported lines & Copy Order No
        WayfairFileBuffer.Reset();
        WayfairFileBuffer.SetRange(DAR_PWF_LineType, 'BGM');
        if WayfairFileBuffer.FindSet() then
            repeat
                WayfairFileBuffer.DAR_PWF_OrderNo := CopyStr(WayfairFileBuffer.DAR_PWF_Value2, 1, 30);
                WayfairFileBuffer.DAR_PWF_WayfairDespWarehouse := CopyStr(WayfairWhse, 1, 50);
                WayfairFileBuffer.Modify(false);
                //>>Separate Orders & Stamp Order No
                WayfairFileBufferOrders.Reset();
                WayfairFileBufferOrders.SetFilter(DAR_PWF_EntryNo, '>%1', WayfairFileBuffer.DAR_PWF_EntryNo);
                WayfairFileBufferOrders.SetFilter(DAR_PWF_LineType, '<>%1', 'UNZ');
                if WayfairFileBufferOrders.FindSet() then
                    repeat
                        WayfairFileBufferOrders.DAR_PWF_OrderNo := WayfairFileBuffer.DAR_PWF_OrderNo;
                        WayfairFileBufferOrders.DAR_PWF_WayfairDespWarehouse := WayfairFileBuffer.DAR_PWF_WayfairDespWarehouse;
                        WayfairFileBufferOrders.Modify(false);
                        //>>Stamp LIN lines with order line no
                        WayfairFileBufferLines.Reset();
                        WayfairFileBufferLines.SetFilter(DAR_PWF_LineType, '%1', 'LIN');
                        WayfairFileBufferLines.SetRange(DAR_PWF_OrderNo, WayfairFileBufferOrders.DAR_PWF_OrderNo);
                        if WayfairFileBufferLines.FindSet() then begin
                            NewLineNo := 0;
                            repeat
                                NewLineNo += 10000;
                                WayfairFileBufferLines.DAR_PWF_OrderLineNo := NewLineNo;
                                WayfairFileBufferLines.Modify(false);
                                //>>Copy order line no to corresponding Item lines
                                WayfairFileBufferDetails.Reset();
                                WayfairFileBufferDetails.SetFilter(DAR_PWF_EntryNo, '>%1', WayfairFileBufferLines.DAR_PWF_EntryNo);
                                if WayfairFileBufferDetails.FindSet() then
                                    repeat
                                        WayfairFileBufferDetails.DAR_PWF_OrderLineNo := WayfairFileBufferLines.DAR_PWF_OrderLineNo;
                                        WayfairFileBufferDetails.Modify(false);
                                    until (WayfairFileBufferDetails.Next() = 0) or ((WayfairFileBufferDetails.DAR_PWF_LineType = 'LIN') or (WayfairFileBufferDetails.DAR_PWF_LineType = 'UNS'));
                            //<<Copy order line no to corresponding Item lines
                            until (WayfairFileBufferLines.Next() = 0);
                        end;
                    //<<Stamp LIN lines with order line no
                    until (WayfairFileBufferOrders.Next() = 0) or (WayfairFileBufferOrders.DAR_PWF_LineType = 'UNT');
            //<<Separate Orders & Stamp Order No
            until WayfairFileBuffer.Next() = 0;
        //<<Loop Through Imported lines & Copy Order No
    end;

    local procedure ProcessIntoCSNOrders(var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        WayfairFileBuffer: Record DAR_PWF_WayfairFileBuffer;
        EVSDBCMessageHeader: Record EVS_DBC_MessageHeader;
        EVSDBCMessageLine: Record EVS_DBC_MessageLine;
        GeneralLedgerSetup: Record "General Ledger Setup";
        Setting: Record DAR_PWF_Setting;
        TempCurrencyCode: Code[10];
        DTMDate: Text;
        StringLength: Integer;
        String: Text;
    begin
        //Get Setting
        Setting := Setting.GetSettings(EVSDBCMessageBatch.EVS_DBC_ProcessCode);

        // Need to check if the data has not been imported before.
        WayfairFileBuffer.Reset();
        if WayfairFileBuffer.FindSet() then
            repeat
                case WayfairFileBuffer.DAR_PWF_LineType of
                    'BGM':
                        begin
                            // Create a messageheader
                            EVSDBCMessageHeader.Init();
                            EVSDBCMessageHeader.Validate(EVS_DBC_MessageBatchID, EVSDBCMessageBatch.EVS_DBC_MessageBatchID);
                            EVSDBCMessageHeader.Validate(EVS_DBC_EntityTableNo, Database::"Sales Header");
                            EVSDBCMessageHeader.Validate(EVS_DBC_EntityTableType, 1);
                            EVSDBCMessageHeader.Validate(EVS_DBC_AccountCode, Setting.DAR_PWF_CustomerNo);
                            EVSDBCMessageHeader.Insert(true);

                            EVSDBCMessageHeader.Validate(EVS_DBC_HeaderRef1, WayfairFileBuffer.DAR_PWF_Value2);
                            EVSDBCMessageHeader.Validate(EVS_DBC_ExternalDocumentNo, WayfairFileBuffer.DAR_PWF_Value2);
                            EVSDBCMessageHeader.Validate(EVS_DBC_AddressCode, Setting.DAR_PWF_ShiptoCode);

                            //Force location & Bin code
                            EVSDBCMessageHeader.Validate(EVS_DBC_RemoteLocationCode, Setting.DAR_PWF_LocationFilter);
                            EVSDBCMessageHeader.Validate(EVS_DBC_RemoteBinCode, Setting.DAR_PWF_BinCode);
                            EVSDBCMessageHeader.Validate(EVS_DBC_Code4, WayfairFileBuffer.DAR_PWF_WayfairDespWarehouse);
                            EVSDBCMessageHeader.Modify(true);
                        end;
                    'DTM':
                        begin
                            DTMDate := WayfairFileBuffer.DAR_PWF_Value2;
                            DTMDate := CopyStr(DTMDate, 7, 2) + CopyStr(DTMDate, 5, 2) + CopyStr(DTMDate, 3, 2);

                            if WayfairFileBuffer.DAR_PWF_Value1 = '137' then begin
                                Evaluate(EVSDBCMessageHeader.EVS_DBC_RemoteOrderDate, DTMDate);
                                EVSDBCMessageHeader.Modify(true);
                            end;
                            if WayfairFileBuffer.DAR_PWF_Value1 = '85' then begin
                                Evaluate(EVSDBCMessageHeader.EVS_DBC_RemoteReqDeliveryDate, DTMDate);
                                EVSDBCMessageHeader.Modify(true);
                            end;
                        end;
                    'RFF':
                        begin
                            if WayfairFileBuffer.DAR_PWF_Value1 = 'VA' then begin
                                EVSDBCMessageHeader.Validate(EVS_DBC_Text1, WayfairFileBuffer.DAR_PWF_Value2);
                                EVSDBCMessageHeader.Modify(false);
                            end;
                            if WayfairFileBuffer.DAR_PWF_Value1 = 'IA' then begin //supplier ID
                                EVSDBCMessageHeader.Validate(EVS_DBC_YourReference, WayfairFileBuffer.DAR_PWF_Value2);
                                EVSDBCMessageHeader.Modify(false);
                            end;
                        end;
                    'NAD':
                        if (WayfairFileBuffer.DAR_PWF_Value1 = 'ST') or (WayfairFileBuffer.DAR_PWF_Value1 = 'OB') then begin
                            EVSDBCMessageHeader.Validate(EVS_DBC_UseAddress, true);
                            EVSDBCMessageHeader.Validate(EVS_DBC_AddressName, CopyStr(WayfairFileBuffer.DAR_PWF_Value3, 1, 50));
                            EVSDBCMessageHeader.Validate(EVS_DBC_Address, CopyStr(WayfairFileBuffer.DAR_PWF_Value5, 1, 50));
                            StringLength := StrLen(WayfairFileBuffer.DAR_PWF_Value6);
                            if StringLength > 30 then
                                EVSDBCMessageHeader.Validate(EVS_DBC_Address2, CopyStr(WayfairFileBuffer.DAR_PWF_Value6, 1, 50))
                            else
                                if WayfairFileBuffer.DAR_PWF_Value10 <> '' then begin
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddressCity, CopyStr(WayfairFileBuffer.DAR_PWF_Value7, 1, 30));
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddressCounty, CopyStr(WayfairFileBuffer.DAR_PWF_Value8, 1, 30));
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddressPostcode, CopyStr(WayfairFileBuffer.DAR_PWF_Value9, 1, 20));
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddCountryRegionCode, CopyStr(WayfairFileBuffer.DAR_PWF_Value10, 1, 10));
                                end else begin
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddressCity, CopyStr(WayfairFileBuffer.DAR_PWF_Value6, 1, 30));
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddressCounty, CopyStr(WayfairFileBuffer.DAR_PWF_Value7, 1, 30));
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddressPostcode, CopyStr(WayfairFileBuffer.DAR_PWF_Value8, 1, 20));
                                    EVSDBCMessageHeader.Validate(EVS_DBC_AddCountryRegionCode, CopyStr(WayfairFileBuffer.DAR_PWF_Value9, 1, 10));
                                end;
                            EVSDBCMessageHeader.Modify(false);
                        end;
                    'COM':
                        begin
                            if WayfairFileBuffer.DAR_PWF_Value2 = 'TE' then begin
                                EVSDBCMessageHeader.Validate(EVS_DBC_ContactTelephone, CopyStr(WayfairFileBuffer.DAR_PWF_Value1, 1, 30));
                                EVSDBCMessageHeader.Modify(true);
                            end;
                            if WayfairFileBuffer.DAR_PWF_Value1 = 'https?' then begin
                                String := StrSubstNo('%1:%2', WayfairFileBuffer.DAR_PWF_Value1, WayfairFileBuffer.DAR_PWF_Value2);
                                String := String.Replace('https?://', '');
                                EVSDBCMessageHeader.Validate(EVS_DBC_TrackingURL, String.Replace('??', '?'));
                                EVSDBCMessageHeader.Modify(true);
                            end;
                        end;
                    'CUX':
                        begin
                            GeneralLedgerSetup.Get();
                            TempCurrencyCode := CopyStr(WayfairFileBuffer.DAR_PWF_Value2, 1, 10);
                            if WayfairFileBuffer.DAR_PWF_Value2 = GeneralLedgerSetup."LCY Code" then
                                TempCurrencyCode := '';
                            EVSDBCMessageHeader.Validate(EVS_DBC_RemoteCurrencyCode, TempCurrencyCode);
                            EVSDBCMessageHeader.Modify(true);
                        end;
                    'LIN':
                        begin
                            EVSDBCMessageLine.Init();
                            EVSDBCMessageLine.EVS_DBC_MessageLineID := 0;
                            EVSDBCMessageLine.Validate(EVS_DBC_MessageHeaderID, EVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
                            EVSDBCMessageLine.Validate(EVS_DBC_RemoteLineNumber, Format(WayfairFileBuffer.DAR_PWF_OrderLineNo));
                            EVSDBCMessageLine.Validate(EVS_DBC_LineRef1, Format(WayfairFileBuffer.DAR_PWF_OrderLineNo));
                            EVSDBCMessageLine.Validate(EVS_DBC_RemoteItemIDentifier, WayfairFileBuffer.DAR_PWF_Value3);
                            EVSDBCMessageLine.Insert(true);
                        end;
                    'IMD':
                        begin
                            EVSDBCMessageLine.Reset();
                            EVSDBCMessageLine.SetRange(EVS_DBC_MessageHeaderID, EVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
                            EVSDBCMessageLine.SetRange(EVS_DBC_RemoteLineNumber, Format(WayfairFileBuffer.DAR_PWF_OrderLineNo));
                            if EVSDBCMessageLine.FindFirst() then begin
                                EVSDBCMessageLine.Validate(EVS_DBC_Text2, WayfairFileBuffer.DAR_PWF_Value6);
                                EVSDBCMessageLine.Modify(true);
                            end;
                        end;
                    'QTY':
                        begin
                            EVSDBCMessageLine.Reset();
                            EVSDBCMessageLine.SetRange(EVS_DBC_MessageHeaderID, EVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
                            EVSDBCMessageLine.SetRange(EVS_DBC_RemoteLineNumber, Format(WayfairFileBuffer.DAR_PWF_OrderLineNo));
                            if EVSDBCMessageLine.FindFirst() then begin
                                EVSDBCMessageLine.Validate(EVS_DBC_RemoteQuantity, WayfairFileBuffer.DAR_PWF_Value2);
                                EVSDBCMessageLine.Modify(true);
                            end;
                        end;
                    'PRI':
                        begin
                            EVSDBCMessageLine.Reset();
                            EVSDBCMessageLine.SetRange(EVS_DBC_MessageHeaderID, EVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
                            EVSDBCMessageLine.SetRange(EVS_DBC_RemoteLineNumber, Format(WayfairFileBuffer.DAR_PWF_OrderLineNo));
                            if EVSDBCMessageLine.FindFirst() then begin
                                EVSDBCMessageLine.Validate(EVS_DBC_RemoteItemPrice, WayfairFileBuffer.DAR_PWF_Value2);
                                EVSDBCMessageLine.Modify(true);
                            end;
                        end;
                    'TDT':
                        begin
                            //for DAR, they use the normal Shipping Agent Code and Shipping Agent Service Code to direct picking
                            //therefore, two new fields were created to hold the "final destination" carrier information
                            EVSDBCMessageHeader.Validate(EVS_DBC_Code2, WayfairFileBuffer.DAR_PWF_Value5);
                            EVSDBCMessageHeader.Validate(EVS_DBC_Code3, WayfairFileBuffer.DAR_PWF_Value8);
                            EVSDBCMessageHeader.Modify(false);
                        end;
                end;
            until WayfairFileBuffer.Next() = 0;
    end;

    procedure ImportShipOrders(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        WayfairFileBuffer: Record DAR_PWF_WayfairFileBuffer;
        TxtInstream: InStream;
        LineArray: array[15] of Text;
        FullLine: Text;
        Line: Text;
        ErrorString: Text;
        i: Integer;
        i2: Integer;
        ValueNo: Integer;
        EntryNo: Integer;
        ApostropheLbl: Label '''';
    begin
        //Get File and check if it has value
        EVSDBCMessageBatch.CalcFields(EVS_DBC_ImportExportFile);
        if not EVSDBCMessageBatch.EVS_DBC_ImportExportFile.HasValue() then begin
            CaptureError('Can not open file ');
            exit;
        end;

        //read the file
        EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateInStream(TxtInstream);
        TxtInstream.Read(FullLine);

        WayfairFileBuffer.LockTable();
        WayfairFileBuffer.DeleteAll();

        for i := 1 to StrLen(FullLine) do
            if Format(FullLine[i]) <> ApostropheLbl then
                Line += Format(FullLine[i])
            else begin
                //process the line
                EntryNo += 1;
                WayfairFileBuffer.Init();
                WayfairFileBuffer.DAR_PWF_EntryNo := EntryNo;
                WayfairFileBuffer.DAR_PWF_LineType := CopyStr(Line, 1, 3);

                ValueNo := 1;
                for i2 := 5 to StrLen(Line) do
                    if not (Line[i2] in ['+', ':']) then
                        LineArray[ValueNo] += Format(Line[i2])
                    else
                        ValueNo += 1;

                //separate the line into columns - cannot compress or will show different columns each time where blanks!!!
                for i2 := 1 to 14 do
                    if Format(LineArray[i2]) <> '' then
                        case i2 of
                            1:
                                WayfairFileBuffer.DAR_PWF_Value1 := Format(LineArray[i2]);
                            2:
                                WayfairFileBuffer.DAR_PWF_Value2 := Format(LineArray[i2]);
                            3:
                                WayfairFileBuffer.DAR_PWF_Value3 := Format(LineArray[i2]);
                            4:
                                WayfairFileBuffer.DAR_PWF_Value4 := Format(LineArray[i2]);
                            5:
                                WayfairFileBuffer.DAR_PWF_Value5 := Format(LineArray[i2]);
                            6:
                                WayfairFileBuffer.DAR_PWF_Value6 := Format(LineArray[i2]);
                            7:
                                WayfairFileBuffer.DAR_PWF_Value7 := Format(LineArray[i2]);
                            8:
                                WayfairFileBuffer.DAR_PWF_Value8 := Format(LineArray[i2]);
                            9:
                                WayfairFileBuffer.DAR_PWF_Value9 := Format(LineArray[i2]);
                            10:
                                WayfairFileBuffer.DAR_PWF_Value10 := Format(LineArray[i2]);
                            11:
                                WayfairFileBuffer.DAR_PWF_Value11 := Format(LineArray[i2]);
                            12:
                                WayfairFileBuffer.DAR_PWF_Value12 := Format(LineArray[i2]);
                            13:
                                WayfairFileBuffer.DAR_PWF_Value13 := Format(LineArray[i2]);
                            14:
                                WayfairFileBuffer.DAR_PWF_Value14 := Format(LineArray[i2]);
                            15:
                                WayfairFileBuffer.DAR_PWF_Value15 := Format(LineArray[i2]);
                        end;

                WayfairFileBuffer.Insert(true);
                Line := '';
                Clear(LineArray);
            end;

        if WayfairFileBuffer.Count = 0 then begin
            CaptureError('No Records found ');
            exit;
        end;

        ProcessOrder(EVSDBCMessageBatch);
        if ErrorsFound then begin
            Clear(ErrorString);
            for i := 1 to ErrorCount do
                if ErrorArray[i] <> '' then
                    if ErrorString = '' then
                        ErrorString := ErrorArray[i]
                    else
                        ErrorString += '</P>' + ErrorArray[i];
            Error(ErrorString);
        end;
    end;

    local procedure ProcessOrder(var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        WayfairFileBuffer: Record DAR_PWF_WayfairFileBuffer;
        Setting: Record DAR_PWF_Setting;
        SalesHeader: Record "Sales Header";
        ShipmentNumber: Text[20];
        WayfairOrderNumber: Text[30];
        ItemNumber: Text[20];
        DTMDate: Text[20];
        DateShipped: Date;
        ItemsFound: Integer;
        ItemsCount: Integer;
        QtyShipped: Integer;
    begin
        Setting := Setting.GetSettings(EVSDBCMessageBatch.EVS_DBC_ProcessCode);

        //Process all orders in file
        WayfairFileBuffer.Reset();
        if WayfairFileBuffer.FindSet() then
            repeat
                case WayfairFileBuffer.DAR_PWF_LineType of
                    'BGM':
                        begin
                            ShipmentNumber := '';
                            if (WayfairFileBuffer.DAR_PWF_Value2 = '') then
                                CaptureError('Missing Shipment No');

                            ShipmentNumber := CopyStr(WayfairFileBuffer.DAR_PWF_Value2, 1, 20);
                            Clear(SalesHeader);
                            DateShipped := 0D;
                            ItemsCount := 0;
                            ItemsFound := 0;
                            ErrorsFound := false;
                        end;
                    'DTM':
                        if (ShipmentNumber <> '') and (CopyStr(WayfairFileBuffer.DAR_PWF_Value1, 1, 2) = '11') and (WayfairFileBuffer.DAR_PWF_Value2 <> '') then begin
                            DTMDate := CopyStr(WayfairFileBuffer.DAR_PWF_Value2, 1, MaxStrLen(DTMDate));
                            DTMDate := CopyStr(DTMDate, 7, 2) + CopyStr(DTMDate, 5, 2) + CopyStr(DTMDate, 3, 2);
                            Evaluate(DateShipped, DTMDate);
                        end;
                    'RFF':
                        if (ShipmentNumber <> '') and (WayfairFileBuffer.DAR_PWF_Value1 = 'VN') then begin
                            if (WayfairFileBuffer.DAR_PWF_Value2 = '') then begin
                                CaptureError('Missing Customer Ref');
                                exit;
                            end;
                            WayfairOrderNumber := CopyStr(WayfairFileBuffer.DAR_PWF_Value2, 1, 30);
                            SalesHeader.Reset();
                            SalesHeader.SetCurrentKey("Sell-to Customer No.", "External Document No.");
                            SalesHeader.SetRange("Sell-to Customer No.", Setting.DAR_PWF_CustomerNo);
                            SalesHeader.SetRange("External Document No.", WayfairOrderNumber);
                            SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
                            if not SalesHeader.FindFirst() then begin
                                CaptureError('Customer Ref not found : ' + WayfairOrderNumber);
                                SalesHeader.Init();
                            end;
                            SalesHeader."Shipment Date" := DateShipped;
                        end;
                    'GIN':
                        if (SalesHeader."No." <> '') and (WayfairFileBuffer.DAR_PWF_Value2 <> '') then
                            SalesHeader."Package Tracking No." := CopyStr(WayfairFileBuffer.DAR_PWF_Value2, 1, 30);
                    'LIN':
                        begin
                            ItemNumber := '';
                            QtyShipped := 0;
                            if (SalesHeader."No." <> '') then
                                if WayfairFileBuffer.DAR_PWF_Value3 <> '' then
                                    ItemNumber := CopyStr(WayfairFileBuffer.DAR_PWF_Value3, 1, 20)
                                else
                                    CaptureError('Item Number missing');
                        end;
                    'QTY':
                        if (SalesHeader."No." <> '') then begin
                            if WayfairFileBuffer.DAR_PWF_Value2 <> '' then
                                Evaluate(QtyShipped, CopyStr(WayfairFileBuffer.DAR_PWF_Value2, 1, 10))
                            else
                                CaptureError('Qty Shipped missing for ' + ItemNumber);

                            if (QtyShipped <> 0) and (ItemNumber <> '') then
                                if ValidateSalesLine(SalesHeader, ItemNumber, QtyShipped) then
                                    ItemsFound += 1;
                        end;
                    'CNT':
                        if (SalesHeader."No." <> '') then begin
                            if WayfairFileBuffer.DAR_PWF_Value2 <> '' then
                                Evaluate(ItemsCount, CopyStr(WayfairFileBuffer.DAR_PWF_Value2, 1, 10))
                            else
                                CaptureError('Item Count missing');

                            if ItemsCount <> ItemsFound then
                                CaptureError('Items Count differs from Items Found');

                            if ErrorsFound = false then begin
                                // Update sales header and ship / Invoice
                                SalesHeader."Posting Date" := Today;
                                SalesHeader.Ship := true;
                                SalesHeader.Invoice := true;
                                SalesHeader.Modify(true);
                                Clear(WayfairManagement);
                                WayfairManagement.PassSalesHeader(SalesHeader);
                                Codeunit.Run(80, SalesHeader);
                            end;
                        end

                end;
            until WayfairFileBuffer.Next() = 0;
    end;

    local procedure ValidateSalesLine(SalesHeader: Record "Sales Header"; ItemNumber: Code[20]; QtyShipped: Integer) Valid: Boolean
    var
        SalesLine: Record "Sales Line";
    begin
        Valid := true;

        if SalesHeader."No." = '' then begin
            CaptureError('Sales Header not found for ' + ItemNumber);
            Valid := false;
        end;

        if Valid then begin
            SalesLine.Reset();
            SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
            SalesLine.SetRange("Document No.", SalesHeader."No.");
            SalesLine.SetRange(Type, SalesLine.Type::Item);
            SalesLine.SetRange("No.", ItemNumber);
            if not SalesLine.FindFirst() then begin
                CaptureError('Item not found ' + ItemNumber);
                Valid := false;
            end;
        end;

        if (Valid) and (QtyShipped > SalesLine."Outstanding Quantity") then begin
            CaptureError('Shipped Qty greater than outstanding Qty ' + ItemNumber);
            Valid := false;
        end;

        if Valid then begin
            SalesLine.Validate("Qty. to Ship", QtyShipped);
            SalesLine."Shipment Date" := SalesHeader."Shipment Date";
            SalesLine.Modify();
        end;
    end;

    local procedure CaptureError(ErrorMessage: Text[100])
    begin
        ErrorCount += 1;
        ErrorArray[ErrorCount] := ErrorMessage;
        ErrorsFound := true;
    end;
}
