codeunit 50555 DAR_PWF_WayfairManagement
{
    var
        VarSalesHeader: Record "Sales Header";

    procedure GenerateLabel(var WarehouseShipmentHeader: Record "Warehouse Shipment Header")
    var
        EVSDBCProcessLink: Record EVS_DBC_ProcessLink;
        EVSDBCProcess: Record EVS_DBC_Process;
        EVSDBCMessageBatch: Record EVS_DBC_MessageBatch;
        EVSDBCMessageHeader: Record EVS_DBC_MessageHeader;
    begin
        EVSDBCProcessLink.SetRange(EVS_DBC_TableNo, Database::Customer);
        EVSDBCProcessLink.SetRange(EVS_DBC_Partner, EVSDBCProcessLink.EVS_DBC_Partner::EVS_WAY_Wayfair);
        EVSDBCProcessLink.SetRange(EVS_DBC_ProcessTypeEnum, EVSDBCProcessLink.EVS_DBC_ProcessTypeEnum::DAR_PWF_WayfairShippingLabel_I);
        EVSDBCProcessLink.SetRange(EVS_DBC_LinkCode, WarehouseShipmentHeader.EVS_EWF_SourceNo);
        if EVSDBCProcessLink.FindFirst() then begin
            EVSDBCProcess.Get(EVSDBCProcessLink.EVS_DBC_ProcessCode);
            CreateShippingLblMessage(EVSDBCProcess, EVSDBCMessageBatch, EVSDBCMessageHeader, WarehouseShipmentHeader);
        end;
    end;

    procedure CreateShippingLblMessage(EVSDBCProcess: Record EVS_DBC_Process; var EVSDBCMessageBatch: Record EVS_DBC_MessageBatch; var MessageHeader: Record EVS_DBC_MessageHeader; var WarehouseShipmentHeader: Record "Warehouse Shipment Header")
    var
        ShippingAgent: Record "Shipping Agent";
        SalesHeader: Record "Sales Header";
        WarehouseShipmentLine: Record "Warehouse Shipment Line";
        MessageLine: Record EVS_DBC_MessageLine;
        WhseShipmentDocEntry: Record EVS_EWF_WhseShipmentDocEntry;
        DocumentAttachment: Record "Document Attachment";
        EVSDBCMessageMgmt: Codeunit EVS_DBC_MessageMgmt;
        EVSWAYPartnerMgmt: Codeunit EVS_WAY_PartnerMgmt;
        EVSWAYProcessRegShipment: Codeunit EVS_WAY_ProcessRegShipment;
        TempBlob: Codeunit "Temp Blob";
        LabelTempBlob: Codeunit "Temp Blob";
        InStream: InStream;
        OutStream: OutStream;
        FileName: Text[250];
        BatchID: Integer;
        LabelDescriptionTxt: Label 'Shipping Label';
    begin
        //Create Message Batch
        FileName := EVSDBCProcess.EVS_DBC_ProcessCode + ' ' + Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>-<Hours24,2><Minutes,2>') + '.pdf';
        BatchID := EVSDBCMessageMgmt.CreateBatch(EVSDBCProcess, TempBlob, FileName);

        //Get Message Batch
        EVSDBCMessageBatch.Get(BatchID);

        //Create Message Header
        MessageHeader.Init();
        MessageHeader.Validate(EVS_DBC_MessageBatchID, EVSDBCMessageBatch.EVS_DBC_MessageBatchID);
        MessageHeader.EVS_DBC_EntityTableNo := Database::"Warehouse Shipment Header";
        MessageHeader.EVS_DBC_EntitySystemID := WarehouseShipmentHeader.SystemId;
        MessageHeader.EVS_DBC_ProcessCode := EVSDBCProcess.EVS_DBC_ProcessCode;
        MessageHeader.Insert(true);

        MessageHeader.EVS_DBC_EntityDocumentNo := WarehouseShipmentHeader."No.";
        MessageHeader.EVS_DBC_ExternalDocumentNo := WarehouseShipmentHeader."External Document No.";
        MessageHeader.Validate(EVS_DBC_MessageStatus, EVS_DBC_MessageStatus::Created);
        MessageHeader.EVS_DBC_ShippingAgentCode := WarehouseShipmentHeader."Shipping Agent Code";
        MessageHeader.EVS_DBC_ShipAgentServiceCode := WarehouseShipmentHeader."Shipping Agent Service Code";
        MessageHeader.EVS_DBC_LocationCode := WarehouseShipmentHeader."Location Code";
        MessageHeader.EVS_DBC_Code1 := WarehouseShipmentHeader.EVS_EWF_SourceDocumentNo;
        MessageHeader.EVS_DBC_ShipmentDate := WarehouseShipmentHeader."Shipment Date";
        if SalesHeader.Get(SalesHeader."Document Type"::Order, WarehouseShipmentHeader.EVS_EWF_SourceDocumentNo) then begin
            if ShippingAgent.Get(SalesHeader."Shipping Agent Code") then
                MessageHeader.EVS_DBC_TrackingURL := CopyStr(ShippingAgent.GetTrackingInternetAddr(SalesHeader."Package Tracking No."), 1, MaxStrLen(MessageHeader.EVS_DBC_TrackingURL));
        end else
            if ShippingAgent.Get(WarehouseShipmentHeader."Shipping Agent Code") then
                MessageHeader.EVS_DBC_TrackingURL := CopyStr(ShippingAgent.GetTrackingInternetAddr(WarehouseShipmentHeader.EVS_EWF_PackageTrackingNo), 1, MaxStrLen(MessageHeader.EVS_DBC_TrackingURL));
        MessageHeader.Modify(true);

        // Now for lines
        WarehouseShipmentLine.SetRange("No.", WarehouseShipmentHeader."No.");
        WarehouseShipmentLine.SetFilter(Quantity, '<>0');
        if WarehouseShipmentLine.FindSet() then
            repeat
                MessageLine.Init();
                MessageLine.EVS_DBC_MessageLineID := 0;
                MessageLine.Validate(EVS_DBC_MessageHeaderID, MessageHeader.EVS_DBC_MessageHeaderID);
                MessageLine.EVS_DBC_EntityTableNo := Database::"Warehouse Shipment Line";
                MessageLine.EVS_DBC_EntitySystemID := WarehouseShipmentLine.SystemId;
                MessageLine.Insert(true);

                // add the needed values                
                if MessageLine.EVS_DBC_EntityDocumentNo = '' then
                    MessageLine.EVS_DBC_EntityDocumentNo := WarehouseShipmentLine."No.";
                if MessageLine.EVS_DBC_EntityLineNo = 0 then
                    MessageLine.EVS_DBC_EntityLineNo := WarehouseShipmentLine."Line No.";
                MessageLine.EVS_DBC_ItemNo := WarehouseShipmentLine."Item No.";
                MessageLine.EVS_DBC_Quantity := WarehouseShipmentLine.Quantity;
                MessageLine.EVS_DBC_ShipmentDate := WarehouseShipmentLine."Shipment Date";
                MessageLine.EVS_DBC_EntityLineNo := WarehouseShipmentLine."Line No.";
                MessageLine.Modify(true);
            until WarehouseShipmentLine.Next() = 0;

        //SubmitShipment
        EVSWAYProcessRegShipment.SplitBatchAndCreateResponseRequests(EVSDBCProcess, EVSDBCMessageBatch);
        EVSWAYProcessRegShipment.Export(EVSDBCProcess, EVSDBCMessageBatch);

        //Generate Shipping Label
        EVSWAYPartnerMgmt.GetDocument(Database::"Warehouse Shipment Header", WarehouseShipmentHeader.SystemId, MessageHeader);

        //Update Batch to processed
        EVSDBCMessageBatch.SetRecFilter();
        EVSDBCMessageMgmt.MoveToProcessedBatch(EVSDBCMessageBatch);

        //Save Label in Document Attachment and Message Batch then delete Shipment Doc Entry to save data
        WhseShipmentDocEntry.SetRange(EVS_EWF_DocumentNo, WarehouseShipmentHeader."No.");
        WhseShipmentDocEntry.SetRange(EVS_EWF_UsageType, WhseShipmentDocEntry.EVS_EWF_UsageType::ShippingLabel);
        WhseShipmentDocEntry.SetRange(EVS_EWF_ReportId, Report::EVS_WAY_ShippingLabel);
        if WhseShipmentDocEntry.FindFirst() then begin
            if WhseShipmentDocEntry.EVS_EWF_BlobRefId.HasValue then begin
                LabelTempBlob.CreateOutStream(OutStream);
                WhseShipmentDocEntry.EVS_EWF_BlobRefId.ExportStream(OutStream);
                // Delete previous label if it exists with our usage type and report ID.
                //
                DocumentAttachment.SetRange("No.", WarehouseShipmentHeader."No.");
                DocumentAttachment.SetRange("Document Type", DocumentAttachment."Document Type"::DAR_PWF_WayfairShippingLabel);
                DocumentAttachment.DeleteAll(true);

                LabelTempBlob.CreateInStream(InStream);

                DocumentAttachment.Init();
                DocumentAttachment."Table ID" := Database::"Warehouse Shipment Header";
                DocumentAttachment."No." := WarehouseShipmentHeader."No.";
                DocumentAttachment."Document Type" := DocumentAttachment."Document Type"::DAR_PWF_WayfairShippingLabel;
                DocumentAttachment."File Type" := DocumentAttachment."File Type"::PDF;
                DocumentAttachment."File Name" := WarehouseShipmentHeader."No." + ' ' + LabelDescriptionTxt + '.pdf';
                DocumentAttachment."File Extension" := 'pdf';
                DocumentAttachment."Document Reference ID".ImportStream(InStream, DocumentAttachment."File Name");
                DocumentAttachment.Insert(true);
                DocumentAttachment.ImportAttachment(InStream, DocumentAttachment."File Name");

                EVSDBCMessageBatch.EVS_DBC_ImportExportFile.CreateOutStream(OutStream);
                WhseShipmentDocEntry.EVS_EWF_BlobRefId.ExportStream(OutStream);
            end;
            WhseShipmentDocEntry.DeleteAll(true);
        end;

        EVSDBCMessageBatch.Modify(true);
    end;

    procedure PrintDocuments(var WarehouseShipmentHeader: Record "Warehouse Shipment Header")
    var
        DocumentAttachment: Record "Document Attachment";
    begin
        DocumentAttachment.SetRange("No.", WarehouseShipmentHeader."No.");
        DocumentAttachment.SetRange("Document Type", Enum::"Attachment Document Type"::DAR_PWF_WayfairShippingLabel);
        if DocumentAttachment.FindSet() then
            SendToPrinter(DocumentAttachment, WarehouseShipmentHeader);
    end;

    local procedure SendToPrinter(SendPrintDocument: Record "Document Attachment"; var WarehouseShipmentHeader: Record "Warehouse Shipment Header")
    var
        Printer: Record EVO_SAPI_Printer;
        Printselection: Record "Printer Selection";
        PrintManagement: Codeunit EVO_SAPI_PrintManagement;
        TempBlob: Codeunit "Temp Blob";
        EVOResult: Codeunit EVO_SAPI_Result;
        Outstream: OutStream;
    begin
        //get the printer
        Printselection.SetRange("Report ID");
        Printselection.SetRange("User ID", UserId);
        if not Printselection.FindFirst() then
            Printselection.SetRange("User ID");
        if not Printselection.FindFirst() then
            Error('No printer found for user %1', UserId);

        // Sort out the blob
        TempBlob.CreateOutStream(Outstream);
        SendPrintDocument."Document Reference ID".ExportStream(OutStream);

        // get the printer for the default printer
        if not Printer.get(UserId, Printselection."Printer Name") then
            Printer.Get('', Printselection."Printer Name");

        EVOResult := PrintManagement.Print(Printer, SendPrintDocument."No." + '.pdf', TempBlob);
        if not EVOResult.Successful() then
            Error(EVOResult.ErrorMessage())
        else
            WarehouseShipmentHeader.EVS_EWF_NoShipLabelPrinted += 1;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::ArchiveManagement, 'OnBeforeArchiveSalesDocument', '', false, false)]
    local procedure RunOnBeforeArchiveSalesDocument(var SalesHeader: Record "Sales Header"; var IsHandled: Boolean)
    begin
        if (SalesHeader."Document Type" = VarSalesHeader."Document Type") and (SalesHeader."No." = VarSalesHeader."No.") then
            IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::ArchiveManagement, 'OnBeforeArchSalesDocumentNoConfirm', '', false, false)]
    local procedure RunOnBeforeArchSalesDocumentNoConfirme(var SalesHeader: Record "Sales Header"; var IsHandled: Boolean)
    begin
        if (SalesHeader."Document Type" = VarSalesHeader."Document Type") and (SalesHeader."No." = VarSalesHeader."No.") then
            IsHandled := true;
    end;

    internal procedure PassSalesHeader(PassedSalesHeader: Record "Sales Header")
    begin
        VarSalesHeader := PassedSalesHeader;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::EVS_DBC_SalesDocImportProcess, 'OnAfterInsertSalesHeader', '', false, false)]
    local procedure RunOnAfterInsertSalesHeader(var MessageHeader: Record EVS_DBC_MessageHeader; var SalesHeader: Record "Sales Header")
    var
        VATRegistrationLog: Record "VAT Registration Log";
    begin
        if not ((MessageHeader.EVS_DBC_Partner = MessageHeader.EVS_DBC_Partner::DAR_PWF_WayfairCSN) or
         (MessageHeader.EVS_DBC_Partner = MessageHeader.EVS_DBC_Partner::DAR_PWF_WayfairDISP)) then
            exit;

        case MessageHeader.EVS_DBC_ProcessTypeEnum of
            Enum::EVS_DBC_ProcessTypeEnum::ImportSalesDocument_I:
                begin
                    SalesHeader.DAR_PWF_SCAC := CopyStr(MessageHeader.EVS_DBC_Code2, 1, 20);
                    SalesHeader.DAR_PWF_ShipSpeed := CopyStr(MessageHeader.EVS_DBC_Code3, 1, 20);
                    SalesHeader."VAT Registration No." := CopyStr(MessageHeader.EVS_DBC_Text1, 1, 20);
                    if (MessageHeader.EVS_DBC_Partner = MessageHeader.EVS_DBC_Partner::DAR_PWF_WayfairDISP) then begin
                        VATRegistrationLog.Reset();
                        VATRegistrationLog.SetRange("Account Type", VATRegistrationLog."Account Type"::Customer);
                        VATRegistrationLog.SetRange("Account No.", SalesHeader."Sell-to Customer No.");
                        VATRegistrationLog.Setfilter(DAR_PWF_WayfairDespCountry, '%1|%2', 'GB', '');
                        VATRegistrationLog.SetRange("Country/Region Code", SalesHeader."Ship-to Country/Region Code");
                        if VATRegistrationLog.FindFirst() then
                            if VATRegistrationLog.DAR_PWF_VATBusPostingGroup <> '' then
                                SalesHeader.Validate("VAT Bus. Posting Group", VATRegistrationLog.DAR_PWF_VATBusPostingGroup);
                    end;
                    SalesHeader.Modify();
                end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforeSalesShptHeaderInsert', '', false, false)]
    local procedure RunOnBeforeSalesShptHeaderInsert_Wayfair(SalesHeader: Record "Sales Header"; var SalesShptHeader: Record "Sales Shipment Header")
    begin
        SalesShptHeader.DAR_PWF_SCAC := SalesHeader.DAR_PWF_SCAC;
        SalesShptHeader.DAR_PWF_ShipSpeed := SalesHeader.DAR_PWF_ShipSpeed;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"EVS_WAY_ProcessRegShipment", 'OnAfterExportShipment', '', false, false)]
    local procedure RunOnAfterExportShipment_UpdateShipmentDate(var EVSDBCMessageHeader: Record EVS_DBC_MessageHeader; PickUpDate: Date)
    var
        WarehouseShipmentHeader: Record "Warehouse Shipment Header";
        WarehouseShipmentLine: Record "Warehouse Shipment Line";
    begin
        case EVSDBCMessageHeader.EVS_DBC_EntityTableNo of
            Database::"Warehouse Shipment Header":
                if WarehouseShipmentHeader.GetBySystemId(EVSDBCMessageHeader.EVS_DBC_EntitySystemID) then
                    if WarehouseShipmentHeader."Shipment Date" <> PickupDate then begin
                        WarehouseShipmentHeader."Shipment Date" := PickupDate;  // Validate triggers a confirmation box.
                        WarehouseShipmentHeader.EVS_EWF_ShipmentDate := PickupDate;
                        WarehouseShipmentHeader.Modify(true);

                        WarehouseShipmentLine.SetRange("No.", WarehouseShipmentHeader."No.");
                        WarehouseShipmentLine.ModifyAll("Shipment Date", WarehouseShipmentHeader."Shipment Date");
                    end;
        end;
    end;
}
