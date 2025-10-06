namespace BCN.DataBridge.Partner.BlueAlligator;
using System.Utilities;
using Microsoft.Inventory.Item;
using Microsoft.CRM.Team;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Pricing.PriceList;
using Microsoft.Sales.History;
using Microsoft.Finance.Currency;
using Microsoft.Sales.Pricing;
using Microsoft.Sales.Customer;
using System.Integration;

codeunit 80003 "Helper Functions"
{
    Permissions =
        tabledata "Blue Alligator Settings" = r,
        tabledata "Export Type" = rim;

    /// <summary>
    /// CreateDefaultFileType.
    /// is called when the data needs adding to the Export type table 
    /// </summary>
    /// <param name="ExportType">enum type to assign to the record</param>
    /// <param name="FileName">Default file name can be changed in setup page.</param>
    /// <param name="RequireSetup">if ticked will call the createSetup function on the interface.</param>
    procedure CreateDefaultFileType(ExportType: Enum "Export File Type"; FileName: Text[250]; RequireSetup: Boolean)
    var
    begin

        this.CreateDefaultFileType(ExportType, FileName, 0, RequireSetup, false);
    end;
    /// <summary>
    /// CreateDefaultFileType.
    /// is called when the data needs adding to the Export type table 
    /// </summary>
    /// <param name="ExportType">enum type to assign to the record</param>
    /// <param name="FileName">Default file name can be changed in setup page.</param>
    /// <param name="RequireSetup">if ticked will call the createSetup function on the interface.</param> 
    /// <param name="UpdateExisting">if ticked will update any process that have allready been created with the passed details</param>

    procedure CreateDefaultFileType(ExportType: Enum "Export File Type"; FileName: Text[250]; RequireSetup: Boolean; UpdateExisting: Boolean)
    var
    begin

        this.CreateDefaultFileType(ExportType, FileName, 0, RequireSetup, UpdateExisting);
    end;

    /// <summary>
    /// CreateDefaultFileType.
    /// is called when the data needs adding to the Export type table 
    /// </summary>
    /// <param name="ExportType">enum type to assign to the record</param>
    /// <param name="FileName">Default file name can be changed in setup page.</param>
    /// <param name="TableNo">if is simple export setting the table no will allow a filter to be set against that table.</param>
    /// <param name="RequireSetup">if ticked will call the createSetup function on the interface.</param>
    /// <param name="UpdateExisting">if ticked will update any process that have allready been created with the passed details</param>

    procedure CreateDefaultFileType(ExportType: Enum "Export File Type"; FileName: Text[250]; TableNo: Integer; RequireSetup: Boolean; UpdateExisting: Boolean)
    var
        ExportTypeRecord: Record "Export Type";
    begin
        ExportTypeRecord.Validate("Export Type", ExportType);
        ExportTypeRecord.Validate("File Name", FileName);
        ExportTypeRecord.Validate("Require Setup", RequireSetup);
        ExportTypeRecord.Validate("Table Filter No.", TableNo);
        if not ExportTypeRecord.Insert(true) then
            ExportTypeRecord.Modify(true);

        // if set to update want to update the other files to match
        if not UpdateExisting then
            exit;
        ExportTypeRecord.SetRange("Export Type", ExportType);
        ExportTypeRecord.ModifyAll("Require Setup", RequireSetup, true);
        ExportTypeRecord.ModifyAll("File Name", FileName, true);
        ExportTypeRecord.ModifyAll("Table Filter No.", TableNo, true);

    end;

    /// <summary>
    /// SetInherited.
    /// Set the inherited value for the table filter. If set the filter used will be inherited from another export type.
    /// </summary>
    /// <param name="ExportType"></param>
    /// <param name="InheritedType"></param>
    /// <param name="UpdateExisting"></param>
    procedure SetInherited(ExportType: Enum "Export File Type"; InheritedType: Enum "Export File Type"; UpdateExisting: Boolean)
    var
        ExportTypeRecord: Record "Export Type";
    begin
        if not ExportTypeRecord.Get(ExportType, '') then
            exit;

        ExportTypeRecord.SetRange("Export Type", ExportType);
        ExportTypeRecord.Validate("Table Filter Inherited", InheritedType);
        ExportTypeRecord.Modify(true);

        if UpdateExisting then
            ExportTypeRecord.ModifyAll("Table Filter Inherited", InheritedType, true);
    end;

    /// <summary>
    /// Creates the date in the correct format.
    /// </summary>
    /// <param name="Date"> Supplied date to format</param>
    /// <param name="ExportType">supplied export to get format from.</param>
    /// <returns>formatted date string</returns>
    procedure FormatDate(Date: Date; ExportType: Record "Export Type"): Text
    var
        BlueAlligatorSettings: Record "Blue Alligator Settings";
    begin
        ExportType.CalcFields("Blue Alligator Code");
        if not BlueAlligatorSettings.Get(ExportType."Blue Alligator Code") then // use blank if it does not exist.

            exit(Format(Date, 0, BlueAlligatorSettings."Date Format"));
    end;


    internal procedure CreateDefaultFileTypes()
    var
        HelperFunctions: Codeunit "Helper Functions";
    begin
        HelperFunctions.CreateDefaultFileType("Export File Type"::CustomerAccounts, 'CustAcc', Database::Customer, true, true);
        HelperFunctions.CreateDefaultFileType("Export File Type"::BackOrder, 'bkord', Database::Customer, true, true);
        HelperFunctions.SetInherited("Export File Type"::BackOrder, "Export File Type"::CustomerAccounts, true);
        HelperFunctions.CreateDefaultFileType("Export File Type"::CatalogueProducts, 'catprods', false, false);
        HelperFunctions.CreateDefaultFileType("Export File Type"::Catalogue, 'cats', false, false);
        HelperFunctions.CreateDefaultFileType("Export File Type"::CreditNarrative, 'creditnarrative', Database::Customer, true, true);
        HelperFunctions.SetInherited("Export File Type"::CreditNarrative, "Export File Type"::CustomerAccounts, true);
        HelperFunctions.CreateDefaultFileType("Export File Type"::Currencies, 'currencies', Database::Currency, true, true);
        HelperFunctions.CreateDefaultFileType("Export File Type"::CustomerAccounts, 'custaccs', Database::Customer, true, true);
        HelperFunctions.CreateDefaultFileType("Export File Type"::CustomerDiscount, 'customerdiscountcodes', Database::"Customer Discount Group", true, true);
        HelperFunctions.CreateDefaultFileType("Export File Type"::Family, 'famcodes', false, false);
        HelperFunctions.CreateDefaultFileType("Export File Type"::HistoryHeader, 'historyh', Database::"Sales Invoice Header", false, false);
        HelperFunctions.SetInherited("Export File Type"::HistoryHeader, "Export File Type"::CustomerAccounts, true);
        HelperFunctions.CreateDefaultFileType("Export File Type"::HistoryLines, 'historyl', false, false);
        HelperFunctions.CreateDefaultFileType("Export File Type"::LedgerCodes, 'ledgercodes', false, false);
        HelperFunctions.CreateDefaultFileType("Export File Type"::LedgerDetails, 'ledgerdets', Database::Customer, true, true);
        HelperFunctions.SetInherited("Export File Type"::LedgerDetails, "Export File Type"::CustomerAccounts, true);
        HelperFunctions.CreateDefaultFileType("Export File Type"::Locations, 'locations', false, false);
        HelperFunctions.CreateDefaultFileType("Export File Type"::PriceListProductMatrix, 'pricelistproductmatrix', Database::"Price List Line", true, true);
        HelperFunctions.CreateDefaultFileType("Export File Type"::PriceLists, 'pricelists', Database::"Price List Line", true, true);
        HelperFunctions.CreateDefaultFileType("Export File Type"::ProductDiscountMatrix, 'customerproductdiscountmatrix', false, false);
        HelperFunctions.CreateDefaultFileType("Export File Type"::Product, 'products', Database::Item, true, true);
        HelperFunctions.CreateDefaultFileType("Export File Type"::Reps, 'reps', Database::"Salesperson/Purchaser", true, true);
        HelperFunctions.CreateDefaultFileType("Export File Type"::SalesTaxGroups, 'salestaxgroups', Database::"VAT Product Posting Group", true, true);
        HelperFunctions.CreateDefaultFileType("Export File Type"::SalesTaxMatrix, 'salestaxmatrix', Database::"VAT Product Posting Group", true, true);
        this.OnAfterSetupDefaultFileTypes();
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterSetupDefaultFileTypes()
    begin

    end;
}
