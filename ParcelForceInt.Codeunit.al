codeunit 50576 "DAR_CPF_ParcelForceIntegration"
{
    Permissions =
    tabledata "Country/Region" = r,
    tabledata DAR_CPF_CountryCarrierSerSetup = r,
    tabledata "Shipping Agent" = r,
    tabledata "Shipping Agent Services" = r,
    tabledata Customer = r,
    tabledata "Company Information" = r,
    tabledata Item = r,
    tabledata "Warehouse Shipment Header" = rm,
    tabledata "Warehouse Shipment Line" = r,
    tabledata "Sales Header" = r,
    tabledata DAR_DDB_Project = r,
    tabledata "XML Buffer" = rd,
    tabledata EVS_EWF_WhseShipmentUnit = r,
    tabledata EVS_EWF_WhseShipmentUnitEntry = r,
    tabledata DAR_CPF_CarrierIntSetting = r,
    tabledata EVS_EWF_WhseShipmentDocEntry = rmdi,
    tabledata DAR_CPF_CarrierSpecialInst = r;

    var
        FunctionalityRefAllObj: Record AllObj;
        FunctionalityRefText: Text;
        ContactNumber: Text;
        tCompany: Text;
        BaseURL: Text;
        DefaultCountryCode: Text;
        UserName: Text;
        Password: Text;
        LabelExportLocation: Text;
        Department: Text;
        ProgressDialogTxt: Label 'Communicating with Parcel Force...';
        FieldBlankErr: Label 'Field: %1 on Table: %2 is blank and requires a value. Please escalate to Support/IT to resolve.', Comment = '%1 is Field Caption, %2 is Table Caption';

    procedure CreateShipment(var WarehouseShipmentHeader: Record "Warehouse Shipment Header")
    var
        CountryRegion: Record "Country/Region";
        ShippingAgentServices: Record "Shipping Agent Services";
        CountryCarrierIntSetting: Record DAR_CPF_CountryCarrierSerSetup;
        CarrierSpecialInstructions: Record DAR_CPF_CarrierSpecialInst;
        CarrierIntSetting: Record DAR_CPF_CarrierIntSetting;
        XMLBuffer: Record "XML Buffer";
        ImporterCountryRegion: Record DAR_CPF_CountryCarrierSerSetup;
        ExporterCountryRegion: Record DAR_CPF_CountryCarrierSerSetup;
        WarehouseShipmentUnit: Record EVS_EWF_WhseShipmentUnit;
        WhseShipmentUnitContent: Record EVS_EWF_WhseShipmentUnitEntry;
        Item: Record Item;
        WarehouseShipmentLine: Record "Warehouse Shipment Line";
        SalesHeader: Record "Sales Header";
        CompanyInformation: Record "Company Information";
        Customer: Record Customer;
        DDDBProject: Record DAR_DDB_Project;
        ShippingAgent: Record "Shipping Agent";
        AllObj: Record AllObj;
        TempEVOEXSEventLogEntry: Record EVO_EXS_EventLogEntry temporary;
        EVOEXSManagement: Codeunit EVO_EXS_Management;
        LogLevel: Enum EVO_EXS_LogLevel;
        RequestTypeTxt: Label 'CreateShipment', Locked = true;
        ServerErr: Label 'Server %1 returned error ''%2''', Comment = '%1 Server Address, %2 = Message.';
        ProgressDialog: Dialog;
        ResponseText: Text;
        Domestic: Boolean;
        RequestUri: Text;
        WebRequest: HttpRequestMessage;
        RequestHttpHeaders: HttpHeaders;
        ContentHttpHeaders: HttpHeaders;
        HTTPContent: HttpContent;
        WebResponse: HttpResponseMessage;
        RequestBody: Text;
        Response: Text;
        SOAPActionLbl: Label 'createShipment';
        ShipmentTypeLbl: Label 'DELIVERY';
        CreateShipmentSuccessLbl: Label 'Shipment Created Successfully!';
        BFPOCode: Text[10];
        IsSuccess: Boolean;
        ErrorString: Text;
        StringBuilder: TextBuilder;
        Phone: Boolean;
        Email: Boolean;
        SystemString: Text;
        FirstParcel: Boolean;
        GrossWeight: Decimal;
        ContentGrossWeight: Decimal;
        InternationalDocs: Boolean;
        CountryOrigin: Code[10];
        ParcelForceErrorInfo: ErrorInfo;
    begin


        CarrierIntSetting.Get(WarehouseShipmentHeader."Shipping Agent Code");
        Initialise(WarehouseShipmentHeader."Shipping Agent Code");

        StringBuilder := StringBuilder;
        StringBuilder.Clear();

        // Calculate the shipping type (Domestic or EURoad/International)
        Domestic := false;
        if WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion = '' then
            Domestic := true
        else begin
            CountryRegion.Get(WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion);
            CountryCarrierIntSetting.Get(CountryRegion.Code);
            Domestic := CountryCarrierIntSetting.DAR_CPF_DomesticRegion;
        end;

        // SOAP header string
        AppendString(StringBuilder, '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" >');
        AppendString(StringBuilder, '<soapenv:Header/>');
        AppendString(StringBuilder, '<soapenv:Body>');
        AppendString(StringBuilder, '<CreateShipmentRequest xmlns="http://www.parcelforce.net/ws/ship/v14">');                                       // Live Web service callable function
        AppendString(StringBuilder, '<Authentication>');                                              // Authentication header
        AppendString(StringBuilder, '<UserName>' + UserName + '</UserName>');
        AppendString(StringBuilder, '<Password>' + Password + '</Password>');
        AppendString(StringBuilder, '</Authentication>');

        // Commented out sections are for the structure of the XML that is generated
        // Please leave in for future reference

        AppendString(StringBuilder, '<RequestedShipment>');                                           // Web Request

        AppendString(StringBuilder, '<DepartmentId>');
        AppendString(StringBuilder, Department);                                                                 // 1, Main Outbound document - 2, Returns - 4, B2C Web Account - 5, B2C Web Returns
        AppendString(StringBuilder, '</DepartmentId>');

        AppendString(StringBuilder, '<ShipmentType>');
        AppendString(StringBuilder, ShipmentTypeLbl);                                                        // Hard Coded as per specification
        AppendString(StringBuilder, '</ShipmentType>');

        AppendString(StringBuilder, '<ContractNumber>');

        AppendString(StringBuilder, ContactNumber);
        AppendString(StringBuilder, '</ContractNumber>');

        AppendString(StringBuilder, '<ServiceCode>');

        ShippingAgentServices.Get(WarehouseShipmentHeader."Shipping Agent Code", WarehouseShipmentHeader."Shipping Agent Service Code");

        ShippingAgent.Get(WarehouseShipmentHeader."Shipping Agent Code");

        Customer.Get(WarehouseShipmentHeader.EVS_EWF_SourceNo);

        if CopyStr(WarehouseShipmentHeader.EVS_EWF_ShipToPostCode, 1, 2) = 'BT' then
            AppendString(StringBuilder, 'SUP')
        else
            if (WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion <> '') and (CountryCarrierIntSetting.DAR_CPF_ParcelforceServiceCode <> '') then
                AppendString(StringBuilder, CountryCarrierIntSetting.DAR_CPF_ParcelforceServiceCode)
            else
                AppendString(StringBuilder, ShippingAgentServices.DAR_COR_CarrierService);

        AppendString(StringBuilder, '</ServiceCode>');

        AppendString(StringBuilder, '<ShippingDate>');
        AppendString(StringBuilder, Format(WarehouseShipmentHeader."Shipment Date", 10, '<Year4>-<Month,2>-<Day,2>'));   // YYYY-MM-DD
        AppendString(StringBuilder, '</ShippingDate>');

        AppendString(StringBuilder, '<RecipientContact>');
        AppendString(StringBuilder, '<BusinessName>');
        AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToName), 1, 40));
        AppendString(StringBuilder, '</BusinessName>');
        AppendString(StringBuilder, '<ContactName>');
        AppendString(StringBuilder, EscapeDataString(' '));
        AppendString(StringBuilder, '</ContactName>');
        // Need to check with DAR about how current notifications are sent (If they are at all)
        //  include all addresses not just 999 IF (WarehouseShipmentHeader."Ship-To E-Mail" <> '') AND (WarehouseShipmentHeader."Ship-to Code" ='999') THEN BEGIN
        if (WarehouseShipmentHeader.EVS_EWF_ShipToEMail <> '') then begin
            AppendString(StringBuilder, '<EmailAddress>');
            AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToEMail), 1, 50));
            AppendString(StringBuilder, '</EmailAddress>');
            Email := true;
        end else
            AppendString(StringBuilder, '<EmailAddress />');

        SystemString := WarehouseShipmentHeader.EVS_EWF_ShipToPhoneNo;
        AppendString(StringBuilder, '<Telephone>' + CopyStr(SystemString.Replace(' ', ''), 1, 15) + '</Telephone>');
        if Domestic then begin                                   // Only available on Domestic shipping
                                                                 //  include all addresses not just 999  IF (WarehouseShipmentHeader."Ship-To Phone No." <> '')  AND (WarehouseShipmentHeader."Ship-to Code" ='999')  THEN
            if (WarehouseShipmentHeader.EVS_EWF_ShipToPhoneNo <> '') then
                if CopyStr(WarehouseShipmentHeader.EVS_EWF_ShipToPhoneNo, 1, 2) = '07' then begin
                    AppendString(StringBuilder, '<MobilePhone>' + CopyStr(SystemString.Replace(' ', ''), 1, 11) + '</MobilePhone>');       // Required if notification type set to SMS (11 chars, no spaces starting 01,02 or 07)
                    Phone := true;
                end;
            if not Phone then
                AppendString(StringBuilder, '<MobilePhone />');
            AppendString(StringBuilder, '<SendersName>');

            if (ShippingAgent.DAR_COR_B2C) and (Customer."Name 2" <> '') then
                tCompany := Customer."Name 2";

            AppendString(StringBuilder, tCompany);
            AppendString(StringBuilder, '</SendersName>');

        end else
            AppendString(StringBuilder, '<MobilePhone />');

        // Collection and delivery notifications

        // International shipments can only be eMail notification. SMS is not allowed

        if Email or Phone then begin
            AppendString(StringBuilder, '<Notifications>');
            //    <!--1 or more repetitions allowed:-->
            if Phone then
                AppendString(StringBuilder, '<NotificationType>SMSDAYOFDESPATCH</NotificationType>');    // Both eMail and SMS can be included as individual fields

            if Email then
                AppendString(StringBuilder, '<NotificationType>EMAIL</NotificationType>');

            AppendString(StringBuilder, '</Notifications>');
        end;
        AppendString(StringBuilder, '</RecipientContact>');

        AppendString(StringBuilder, '<RecipientAddress>');

        AppendString(StringBuilder, '<AddressLine1>');                                                 // Mandatory
        AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToAddress), 1, 40));
        AppendString(StringBuilder, '</AddressLine1>');
        AppendString(StringBuilder, '<AddressLine2>');                                                 // Optional
        AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToAddress2), 1, 40));
        AppendString(StringBuilder, '</AddressLine2>');

        if not Domestic then begin                                                      // and country is ROI then this is Mandatory
                                                                                        // AND ROI
            AppendString(StringBuilder, '<AddressLine3>');
            if WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion = 'IE' then
                AppendString(StringBuilder, RemoveCounty(WarehouseShipmentHeader.EVS_EWF_ShipToCounty))
            else
                AppendString(StringBuilder, WarehouseShipmentHeader.EVS_EWF_ShipToCounty);
            AppendString(StringBuilder, '</AddressLine3>');
        end;

        // If country is 17 (HM Forces) must be hard coded to 'BFPO'
        AppendString(StringBuilder, '<Town>');                                                        // Mandatory
        Clear(BFPOCode);
        if CheckBFPO(WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion, BFPOCode) then
            AppendString(StringBuilder, BFPOCode)
        else
            AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToCity), 1, 30));
        AppendString(StringBuilder, '</Town>');

        // If country is 17 (HM Forces) must be hard coded to 'BFPO'
        // Now need to send postcode for IE
        if (WarehouseShipmentHeader.EVS_EWF_ShipToPostCode <> '') then begin
            AppendString(StringBuilder, '<Postcode>');                                                    // Mandatory
            if CheckBFPO(WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion, BFPOCode) then
                AppendString(StringBuilder, BFPOCode)
            else
                AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToPostCode), 1, 16));
            AppendString(StringBuilder, '</Postcode>');
        end;

        AppendString(StringBuilder, '<Country>');
        if Domestic then
            AppendString(StringBuilder, DefaultCountryCode)       // (was) Hardcoded to GB for domestic shipments
        else
            AppendString(StringBuilder, WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion);

        AppendString(StringBuilder, '</Country>');

        AppendString(StringBuilder, '</RecipientAddress>');

        CompanyInformation.Get();

        // Included in International Shipping
        if not Domestic then begin

            InternationalDocs := false;
            if WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion <> '' then
                if ImporterCountryRegion.Get(WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion) then
                    InternationalDocs := ImporterCountryRegion.DAR_CPF_PrintInternationalDocs;

            AppendString(StringBuilder, '<ImporterContact>');

            AppendString(StringBuilder, '<BusinessName>');

            if (not InternationalDocs) or (ImporterCountryRegion.DAR_CPF_ImporterBusinessName = '') then
                AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToName), 1, 40))
            else
                AppendString(StringBuilder, CopyStr(EscapeDataString(ImporterCountryRegion.DAR_CPF_ImporterBusinessName), 1, 40));

            AppendString(StringBuilder, '</BusinessName>');
            AppendString(StringBuilder, '<ContactName />');
            AppendString(StringBuilder, '<EmailAddress />');
            if ImporterCountryRegion.DAR_CPF_ImporterBusinessName <> '' then begin
                AppendString(StringBuilder, '<Telephone>');
                AppendString(StringBuilder, CopyStr(EscapeDataString(CompanyInformation."Phone No."), 1, 15));
                AppendString(StringBuilder, '</Telephone>');
            end;

            AppendString(StringBuilder, '</ImporterContact>');

            AppendString(StringBuilder, '<ImporterAddress>');
            AppendString(StringBuilder, '<AddressLine1>');                                                 // Mandatory

            if (not InternationalDocs) or (ImporterCountryRegion.DAR_CPF_ImporterBusinessName = '') then
                AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToAddress), 1, 40))
            else begin
                if ImporterCountryRegion.DAR_CPF_ImpAddressLine1 = '' then
                    Error(FieldBlankErr, ImporterCountryRegion.FieldCaption(DAR_CPF_ImpAddressLine1), ImporterCountryRegion.TableCaption);
                AppendString(StringBuilder, CopyStr(EscapeDataString(ImporterCountryRegion.DAR_CPF_ImpAddressLine1), 1, 40));
            end;
            AppendString(StringBuilder, '</AddressLine1>');
            AppendString(StringBuilder, '<AddressLine2>');                                                 // Optional

            if (not InternationalDocs) or (ImporterCountryRegion.DAR_CPF_ImporterBusinessName = '') then
                AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToAddress2), 1, 40))
            else
                AppendString(StringBuilder, CopyStr(EscapeDataString(ImporterCountryRegion.DAR_CPF_ImpAddressLine2), 1, 40));

            AppendString(StringBuilder, '</AddressLine2>');
            AppendString(StringBuilder, '<AddressLine3>');

            if (not InternationalDocs) or (ImporterCountryRegion.DAR_CPF_ImporterBusinessName = '') then begin
                if WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion = 'IE' then
                    AppendString(StringBuilder, RemoveCounty(WarehouseShipmentHeader.EVS_EWF_ShipToCounty))
                else
                    AppendString(StringBuilder, WarehouseShipmentHeader.EVS_EWF_ShipToCounty);
            end else
                if ImporterCountryRegion.DAR_CPF_CountryCode = 'IE' then
                    AppendString(StringBuilder, RemoveCounty(ImporterCountryRegion.DAR_CPF_ImpAddressLine3))
                else begin
                    if ImporterCountryRegion.DAR_CPF_ImpAddressLine3 = '' then
                        Error(FieldBlankErr, ImporterCountryRegion.FieldCaption(DAR_CPF_ImpAddressLine3), ImporterCountryRegion.TableCaption);
                    AppendString(StringBuilder, ImporterCountryRegion.DAR_CPF_ImpAddressLine3);
                end;
            AppendString(StringBuilder, '</AddressLine3>');
            AppendString(StringBuilder, '<Town>');                                                        // Mandatory

            if (not InternationalDocs) or (ImporterCountryRegion.DAR_CPF_ImporterBusinessName = '') then
                AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToCity), 1, 30))
            else begin
                if ImporterCountryRegion.DAR_CPF_ImpTown = '' then
                    Error(FieldBlankErr, ImporterCountryRegion.FieldCaption(DAR_CPF_ImpTown), ImporterCountryRegion.TableCaption);
                AppendString(StringBuilder, CopyStr(EscapeDataString(ImporterCountryRegion.DAR_CPF_ImpTown), 1, 30));
            end;
            AppendString(StringBuilder, '</Town>');
            if (not InternationalDocs) or (ImporterCountryRegion.DAR_CPF_ImporterBusinessName = '') then begin
                if (WarehouseShipmentHeader.EVS_EWF_ShipToPostCode <> '') then begin
                    AppendString(StringBuilder, '<Postcode>');  // Mandatory
                    AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToPostCode), 1, 16));
                    AppendString(StringBuilder, '</Postcode>');
                end else
                    AppendString(StringBuilder, '<Postcode />');
            end else
                if (ImporterCountryRegion.DAR_CPF_ImpPostcode <> '') then begin
                    AppendString(StringBuilder, '<Postcode>');  // Mandatory

                    if ImporterCountryRegion.DAR_CPF_ImpPostcode = '' then
                        Error(FieldBlankErr, ImporterCountryRegion.FieldCaption(DAR_CPF_ImpPostcode), ImporterCountryRegion.TableCaption);
                    AppendString(StringBuilder, CopyStr(EscapeDataString(ImporterCountryRegion.DAR_CPF_ImpPostcode), 1, 16));
                    AppendString(StringBuilder, '</Postcode>');
                end else
                    AppendString(StringBuilder, '<Postcode />');

            AppendString(StringBuilder, '<Country>');

            if (not InternationalDocs) or (ImporterCountryRegion.DAR_CPF_ImporterBusinessName = '') then
                AppendString(StringBuilder, WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion)
            else
                if ImporterCountryRegion.DAR_CPF_ImpCountryCode <> '' then
                    AppendString(StringBuilder, ImporterCountryRegion.DAR_CPF_ImpCountryCode)
                else
                    AppendString(StringBuilder, 'GB');

            AppendString(StringBuilder, '</Country>');
            AppendString(StringBuilder, '</ImporterAddress>');

            if WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion <> '' then
                ExporterCountryRegion.Get(WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion);

            AppendString(StringBuilder, '<ExporterContact>');
            AppendString(StringBuilder, '<BusinessName>');
            if (not InternationalDocs) or (ExporterCountryRegion.DAR_CPF_ExporterBusinessName = '') then
                AppendString(StringBuilder, CopyStr(EscapeDataString(CompanyInformation.Name), 1, 40))
            else
                if ExporterCountryRegion.DAR_CPF_ExporterBusinessName <> '' then
                    AppendString(StringBuilder, CopyStr(EscapeDataString(ExporterCountryRegion.DAR_CPF_ExporterBusinessName), 1, 40))
                else begin
                    if CompanyInformation.Name = '' then
                        Error(FieldBlankErr, CompanyInformation.FieldCaption(Name), CompanyInformation.TableCaption);
                    AppendString(StringBuilder, CopyStr(EscapeDataString(CompanyInformation.Name), 1, 40));
                end;

            AppendString(StringBuilder, '</BusinessName>');
            AppendString(StringBuilder, '<ContactName />');
            AppendString(StringBuilder, '<EmailAddress />');
            AppendString(StringBuilder, '<Telephone>');
            AppendString(StringBuilder, CopyStr(EscapeDataString(CompanyInformation."Phone No."), 1, 15));
            AppendString(StringBuilder, '</Telephone>');
            AppendString(StringBuilder, '</ExporterContact>');

            AppendString(StringBuilder, '<ExporterAddress>');
            AppendString(StringBuilder, '<AddressLine1>');                                                 // Mandatory

            if not InternationalDocs then
                AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToAddress), 1, 40))
            else
                if ExporterCountryRegion.DAR_CPF_ExporterBusinessName <> '' then
                    AppendString(StringBuilder, CopyStr(EscapeDataString(ExporterCountryRegion.DAR_CPF_ExpAddressLine1), 1, 40))
                else begin
                    if CompanyInformation.Address = '' then
                        Error(FieldBlankErr, CompanyInformation.FieldCaption(Address), CompanyInformation.TableCaption);
                    AppendString(StringBuilder, CopyStr(EscapeDataString(CompanyInformation.Address), 1, 40));
                end;

            AppendString(StringBuilder, '</AddressLine1>');
            AppendString(StringBuilder, '<AddressLine2>');                                                 // Optional

            if not InternationalDocs then
                AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToAddress2), 1, 40))
            else
                if ExporterCountryRegion.DAR_CPF_ExporterBusinessName <> '' then
                    AppendString(StringBuilder, CopyStr(EscapeDataString(ExporterCountryRegion.DAR_CPF_ExpAddressLine2), 1, 40))
                else
                    AppendString(StringBuilder, CopyStr(EscapeDataString(CompanyInformation."Address 2"), 1, 40));

            AppendString(StringBuilder, '</AddressLine2>');
            AppendString(StringBuilder, '<AddressLine3>');

            if not InternationalDocs then begin
                if WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion = 'IE' then
                    AppendString(StringBuilder, RemoveCounty(WarehouseShipmentHeader.EVS_EWF_ShipToCounty))
                else
                    AppendString(StringBuilder, WarehouseShipmentHeader.EVS_EWF_ShipToCounty);
            end else
                if (ExporterCountryRegion.DAR_CPF_ExporterBusinessName <> '') and (ExporterCountryRegion.DAR_CPF_CountryCode = 'IE') then
                    AppendString(StringBuilder, RemoveCounty(ExporterCountryRegion.DAR_CPF_ExpAddressLine3))
                else
                    if ExporterCountryRegion.DAR_CPF_ExporterBusinessName <> '' then
                        AppendString(StringBuilder, ExporterCountryRegion.DAR_CPF_ExpAddressLine3)
                    else begin
                        if CompanyInformation.County = '' then
                            Error(FieldBlankErr, CompanyInformation.FieldCaption(County), CompanyInformation.TableCaption);
                        AppendString(StringBuilder, CopyStr(EscapeDataString(CompanyInformation.County), 1, 40));
                    end;

            AppendString(StringBuilder, '</AddressLine3>');
            AppendString(StringBuilder, '<Town>');                                                        // Mandatory

            if not InternationalDocs then
                AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToCity), 1, 30))
            else
                if ExporterCountryRegion.DAR_CPF_ExporterBusinessName <> '' then
                    AppendString(StringBuilder, CopyStr(EscapeDataString(ExporterCountryRegion.DAR_CPF_ExpTown), 1, 30))
                else begin
                    if CompanyInformation.City = '' then
                        Error(FieldBlankErr, CompanyInformation.FieldCaption(City), CompanyInformation.TableCaption);
                    AppendString(StringBuilder, CopyStr(EscapeDataString(CompanyInformation.City), 1, 30));
                end;

            AppendString(StringBuilder, '</Town>');
            if not InternationalDocs then begin
                if (WarehouseShipmentHeader.EVS_EWF_ShipToPostCode <> '') then begin
                    AppendString(StringBuilder, '<Postcode>');  // Mandatory
                    AppendString(StringBuilder, CopyStr(EscapeDataString(WarehouseShipmentHeader.EVS_EWF_ShipToPostCode), 1, 16));
                    AppendString(StringBuilder, '</Postcode>');
                end else
                    AppendString(StringBuilder, '<Postcode />');
            end else begin
                if (ExporterCountryRegion.DAR_CPF_ExporterBusinessName <> '') then begin
                    AppendString(StringBuilder, '<Postcode>');  // Mandatory
                    AppendString(StringBuilder, CopyStr(EscapeDataString(ExporterCountryRegion.DAR_CPF_ExpPostcode), 1, 16))
                end else begin
                    AppendString(StringBuilder, '<Postcode>');  // Mandatory

                    if CompanyInformation."Post Code" = '' then
                        Error(FieldBlankErr, CompanyInformation.FieldCaption("Post Code"), CompanyInformation.TableCaption);
                    AppendString(StringBuilder, CopyStr(EscapeDataString(CompanyInformation."Post Code"), 1, 16));
                end;
                AppendString(StringBuilder, '</Postcode>');
            end;
            AppendString(StringBuilder, '<Country>');
            if not InternationalDocs then
                AppendString(StringBuilder, WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion)
            else
                if ExporterCountryRegion.DAR_CPF_ExporterBusinessName <> '' then begin
                    if ExporterCountryRegion.DAR_CPF_ExpCountryCode <> '' then
                        AppendString(StringBuilder, CopyStr(EscapeDataString(ExporterCountryRegion.DAR_CPF_ExpCountryCode), 1, 2))
                    else
                        AppendString(StringBuilder, 'GB');
                end else
                    if CompanyInformation."Country/Region Code" <> '' then
                        AppendString(StringBuilder, CompanyInformation."Country/Region Code")
                    else
                        AppendString(StringBuilder, 'GB');

            AppendString(StringBuilder, '</Country>');

            AppendString(StringBuilder, '</ExporterAddress>');
        end;

        AppendString(StringBuilder, '<TotalNumberOfParcels>');     // Has to be > 0
        if WarehouseShipmentHeader.EVS_EWF_NoCartons <> 0 then
            AppendString(StringBuilder, Format(WarehouseShipmentHeader.EVS_EWF_NoCartons))
        else
            AppendString(StringBuilder, Format(WarehouseShipmentHeader.EVS_EWF_NoCartons));
        AppendString(StringBuilder, '</TotalNumberOfParcels>');

        AppendString(StringBuilder, '<Enhancement>');
        AppendString(StringBuilder, '<EnhancedCompensation>0</EnhancedCompensation>');
        if Domestic then
            if ShippingAgentServices.DAR_COR_SaturdayDelivery then
                AppendString(StringBuilder, '<SaturdayDeliveryRequired>1</SaturdayDeliveryRequired>')
            else
                AppendString(StringBuilder, '<SaturdayDeliveryRequired>0</SaturdayDeliveryRequired>');

        AppendString(StringBuilder, '</Enhancement>');

        // We will always print our own labels - Not available for international shipping (At least not in the spec)

        if not Domestic then begin
            AppendString(StringBuilder, '<InternationalInfo>');
            AppendString(StringBuilder, '<Parcels>');

            WarehouseShipmentUnit.SetRange(EVS_EWF_DocumentNo, WarehouseShipmentHeader."No.");
            if WarehouseShipmentUnit.FindSet() then begin
                FirstParcel := true;
                repeat
                    AppendString(StringBuilder, '<Parcel>');
                    AppendString(StringBuilder, '<Weight>');

                    Clear(GrossWeight);
                    WarehouseShipmentUnit.CalcFields(EVS_EWF_TotalGrossWeight);
                    GrossWeight := WarehouseShipmentUnit.EVS_EWF_TotalGrossWeight;
                    AppendString(StringBuilder, Format(GrossWeight));
                    AppendString(StringBuilder, '</Weight>');
                    AppendString(StringBuilder, '<Length>');
                    if WarehouseShipmentUnit.EVS_EWF_Length = 0 then
                        WarehouseShipmentUnit.EVS_EWF_Length := 1;

                    AppendString(StringBuilder, Format(WarehouseShipmentUnit.EVS_EWF_Length));
                    AppendString(StringBuilder, '</Length>');
                    AppendString(StringBuilder, '<Height>');
                    if WarehouseShipmentUnit.EVS_EWF_Height = 0 then
                        WarehouseShipmentUnit.EVS_EWF_Height := 1;

                    AppendString(StringBuilder, Format(WarehouseShipmentUnit.EVS_EWF_Height));
                    AppendString(StringBuilder, '</Height>');
                    AppendString(StringBuilder, '<Width>');
                    if WarehouseShipmentUnit.EVS_EWF_Width = 0 then
                        WarehouseShipmentUnit.EVS_EWF_Width := 1;

                    AppendString(StringBuilder, Format(WarehouseShipmentUnit.EVS_EWF_Width));
                    AppendString(StringBuilder, '</Width>');
                    AppendString(StringBuilder, '<PurposeOfShipment>');
                    AppendString(StringBuilder, 'Sold');                   // Gift, Not Sold, Personal Effects, Sample, Sold
                    AppendString(StringBuilder, '</PurposeOfShipment>');

                    // Optional
                    if InternationalDocs then begin
                        AppendString(StringBuilder, '<InvoiceNumber>');
                        AppendString(StringBuilder, WarehouseShipmentHeader."No.");
                        AppendString(StringBuilder, '</InvoiceNumber>');
                        AppendString(StringBuilder, '<ExportLicenseNumber>');
                        AppendString(StringBuilder, CompanyInformation.DAR_CPF_ExportLicenseNumber);
                        AppendString(StringBuilder, '</ExportLicenseNumber>');
                        AppendString(StringBuilder, '<CertificateNumber>');
                        AppendString(StringBuilder, CompanyInformation.DAR_CPF_CertificateNumber);
                        AppendString(StringBuilder, '</CertificateNumber>');
                    end;

                    WhseShipmentUnitContent.Reset();
                    WhseShipmentUnitContent.SetRange(EVS_EWF_DocumentNo, WarehouseShipmentHeader."No.");
                    WhseShipmentUnitContent.SetRange(EVS_EWF_CartonNo, WarehouseShipmentUnit.EVS_EWF_CartonNo);
                    WhseShipmentUnitContent.SetRange(EVS_EWF_PalletNo, WarehouseShipmentUnit.EVS_EWF_PalletNo);
                    WhseShipmentUnitContent.SetFilter(EVS_EWF_Quantity, '>0');
                    if WhseShipmentUnitContent.FindSet() then begin
                        if InternationalDocs then begin
                            //If Documents Only is set to 0 then this is Mandatory
                            AppendString(StringBuilder, '<ContentDetails>');
                            repeat
                                //<!--1 or more repetitions:-->
                                AppendString(StringBuilder, '<ContentDetail>');
                                AppendString(StringBuilder, '<CountryOfManufacture>');
                                Item.Get(WhseShipmentUnitContent.EVS_EWF_ItemNo);
                                if Item."Country/Region of Origin Code" <> '' then
                                    AppendString(StringBuilder, Item."Country/Region of Origin Code")
                                else begin
                                    CountryOrigin := 'GB';
                                    if Item.DAR_DDB_ProjectNo <> 0 then
                                        if DDDBProject.Get(Item.DAR_DDB_ProjectNo) then
                                            if DDDBProject.DAR_DDB_CountryOfOrigin <> 'UK' then
                                                CountryOrigin := '';
                                    AppendString(StringBuilder, CountryOrigin);
                                end;
                                AppendString(StringBuilder, '</CountryOfManufacture>');
                                AppendString(StringBuilder, '<ManufacturersName />');
                                AppendString(StringBuilder, '<Description>');

                                if Item.Description = '' then
                                    Error(FieldBlankErr, Item.FieldCaption(Description), Item.TableCaption);
                                AppendString(StringBuilder, EscapeDataString(CopyStr(Item.Description, 1, 30)));
                                AppendString(StringBuilder, '</Description>');
                                AppendString(StringBuilder, '<UnitWeight>');

                                if Item."Gross Weight" = 0 then
                                    Item."Gross Weight" := 1;

                                ContentGrossWeight := Round(Item."Gross Weight", 0.01, '<');
                                AppendString(StringBuilder, Format(ContentGrossWeight));

                                AppendString(StringBuilder, '</UnitWeight>');
                                AppendString(StringBuilder, '<UnitQuantity>');
                                WhseShipmentUnitContent.TestField(EVS_EWF_Quantity);
                                AppendString(StringBuilder, Format(WhseShipmentUnitContent.EVS_EWF_Quantity));
                                AppendString(StringBuilder, '</UnitQuantity>');
                                AppendString(StringBuilder, '<UnitValue>');
                                WarehouseShipmentLine.Get(WhseShipmentUnitContent.EVS_EWF_DocumentNo, WhseShipmentUnitContent.EVS_EWF_WhseShipmentLineNo);
                                if WarehouseShipmentLine.EVS_EWF_UnitPriceLCY <> 0 then
                                    AppendString(StringBuilder, Format(Round(WarehouseShipmentLine.EVS_EWF_UnitPriceLCY, 0.01)))
                                else
                                    AppendString(StringBuilder, Format(Round(Item."Unit Price", 0.01)));

                                AppendString(StringBuilder, '</UnitValue>');
                                AppendString(StringBuilder, '<Currency>');
                                SalesHeader.Get(WarehouseShipmentLine."Source Subtype", WarehouseShipmentLine."Source No.");
                                AppendString(StringBuilder, 'gbp'); // Always Use GBP 11/01/21 LH/SB

                                AppendString(StringBuilder, '</Currency>');
                                AppendString(StringBuilder, '<TariffCode>');

                                if Item."Tariff No." = '' then
                                    Error(FieldBlankErr, Item.FieldCaption("Tariff No."), Item.TableCaption);
                                if Item."Tariff No." = '0' then
                                    Item."Tariff No." := '9405500090';
                                AppendString(StringBuilder, Format(Item."Tariff No."));
                                AppendString(StringBuilder, '</TariffCode>');
                                AppendString(StringBuilder, '<TariffDescription />');
                                AppendString(StringBuilder, '</ContentDetail>');
                            until WhseShipmentUnitContent.Next() = 0;
                            AppendString(StringBuilder, '</ContentDetails>');
                            if FirstParcel then begin
                                AppendString(StringBuilder, '<ShippingCost>');
                                AppendString(StringBuilder, '6.50');                   //HARDCODED - SS SAID TO LEAVE THIS AS IS BECAUSE IT SHOULD BE THE COST OF US TO SEND THE PARCEL
                                AppendString(StringBuilder, '</ShippingCost>');
                            end else begin
                                AppendString(StringBuilder, '<ShippingCost>');
                                AppendString(StringBuilder, '0.00');                   //HAVE TO SUBMIT A VALUE HERE NOT A BLANK TAG
                                AppendString(StringBuilder, '</ShippingCost>');
                            end;
                        end; //internationaldocs
                        FirstParcel := false;
                    end;
                    AppendString(StringBuilder, '</Parcel>');
                until WarehouseShipmentUnit.Next() = 0;

                AppendString(StringBuilder, '</Parcels>');
            end else begin
                ParcelForceErrorInfo := ErrorInfo.Create('No Shipment Unit information found!');
                Error(ParcelForceErrorInfo);
            end;
            if InternationalDocs then begin

                AppendString(StringBuilder, '<ExporterCustomsReference>');
                if ExporterCountryRegion.DAR_CPF_ExporterBusinessName <> '' then begin
                    AppendString(StringBuilder, ExporterCountryRegion.DAR_CPF_ExpCustomsReference);
                    AppendString(StringBuilder, '</ExporterCustomsReference>');
                end else
                    if CompanyInformation."EORI Number" <> '' then begin
                        AppendString(StringBuilder, CompanyInformation."EORI Number");
                        AppendString(StringBuilder, '</ExporterCustomsReference>');
                    end else
                        AppendString(StringBuilder, '<ExporterCustomsReference />');

                if ImporterCountryRegion.DAR_CPF_ImporterBusinessName <> '' then begin
                    AppendString(StringBuilder, '<RecipientImporterVatNo>');
                    if Customer."EORI Number" <> '' then
                        AppendString(StringBuilder, Customer."EORI Number")
                    else
                        AppendString(StringBuilder, Customer."VAT Registration No.");
                    AppendString(StringBuilder, '|');
                    AppendString(StringBuilder, ImporterCountryRegion.DAR_CPF_RecipientImporterVATNo);
                    AppendString(StringBuilder, '</RecipientImporterVatNo>');
                end else
                    if Customer."EORI Number" <> '' then begin
                        AppendString(StringBuilder, '<RecipientImporterVatNo>');
                        AppendString(StringBuilder, Customer."EORI Number");
                        AppendString(StringBuilder, '</RecipientImporterVatNo>');
                    end else
                        AppendString(StringBuilder, '<RecipientImporterVatNo />');
            end;
            AppendString(StringBuilder, '<ShipmentDescription />');
            AppendString(StringBuilder, '<TermsOfDelivery>DDP</TermsOfDelivery>');
            AppendString(StringBuilder, '</InternationalInfo>');
        end;

        // Special Delivery options
        AppendString(StringBuilder, '<ReferenceNumber1>');
        AppendString(StringBuilder, CopyStr((WarehouseShipmentHeader."No." + ' ' + WarehouseShipmentHeader.EVS_EWF_SourceNo), 1, 24));
        AppendString(StringBuilder, '</ReferenceNumber1>');

        // Special delivery instructions are optional so if non on file, do not include
        CarrierSpecialInstructions.SetFilter(DAR_CPF_CustomerNo, WarehouseShipmentHeader.EVS_EWF_ShipToCode);
        if CarrierSpecialInstructions.FindFirst() then begin
            if CarrierSpecialInstructions.DAR_CPF_SpecialInstructions1 <> '' then begin
                AppendString(StringBuilder, '<SpecialInstructions1>');
                AppendString(StringBuilder, CopyStr(EscapeDataString(CarrierSpecialInstructions.DAR_CPF_SpecialInstructions1), 1, 25));
                AppendString(StringBuilder, '</SpecialInstructions1>');
            end;
            if CarrierSpecialInstructions.DAR_CPF_SpecialInstructions2 <> '' then begin
                AppendString(StringBuilder, '<SpecialInstructions2>');
                AppendString(StringBuilder, CopyStr(EscapeDataString(CarrierSpecialInstructions.DAR_CPF_SpecialInstructions2), 1, 25));
                AppendString(StringBuilder, '</SpecialInstructions2>');
            end;
            if CarrierSpecialInstructions.DAR_CPF_SpecialInstructions3 <> '' then begin
                AppendString(StringBuilder, '<SpecialInstructions3>');
                AppendString(StringBuilder, CopyStr(EscapeDataString(CarrierSpecialInstructions.DAR_CPF_SpecialInstructions3), 1, 25));
                AppendString(StringBuilder, '</SpecialInstructions3>');
            end;
            if CarrierSpecialInstructions.DAR_CPF_SpecialInstructions4 <> '' then begin
                AppendString(StringBuilder, '<SpecialInstructions4>');
                AppendString(StringBuilder, CopyStr(EscapeDataString(CarrierSpecialInstructions.DAR_CPF_SpecialInstructions4), 1, 25));
                AppendString(StringBuilder, '</SpecialInstructions4>');
            end;
        end;

        if Domestic then begin
            AppendString(StringBuilder, '<ConsignmentHandling>');
            if WarehouseShipmentHeader.EVS_EWF_NoCartons > 1 then
                AppendString(StringBuilder, 'true')
            else
                AppendString(StringBuilder, 'false');
            AppendString(StringBuilder, '</ConsignmentHandling>');
        end;

        // SOAP footer string
        AppendString(StringBuilder, '</RequestedShipment>');
        AppendString(StringBuilder, '</CreateShipmentRequest>');
        AppendString(StringBuilder, '</soapenv:Body>');
        AppendString(StringBuilder, '</soapenv:Envelope>');

        // Construct the web request body
        RequestBody := StringBuilder.ToText();

        RequestUri := BaseURL;

        HTTPContent.WriteFrom(RequestBody);

        HTTPContent.GetHeaders(ContentHttpHeaders);
        ContentHttpHeaders.Clear();
        ContentHttpHeaders.Add('Content-Type', 'application/xml;charset=utf-8');

        WebRequest.Content := HTTPContent;
        WebRequest.SetRequestUri(RequestUri);
        WebRequest.Method := 'POST';

        WebRequest.GetHeaders(RequestHttpHeaders);
        RequestHttpHeaders.Add('SOAPAction', SOAPActionLbl);

        SetFunctionalityReference(AllObj."Object Type"::Codeunit, Codeunit::DAR_CPF_ParcelForceIntegration, RequestTypeTxt);
        // Submits HTTP requests using External Services.
        // Returns HTTP Response message directly, use overload if you want response as text.

        if GuiAllowed() then
            ProgressDialog.Open(ProgressDialogTxt);

        // Initialise External Services log.
        //        
        Clear(TempEVOEXSEventLogEntry);
        LogLevel := LogLevel::EVO_EXS_Parent;
        TempEVOEXSEventLogEntry := InitTempEventLog(WarehouseShipmentHeader);

        Clear(ResponseText);
        EVOEXSManagement.SendRequest(WebRequest, WebResponse, LogLevel, TempEVOEXSEventLogEntry);
        if (WebResponse.HttpStatusCode < 200) or (WebResponse.HttpStatusCode > 299) or (not WebResponse.Content.ReadAs(ResponseText)) then
            Error(ServerErr, RequestUri, StripQuotes(ResponseText)); // Display raw response if response is not Json (i.e. labels).

        if GuiAllowed() then
            ProgressDialog.Close();

        WebResponse.Content().ReadAs(Response);

        XMLBuffer.Reset();
        XMLBuffer.DeleteAll(true);
        XMLBuffer.LoadFromText(Response);

        // Check for Success status
        XMLBuffer.SetRange(Name, 'Status');
        if XMLBuffer.FindFirst() then
            if XMLBuffer.Value = 'ALLOCATED' then
                IsSuccess := true;

        // If successful can get the shipment number
        if IsSuccess then begin
            XMLBuffer.SetRange(Name, 'ShipmentNumber');
            if XMLBuffer.FindFirst() then begin
                WarehouseShipmentHeader.Get(WarehouseShipmentHeader."No.");
                WarehouseShipmentHeader.EVS_EWF_PackageTrackingNo := CopyStr(XMLBuffer.Value, 1, 30);
                WarehouseShipmentHeader.Modify(true);

                if GuiAllowed then
                    Message(CreateShipmentSuccessLbl);
            end;
        end else begin
            // Need to find and loop through alerts.
            XMLBuffer.SetRange(Name, 'Message');
            if XMLBuffer.FindSet() then
                repeat
                    ErrorString += XMLBuffer.Value + '\';
                until XMLBuffer.Next() = 0;

            ParcelForceErrorInfo := ErrorInfo.Create(ErrorString);
            Error(ParcelForceErrorInfo);
        end;
    end;

    /*procedure CancelShipment(var WarehouseShipmentHeader: Record "Warehouse Shipment Header"): Boolean
    var
        StringBuilder: DotNet StringBuilder;
        BaseURL: Text;
        ParcelForceWWContracts: Record UnknownRecord50111;
        SOAPMessage: Text;
        StringBuilder2: DotNet StringBuilder;
        Window: Dialog;
        "*** Web Functions **": Integer;
        RequestUri: Text;
        WebRequest: DotNet HttpWebRequest;
        RequestBody: Text;
        WebResponse: DotNet HttpWebResponse;
        StreamReader: DotNet StreamReader;
        Response: Text;
        RequestStream: Codeunit DotNet_StreamReader;
        InStream: InStream;
        Encoding: DotNet ;
        XMLBuffer: Record "XML Buffer" temporary;
        SOAPAction: Label 'CancelShipment';
    begin
        Initialise(WarehouseShipmentHeader."Shipping Agent Code");
        StringBuilder := StringBuilder.StringBuilder;
        StringBuilder.Clear;

        // SOAP header string
        AppendString(StringBuilder, '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:v14="http://www.parcelforce.net/ws/ship/v14">');
        AppendString(StringBuilder, '<soapenv:Header/>');
        AppendString(StringBuilder, '<soapenv:Body>');

        // Web service callable function
        AppendString(StringBuilder, '<CancelShipmentRequest>');

        // Authentication header
        AppendString(StringBuilder, '<Authentication>');
        AppendString(StringBuilder, '<UserName>' + UserName + '</UserName>');
        AppendString(StringBuilder, '<Password>' + Password + '</Password>');
        AppendString(StringBuilder, '</Authentication>');

        AppendString(StringBuilder, '<WarehouseShipmentHeader>');
        AppendString(StringBuilder, WarehouseShipmentHeader."Delivery Number");
        AppendString(StringBuilder, '</WarehouseShipmentHeader>');

        // SOAP footer string
        AppendString(StringBuilder, '</CancelShipmentRequest>');
        AppendString(StringBuilder, '</soapenv:Body>');
        AppendString(StringBuilder, '</soapenv:Envelope>');

        // Construct the web request body
        RequestBody := StringBuilder.ToString;
        RequestUri := UrlPathEncode(BaseURL);
        WebRequest := WebRequest.HttpWebRequest;
        WebRequest := WebRequest.Create(RequestUri);
        WebRequest.Method := 'POST';
        WebRequest.ContentType('application/xml;charset=utf-8');
        WebRequest.Headers.Add('SOAPAction', SOAPAction);
        WebRequest.ContentLength(StrLen(RequestBody));
        RequestStream := WebRequest.GetRequestStream;
        RequestStream.Write(Encoding.UTF8.GetBytes(RequestBody), 0, Encoding.UTF8.GetBytes(RequestBody).Length);
        RequestStream.Close;
        WebResponse := WebRequest.GetResponse;
        StreamReader := StreamReader.StreamReader(WebResponse.GetResponseStream);
        Response := StreamReader.ReadToEnd;

        XMLBuffer.Reset();
        XMLBuffer.DeleteAll();
        XMLBuffer.LoadFromText(Response);

        XMLBuffer.SetFilter(Name, 'Status');
        // Find first record in parsed XML buffer
        if XMLBuffer.FindFirst() then begin
            // Scan all records for relevant information
            if XMLBuffer.Value = 'CANCELLED' then
                exit(true);
        end else begin
            Error('Unable to find shipment to cancel! XMLResponse: %1', Response);
        end;
    end;


    procedure CreateManifest(pShippingAgentCode: Code[10])
    var
        StringBuilder: DotNet StringBuilder;
        BaseURL: Text;
        SOAPMessage: Text;
        "Warehouse Shipment": Record "Warehouse Shipment Header";
        StringBuilder2: DotNet StringBuilder;
        Window: Dialog;
        "*** Web Functions **": Integer;
        RequestUri: Text;
        WebRequest: DotNet HttpWebRequest;
        RequestBody: Text;
        WebResponse: DotNet HttpWebResponse;
        StreamReader: DotNet StreamReader;
        StreamWriter: DotNet StreamWriter;
        Response: Text;
        RequestStream: DotNet Stream;
        InStream: InStream;
        Encoding: DotNet Encoding;
        XMLBuffer: Record "XML Buffer" temporary;
        ProperIndent: Text;
        LabelBuffer: Text[1024];
        OutStream: OutStream;
        fileMgt: Codeunit "File Management";
        SOAPAction: Label 'createManifest';
        ManifestNumber: Text;
    begin
        Initialise(pShippingAgentCode);
        StringBuilder := StringBuilder.StringBuilder;
        StringBuilder.Clear;
        ProperIndent := ' ';        // Indent char for XML markup

        // SOAP header string
        //AppendString(StringBuilder,'<?xml version="1.0" encoding="UTF-8"?>');
        AppendString(StringBuilder, '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:v14="http://www.parcelforce.net/ws/ship/v14">');
        AppendString(StringBuilder, '<soapenv:Header/>');
        AppendString(StringBuilder, '<soapenv:Body>');

        // Web service callable function
        AppendString(StringBuilder, '<CreateManifestRequest>');

        // Authentication header
        AppendString(StringBuilder, '<Authentication>');
        AppendString(StringBuilder, '<UserName>' + UserName + '</UserName>');
        AppendString(StringBuilder, '<Password>' + Password + '</Password>');
        AppendString(StringBuilder, '</Authentication>');

        AppendString(StringBuilder, '<DepartmentId>');
        AppendString(StringBuilder, '1');    // 1, Main Outbound document - 2, Returns - 4, B2C Web Account - 5, B2C Web Returns
        AppendString(StringBuilder, '</DepartmentId>');

        // SOAP footer string
        AppendString(StringBuilder, '</CreateManifestRequest>');
        AppendString(StringBuilder, '</soapenv:Body>');
        AppendString(StringBuilder, '</soapenv:Envelope>');

        // Construct the web request body
        RequestBody := StringBuilder.ToString;

        //MESSAGE('XML Request: %1', RequestBody);

        RequestUri := UrlPathEncode(BaseURL);
        WebRequest := WebRequest.HttpWebRequest;
        WebRequest := WebRequest.Create(RequestUri);
        WebRequest.Method := 'POST';
        WebRequest.ContentType('application/xml;charset=utf-8');
        WebRequest.Headers.Add('SOAPAction', SOAPAction);   // Text constant for SOAP Action
        WebRequest.ContentLength(StrLen(RequestBody));
        RequestStream := WebRequest.GetRequestStream;
        RequestStream.Write(Encoding.UTF8.GetBytes(RequestBody), 0, Encoding.UTF8.GetBytes(RequestBody).Length);
        RequestStream.Close;
        WebResponse := WebRequest.GetResponse;
        StreamReader := StreamReader.StreamReader(WebResponse.GetResponseStream);
        Response := StreamReader.ReadToEnd;

        //XMLBuffer.LOCKTABLE;
        XMLBuffer.Reset();
        XMLBuffer.DeleteAll();
        XMLBuffer.LoadFromText(Response);

        // Scan all the xml for the manifest number and possibly mutiple shipment numbers
        XMLBuffer.SetFilter(Name, 'ManifestNumber');
        if XMLBuffer.FindFirst() then begin
            ManifestNumber := XMLBuffer.Value;
        end else begin
            Error('No Manifest received! XMLResponse: %1', Response);
        end;

        // After the Create Manifest Request has been completed this Request must be run to print the manifest(s).
        PrintManifest(ManifestNumber, pShippingAgentCode);
    end;
    */

    procedure CreateLabel(WarehouseShipmentHeader: Record "Warehouse Shipment Header")
    var
        CountryCarrierSerSetup: Record DAR_CPF_CountryCarrierSerSetup;
        CarrierIntSetting: Record DAR_CPF_CarrierIntSetting;
        XMLBuffer: Record "XML Buffer";
        AllObj: Record AllObj;
        TempEVOEXSEventLogEntry: Record EVO_EXS_EventLogEntry temporary;
        WhseShipmentDocEntry: Record EVS_EWF_WhseShipmentDocEntry;
        EVOEXSManagement: Codeunit EVO_EXS_Management;
        TempBlob: Codeunit "Temp Blob";
        ConvertBase64: Codeunit "Base64 Convert";
        LogLevel: Enum EVO_EXS_LogLevel;
        RequestTypeTxt: Label 'GenerateShippingLabel', Locked = true;
        ServerErr: Label 'Server %1 returned error ''%2''', Comment = '%1 Server Address, %2 = Message.';
        ProgressDialog: Dialog;
        ResponseText: Text;
        StringBuilder: TextBuilder;
        RequestUri: Text;
        RequestBody: Text;
        Response: Text;
        ProperIndent: Text;
        SOAPActionLbl: Label 'printLabel';
        PDFOutStream: OutStream;
        PDFInstream: InStream;
        LargeText: Text;
        StartElement: Text;
        EndElement: Text;
        ErrorString: Text;
        FileName: Text[250];
        StartPos: Integer;
        EndPos: Integer;
        WebRequest: HttpRequestMessage;
        RequestHttpHeaders: HttpHeaders;
        ContentHttpHeaders: HttpHeaders;
        HTTPContent: HttpContent;
        WebResponse: HttpResponseMessage;
        LabelDescriptionTxt: Label 'Shipping Label - Parcel Force';
        GenerateShipmentSuccessLbl: Label 'Label generated successfully';
        ParcelForceErrorInfo: ErrorInfo;
    begin
        // Send the Received shipment number back to Parcel Force to request a base64 encoded shipping label
        Initialise(WarehouseShipmentHeader."Shipping Agent Code");

        StringBuilder := StringBuilder;
        StringBuilder.Clear();
        ProperIndent := ' ';        // Indent char for XML markup

        // SOAP header string
        AppendString(StringBuilder, '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" >');
        AppendString(StringBuilder, '<soapenv:Header/>');
        AppendString(StringBuilder, '<soapenv:Body>');

        // Web service callable function
        AppendString(StringBuilder, '<PrintLabelRequest xmlns="http://www.parcelforce.net/ws/ship/v14">');

        // Authentication header
        AppendString(StringBuilder, '<Authentication>');
        AppendString(StringBuilder, '<UserName>' + UserName + '</UserName>');
        AppendString(StringBuilder, '<Password>' + Password + '</Password>');
        AppendString(StringBuilder, '</Authentication>');

        AppendString(StringBuilder, '<ShipmentNumber>');
        AppendString(StringBuilder, WarehouseShipmentHeader.EVS_EWF_PackageTrackingNo);
        AppendString(StringBuilder, '</ShipmentNumber>');

        // PDF - to return a PDF image of the Label.
        // XML - to return a data stream in order to create own label.
        // PDF-XML - to return the Parcelforce label as PDF and the Partner label as XML.
        // XML-PDF ã to return the Parcelforce label as XML and the Partner label as PDF
        // Note: default will be PDF format if not included.
        AppendString(StringBuilder, '<PrintFormat>PDF</PrintFormat>');

        // SOAP footer string
        AppendString(StringBuilder, '</PrintLabelRequest>');
        AppendString(StringBuilder, '</soapenv:Body>');
        AppendString(StringBuilder, '</soapenv:Envelope>');

        CarrierIntSetting.Get(WarehouseShipmentHeader."Shipping Agent Code");
        // Construct the web request body
        RequestBody := StringBuilder.ToText();

        RequestUri := BaseURL;

        HTTPContent.WriteFrom(RequestBody);

        HTTPContent.GetHeaders(ContentHttpHeaders);
        ContentHttpHeaders.Clear();
        ContentHttpHeaders.Add('Content-Type', 'application/xml;charset=utf-8');

        WebRequest.Content := HTTPContent;
        WebRequest.SetRequestUri(RequestUri);
        WebRequest.Method := 'POST';

        WebRequest.GetHeaders(RequestHttpHeaders);
        RequestHttpHeaders.Add('SOAPAction', SOAPActionLbl);

        SetFunctionalityReference(AllObj."Object Type"::Codeunit, Codeunit::DAR_CPF_ParcelForceIntegration, RequestTypeTxt);
        // Submits HTTP requests using External Services.
        // Returns HTTP Response message directly, use overload if you want response as text.

        if GuiAllowed() then
            ProgressDialog.Open(ProgressDialogTxt);

        // Initialise External Services log.
        //        
        Clear(TempEVOEXSEventLogEntry);
        LogLevel := LogLevel::EVO_EXS_Parent;
        TempEVOEXSEventLogEntry := InitTempEventLog(WarehouseShipmentHeader);

        Clear(ResponseText);
        EVOEXSManagement.SendRequest(WebRequest, WebResponse, LogLevel, TempEVOEXSEventLogEntry);
        if (WebResponse.HttpStatusCode < 200) or (WebResponse.HttpStatusCode > 299) or (not WebResponse.Content.ReadAs(ResponseText)) then
            Error(ServerErr, RequestUri, StripQuotes(ResponseText)); // Display raw response if response is not Json (i.e. labels).

        if GuiAllowed() then
            ProgressDialog.Close();

        WebResponse.Content().ReadAs(Response);

        StartElement := '<Data>';
        EndElement := '</Data>';
        StartPos := StrPos(Response, StartElement) + 6;
        EndPos := StrPos(Response, EndElement) - 1;
        EndPos := EndPos - StartPos;

        // Grab only the base 64 encoded data - Assumes that there is only 1 label per XML file *There may be 2 or 3!*
        if EndPos > 0 then
            LargeText := CopyStr(Response, StartPos, EndPos)
        else begin
            XMLBuffer.Reset();
            XMLBuffer.DeleteAll(true);
            XMLBuffer.LoadFromText(Response);

            // Need to find and loop through alerts.
            XMLBuffer.SetRange(Name, 'Message');
            if XMLBuffer.FindSet() then
                repeat
                    ErrorString += XMLBuffer.Value + '\';
                until XMLBuffer.Next() = 0;

            ParcelForceErrorInfo := ErrorInfo.Create(ErrorString);
            Error(ParcelForceErrorInfo)
        end;

        // Convert the Base64 label to a PDF, store it in a blob and print it
        TempBlob.CreateOutStream(PDFOutStream);
        ConvertBase64.FromBase64(LargeText, PDFOutStream);

        // Delete previous label if it exists with our usage type and report ID.
        WhseShipmentDocEntry.SetRange(EVS_EWF_DocumentNo, WarehouseShipmentHeader."No.");
        WhseShipmentDocEntry.SetRange(EVS_EWF_UsageType, WhseShipmentDocEntry.EVS_EWF_UsageType::ShippingLabel);
        WhseShipmentDocEntry.DeleteAll(true);

        TempBlob.CreateInStream(PDFInstream);
        FileName := WarehouseShipmentHeader."No." + '_' + LabelDescriptionTxt + '.pdf';
        // Add the document
        WhseShipmentDocEntry.DAR_COR_InsertRecord(TempBlob, WarehouseShipmentHeader, FileName, LabelDescriptionTxt, Report::DAR_CPF_ShippingLabel,
                   WhseShipmentDocEntry.EVS_EWF_UsageType::ShippingLabel, false);


        if WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion <> '' then
            CountryCarrierSerSetup.Get(WarehouseShipmentHeader.EVS_EWF_ShipToCountryRegion);

        if CountryCarrierSerSetup.DAR_CPF_PrintInternationalDocs then begin
            CreateDocument(WarehouseShipmentHeader."No.", WarehouseShipmentHeader."Shipping Agent Code", Report::"DAR_CPF_ExportDocument");
            CreateDocument(WarehouseShipmentHeader."No.", WarehouseShipmentHeader."Shipping Agent Code", Report::DAR_CPF_CommercialInvoice);
        end;

        if GuiAllowed then
            Message(GenerateShipmentSuccessLbl);
    end;

    procedure CreateDocument(ShipmentNumber: Text; pShippingAgentCode: Code[10]; ShippingDocument: Integer)
    var
        WarehouseShipmentHeader2: Record "Warehouse Shipment Header";
        WarehouseShipmentHeader: Record "Warehouse Shipment Header";
        CarrierIntSetting: Record DAR_CPF_CarrierIntSetting;
        AllObj: Record AllObj;
        TempEVOEXSEventLogEntry: Record EVO_EXS_EventLogEntry temporary;
        WhseShipmentDocEntry: Record EVS_EWF_WhseShipmentDocEntry;
        EVOEXSManagement: Codeunit EVO_EXS_Management;
        TempBlob: Codeunit "Temp Blob";
        ConvertBase64: Codeunit "Base64 Convert";
        LogLevel: Enum EVO_EXS_LogLevel;
        RequestTypeTxt: Label 'GenerateCustomLabel', Locked = true;
        ServerErr: Label 'Server %1 returned error ''%2''', Comment = '%1 Server Address, %2 = Message.';
        ProgressDialog: Dialog;
        ResponseText: Text;
        SOAPActionLbl: Label 'printDocument';
        StringBuilder: TextBuilder;
        RequestUri: Text;
        RequestBody: Text;
        Response: Text;
        ProperIndent: Text;
        PDFOutStream: OutStream;
        LargeText: Text;
        StartElement: Text;
        EndElement: Text;
        StartPos: Integer;
        EndPos: Integer;
        DocString: Text[100];
        WebRequest: HttpRequestMessage;
        RequestHttpHeaders: HttpHeaders;
        ContentHttpHeaders: HttpHeaders;
        HTTPContent: HttpContent;
        WebResponse: HttpResponseMessage;
        LabelDescriptionTxt: Text;
    begin
        // Used for Customer Declarations and Invoices (International Shipping)
        // A separate print document request web call needs to be transmitted to
        // obtain the Customs Documentation types Customs Document and Commercial Invoice.
        // Customs Documents are produced for non-EU, non-document and non-GlobalExpress international shi

        Initialise(pShippingAgentCode);
        StringBuilder := StringBuilder;
        StringBuilder.Clear();
        ProperIndent := ' ';        // Indent char for XML markup

        // SOAP header string
        AppendString(StringBuilder, '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">');
        AppendString(StringBuilder, '<soapenv:Header/>');
        AppendString(StringBuilder, '<soapenv:Body>');

        // Web service callable function
        AppendString(StringBuilder, '<PrintDocumentRequest xmlns="http://www.parcelforce.net/ws/ship/v14">');

        // Authentication header
        AppendString(StringBuilder, '<Authentication>');
        AppendString(StringBuilder, '<UserName>' + UserName + '</UserName>');
        AppendString(StringBuilder, '<Password>' + Password + '</Password>');
        AppendString(StringBuilder, '</Authentication>');

        WarehouseShipmentHeader2.Get(ShipmentNumber);
        AppendString(StringBuilder, '<ShipmentNumber>');
        AppendString(StringBuilder, WarehouseShipmentHeader2.EVS_EWF_PackageTrackingNo);
        AppendString(StringBuilder, '</ShipmentNumber>');

        AppendString(StringBuilder, '<DocumentType>');
        if ShippingDocument = Report::"DAR_CPF_ExportDocument" then
            AppendString(StringBuilder, Format(1))    // 1, Customs Document - 2, Commercial Invoice
        else
            AppendString(StringBuilder, Format(2));

        //DAR001.SP01 -
        AppendString(StringBuilder, '</DocumentType>');

        AppendString(StringBuilder, '<PrintFormat>');
        AppendString(StringBuilder, 'PDF');
        AppendString(StringBuilder, '</PrintFormat>');

        // SOAP footer string
        AppendString(StringBuilder, '</PrintDocumentRequest>');
        AppendString(StringBuilder, '</soapenv:Body>');
        AppendString(StringBuilder, '</soapenv:Envelope>');

        // Construct the web request body
        RequestBody := StringBuilder.ToText();

        WarehouseShipmentHeader.Get(ShipmentNumber);
        CarrierIntSetting.Get(WarehouseShipmentHeader."Shipping Agent Code");

        RequestUri := BaseURL;

        HTTPContent.WriteFrom(RequestBody);

        HTTPContent.GetHeaders(ContentHttpHeaders);
        ContentHttpHeaders.Clear();
        ContentHttpHeaders.Add('Content-Type', 'application/xml;charset=utf-8');
        ContentHttpHeaders.Add('Content-Encoding', 'UTF8');

        WebRequest.Content := HTTPContent;
        WebRequest.SetRequestUri(RequestUri);
        WebRequest.Method := 'POST';

        WebRequest.GetHeaders(RequestHttpHeaders);
        RequestHttpHeaders.Add('SOAPAction', SOAPActionLbl);

        SetFunctionalityReference(AllObj."Object Type"::Codeunit, Codeunit::DAR_CPF_ParcelForceIntegration, RequestTypeTxt);
        // Submits HTTP requests using External Services.
        // Returns HTTP Response message directly, use overload if you want response as text.

        if GuiAllowed() then
            ProgressDialog.Open(ProgressDialogTxt);

        // Initialise External Services log.
        //        
        Clear(TempEVOEXSEventLogEntry);
        LogLevel := LogLevel::EVO_EXS_Parent;
        TempEVOEXSEventLogEntry := InitTempEventLog(WarehouseShipmentHeader);

        Clear(ResponseText);
        EVOEXSManagement.SendRequest(WebRequest, WebResponse, LogLevel, TempEVOEXSEventLogEntry);
        if (WebResponse.HttpStatusCode < 200) or (WebResponse.HttpStatusCode > 299) or (not WebResponse.Content.ReadAs(ResponseText)) then
            Error(ServerErr, RequestUri, StripQuotes(ResponseText)); // Display raw response if response is not Json (i.e. labels).

        if GuiAllowed() then
            ProgressDialog.Close();

        WebResponse.Content().ReadAs(Response);

        // Scan all the xml for the manifest number and possibly mutiple shipment numbers
        StartElement := '<Data>';
        EndElement := '</Data>';
        StartPos := StrPos(Response, StartElement) + 6;
        EndPos := StrPos(Response, EndElement) - 1;
        EndPos := EndPos - StartPos;

        // Grab only the base 64 encoded data - Assumes that there is only 1 label per XML file *There may be 2 or 3!*
        LargeText := CopyStr(Response, StartPos, EndPos);

        // Save the label so we can check the output

        if ShippingDocument = Report::DAR_CPF_PrintExportDocument then begin
            // Convert the Base64 label to a PDF, store it in a blob and print it
            TempBlob.CreateOutStream(PDFOutStream);
            ConvertBase64.FromBase64(LargeText, PDFOutStream);

            DocString := 'CUSTOMSDOC';
            LabelDescriptionTxt := DocString + '_' + WarehouseShipmentHeader."No.";
            WhseShipmentDocEntry.SetRange(EVS_EWF_DocumentNo, WarehouseShipmentHeader."No.");
            WhseShipmentDocEntry.SetRange(EVS_EWF_UsageType, WhseShipmentDocEntry.EVS_EWF_UsageType::DAR_COR_CarrierDocument);
            WhseShipmentDocEntry.DeleteAll(true);


            // Add the document
            WhseShipmentDocEntry.DAR_COR_InsertRecord(TempBlob, WarehouseShipmentHeader, WarehouseShipmentHeader."No." + '_CUSTOMS.pdf', DocString,
                        Report::"DAR_CPF_ExportDocument", WhseShipmentDocEntry.EVS_EWF_UsageType::DAR_COR_CarrierDocument, true);

        end else begin
            // Convert the Base64 label to a PDF, store it in a blob and print it
            TempBlob.CreateOutStream(PDFOutStream);
            ConvertBase64.FromBase64(LargeText, PDFOutStream);

            DocString := 'COMMERCIALINV';
            LabelDescriptionTxt := DocString + '_' + WarehouseShipmentHeader."No.";

            WhseShipmentDocEntry.SetRange(EVS_EWF_DocumentNo, WarehouseShipmentHeader."No.");
            WhseShipmentDocEntry.SetRange(EVS_EWF_UsageType, WhseShipmentDocEntry.EVS_EWF_UsageType::DAR_COR_CommercialInvoice);
            WhseShipmentDocEntry.DeleteAll(true);
            // Add the document
            WhseShipmentDocEntry.DAR_COR_InsertRecord(TempBlob, WarehouseShipmentHeader, WarehouseShipmentHeader."No." + '_INV.pdf', DocString,
                        Report::DAR_CPF_CommercialInvoice, WhseShipmentDocEntry.EVS_EWF_UsageType::DAR_COR_CommercialInvoice, true);

        end;
    end;

    /*procedure PrintManifest(ManifestNumber: Text; pShippingAgentCode: Code[10])
    var
        StringBuilder: DotNet StringBuilder;
        BaseURL: Text;
        SOAPMessage: Text;
        "Warehouse Shipment": Record "Warehouse Shipment Header";
        StringBuilder2: DotNet StringBuilder;
        Window: Dialog;
        "*** Web Functions **": Integer;
        RequestUri: Text;
        WebRequest: DotNet HttpWebRequest;
        RequestBody: Text;
        WebResponse: DotNet HttpWebResponse;
        StreamReader: DotNet StreamReader;
        StreamWriter: DotNet StreamWriter;
        Response: Text;
        RequestStream: DotNet Stream;
        InStream: InStream;
        Encoding: DotNet Encoding;
        XMLBuffer: Record "XML Buffer" temporary;
        ProperIndent: Text;
        LabelBuffer: Text[1024];
        OutStream: OutStream;
        fileMgt: Codeunit "File Management";
        TempBlob: Record TempBlob temporary;
        LargeText: Text;
        StartElement: Text;
        EndElement: Text;
        StartPos: Integer;
        EndPos: Integer;
        ConvertBase64: DotNet Convert;
        Bytes: DotNet Array;
        MemoryStream: DotNet MemoryStream;
        PDFText: BigText;
        SOAPAction: Label 'printManifest';
    begin
        // Send the Received manifest number back to Parcel Force to request a base64 encoded manifest
        Initialise(pShippingAgentCode);
        StringBuilder := StringBuilder.StringBuilder;
        StringBuilder.Clear;
        ProperIndent := ' ';        // Indent char for XML markup

        // SOAP header string
        //AppendString(StringBuilder,'<?xml version="1.0" encoding="UTF-8"?>');
        AppendString(StringBuilder, '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:v14="http://www.parcelforce.net/ws/ship/v14">');
        AppendString(StringBuilder, '<soapenv:Header/>');
        AppendString(StringBuilder, '<soapenv:Body>');

        // Web service callable function
        AppendString(StringBuilder, '<PrintManifestRequest>');

        // Authentication header
        AppendString(StringBuilder, '<Authentication>');
        AppendString(StringBuilder, '<UserName>' + UserName + '</UserName>');
        AppendString(StringBuilder, '<Password>' + Password + '</Password>');
        AppendString(StringBuilder, '</Authentication>');

        AppendString(StringBuilder, '<ManifestNumber>');
        AppendString(StringBuilder, ManifestNumber);
        AppendString(StringBuilder, '</ManifestNumber>');

        // PDF - to return a PDF image of the Label.
        // XML - to return a data stream in order to create own label.
        // PDF-XML - to return the Parcelforce label as PDF and the Partner label as XML.
        // XML-PDF ã to return the Parcelforce label as XML and the Partner label as PDF
        // Note: default will be PDF format if not included.
        AppendString(StringBuilder, '<PrintFormat>PDF</PrintFormat>');

        // SOAP footer string
        AppendString(StringBuilder, '</PrintManifestRequest>');
        AppendString(StringBuilder, '</soapenv:Body>');
        AppendString(StringBuilder, '</soapenv:Envelope>');

        // Construct the web request body
        RequestBody := StringBuilder.ToString;

        //MESSAGE('XML Request: %1', RequestBody);

        RequestUri := UrlPathEncode(BaseURL);
        WebRequest := WebRequest.HttpWebRequest;
        WebRequest := WebRequest.Create(RequestUri);
        WebRequest.Method := 'POST';
        WebRequest.ContentType('application/xml;charset=utf-8');
        WebRequest.Headers.Add('SOAPAction', SOAPAction);   // Text constant for SOAP Action
        WebRequest.ContentLength(StrLen(RequestBody));
        RequestStream := WebRequest.GetRequestStream;
        RequestStream.Write(Encoding.UTF8.GetBytes(RequestBody), 0, Encoding.UTF8.GetBytes(RequestBody).Length);
        RequestStream.Close;
        WebResponse := WebRequest.GetResponse;
        StreamReader := StreamReader.StreamReader(WebResponse.GetResponseStream);
        Response := StreamReader.ReadToEnd;

        StartElement := '<Data>';
        EndElement := '</Data>';
        StartPos := StrPos(Response, StartElement) + 6;
        EndPos := StrPos(Response, EndElement) - 1;
        EndPos := EndPos - StartPos;

        // Grab only the base 64 encoded data - Assumes that there is only 1 label per XML file *There may be 2 or 3!*
        LargeText := CopyStr(Response, StartPos, EndPos);

        // Convert the Base64 label to a PDF, store it in a blob and print it
        Bytes := ConvertBase64.FromBase64String(LargeText);
        MemoryStream := MemoryStream.MemoryStream(Bytes);
        TempBlob.Blob.CreateOutStream(OutStream);
        MemoryStream.WriteTo(OutStream);
        // Save the label so we can check the output
        TempBlob.Blob.Export('manifest_' + ManifestNumber + '.pdf');
    end;*/

    local procedure Initialise(ShippingAgentCode: Code[10])
    var
        CarrierIntSetting: Record DAR_CPF_CarrierIntSetting;
        ContactNumberMissingLbl: Label 'Contact Number is not setup.';
        TestMode: Boolean;
    begin
        // Get the details from here 
        CarrierIntSetting.Get(ShippingAgentCode);
        TestMode := CarrierIntSetting.DAR_CPF_TestingMode;
        DefaultCountryCode := CarrierIntSetting.DAR_CPF_DefaultCountry;
        // Get the settings
        ContactNumber := CarrierIntSetting.DAR_CPF_ContractNumber;
        if not TestMode then begin
            BaseURL := CarrierIntSetting.DAR_CPF_BaseURL;
            UserName := CarrierIntSetting.DAR_CPF_UserName;
            Password := CarrierIntSetting.DAR_CPF_Password;
        end
        else begin
            BaseURL := CarrierIntSetting.DAR_CPF_TestBaseURL;
            UserName := CarrierIntSetting.DAR_CPF_TestUserName;
            Password := CarrierIntSetting.DAR_CPF_TestPassword;
        end;
        tCompany := CarrierIntSetting.DAR_CPF_CompanyName;
        //ReportID := CarrierIntSetting.DAR_CPF_ReportID;
        LabelExportLocation := CarrierIntSetting.DAR_CPF_LabelExportDir;
        Department := CarrierIntSetting.DAR_CPF_Department;
        // Check Values
        if ContactNumber = '' then
            Error(ContactNumberMissingLbl);
    end;

    local procedure EscapeDataString(Value: Text) ReturnValue: Text
    var
        String: Text;
    begin
        String := Value;
        String := String.Replace('"', '');
        String := String.Replace('<', '');
        String := String.Replace('>', '');
        String := String.Replace('&', '');
        String := String.Replace('ä', 'a');
        ReturnValue := String;
    end;

    local procedure RemoveCounty(County: Text): Text
    var
        Position: Integer;
    begin
        Position := StrPos(LowerCase(County), 'county');
        if Position > 0 then begin
            County := CopyStr(County, Position + 7);
            County := UpperCase(CopyStr(County, 1, 1)) + LowerCase(CopyStr(County, 2));

        end;
        exit(County);
    end;

    local procedure AppendString(var StringBuilder: TextBuilder; InputString: Text)
    var
        Delimiter: Text;
    begin
        Delimiter := '';
        if StringBuilder.Length > 0 then
            StringBuilder.Append(Delimiter);
        StringBuilder.Append(InputString.Trim());
    end;

    local procedure CheckBFPO(pCountryRegion: Code[10]; var BFPO: Text[10]): Boolean
    var
        CountryRegionL: Record DAR_CPF_CountryCarrierSerSetup;
    begin
        //+ 5508
        if CountryRegionL.Get(pCountryRegion) then begin
            BFPO := CountryRegionL.DAR_CPF_ParcelForceBFPOID;
            exit(CountryRegionL.DAR_CPF_ParcelForceBFPORegion);
        end;
    end;


    //TODO Check if warehouse shipment documents move to posted.
    local procedure InitTempEventLog(RelatedRecordAsVariant: Variant) TempEVOEXSEventLogEntry: Record EVO_EXS_EventLogEntry temporary
    var
        RecordRef: RecordRef;
        ModuleInfo: ModuleInfo;
    begin
        // Initialise and populate the External Services Log.
        // This is later passed to EVO_EXS_Management to perform the request and log it.

        TempEVOEXSEventLogEntry.Init();
        TempEVOEXSEventLogEntry.EVO_EXS_AllowRetry := false;
        TempEVOEXSEventLogEntry.EVO_EXS_Service := EVO_EXS_Service::DAR_CPF_ParcelForce;

        // Set functionality reference.
        //
        if (FunctionalityRefAllObj."Object ID" <> 0) then
            TempEVOEXSEventLogEntry.SetFunctionalityReference(FunctionalityRefAllObj, FunctionalityRefText);

        // Set Extension info.
        //
        if NavApp.GetCurrentModuleInfo(ModuleInfo) then
            TempEVOEXSEventLogEntry.EVO_EXS_InitiatedByExtension := CopyStr(ModuleInfo.Name, 1, MaxStrLen(TempEVOEXSEventLogEntry.EVO_EXS_InitiatedByExtension));

        // Set related record.
        //
        if RelatedRecordAsVariant.IsRecord() then begin
            RecordRef.GetTable(RelatedRecordAsVariant);

            TempEVOEXSEventLogEntry.EVO_EXS_TableNo := RecordRef.Number();
            TempEVOEXSEventLogEntry.EVO_EXS_RelatedSystemId := RecordRef.Field(RecordRef.SystemIdNo()).Value();
        end;
    end;

    procedure SetFunctionalityReference(ObjectType: Integer; ObjectID: Integer; ReferenceText: Text)
    begin
        // Set functionality reference data used by External Services for logging.
        //
        if not FunctionalityRefAllObj.Get(ObjectType, ObjectID) then
            Clear(FunctionalityRefAllObj);

        FunctionalityRefText := ReferenceText;
    end;

    local procedure StripQuotes(InputText: Text): Text
    begin
        exit(DelChr(InputText, '<>', '"'''));
    end;

}
