codeunit 50502 DAR_PNX_NextProcessMgmt
{
    procedure InvoiceMatching(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        EVSDBCMessageHeader: Record EVS_DBC_MessageHeader;
        TempExcelBuffer: Record "Excel Buffer" temporary;
        ExcelInStream: InStream;
        SheetName: Text;
        itemNo, CommissionRateType, SalesCountry, VATCode : text;
        NetItemPrice, SalesItemPrice, ReturnItemPrice, NetQuantity, SalesQuantity, ReturnQuantity, NetCost, SalesCost, ReturnCost,
        CommissionRate, VatAmount, NSVE, Commision, UKVat : decimal;
        LineNo, RowNo : Integer;
        DiscountPercentage, NextVatRate : Decimal;
        ErrorList: List of [Text];
        ErrorLbl: Label 'Value %1 cannot be converted to decimal', Comment = '%1 is the field';
    begin
        // get the Stream
        EVSDBCMessageBatch.CalcFields(EVS_DBC_ImportExportFile);
        if not EVSDBCMessageBatch.EVS_DBC_ImportExportFile.HasValue() then
            exit;

        EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateInStream(ExcelInStream);
        SheetName := GetSheetName(EVSDBCProcess.EVS_DBC_ProcessCode, TempExcelBuffer, ExcelInStream);

        // Read Stream
        ReadExcelSheet(TempExcelBuffer, ExcelInStream, SheetName);

        // Get the value
        LineNo := 0;

        RowNo := 3;
        // Create a messageheader
        EVSDBCMessageHeader.Init();
        EVSDBCMessageHeader.Validate(EVS_DBC_MessageBatchID, EVSDBCMessageBatch.EVS_DBC_MessageBatchID);

        EVSDBCMessageHeader.Insert(true);

        // Need to loop through the lines
        TempExcelBuffer.SetFilter("Row No.", '>2');
        if TempExcelBuffer.FindSet() then
            repeat
                if RowNo <> TempExcelBuffer."Row No." then begin


                    // Need to calculate the values
                    if NetQuantity <> 0 then
                        NetItemPrice := Round(NetCost / NetQuantity, 0.001);

                    if SalesQuantity <> 0 then
                        SalesItemPrice := Round(SalesCost / SalesQuantity, 0.001);

                    if ReturnQuantity <> 0 then
                        ReturnItemPrice := Round(ReturnCost / ReturnQuantity, 0.001);

                    // Prices include NEXT VAT so needs removing
                    NextVatRate := NextVatRate / 100;
                    NetItemPrice := NetItemPrice / (1 + NextVatRate);
                    SalesItemPrice := SalesItemPrice / (1 + NextVatRate);
                    ReturnItemPrice := ReturnItemPrice / (1 + NextVatRate);

                    // Sometimes the Sales Quantity is negative
                    if SalesQuantity < 0 then begin
                        ReturnQuantity += -SalesQuantity;
                        SalesQuantity := 0;
                        if ReturnItemPrice = 0 then
                            ReturnItemPrice := SalesItemPrice;
                    end;

                    if itemNo <> '' then begin
                        LineNo += 10000;
                        if SalesQuantity <> 0 then
                            AddLine(EVSDBCMessageHeader, RowNo, ItemNo, SalesItemPrice, Commision, SalesQuantity, CommissionRate, VATCode);
                        if ReturnQuantity <> 0 then
                            AddLine(EVSDBCMessageHeader, RowNo, ItemNo, ReturnItemPrice, Commision, ReturnQuantity, CommissionRate, VATCode);
                    end;
                    // rest the values
                    itemNo := '';
                    SalesQuantity := 0;
                    ReturnQuantity := 0;
                    NetQuantity := 0;
                    NetItemPrice := 0;
                    SalesItemPrice := 0;
                    ReturnItemPrice := 0;
                    DiscountPercentage := 0;
                    VATCode := '';

                    // Set the row o
                    RowNo := TempExcelBuffer."Row No.";

                    if TempExcelBuffer."Cell Value as Text" = 'Total' then
                        // GetTotals(EVSDBCMessageHeader, TempExcelBuffer, RowNo);
                        exit;


                end;
                case TempExcelBuffer."Column No." of
                    1:
                        if TempExcelBuffer."Cell Value as Text" <> '' then
                            if not Evaluate(CommissionRate, TempExcelBuffer."Cell Value as Text") then
                                ErrorList.Add(StrSubstNo(ErrorLbl, 'CommissionRate'));
                    2:
                        CommissionRateType := TempExcelBuffer."Cell Value as Text";
                    4:
                        itemNo := TempExcelBuffer."Cell Value as Text";
                    7:
                        if not Evaluate(SalesQuantity, TempExcelBuffer."Cell Value as Text") then
                            ErrorList.Add(StrSubstNo(ErrorLbl, 'Dispatch Quantity'));
                    8:
                        if not Evaluate(SalesCost, TempExcelBuffer."Cell Value as Text") then
                            ErrorList.Add(StrSubstNo(ErrorLbl, 'SalesCost'));
                    9:
                        if not Evaluate(ReturnQuantity, TempExcelBuffer."Cell Value as Text") then
                            ErrorList.Add(StrSubstNo(ErrorLbl, 'ReturnQuantity'));
                    10:
                        if not Evaluate(ReturnCost, TempExcelBuffer."Cell Value as Text") then
                            ErrorList.Add(StrSubstNo(ErrorLbl, 'ReturnCost'));
                    11:
                        if not Evaluate(NetQuantity, TempExcelBuffer."Cell Value as Text") then
                            ErrorList.Add(StrSubstNo(ErrorLbl, 'NetQuantity'));
                    12:
                        if not Evaluate(NetCost, TempExcelBuffer."Cell Value as Text") then
                            ErrorList.Add(StrSubstNo(ErrorLbl, 'NetCost'));
                    13:
                        SalesCountry := TempExcelBuffer."Cell Value as Text";
                    14:
                        if not Evaluate(NextVatRate, TempExcelBuffer."Cell Value as Text") then
                            ErrorList.Add(StrSubstNo(ErrorLbl, 'NextVatRate'));
                    15:
                        if not Evaluate(VatAmount, TempExcelBuffer."Cell Value as Text") then
                            ErrorList.Add(StrSubstNo(ErrorLbl, 'VatAmount'));
                    16:
                        if not Evaluate(NSVE, TempExcelBuffer."Cell Value as Text") then
                            ErrorList.Add(StrSubstNo(ErrorLbl, 'NSVE'));
                    17:
                        if not Evaluate(Commision, TempExcelBuffer."Cell Value as Text") then
                            ErrorList.Add(StrSubstNo(ErrorLbl, 'Commision'));
                    18:
                        if not Evaluate(UKVat, TempExcelBuffer."Cell Value as Text") then
                            ErrorList.Add(StrSubstNo(ErrorLbl, 'UKVat'));
                end;





            until TempExcelBuffer.Next() = 0;
    end;

    local procedure AddLine(var EVSDBCMessageHeader: record EVS_DBC_MessageHeader; LineNo: integer; ItemNo: Text; ItemPrice: Decimal;
            ItemDiscount: decimal; ItemQuantity: decimal; DiscountPercentage: Decimal; VatCode: Text)
    var
        EVSDBCMessageLine: Record EVS_DBC_MessageLine;
    begin
        // Add the 
        // EVSDBCMessageLine.SetRange(EVS_DBC_RemoteItemIDentifier, ItemNo);
        // EVSDBCMessageLine.SetRange(EVS_DBC_RemoteItemPrice, Format(ItemPrice));
        // EVSDBCMessageLine.SetRange(EVS_DBC_Discount, ItemDiscount);
        // EVSDBCMessageLine.SetRange(EVS_DBC_MessageHeaderID, EVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
        // if not EVSDBCMessageLine.FindFirst() then begin
        // Set the defaults
        //EVSDBCMessageLine.Validate(EVS_DBC_LineRef1, EVSDBCMessageHeader.EVS_DBC_EntityDocumentNo);
        EVSDBCMessageLine.Validate(EVS_DBC_AccountCode, EVSDBCMessageHeader.EVS_DBC_AccountCode);
        EVSDBCMessageLine.Validate(EVS_DBC_EntityDocumentNo, EVSDBCMessageHeader.EVS_DBC_EntityDocumentNo);
        EVSDBCMessageLine.Validate(EVS_DBC_RemoteLineNumber, Format(LineNo));


        // Set the vallues
        EVSDBCMessageLine.Validate(EVS_DBC_RemoteItemIDentifier, ItemNo);
        EVSDBCMessageLine.Validate(EVS_DBC_Discount, ItemDiscount);
        EVSDBCMessageLine.Validate(EVS_DBC_MessageHeaderID, EVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
        EVSDBCMessageLine.Validate(EVS_DBC_RemoteVatCode, VatCode);
        EVSDBCMessageLine.Validate(EVS_DBC_RemoteDiscount, Format(DiscountPercentage));
        EVSDBCMessageLine.Insert(true);
        // end;
        // Save the values
        EVSDBCMessageLine.Validate(EVS_DBC_RemoteItemPrice, Format(ItemPrice));

        EVSDBCMessageLine.Validate(EVS_DBC_RemoteQuantity, Format(ItemQuantity));

        EVSDBCMessageLine.Modify(true);

    end;

    /*local procedure GetTotals(var EVSDBCMessageHeader: Record EVS_DBC_MessageHeader; var TempExcelBuffer: Record "Excel Buffer" temporary; RowNo: Integer)
    var
        ErrorLbl: Label 'Value %1 cannot be converted to decimal', Comment = '%1 is the field';
        Modify: Boolean;
    begin
        if TempExcelBuffer.Get(RowNo + 1, 12) then
            if not Evaluate(EVSDBCMessageHeader.EVS_DBC_TotalValue, TempExcelBuffer."Cell Value as Text") then
                EVSDBCMessageHeader.LogError(StrSubstNo(ErrorLbl, 'TotalCost'))
            else
                Modify := true;
        if TempExcelBuffer.Get(RowNo + 1, 15) then
            if not Evaluate(EVSDBCMessageHeader.EVS_DBC_TotalVatValue, TempExcelBuffer."Cell Value as Text") then
                EVSDBCMessageHeader.LogError(StrSubstNo(ErrorLbl, 'VATAmount'))
            else
                Modify := true;
        if Modify then
            EVSDBCMessageHeader.Modify(true);
    end;*/

    local procedure GetSheetName(ProcessCode: Code[20]; TempExcelBuffer: Record "Excel Buffer"; FileInStream: InStream): Text[250]
    var
        Setting: Record DAR_PNX_Setting;
        TempNameValueBuffer: Record "Name/Value Buffer" temporary;
        SelectedSheetName: Text[250];
    begin

        Setting.Get(ProcessCode);
        SelectedSheetName := Setting.DAR_PNX_ImportSheetName;
        if SelectedSheetName = '' then
            if TempExcelBuffer.GetSheetsNameListFromStream(FileInStream, TempNameValueBuffer) then begin
                TempNameValueBuffer.FindFirst();
                SelectedSheetName := TempNameValueBuffer.Value;
            end;
        exit(SelectedSheetName);
    end;

    local procedure ReadExcelSheet(var TempExcelBuffer: Record "Excel Buffer" temporary; var ExcelInStream: InStream; SheetName: Text)
    begin
        TempExcelBuffer.OpenBookStream(ExcelInStream, SheetName);
        TempExcelBuffer.ReadSheet();
    end;

    procedure OrderImport(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch; NEXOption: Option NEXNonStocked,NEXDirDisp)
    var
        Setting: Record DAR_PNX_Setting;
        DARPNXNextNonStockedOrder: XmlPort DAR_PNX_NextNonStockedOrder;
        DARPNXNextDirectDispOrder: XmlPort DAR_PNX_NextDirectDispOrder;
        InboundInStream: InStream;
    begin
        // get the Stream
        EVSDBCMessageBatch.CalcFields(EVS_DBC_ImportExportFile);
        EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateInStream(InboundInStream);

        //Import File
        case NEXOption of
            NexOption::NEXNonStocked:
                begin
                    DARPNXNextNonStockedOrder.SetSource(InboundInStream);
                    DARPNXNextNonStockedOrder.setMessageBatchID(EVSDBCMessageBatch.EVS_DBC_MessageBatchID);
                    DARPNXNextNonStockedOrder.Import();
                end;
            NEXOption::NEXDirDisp:
                begin
                    DARPNXNextDirectDispOrder.SetSource(InboundInStream);
                    DARPNXNextDirectDispOrder.setMessageBatchID(EVSDBCMessageBatch.EVS_DBC_MessageBatchID);
                    DARPNXNextDirectDispOrder.Import();
                end;
        end;

        Commit();

        Setting.Get(EVSDBCMessageBatch.EVS_DBC_ProcessCode);
        //Update Last Execution Datetime
        Setting.DAR_PNX_ProcessLastExecution := CurrentDateTime;
        Setting.Modify();
    end;

    procedure OrderAcknowledge(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        EVSDBCMessageHeader: Record EVS_DBC_MessageHeader;
        TempBlob: Codeunit "Temp Blob";
    begin
        //get the headers
        EVSDBCMessageHeader.SetRange(EVS_DBC_MessageBatchID, EVSDBCMessageBatch.EVS_DBC_MessageBatchID);
        if EVSDBCMessageHeader.FindSet() then
            repeat
                Clear(TempBlob);
                SendOrderAck(EVSDBCMessageHeader, EVSDBCMessageBatch, TempBlob);
            until EVSDBCMessageHeader.Next() = 0;
    end;

    local procedure SendOrderAck(EVSDBCMessageHeader: Record EVS_DBC_MessageHeader; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch; var TempBlob: Codeunit "Temp Blob"): Boolean
    var
        Setting: Record DAR_PNX_Setting;
        EVSDBCMessageMgmt: Codeunit EVS_DBC_MessageMgmt;
        DARPNXNEXTNonStockedOrderAck: XmlPort DAR_PNX_NEXTNonStockedOrderAck;
        XMLFileName: Text[250];
        XMLOutStream: OutStream;
    begin
        //Get Settings
        Setting.Get(EVSDBCMessageBatch.EVS_DBC_ProcessCode);

        //get the Stream
        TempBlob.CreateOutStream(XMLOutStream);

        // Need to create the File Name
        XMLFileName += Setting.DAR_PNX_AckFilePrefix;
        XMLFileName += EVSDBCMessageHeader.EVS_DBC_ExternalDocumentNo;
        XMLFileName += Setting.DAR_PNX_FIleExtension;

        DARPNXNEXTNonStockedOrderAck.SetDestination(XMLOutStream);
        EVSDBCMessageHeader.SetRecFilter();
        DARPNXNEXTNonStockedOrderAck.SetTableView(EVSDBCMessageHeader);
        DARPNXNEXTNonStockedOrderAck.Export();
        EVSDBCMessageBatch.EVS_DBC_ImportExportFileName := XMLFileName;
        EVSDBCMessageBatch.Modify();
        EVSDBCMessageMgmt.UpdateCreateBatch(EVSDBCMessageBatch, EVSDBCMessageHeader, TempBlob, EVS_DBC_MessageStatus::Exported);
        EVSDBCMessageBatch.EVS_DBC_MessageStatus := EVS_DBC_MessageStatus::Exported;

        // Commit as we have created the file and errors would roll back this completion.
        Commit();

        //Update Last Execution Datetime
        Setting.DAR_PNX_ProcessLastExecution := CurrentDateTime;
        Setting.Modify();
    end;

    procedure OrderStatus(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        EVSDBCMessageHeader: Record EVS_DBC_MessageHeader;
        TempBlob: Codeunit "Temp Blob";
    begin
        // This is split into two parts,
        // Cancelation and Dispatch.
        EVSDBCMessageHeader.SetRange(EVS_DBC_MessageBatchID, EVSDBCMessageBatch.EVS_DBC_MessageBatchID);
        if EVSDBCMessageHeader.FindSet() then
            repeat
                Clear(TempBlob);
                CreateOrderStatusFile(EVSDBCMessageHeader, EVSDBCMessageBatch, TempBlob);
            until EVSDBCMessageHeader.Next() = 0;
    end;

    local procedure CreateOrderStatusFile(EVSDBCMessageHeader: Record EVS_DBC_MessageHeader; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch; var TempBlob: Codeunit "Temp Blob")
    var
        EVSDBCMessageLine: Record EVS_DBC_MessageLine;
        Setting: Record DAR_PNX_Setting;
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesHeader: Record "Sales Header";
        XMLWriter: Codeunit XmlWriter;
        EVSDBCMessageMgmt: Codeunit EVS_DBC_MessageMgmt;
        XMLBigText: BigText;
        ShipToCode: Code[20];
        XMLFileName: Text[250];
        XMLOutStream: OutStream;
    begin
        //Get Settings
        Setting.Get(EVSDBCMessageBatch.EVS_DBC_ProcessCode);

        //get the Stream
        TempBlob.CreateOutStream(XMLOutStream);

        // Do the last order
        // Need to create the File Name
        XMLFileName += Setting.DAR_PNX_StatusFilePrefix;
        XMLFileName += EVSDBCMessageHeader.EVS_DBC_ExternalDocumentNo;
        XMLFileName += Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>-<Hours24,2><Minutes,2>');
        XMLFileName += Setting.DAR_PNX_FIleExtension;

        XMLWriter.WriteProcessingInstruction('xml', 'version="1.0" encoding="UTF-8"');
        //Create Parent element
        XMLWriter.WriteStartElement('OrderStatus');
        XMLWriter.WriteStartElement('Order');
        XMLWriter.WriteElementString('ID', EVSDBCMessageHeader.EVS_DBC_ExternalDocumentNo);
        XMLWriter.WriteStartElement('Items');

        if SalesShipmentHeader.GetBySystemId(EVSDBCMessageHeader.EVS_DBC_EntitySystemID) then
            ShipToCode := SalesShipmentHeader."Ship-to Code"
        else
            if SalesHeader.GetBySystemId(EVSDBCMessageHeader.EVS_DBC_EntitySystemID) then
                ShipToCode := SalesHeader."Ship-to Code";
        //Get Lines
        EVSDBCMessageLine.SetRange(EVS_DBC_MessageHeaderID, EVSDBCMessageHeader.EVS_DBC_MessageHeaderID);
        if EVSDBCMessageLine.FindSet() then
            repeat
                //Create Child elements
                XMLWriter.WriteStartElement('Item');
                XMLWriter.WriteElementString('ItemID', Format(EVSDBCMessageLine.EVS_DBC_LineRef1));
                XMLWriter.WriteElementString('EAN', EVSDBCMessageLine.EVS_DBC_RemoteItemIDentifier);
                XMLWriter.WriteElementString('Quantity', Format(EVSDBCMessageLine.EVS_DBC_Quantity));
                if EVSDBCMessageHeader.EVS_DBC_LinkSelectionValue = 'Cancellation' then
                    XMLWriter.WriteElementString('Status', 'Cancelled')
                else
                    XMLWriter.WriteElementString('Status', 'Dispatched');
                XMLWriter.WriteEndElement();
            until EVSDBCMessageLine.Next() = 0;
        //Close items
        XMLWriter.WriteEndElement();
        XMLWriter.WriteElementString('Brand', Setting.DAR_PNX_Brand);
        if Setting.DAR_PNX_TrackingLink = '' then
            XMLWriter.WriteElementString('ShippingReference', EVSDBCMessageHeader.EVS_DBC_TrackingNumber)
        else
            XMLWriter.WriteElementString('ShippingReference', Setting.DAR_PNX_TrackingLink);
        XMLWriter.WriteElementString('Destination', ShipToCode);
        XMLWriter.WriteElementString('DateTimeStamp', Format(CurrentDateTime, 20, '<Year4>-<Month,2>-<Day,2>T<Hour,2>:<Minute,2>:<Second,2>'));

        XMLWriter.WriteEndElement();
        //End writing top element and XML document
        XMLWriter.WriteEndElement();

        //Write to Outstream
        XMLWriter.ToBigText(XMLBigText);
        XMLBigText.Write(XMLOutStream);

        //Update Message Batch Status
        EVSDBCMessageBatch.EVS_DBC_ImportExportFileName := XMLFileName;
        EVSDBCMessageBatch.Modify();
        EVSDBCMessageMgmt.UpdateCreateBatch(EVSDBCMessageBatch, EVSDBCMessageHeader, TempBlob, EVS_DBC_MessageStatus::Exported);
        EVSDBCMessageBatch.EVS_DBC_MessageStatus := EVS_DBC_MessageStatus::Exported;

        // Commit as we have created the file and errors would roll back this completion.
        Commit();

        //Update Last Execution Datetime
        Setting.DAR_PNX_ProcessLastExecution := CurrentDateTime;
        Setting.Modify();
    end;

    procedure DispOrderAcknowledge(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        SalesHeader: Record "Sales Header";
        EVSDBCMessageHeader: Record EVS_DBC_MessageHeader;
        Setting: Record DAR_PNX_Setting;
        XMLWriter: Codeunit XmlWriter;
        XmlBigText: BigText;
        XMLFileName: Text;
        XMLOutStream: OutStream;
    begin
        //Get Settings
        Setting.Get(EVSDBCMessageBatch.EVS_DBC_ProcessCode);

        //get the Stream
        EVSDBCMessageBatch.CalcFields(EVS_DBC_ImportExportFile);
        EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateOutStream(XMLOutStream, TextEncoding::UTF8);

        //Create the file
        // Need to create the File Name
        XMLFileName += Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>-<Hours24,2><Minutes,2>');
        XMLFileName += Setting.DAR_PNX_FIleExtension;

        XMLWriter.WriteProcessingInstruction('xml', 'version="1.0" encoding="UTF-8"');

        //Create Parent element
        XMLWriter.WriteStartElement('orders');
        // Get the extended sales header
        EVSDBCMessageHeader.SetRange(EVS_DBC_MessageBatchID, EVSDBCMessageBatch.EVS_DBC_MessageBatchID);
        if EVSDBCMessageHeader.FindSet() then
            repeat
                // Check the Sales header
                if SalesHeader.Get(SalesHeader."Document Type"::Order, EVSDBCMessageHeader.EVS_DBC_EntityDocumentNo) then begin
                    XMLWriter.WriteStartElement('order');
                    XMLWriter.WriteElementString('id', SalesHeader."External Document No.");
                    XMLWriter.WriteEndElement();
                end;
            until EVSDBCMessageHeader.Next() = 0;
        //End writing top element and XML document
        XMLWriter.WriteEndElement();

        //Write to Outstream
        XMLWriter.ToBigText(XmlBigText);
        XmlBigText.Write(XMLOutStream);

        //Update Message Batch Status
        EVSDBCMessageBatch.EVS_DBC_MessageStatus := EVS_DBC_MessageStatus::Exported;
        EVSDBCMessageBatch.Validate(EVS_DBC_ImportExportFileName, XMLFileName);
        EVSDBCMessageBatch.Modify(true);

        // Commit as we have created the file and errors would roll back this completion.
        Commit();

        //Update Last Execution Datetime
        Setting.DAR_PNX_ProcessLastExecution := CurrentDateTime;
        Setting.Modify();
    end;

    procedure DispatchOrderStatus(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch)
    var
        EVSDBCMessageHeader: Record EVS_DBC_MessageHeader;
        Setting: Record DAR_PNX_Setting;
        XMLWriter: Codeunit XmlWriter;
        XMLBigText: BigText;
        XMLFileName: Text;
        XMLOutStream: OutStream;
    begin
        //Get Settings
        Setting.Get(EVSDBCMessageBatch.EVS_DBC_ProcessCode);

        //get the Stream
        EVSDBCMessageBatch.CalcFields(EVS_DBC_ImportExportFile);
        EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateOutStream(XMLOutStream, TextEncoding::UTF8);
        //Dispatch
        //Create the file
        // Need to create the File Name
        XMLFileName += Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>-<Hours24,2><Minutes,2>');
        XMLFileName += Setting.DAR_PNX_FIleExtension;

        XMLWriter.WriteProcessingInstruction('xml', 'version="1.0" encoding="UTF-8"');

        //Create Parent element
        XMLWriter.WriteStartElement('orders');

        // Loop through the headers in batch
        EVSDBCMessageHeader.SetRange(EVS_DBC_MessageBatchID, EVSDBCMessageBatch.EVS_DBC_MessageBatchID);
        if EVSDBCMessageHeader.FindSet() then
            repeat
                XMLWriter.WriteStartElement('order');
                XMLWriter.WriteElementString('id', EVSDBCMessageHeader.EVS_DBC_ExternalDocumentNo);
                XMLWriter.WriteElementString('shipping_tracking', EVSDBCMessageHeader.EVS_DBC_TrackingNumber);
                XMLWriter.WriteEndElement();
            until EVSDBCMessageHeader.Next() = 0;

        //End writing top element and XML document
        XMLWriter.WriteEndElement();

        //Write to Outstream
        XMLWriter.ToBigText(XMLBigText);
        XMLBigText.Write(XMLOutStream);

        //Update Message Batch Status
        EVSDBCMessageBatch.EVS_DBC_MessageStatus := EVS_DBC_MessageStatus::Exported;
        EVSDBCMessageBatch.Validate(EVS_DBC_ImportExportFileName, XMLFileName);
        EVSDBCMessageBatch.Modify(true);

        // Commit as we have created the file and errors would roll back this completion.
        Commit();

        //Update Last Execution Datetime
        Setting.DAR_PNX_ProcessLastExecution := CurrentDateTime;
        Setting.Modify();
    end;

    internal procedure StockFeed(var EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch; NEXOption: Option NEXNonStocked,NEXDirDisp)
    var
        MessageHeader: Record EVS_DBC_MessageHeader;
        NEXTDirDispStockLevel: XmlPort DAR_PNX_NEXTDirDispStockLevel;
        NEXTNonStockedLevel: XmlPort DAR_PNX_NEXTNonStockedLevel;
        XMLOutStream: OutStream;
        XMLFileName: Text[250];
    begin
        //Create Message Header
        MessageHeader.Init();
        MessageHeader.Validate(EVS_DBC_MessageBatchID, EVSDBCMessageBatch.EVS_DBC_MessageBatchID);
        MessageHeader.Insert(true);

        //get the Stream
        EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateOutStream(XMLOutStream);

        case NEXOption of
            NexOption::NEXNonStocked:
                begin
                    // Need to create the File Name
                    XMLFileName := 'INV_' + Format(CurrentDateTime, 0, '<Month,2>-<Day,2>-<Hours24,2><Minutes,2><Seconds,2>') + '.xml';
                    NEXTNonStockedLevel.SetDestination(XMLOutStream);
                    NEXTNonStockedLevel.setMessageHeaderID(MessageHeader.EVS_DBC_MessageHeaderID);
                    NEXTNonStockedLevel.Export();
                end;
            NEXOption::NEXDirDisp:
                begin
                    // Need to create the File Name
                    XMLFileName := 'NEX03_' + Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hour,2><Minute,2><Seconds,2>') + '.xml';
                    NEXTDirDispStockLevel.SetDestination(XMLOutStream);
                    NEXTDirDispStockLevel.setMessageHeaderID(MessageHeader.EVS_DBC_MessageHeaderID);
                    NEXTDirDispStockLevel.Export();
                end;
        end;

        //Save Batch
        EVSDBCMessageBatch.EVS_DBC_ImportExportFileName := XMLFileName;
        EVSDBCMessageBatch.EVS_DBC_MessageStatus := EVS_DBC_MessageStatus::Exported;
        EVSDBCMessageBatch.Modify(true);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::EVS_DBC_SalesDocImportProcess, 'InsertSalesLine_OnBeforeModifySalesLine', '', false, false)]
    local procedure RunOnBeforeModifyNextSalesLine(var EVSDBCMessageHeader: Record EVS_DBC_MessageHeader; var EVSDBCMessageLine: Record EVS_DBC_MessageLine; var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line")
    begin
        if not (EVSDBCMessageHeader.EVS_DBC_Partner in [EVSDBCMessageHeader.EVS_DBC_Partner::DAR_PNX_NextDirectDispatch, EVSDBCMessageHeader.EVS_DBC_Partner::DAR_PNX_NextNonStocked]) then
            exit;

        case EVSDBCMessageHeader.EVS_DBC_ProcessTypeEnum of
            Enum::EVS_DBC_ProcessTypeEnum::ImportSalesDocument_I:
                SalesLine.Validate(DAR_ENC_ExternalLineNo, EVSDBCMessageLine.EVS_DBC_LineRef1);
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::EVS_DBC_HelperFunctions, 'OnGetItemNo_TryGetItemNo', '', false, false)]
    local procedure OnGetItemNo_TryGetItemNo(var CustomerNo: Code[20]; var ItemRef: Text[50]; var ItemNo: Code[20]; var ErrorMessage: Text)
    var
        item: Record item;
    begin
        if item.get(ItemRef) then
            ItemNo := item."No.";
    end;
}
