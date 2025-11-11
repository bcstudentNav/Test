namespace TechnologyServicesGroup.IP.BACS;

using Microsoft.Bank.Payment;
using Microsoft.Purchases.Vendor;
using Microsoft.Finance.GeneralLedger.Journal;
codeunit 70300 "BACSPayment Export Data Subs"
{
    [EventSubscriber(ObjectType::Table, Database::"Payment Export Data", 'OnAfterSetVendorAsRecipient', '', false, false)]
    local procedure OnAfterSetVendorAsRecipientTransferValuesFromTheBankAccount(var PaymentExportData: Record "Payment Export Data"; var VendorBankAccount: Record "Vendor Bank Account")
    begin
        PaymentExportData."TSGRecipient Bank Sort Code" := VendorBankAccount."Bank Branch No.";
        PaymentExportData."TSGRecipient IBAN" := VendorBankAccount.IBAN;
        PaymentExportData."TSGRecipient SWIFT Code" := VendorBankAccount."SWIFT Code";
        PaymentExportData."TSGRecipient Name & Address" := CopyStr(VendorBankAccount.Name + VendorBankAccount.Address, 1, 100);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Pmt Export Mgt Gen. Jnl Line", 'OnBeforeInsertPmtExportDataJnlFromGenJnlLine', '', false, false)]
    local procedure OnBeforeInsertPmtExportDataJnlFromGenJnlLineTransferValuesFromTheBankAccount(GenJournalLine: Record "Gen. Journal Line"; var PaymentExportData: Record "Payment Export Data")
    var
        Vendor: record Vendor;
        VendorBankAccount: record "Vendor Bank Account";
    begin
        if GenJournalLine."Document Type" <> GenJournalLine."Document Type"::Payment then
            exit;
        if GenJournalLine."Account Type" <> GenJournalLine."Account Type"::Vendor then
            exit;
        if not Vendor.Get(GenJournalLine."Account No.") then
            exit;
        PaymentExportData."TSGRecipient Name & Address" := CopyStr(Vendor.Name + ' ' + Vendor.Address, 1, 30);

        VendorBankAccount.Reset();
        VendorBankAccount.Get(Vendor."No.", GenJournalLine."Recipient Bank Account");
        PaymentExportData."TSGRecipient Bank Sort Code" := VendorBankAccount."Bank Branch No.";
        PaymentExportData."TSGRecipient IBAN" := VendorBankAccount.IBAN;
        PaymentExportData."TSGRecipient SWIFT Code" := VendorBankAccount."SWIFT Code";
    end;
}
