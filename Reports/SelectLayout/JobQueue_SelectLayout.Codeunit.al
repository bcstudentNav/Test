namespace BCN.KandyToys.Core;

using System.Threading;
using Microsoft.Foundation.Reporting;
using System.Text;
using System.Utilities;
using System.Email;
using Microsoft.Sales.Document;
using Microsoft.Sales.Customer;
using Microsoft.CRM.Team;
using System.Reflection;
codeunit 50029 "Send SO Email"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    var
        SalesHeader2: Record "Sales Header";
        ReportSelections: Record "Report Selections";
        Base64: Codeunit "Base64 Convert";
        TempBlob: Codeunit "Temp Blob";
        EmailMessage: Codeunit "Email Message";
        Email: Codeunit Email;
        SOHdrRecRef: RecordRef;
        EmailRecipientType: Enum "Email Recipient Type";
        Body: Text;
        Subject: Text;
        InStr: InStream;
        OutputStream: OutStream;
        EmailAddress: Text[250];
        BccEmailAddress: Text[250];
        CCEmailAddress: Text[250];
    begin
        // Get current job queue entry
        if Rec."Parameter String" = '' then
            exit;

        this.SalesHeader.SetLoadFields("Sell-to Customer No.", "Ship-to Code", "EVS_ESF_TakenAtCode", "Order Ack. Email Sent", Status);
        this.SalesHeader.Get(this.SalesHeader."Document Type"::Order, CopyStr(Rec."Parameter String", 1, 20));
        this.GetOrderAckEmailAddresses(EmailAddress, CCEmailAddress, BccEmailAddress);


        // Create email message
        //Attachement
        Clear(TempBlob);
        SOHdrRecRef.GetTable(this.SalesHeader);
        SOHdrRecRef.SetRecFilter(); // Set filter on recordref otherwise report will error if there are no filters.

        //GetOrderAckEmailAddresses is already applying the filters
        if (this.CustomReportSelection.FindFirst()) and (this.CustomReportSelection."Report ID" <> 0) then begin
            TempBlob.CreateOutStream(OutputStream);
            Report.SaveAs(this.CustomReportSelection."Report ID", '', ReportFormat::Pdf, OutputStream, SOHdrRecRef);

            //Check the Email Body
            if this.CustomReportSelection."Use for Email Body" then
                Body := this.GetMailBody(SOHdrRecRef, this.CustomReportSelection."Report ID", this.CustomReportSelection."Email Body Layout Name")
        end
        else begin
            //Use standard functionality to get the report id from report selections
            ReportSelections.Reset();
            ReportSelections.SetRange(Usage, ReportSelections.Usage::"S.Order");
            if ReportSelections.FindFirst() then begin
                if ReportSelections."Use for Email Body" then
                    Body := this.GetMailBody(SOHdrRecRef, ReportSelections."Report ID", ReportSelections."Report Layout Name");
                Report.SaveAs(ReportSelections."Report ID", '', ReportFormat::Pdf, OutputStream, SOHdrRecRef);
            end;

        end;

        if TempBlob.HasValue() then begin
            TempBlob.CreateInStream(InStr);

            Clear(EmailMessage);
            Subject := 'Order Acknowledgement - Order No. ' + this.SalesHeader."No.";
            if Body = '' then
                Body := 'Document Attached';
            EmailMessage.Create(EmailAddress, Subject, Body, true);
            EmailMessage.AddRecipient(EmailRecipientType::Cc, CCEmailAddress);
            EmailMessage.AddRecipient(EmailRecipientType::Bcc, BccEmailAddress);
            EmailMessage.SetBody(Body);
            EmailMessage.AddAttachment('OrderAck_' + this.SalesHeader."No." + '.pdf', 'application/pdf', Base64.ToBase64(InStr));
            if Email.Send(EmailMessage) then
                if SalesHeader2.Get(this.SalesHeader."Document Type", this.SalesHeader."No.") then
                    if SalesHeader2.Status = "Sales Document Status"::Released then
                        if SalesHeader2."Order Ack. Email Sent" = false then begin
                            SalesHeader2.Validate("Order Ack. Email Sent", true);
                            SalesHeader2.Modify(true);
                        end;
        end;
    end;

    local procedure GetOrderAckEmailAddresses(var EmailAddress: Text[250]; var CCEmailAddress: Text[250]; var BccEmailAddress: Text[250]);
    var
        SalesMgmt: Codeunit "Sales Mgmt.";
        SalesPersonEmailAddress: Text[250];
        StartPos: Integer;
        EndSepPos: Integer;
        EmailSeparatorLbl: Label ';', Comment = 'Separator for email addresses';
    begin
        Clear(EmailAddress);
        Clear(BccEmailAddress);

        //Check	if the customer supports a document layout record of type Order Confirmation 
        this.CustomReportSelection.Reset();
        this.CustomReportSelection.SetRange(Usage, this.CustomReportSelection.Usage::"S.Order");
        this.CustomReportSelection.SetRange("Source Type", Database::Customer);
        this.CustomReportSelection.SetRange("Source No.", this.SalesHeader."Sell-to Customer No.");
        this.CustomReportSelection.SetFilter("Send To Email", '<>%1', '');
        // this.CustomReportSelection.SetLoadFields("Send To Email", "Report ID", Repo);
        if this.CustomReportSelection.FindFirst() then
            if this.CustomReportSelection."Send To Email" <> '' then
                EmailAddress := this.CustomReportSelection."Send To Email";

        //Check CC, Bcc email
        Clear(BccEmailAddress);
        Clear(CCEmailAddress);

        SalesMgmt.GetOrderConfirmationBccAddress(this.SalesHeader."No.", BccEmailAddress, SalesPersonEmailAddress);
        CCEmailAddress := SalesPersonEmailAddress;

        if SalesPersonEmailAddress <> '' then begin
            StartPos := StrPos(BccEmailAddress, SalesPersonEmailAddress);
            //check if there is a delimiter after the email address
            EndSepPos := StrPos(BccEmailAddress, SalesPersonEmailAddress) + StrLen(SalesPersonEmailAddress) + 1;

            //if there is a delimiter after the email address, remove also the delimiter
            if CopyStr(BccEmailAddress, EndSepPos, 1) = EmailSeparatorLbl then
                BccEmailAddress := DelStr(BccEmailAddress, StartPos, StrLen(SalesPersonEmailAddress) + 1)
            else
                BccEmailAddress := DelStr(BccEmailAddress, StartPos, StrLen(SalesPersonEmailAddress));
        end;
        //If the customer does not have a document layout of this type, then still collect the email addresses and use them as the main email address
        if EmailAddress = '' then begin
            EmailAddress := BccEmailAddress;
            Clear(BccEmailAddress);
        end;
    end;

    local procedure GetMailBody(RecRef: RecordRef; ReportId: Integer; ReportLayoutName: Text[250]) BodyText: Text
    var
        TempBlob: Codeunit "Temp Blob";
        DesigntimeReportSelection: Codeunit "Design-time Report Selection";
        ReportBodyOutstream: OutStream;
        ReportBodyInstream: InStream;
    begin
        DesigntimeReportSelection.SetSelectedLayout(ReportLayoutName); //determine the report layout before running the report
        TempBlob.CreateOutStream(ReportBodyOutstream);
        Report.SaveAs(ReportId, '', ReportFormat::Html, ReportBodyOutstream, RecRef);
        TempBlob.CreateInStream(ReportBodyInstream);

        ReportBodyInstream.ReadText(BodyText);
    end;

    var
        SalesHeader: Record "Sales Header";
        CustomReportSelection: Record "Custom Report Selection";
}
