codeunit 71130006 EVO_AMC_Management
{
    procedure CreateMedia(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; DoNotExtractZip: Boolean; var TempEVOAMCSetup: Record EVO_AMC_Setup temporary; var EVOAMCEntry: Record EVO_AMC_Entry; var SourceTempBlob: Codeunit "Temp Blob"; var ReturnMessage: Text): Boolean
    var
        TargetTempBlob: Codeunit "Temp Blob";
        IMediaInterface: Interface EVO_AMC_IMediaProvider;
        IsHandled: Boolean;
        SourceInStream: InStream;
        TargetInStream: InStream;
        ExifOrientation: Integer;
        ImageType: Text;
        Result: Boolean;
    begin
        if not TempEVOAMCSetup.EVO_AMC_Got then
            GetOptions(TableNo, TempEVOAMCSetup);

        Clear(ReturnMessage);
        OnBeforeCreateMedia(TableNo, RelatedSystemId, FileName, EVOAMCEntry, TempEVOAMCSetup, SourceTempBlob, Result, ReturnMessage, IsHandled);
        if IsHandled then
            exit(Result);

        if not DoNotExtractZip then
            if FileManagement.HasExtension(FileName) then
                if LowerCase(FileManagement.GetExtension(FileName)) = 'zip' then
                    exit(CreateMediaFromZip(TableNo, RelatedSystemId, FileName, TempEVOAMCSetup, SourceTempBlob, ReturnMessage));

        SourceTempBlob.CreateInStream(SourceInStream);
        IMediaInterface := TempEVOAMCSetup.EVO_AMC_StorageType;
        if TempEVOAMCSetup.EVO_AMC_MaximumFileSizeKB <> 0 then
            if SourceTempBlob.Length() / 1024 > TempEVOAMCSetup.EVO_AMC_MaximumFileSizeKB then begin
                ReturnMessage := 'File size is more than maximum - ' + Format(TempEVOAMCSetup.EVO_AMC_MaximumFileSizeKB) + 'kb.';
                exit(false);
            end;

        EVOAMCEntry.EVO_AMC_TableNo := TableNo;
        EVOAMCEntry.EVO_AMC_RelatedSystemId := RelatedSystemId;
        EVOAMCEntry.EVO_AMC_Code := GetCode(TableNo, RelatedSystemId);
        EVOAMCEntry.EVO_AMC_StorageType := TempEVOAMCSetup.EVO_AMC_StorageType;
        EVOAMCEntry.EVO_AMC_Filename := CopyStr(FileName, 1, MaxStrLen(EVOAMCEntry.EVO_AMC_Filename));

        if TempEVOAMCSetup.EVO_AMC_CalculateMD5Hash then
            EVOAMCEntry.EVO_AMC_MD5Hash := CalculateMD5Hash(SourceInStream); //MD5

        if EVOAMCEntry.EVO_AMC_Type = EVOAMCEntry.EVO_AMC_Type::EVO_AMC_AllMedia then
            EVOAMCEntry.EVO_AMC_Type := GetType(EVOAMCEntry.EVO_AMC_StorageUrl, FileName);
        EVOAMCEntry.EVO_AMC_Size := SourceTempBlob.Length();

        if EVOAMCEntry.EVO_AMC_Type = EVOAMCEntry.EVO_AMC_Type::EVO_AMC_Picture then
            if TryGetImageType(SourceTempBlob, ImageType) then
                // if TryGetImageType(EVOAMCEntry, SourceTempBlob, ImageType) then
                EVOAMCEntry.EVO_AMC_HtmlFormatType := CopyStr(ImageType, 1, MaxStrLen(EVOAMCEntry.EVO_AMC_HtmlFormatType));

        if (EVOAMCEntry.IsJpeg()) and (TempEVOAMCSetup.EVO_AMC_ExifCorrection) then
            if TryGetJpgExifOrientation(SourceTempBlob, ExifOrientation) then
                EVOAMCEntry.EVO_AMC_ExifOrientation := ExifOrientation;

        if RequireThumbnailStorage(EVOAMCEntry, TempEVOAMCSetup) then begin //Set the Media as the resized thumbnail.
            ScaleToThumbnail(SourceTempBlob, TargetTempBlob, TempEVOAMCSetup.EVO_AMC_ThumbnailWidth, TempEVOAMCSetup.EVO_AMC_ThumbnailHeight, TempEVOAMCSetup.EVO_AMC_ThumbnailQuality, EVOAMCEntry.EVO_AMC_ExifOrientation);
            TargetTempBlob.CreateInStream(TargetInStream);
            if not TargetInStream.EOS then begin
                EVOAMCEntry.EVO_AMC_Thumbnail.ImportStream(TargetInStream, FileName);
                EVOAMCEntry.EVO_AMC_ThumbnailSize := TargetTempBlob.Length();
            end;
        end else
            EVOAMCEntry.EVO_AMC_ThumbnailSize := 0;

        if not EVOAMCEntry.Insert(true) then begin
            if ReturnMessage = '' then
                ReturnMessage := 'Unable to insert media.';

            exit(false);
        end;

        Result := IMediaInterface.AddMedia(EVOAMCEntry, SourceTempBlob, ReturnMessage);
        if not Result then
            if TempEVOAMCSetup.EVO_AMC_DatabaseFallback then begin
                IMediaInterface := EVOAMCEntry.EVO_AMC_StorageType::EVO_AMC_Database;
                EVOAMCEntry.EVO_AMC_StorageType := EVOAMCEntry.EVO_AMC_StorageType::EVO_AMC_Database;
                Result := IMediaInterface.AddMedia(EVOAMCEntry, SourceTempBlob, ReturnMessage);
            end else begin
                EVOAMCEntry.Delete(false);
                exit(false);
            end;

        OnAfterCreateMedia(EVOAMCEntry, SourceTempBlob, Result, ReturnMessage);
        exit(Result);
    end;

    procedure CreateMedia(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; var TempEVOAMCSetup: Record EVO_AMC_Setup temporary; var EVOAMCEntry: Record EVO_AMC_Entry; var SourceTempBlob: Codeunit "Temp Blob"; var ReturnMessage: Text): Boolean
    begin
        exit(CreateMedia(TableNo, RelatedSystemId, FileName, false, TempEVOAMCSetup, EVOAMCEntry, SourceTempBlob, ReturnMessage));
    end;

    procedure CreateMedia(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; var TempEVOAMCSetup: Record EVO_AMC_Setup temporary; var EVOAMCEntry: Record EVO_AMC_Entry; var SourceTempBlob: Codeunit "Temp Blob"): Boolean
    var
        ReturnMessage: Text;
    begin
        exit(CreateMedia(TableNo, RelatedSystemId, FileName, TempEVOAMCSetup, EVOAMCEntry, SourceTempBlob, ReturnMessage));
    end;

    procedure CreateMedia(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; var EVOAMCEntry: Record EVO_AMC_Entry; var SourceTempBlob: Codeunit "Temp Blob"; var ReturnMessage: Text): Boolean
    var
        TempEVOAMCSetup: Record EVO_AMC_Setup temporary;
    begin
        exit(CreateMedia(TableNo, RelatedSystemId, FileName, TempEVOAMCSetup, EVOAMCEntry, SourceTempBlob, ReturnMessage));
    end;

    procedure CreateMedia(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; var EVOAMCEntry: Record EVO_AMC_Entry; var SourceTempBlob: Codeunit "Temp Blob"): Boolean
    var
        TempEVOAMCSetup: Record EVO_AMC_Setup temporary;
    begin
        exit(CreateMedia(TableNo, RelatedSystemId, FileName, TempEVOAMCSetup, EVOAMCEntry, SourceTempBlob));
    end;

    procedure CreateMedia(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; var SourceTempBlob: Codeunit "Temp Blob"): Boolean
    var
        SourceInStream: InStream;
    begin
        SourceTempBlob.CreateInStream(SourceInStream);
        exit(CreateMedia(TableNo, RelatedSystemId, FileName, SourceInStream));
    end;

    procedure CreateMedia(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; var SourceInStream: InStream): Boolean
    var
        EVOAMCEntry: Record EVO_AMC_Entry;
    begin
        exit(CreateMedia(TableNo, RelatedSystemId, FileName, EVOAMCEntry, SourceInStream));
    end;

    procedure CreateMedia(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; var EVOAMCEntry: Record EVO_AMC_Entry; var SourceInStream: InStream): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        TargetOutStream: OutStream;
    begin
        TempBlob.CreateOutStream(TargetOutStream);
        CopyStream(TargetOutStream, SourceInStream);
        exit(CreateMedia(TableNo, RelatedSystemId, FileName, EVOAMCEntry, TempBlob));
    end;

    procedure CreateMedia(TableNo: Integer; RelatedSystemId: Guid): Boolean
    var
        FromFile: Text;
        SourceInStream: InStream;
    begin
        if UploadIntoStream('Import Media', '', GetUploadFilter(), FromFile, SourceInStream) then
            exit(CreateMedia(TableNo, RelatedSystemId, FromFile, SourceInStream));
    end;

    procedure CreateMediaUrl(TableNo: Integer; RelatedSystemId: Guid; Url: Text; var TempEVOAMCSetup: Record EVO_AMC_Setup; var EVOAMCEntry: Record EVO_AMC_Entry; var ReturnMessage: Text): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        FileName: Text;
        Result: Boolean;
    begin
        Clear(ReturnMessage);
        CheckUrl(Url, MaxStrLen(EVOAMCEntry.EVO_AMC_StorageUrl));
        FileName := Url.Substring(Url.LastIndexOf('/') + 1);
        if FileManagement.HasExtension(FileName) then begin
            if FileName.Contains('?') then
                FileName := CopyStr(FileName, 1, StrPos(FileName, '?') - 1);
        end else
            Clear(FileName);

        EVOAMCEntry.EVO_AMC_StorageUrl := CopyStr(Url, 1, MaxStrLen(EVOAMCEntry.EVO_AMC_StorageUrl));
        EVOAMCEntry.EVO_AMC_EmbedUrl := CopyStr(GenerateEmbedUrl(EVOAMCEntry.EVO_AMC_StorageUrl), 1, MaxStrLen(EVOAMCEntry.EVO_AMC_EmbedUrl));
        if EVOAMCEntry.EVO_AMC_EmbedUrl = '' then
            if GetWebMedia(Url, TempBlob) then
                exit(CreateMedia(TableNo, RelatedSystemId, FileName, TempEVOAMCSetup, EVOAMCEntry, TempBlob, ReturnMessage));

        EVOAMCEntry.EVO_AMC_TableNo := TableNo;
        EVOAMCEntry.EVO_AMC_RelatedSystemId := RelatedSystemId;
        EVOAMCEntry.EVO_AMC_Code := GetCode(TableNo, RelatedSystemId);
        EVOAMCEntry.EVO_AMC_StorageType := EVOAMCEntry.EVO_AMC_StorageType::EVO_AMC_Url;
        EVOAMCEntry.EVO_AMC_Filename := CopyStr(FileName, 1, MaxStrLen(EVOAMCEntry.EVO_AMC_Filename));
        EVOAMCEntry.EVO_AMC_Size := 0;
        EVOAMCEntry.EVO_AMC_ThumbnailSize := 0;
        if EVOAMCEntry.EVO_AMC_Type = EVOAMCEntry.EVO_AMC_Type::EVO_AMC_AllMedia then
            if EVOAMCEntry.EVO_AMC_EmbedUrl <> '' then
                EVOAMCEntry.EVO_AMC_Type := EVOAMCEntry.EVO_AMC_Type::EVO_AMC_Video
            else
                EVOAMCEntry.EVO_AMC_Type := GetType(EVOAMCEntry.EVO_AMC_StorageUrl, FileName);

        Result := EVOAMCEntry.Insert(true);
        OnAfterCreateMedia(EVOAMCEntry, TempBlob, Result, ReturnMessage);
        exit(Result);
    end;

    procedure CreateMediaUrl(TableNo: Integer; RelatedSystemId: Guid; Url: Text; var TempEVOAMCSetup: Record EVO_AMC_Setup; var EVOAMCEntry: Record EVO_AMC_Entry): Boolean
    var
        ReturnMessage: Text;
    begin
        exit(CreateMediaUrl(TableNo, RelatedSystemId, Url, TempEVOAMCSetup, EVOAMCEntry, ReturnMessage));
    end;

    procedure CreateMediaUrl(TableNo: Integer; RelatedSystemId: Guid; Url: Text; var EVOAMCEntry: Record EVO_AMC_Entry): Boolean
    var
        TempEVOAMCSetup: Record EVO_AMC_Setup temporary;
    begin
        exit(CreateMediaUrl(TableNo, RelatedSystemId, Url, TempEVOAMCSetup, EVOAMCEntry));
    end;

    procedure CreateMediaUrl(TableNo: Integer; RelatedSystemId: Guid; Url: Text): Boolean
    var
        EVOAMCEntry: Record EVO_AMC_Entry;
    begin
        exit(CreateMediaUrl(TableNo, RelatedSystemId, Url, EVOAMCEntry));
    end;

    procedure CreateMediaBase64(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; Base64Contents: Text; var TempEVOAMCSetup: Record EVO_AMC_Setup; var EVOAMCEntry: Record EVO_AMC_Entry; var ReturnMessage: Text): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        TargetOutStream: OutStream;
    begin
        Clear(ReturnMessage);
        if Base64Contents = '' then
            exit(false);

        EVOAMCEntry.Init();
        TempBlob.CreateOutStream(TargetOutStream);
        Base64Convert.FromBase64(Base64Contents, TargetOutStream);
        exit(CreateMedia(TableNo, RelatedSystemId, FileName, TempEVOAMCSetup, EVOAMCEntry, TempBlob, ReturnMessage));
    end;

    procedure CreateMediaBase64(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; Base64Contents: Text; var TempEVOAMCSetup: Record EVO_AMC_Setup; var EVOAMCEntry: Record EVO_AMC_Entry): Boolean
    var
        ReturnMessage: Text;
    begin
        exit(CreateMediaBase64(TableNo, RelatedSystemId, FileName, Base64Contents, TempEVOAMCSetup, EVOAMCEntry, ReturnMessage));
    end;

    procedure CreateMediaBase64(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; Base64Contents: Text; var EVOAMCEntry: Record EVO_AMC_Entry; var ReturnMessage: Text): Boolean
    var
        TempEVOAMCSetup: Record EVO_AMC_Setup temporary;
    begin
        exit(CreateMediaBase64(TableNo, RelatedSystemId, FileName, Base64Contents, TempEVOAMCSetup, EVOAMCEntry, ReturnMessage));
    end;

    procedure CreateMediaBase64(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; Base64Contents: Text; var EVOAMCEntry: Record EVO_AMC_Entry): Boolean
    var
        TempEVOAMCSetup: Record EVO_AMC_Setup temporary;
        ReturnMessage: Text;
    begin
        exit(CreateMediaBase64(TableNo, RelatedSystemId, FileName, Base64Contents, TempEVOAMCSetup, EVOAMCEntry, ReturnMessage));
    end;

    procedure CreateMediaBase64(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; Base64Contents: Text): Boolean
    var
        EVOAMCEntry: Record EVO_AMC_Entry;
    begin
        exit(CreateMediaBase64(TableNo, RelatedSystemId, FileName, Base64Contents, EVOAMCEntry));
    end;

    [Obsolete('Use CreateMediaFromZip using ZipFileName instead.')]
    procedure CreateMediaFromZip(TableNo: Integer; RelatedSystemId: Guid; var TempMediaSetup: Record EVO_AMC_Setup temporary; var SourceTempBlob: Codeunit "Temp Blob"; var ReturnMessage: Text): Boolean
    begin
        exit(CreateMediaFromZip(TableNo, RelatedSystemId, 'Unnamed', TempMediaSetup, SourceTempBlob, ReturnMessage));
    end;

    procedure CreateMediaFromZip(TableNo: Integer; RelatedSystemId: Guid; ZipFileName: Text; var TempEVOAMCSetup: Record EVO_AMC_Setup temporary; var SourceTempBlob: Codeunit "Temp Blob"; var ReturnMessage: Text): Boolean
    var
        EVOAMCEntry: Record EVO_AMC_Entry;
        DataCompression: Codeunit "Data Compression";
        TargetTempBlob: Codeunit "Temp Blob";
        ZipInStream: InStream;
        TargetOutStream: OutStream;
        FileName: Text;
        FileList: List of [Text];
        ExtensionList: list of [Text];
        i: Integer;
        ResultCount: Integer;
        IsHandled: Boolean;
        CreatedFilesAmountFromZipLbl: Label 'Created %1 out of %2 files inside the zip.', Comment = '%1 = Success Count, %2 = Total Count';
    begin
        SourceTempBlob.CreateInStream(ZipInStream);
        DataCompression.OpenZipArchive(ZipInStream, false);
        DataCompression.GetEntryList(FileList);
        OnBeforeCreateMediaFromZip(TableNo, RelatedSystemId, ZipFileName, TempEVOAMCSetup, SourceTempBlob, FileList, DataCompression, ReturnMessage, IsHandled);
        if IsHandled then
            exit;

        AcceptedFileExtensions(ExtensionList);
        for i := 1 to FileList.Count do begin
            FileList.Get(i, FileName);
            if FileName.Contains('\') then
                FileName := FileName.Substring(FileName.LastIndexOf('\') + 1);

            if FileManagement.HasExtension(FileName) then
                if ExtensionList.Contains(LowerCase(FileManagement.GetExtension(FileName))) then begin
                    Clear(TargetTempBlob);
                    Clear(EVOAMCEntry);
                    TargetTempBlob.CreateOutStream(TargetOutStream);
                    DataCompression.ExtractEntry(FileName, TargetOutStream);
                    if CreateMedia(TableNo, RelatedSystemId, FileName, TempEVOAMCSetup, EVOAMCEntry, TargetTempBlob) then
                        ResultCount += 1;
                end;
        end;

        ReturnMessage := StrSubstNo(CreatedFilesAmountFromZipLbl, ResultCount, FileList.Count);
        exit(ResultCount > 0);
    end;

    procedure UpdateMedia(var EVOAMCEntry: Record EVO_AMC_Entry; ConfirmOnDeleteFailure: Boolean; FileName: Text; var TempEVOAMCSetup: Record EVO_AMC_Setup temporary; var SourceTempBlob: Codeunit "Temp Blob"; var ReturnMessage: Text): Boolean
    var
        TargetTempBlob: Codeunit "Temp Blob";
        IMediaInterface: Interface EVO_AMC_IMediaProvider;
        IsHandled: Boolean;
        SourceInStream: InStream;
        TargetInStream: InStream;
        ExifOrientation: Integer;
        ImageType: Text;
        Result: Boolean;
    begin
        Clear(ReturnMessage);
        if not GuiAllowed then
            ConfirmOnDeleteFailure := false;

        OnBeforeUpdateMedia(EVOAMCEntry, ReturnMessage, Result, IsHandled);
        if IsHandled then
            exit(Result);

        SourceTempBlob.CreateInStream(SourceInStream);
        IMediaInterface := EVOAMCEntry.EVO_AMC_StorageType;
        if not TempEVOAMCSetup.EVO_AMC_Got then
            GetOptions(EVOAMCEntry.EVO_AMC_TableNo, TempEVOAMCSetup);
        if TempEVOAMCSetup.EVO_AMC_MaximumFileSizeKB <> 0 then
            if SourceTempBlob.Length() / 1024 > TempEVOAMCSetup.EVO_AMC_MaximumFileSizeKB then begin
                ReturnMessage := 'File size is more than maximum - ' + Format(TempEVOAMCSetup.EVO_AMC_MaximumFileSizeKB) + 'kb.';
                exit(false);
            end;

        if not IMediaInterface.DeleteMedia(EVOAMCEntry, ReturnMessage) then
            if ConfirmOnDeleteFailure then
                if not Confirm('Unable to delete %1. Continue?\\Path: %2', true, EVOAMCEntry.EVO_AMC_Filename, EVOAMCEntry.EVO_AMC_ExternalStoragePath) then
                    exit(false);

        EVOAMCEntry.EVO_AMC_Filename := CopyStr(FileName, 1, MaxStrLen(EVOAMCEntry.EVO_AMC_Filename));

        if TempEVOAMCSetup.EVO_AMC_CalculateMD5Hash then
            EVOAMCEntry.EVO_AMC_MD5Hash := CalculateMD5Hash(SourceInStream); //MD5

        if EVOAMCEntry.EVO_AMC_Type = EVOAMCEntry.EVO_AMC_Type::EVO_AMC_AllMedia then
            EVOAMCEntry.EVO_AMC_Type := GetType(EVOAMCEntry.EVO_AMC_StorageUrl, FileName);
        EVOAMCEntry.EVO_AMC_Size := SourceTempBlob.Length();

        if EVOAMCEntry.EVO_AMC_Type = EVOAMCEntry.EVO_AMC_Type::EVO_AMC_Picture then
            if TryGetImageType(SourceTempBlob, ImageType) then
                // if TryGetImageType(EVOAMCEntry, SourceTempBlob, ImageType) then
                EVOAMCEntry.EVO_AMC_HtmlFormatType := CopyStr(ImageType, 1, MaxStrLen(EVOAMCEntry.EVO_AMC_HtmlFormatType));

        if (EVOAMCEntry.IsJpeg()) and (TempEVOAMCSetup.EVO_AMC_ExifCorrection) then
            if TryGetJpgExifOrientation(SourceTempBlob, ExifOrientation) then
                EVOAMCEntry.EVO_AMC_ExifOrientation := ExifOrientation;

        if RequireThumbnailStorage(EVOAMCEntry, TempEVOAMCSetup) then begin //Set the Media as the resized thumbnail.
            Clear(EVOAMCEntry.EVO_AMC_Thumbnail);
            ScaleToThumbnail(SourceTempBlob, TargetTempBlob, TempEVOAMCSetup.EVO_AMC_ThumbnailWidth, TempEVOAMCSetup.EVO_AMC_ThumbnailHeight, TempEVOAMCSetup.EVO_AMC_ThumbnailQuality, EVOAMCEntry.EVO_AMC_ExifOrientation);
            TargetTempBlob.CreateInStream(TargetInStream);
            if not TargetInStream.EOS then begin
                EVOAMCEntry.EVO_AMC_Thumbnail.ImportStream(TargetInStream, FileName);
                EVOAMCEntry.EVO_AMC_ThumbnailSize := TargetTempBlob.Length();
            end;
        end else
            EVOAMCEntry.EVO_AMC_ThumbnailSize := 0;

        if EVOAMCEntry.Modify(true) then
            Result := IMediaInterface.AddMedia(EVOAMCEntry, SourceTempBlob, ReturnMessage);

        if not Result then begin
            if ReturnMessage = '' then
                ReturnMessage := 'Unable to update media.';

            exit(false);
        end;

        OnAfterUpdateMedia(EVOAMCEntry, SourceTempBlob, ReturnMessage);
        exit(Result);
    end;

    procedure UpdateMedia(var EVOAMCEntry: Record EVO_AMC_Entry; ConfirmOnDeleteFailure: Boolean; FileName: Text; var TempEVOAMCSetup: Record EVO_AMC_Setup temporary; var SourceTempBlob: Codeunit "Temp Blob"): Boolean
    var
        ReturnMessage: Text;
    begin
        exit(UpdateMedia(EVOAMCEntry, ConfirmOnDeleteFailure, FileName, TempEVOAMCSetup, SourceTempBlob, ReturnMessage));
    end;

    procedure UpdateMedia(var EVOAMCEntry: Record EVO_AMC_Entry; ConfirmOnDeleteFailure: Boolean; FileName: Text; var SourceTempBlob: Codeunit "Temp Blob"; var ReturnMessage: Text): Boolean
    var
        TempEVOAMCSetup: Record EVO_AMC_Setup temporary;
    begin
        exit(UpdateMedia(EVOAMCEntry, ConfirmOnDeleteFailure, FileName, TempEVOAMCSetup, SourceTempBlob, ReturnMessage));
    end;

    procedure UpdateMedia(var EVOAMCEntry: Record EVO_AMC_Entry; ConfirmOnDeleteFailure: Boolean; FileName: Text; var SourceTempBlob: Codeunit "Temp Blob"): Boolean
    var
        TempEVOAMCSetup: Record EVO_AMC_Setup temporary;
    begin
        exit(UpdateMedia(EVOAMCEntry, ConfirmOnDeleteFailure, FileName, TempEVOAMCSetup, SourceTempBlob));
    end;

    procedure UpdateMedia(var EVOAMCEntry: Record EVO_AMC_Entry; FileName: Text; var SourceTempBlob: Codeunit "Temp Blob"): Boolean
    begin
        exit(UpdateMedia(EVOAMCEntry, true, FileName, SourceTempBlob));
    end;

    procedure UpdateMedia(var EVOAMCEntry: Record EVO_AMC_Entry): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        FromFile: Text;
        SourceInStream: InStream;
        TargetOutStream: OutStream;
    begin
        if UploadIntoStream('Import Media', '', GetUploadFilter(), FromFile, SourceInStream) then begin
            TempBlob.CreateOutStream(TargetOutStream);
            CopyStream(TargetOutStream, SourceInStream);
            exit(UpdateMedia(EVOAMCEntry, FromFile, TempBlob));
        end;
    end;

    procedure UpdateMediaUrl(var EVOAMCEntry: Record EVO_AMC_Entry; ConfirmOnDeleteFailure: Boolean; Url: Text; var TempEVOAMCSetup: Record EVO_AMC_Setup temporary; var ReturnMessage: Text): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        FileName: Text;
    begin
        Clear(ReturnMessage);
        CheckUrl(Url, MaxStrLen(EVOAMCEntry.EVO_AMC_StorageUrl));
        FileName := Url.Substring(Url.LastIndexOf('/') + 1);
        if FileManagement.HasExtension(FileName) then begin
            if FileName.Contains('?') then
                FileName := CopyStr(FileName, 1, StrPos(FileName, '?') - 1);
        end else
            Clear(FileName);

        EVOAMCEntry.EVO_AMC_StorageUrl := CopyStr(Url, 1, MaxStrLen(EVOAMCEntry.EVO_AMC_StorageUrl));
        if GetWebMedia(Url, TempBlob) then
            exit(UpdateMedia(EVOAMCEntry, ConfirmOnDeleteFailure, FileName, TempBlob))
        else begin
            Clear(EVOAMCEntry.EVO_AMC_Thumbnail);
            EVOAMCEntry.EVO_AMC_StorageType := EVOAMCEntry.EVO_AMC_StorageType::EVO_AMC_Url;
            EVOAMCEntry.EVO_AMC_Filename := CopyStr(FileName, 1, MaxStrLen(EVOAMCEntry.EVO_AMC_Filename));
            if EVOAMCEntry.EVO_AMC_Type = EVOAMCEntry.EVO_AMC_Type::EVO_AMC_AllMedia then
                EVOAMCEntry.EVO_AMC_Type := GetType(EVOAMCEntry.EVO_AMC_StorageUrl, FileName);
            EVOAMCEntry.EVO_AMC_Size := 0;
            EVOAMCEntry.EVO_AMC_ThumbnailSize := 0;
            exit(EVOAMCEntry.Modify(true));
        end;
    end;

    procedure UpdateMediaUrl(var EVOAMCEntry: Record EVO_AMC_Entry; ConfirmOnDeleteFailure: Boolean; Url: Text; var TempEVOAMCSetup: Record EVO_AMC_Setup temporary): Boolean
    var
        ReturnMessage: Text;
    begin
        exit(UpdateMediaUrl(EVOAMCEntry, ConfirmOnDeleteFailure, Url, TempEVOAMCSetup, ReturnMessage));
    end;

    procedure UpdateMediaUrl(var EVOAMCEntry: Record EVO_AMC_Entry; ConfirmOnDeleteFailure: Boolean; Url: Text): Boolean
    var
        TempEVOAMCSetup: Record EVO_AMC_Setup temporary;
    begin
        exit(UpdateMediaUrl(EVOAMCEntry, ConfirmOnDeleteFailure, Url, TempEVOAMCSetup));
    end;

    procedure UpdateMediaUrl(var EVOAMCEntry: Record EVO_AMC_Entry; Url: Text): Boolean
    begin
        exit(UpdateMediaUrl(EVOAMCEntry, true, Url));
    end;

    procedure UpdateMediaBase64(var EVOAMCEntry: Record EVO_AMC_Entry; ConfirmOnDeleteFailure: Boolean; FileName: Text; Base64Contents: Text; var TempEVOAMCSetup: Record EVO_AMC_Setup temporary; var ReturnMessage: Text): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        TargetOutStream: OutStream;
    begin
        if Base64Contents = '' then
            exit(false);

        TempBlob.CreateOutStream(TargetOutStream);
        Base64Convert.FromBase64(Base64Contents, TargetOutStream);
        exit(UpdateMedia(EVOAMCEntry, ConfirmOnDeleteFailure, FileName, TempBlob, ReturnMessage));
    end;

    procedure UpdateMediaBase64(var EVOAMCEntry: Record EVO_AMC_Entry; ConfirmOnDeleteFailure: Boolean; FileName: Text; Base64Contents: Text; var TempEVOAMCSetup: Record EVO_AMC_Setup temporary): Boolean
    var
        ReturnMessage: Text;
    begin
        exit(UpdateMediaBase64(EVOAMCEntry, ConfirmOnDeleteFailure, FileName, Base64Contents, TempEVOAMCSetup, ReturnMessage));
    end;

    procedure UpdateMediaBase64(var EVOAMCEntry: Record EVO_AMC_Entry; ConfirmOnDeleteFailure: Boolean; FileName: Text; Base64Contents: Text; var ReturnMessage: Text): Boolean
    var
        TempEVOAMCSetup: Record EVO_AMC_Setup temporary;
    begin
        exit(UpdateMediaBase64(EVOAMCEntry, ConfirmOnDeleteFailure, FileName, Base64Contents, TempEVOAMCSetup, ReturnMessage));
    end;

    procedure UpdateMediaBase64(var EVOAMCEntry: Record EVO_AMC_Entry; ConfirmOnDeleteFailure: Boolean; FileName: Text; Base64Contents: Text): Boolean
    var
        TempEVOAMCSetup: Record EVO_AMC_Setup temporary;
    begin
        exit(UpdateMediaBase64(EVOAMCEntry, ConfirmOnDeleteFailure, FileName, Base64Contents, TempEVOAMCSetup));
    end;

    procedure UpdateMediaBase64(var EVOAMCEntry: Record EVO_AMC_Entry; FileName: Text; Base64Contents: Text): Boolean
    begin
        exit(UpdateMediaBase64(EVOAMCEntry, true, FileName, Base64Contents));
    end;

    [Obsolete('Removed as it''s been made redundant.', '26.0')]
    procedure GetThumbnails(TableNo: Integer; RelatedSystemId: Guid; MaxToLoad: Integer) MediaArray: JsonArray
    var
        MediaEntry: Record EVO_AMC_Entry;
        HtmlSource: Text;
        Loaded: Integer;
    begin
        MediaEntry.SetCurrentKey(EVO_AMC_TableNo, EVO_AMC_RelatedSystemId, EVO_AMC_SortNo);
        MediaEntry.SetAscending(EVO_AMC_SortNo, true);
        MediaEntry.SetRange(EVO_AMC_TableNo, TableNo);
        MediaEntry.SetRange(EVO_AMC_RelatedSystemId, RelatedSystemId);
        if MediaEntry.FindSet() then
            repeat
                HtmlSource := MediaEntry.HtmlImgSrc();
                if HtmlSource <> '' then begin
                    MediaArray.Add(MediaEntry.GetThumbnailJsonObject(HtmlSource));
                    Loaded += 1;
                end;
            until (MediaEntry.Next() = 0) or (Loaded >= MaxToLoad);
    end;

    [Obsolete('Removed as it''s been made redundant.', '26.0')]
    procedure GetThumbnails(TableNo: Integer; RelatedSystemId: Guid) MediaArray: JsonArray
    begin
        exit(GetThumbnails(TableNo, RelatedSystemId, 0))
    end;

    procedure UpdateThumbnail(var EVOAMCEntry: Record EVO_AMC_Entry; var SourceTempBlob: Codeunit "Temp Blob")
    var
        TempEVOAMCSetup: Record EVO_AMC_Setup temporary;
    begin
        GetOptions(EVOAMCEntry.EVO_AMC_TableNo, TempEVOAMCSetup);
        UpdateThumbnail(EVOAMCEntry, TempEVOAMCSetup.EVO_AMC_ThumbnailWidth, TempEVOAMCSetup.EVO_AMC_ThumbnailHeight, TempEVOAMCSetup.EVO_AMC_ThumbnailQuality, SourceTempBlob);
    end;

    procedure UpdateThumbnail(var EVOAMCEntry: Record EVO_AMC_Entry; TargetWidth: Integer; TargetHeight: Integer; TargetQuality: Integer; var SourceTempBlob: Codeunit "Temp Blob")
    var
        TempEVOAMCSetup: Record EVO_AMC_Setup temporary;
        TargetTempBlob: Codeunit "Temp Blob";
        TargetInStream: InStream;
        ImageType: Text;
        ExifOrientation: Integer;
    begin
        GetOptions(EVOAMCEntry.EVO_AMC_TableNo, TempEVOAMCSetup);
        if not RequireThumbnailStorage(EVOAMCEntry, TempEVOAMCSetup) then
            exit;

        if TryGetImageType(SourceTempBlob, ImageType) then
            // if TryGetImageType(EVOAMCEntry, SourceTempBlob, ImageType) then
            EVOAMCEntry.EVO_AMC_HtmlFormatType := CopyStr(ImageType, 1, MaxStrLen(EVOAMCEntry.EVO_AMC_HtmlFormatType));

        if (EVOAMCEntry.IsJpeg()) and (TempEVOAMCSetup.EVO_AMC_ExifCorrection) then
            if TryGetJpgExifOrientation(SourceTempBlob, ExifOrientation) then
                EVOAMCEntry.EVO_AMC_ExifOrientation := ExifOrientation;

        Clear(EVOAMCEntry.EVO_AMC_Thumbnail);
        ScaleToThumbnail(SourceTempBlob, TargetTempBlob, TargetWidth, TargetHeight, TargetQuality, EVOAMCEntry.EVO_AMC_ExifOrientation);
        TargetTempBlob.CreateInStream(TargetInStream);
        EVOAMCEntry.EVO_AMC_Thumbnail.ImportStream(TargetInStream, EVOAMCEntry.EVO_AMC_Filename);
        EVOAMCEntry.EVO_AMC_ThumbnailSize := TargetTempBlob.Length();
    end;

    procedure UpdateThumbnail(var EVOAMCEntry: Record EVO_AMC_Entry)
    var
        SourceTempBlob: Codeunit "Temp Blob";
    begin
        if EVOAMCEntry.GetMedia(SourceTempBlob) then
            UpdateThumbnail(EVOAMCEntry, SourceTempBlob);
    end;

    procedure ImportMedia(TableNo: Integer; RelatedSystemId: Guid; var EVOAMCEntry: Record EVO_AMC_Entry; var ReturnMessage: Text): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        IsHandled: Boolean;
        FromFile: Text;
        SourceInStream: InStream;
        TargetOutStream: OutStream;
    begin
        Clear(ReturnMessage);
        OnBeforeImportMedia(TableNo, RelatedSystemId, EVOAMCEntry, ReturnMessage, IsHandled);
        if IsHandled then
            exit;

        if GetStorageType(TableNo) <> Enum::EVO_AMC_StorageType::EVO_AMC_Url then begin
            if not UploadIntoStream('Import Media', '', GetUploadFilter(), FromFile, SourceInStream) then begin
                ReturnMessage := 'CANCELLED';
                exit;
            end;

            TempBlob.CreateOutStream(TargetOutStream);
            CopyStream(TargetOutStream, SourceInStream);
            exit(CreateMedia(TableNo, RelatedSystemId, FromFile, EVOAMCEntry, TempBlob, ReturnMessage));
        end else
            exit(ImportWebMedia(TableNo, RelatedSystemId, EVOAMCEntry, ReturnMessage));
    end;

    procedure ImportMedia(TableNo: Integer; RelatedSystemId: Guid; var EVOAMCEntry: Record EVO_AMC_Entry): Boolean
    var
        ReturnMessage: Text;
    begin
        exit(ImportMedia(TableNo, RelatedSystemId, EVOAMCEntry, ReturnMessage));
    end;

    procedure ImportMedia(TableNo: Integer; RelatedSystemId: Guid): Boolean
    var
        EVOAMCEntry: Record EVO_AMC_Entry;
    begin
        exit(ImportMedia(TableNo, RelatedSystemId, EVOAMCEntry));
    end;

    procedure ImportWebMedia(TableNo: Integer; RelatedSystemId: Guid; var EVOAMCEntry: Record EVO_AMC_Entry; var ReturnMessage: Text): Boolean
    var
        TempEVOAMCSetup: Record EVO_AMC_Setup temporary;
        Url: Text;
    begin
        Url := InputUrl();
        if Url = '' then begin
            ReturnMessage := 'CANCELLED';
            exit;
        end;

        GetOptions(TableNo, TempEVOAMCSetup);
        TempEVOAMCSetup.EVO_AMC_StorageType := TempEVOAMCSetup.EVO_AMC_StorageType::EVO_AMC_Url;
        exit(CreateMediaUrl(TableNo, RelatedSystemId, Url, TempEVOAMCSetup, EVOAMCEntry, ReturnMessage));
    end;

    procedure ImportWebMedia(TableNo: Integer; RelatedSystemId: Guid; var EVOAMCEntry: Record EVO_AMC_Entry): Boolean
    var
        ReturnMessage: Text;
    begin
        exit(ImportWebMedia(TableNo, RelatedSystemId, EVOAMCEntry, ReturnMessage));
    end;

    procedure ImportWebMedia(TableNo: Integer; RelatedSystemId: Guid): Boolean
    var
        EVOAMCEntry: Record EVO_AMC_Entry;
        ReturnMessage: Text;
    begin
        exit(ImportWebMedia(TableNo, RelatedSystemId, EVOAMCEntry, ReturnMessage));
    end;

    procedure BackupMediaToZip()
    var
        EVOAMCEntry: Record EVO_AMC_Entry;
        IsHandled: Boolean;
        BackupQst: Label 'This may take a long time and is only recommended while the system is not in use.\\Continue?';
    begin
        OnBeforeBackupMediaToZip(IsHandled);
        if IsHandled then
            exit;

        if Confirm(BackupQst, true) then
            ExportZip(EVOAMCEntry);
    end;

    procedure RestoreMediaFromZip()
    var
        EVOAMCEntry: Record EVO_AMC_Entry;
        DataCompression: Codeunit "Data Compression";
        TempBlob: Codeunit "Temp Blob";
        SourceInStream: InStream;
        TargetOutStream: OutStream;
        FromFile: Text;
        MediaPath: Text;
        MediaPathList: List of [Text];
        MediaList: List of [Text];
        ZipFilterLbl: Label 'Zip File (*.zip)|*.zip';
        TableNo: Integer;
        RelatedSystemId: Guid;
        FileName: Text;
        ReturnMessage: Text;
        TotalFailureMessage: Text;
        TotalFailureCount: Integer;
        TotalSkippedCount: Integer;
        TotalCount: Integer;
        i: Integer;
        IsHandled: Boolean;
        RestoreQst: Label 'This may take a long time and is only recommended while the system is not in use. This will only succeed if the folder & file structure matches data taken using the backup or export functionality.\\Continue?';
        FileFailedUploadTxt: Label 'File %1 failed to upload: %2', Comment = '%1 = File Name, %2 = Error';
        ResultsMsgDialogTxt: Label 'Total: %1\Failures: %2\Skipped: %3\Error Details: %4', Comment = '%1 = Total Failure Count, %2 = Total Count, %3 = Total Skipped Count, %4 = Failure Messages';
        RestoreCompletedSuccMsg: Label 'Restore completed successfully.';
    begin
        OnBeforeRestoreMediaFromZip(IsHandled);
        if IsHandled then
            exit;

        if not UploadIntoStream('Import Zip File', '', ZipFilterLbl, FromFile, SourceInStream) then
            exit;

        if not Confirm(RestoreQst, true) then
            exit;

        DataCompression.OpenZipArchive(SourceInStream, false);
        DataCompression.GetEntryList(MediaList);
        TotalCount := MediaList.Count;
        for i := 1 to TotalCount do begin
            MediaList.Get(i, MediaPath);
            MediaPathList := MediaPath.Split('\');
            if Evaluate(TableNo, MediaPathList.Get(1)) then begin
                if Evaluate(RelatedSystemId, MediaPathList.Get(2)) then begin
                    Clear(EVOAMCEntry);
                    Clear(TempBlob);
                    FileName := MediaPathList.Get(MediaPathList.Count);
                    FileName := FileName.Substring(FileName.IndexOf('_') + 1);
                    if not FileManagement.HasExtension(FileName) then
                        FileName := FileName + '.jpg';

                    TempBlob.CreateOutStream(TargetOutStream);
                    DataCompression.ExtractEntry(MediaPath, TargetOutStream);
                    if not CreateMedia(TableNo, RelatedSystemId, FileName, EVOAMCEntry, TempBlob, ReturnMessage) then begin
                        TotalFailureCount += 1;
                        TotalFailureMessage += StrSubstNo(FileFailedUploadTxt, FileName, ReturnMessage);
                    end;
                end else
                    TotalSkippedCount += 1;
            end else
                TotalSkippedCount += 1;
        end;
        DataCompression.CloseZipArchive();
        if (TotalFailureCount = 0) and (TotalSkippedCount = 0) then
            Message(RestoreCompletedSuccMsg)
        else
            Message(StrSubstNo(ResultsMsgDialogTxt, TotalFailureCount, TotalCount, TotalSkippedCount, TotalFailureMessage));
    end;

    procedure ExportZip(var EVOAMCEntry: Record EVO_AMC_Entry; ZipFileName: Text)
    var
        DataCompression: Codeunit "Data Compression";
        TempBlob: Codeunit "Temp Blob";
        SourceInStream: InStream;
        TargetOutStream: OutStream;
    begin
        if not EVOAMCEntry.FindSet() then
            exit;

        if ZipFileName = '' then
            ZipFileName := StrSubstNo(ZipFileNameLbl, CurrentDateTime())
        else
            if not FileManagement.HasExtension(ZipFileName) then
                ZipFileName += '.zip'
            else
                if FileManagement.GetExtension(ZipFileName) <> 'zip' then
                    ZipFileName += '.zip';

        ZipFileName := FileManagement.StripNotsupportChrInFileName(ZipFileName);
        DataCompression.CreateZipArchive();
        repeat
            if (EVOAMCEntry.EVO_AMC_Type in [EVOAMCEntry.EVO_AMC_Type::EVO_AMC_Picture, EVOAMCEntry.EVO_AMC_Type::EVO_AMC_Video]) and (EVOAMCEntry.EVO_AMC_Filename <> '') then begin
                Clear(TempBlob);
                if EVOAMCEntry.GetMedia(TempBlob) then
                    if TempBlob.HasValue() then begin
                        TempBlob.CreateInStream(SourceInStream);
                        DataCompression.AddEntry(SourceInStream, StrSubstNo(FileEntryLbl, EVOAMCEntry.EVO_AMC_TableNo, EVOAMCEntry.EVO_AMC_RelatedSystemId, EVOAMCEntry.EVO_AMC_EntryNo, EVOAMCEntry.EVO_AMC_Filename));
                    end;
            end;
        until EVOAMCEntry.Next() = 0;

        Clear(TempBlob);
        TempBlob.CreateOutStream(TargetOutStream);
        DataCompression.SaveZipArchive(TargetOutStream);
        FileManagement.BLOBExport(TempBlob, ZipFileName, true);
        DataCompression.CloseZipArchive();
    end;

    procedure ExportZip(var EVOAMCEntry: Record EVO_AMC_Entry)
    begin
        ExportZip(EVOAMCEntry, '');
    end;

    procedure ExportThumbnailZip(var EVOAMCEntry: Record EVO_AMC_Entry; ZipFileName: Text)
    var
        DataCompression: Codeunit "Data Compression";
        TempBlob: Codeunit "Temp Blob";
        SourceInStream: InStream;
        TargetOutStream: OutStream;
    begin
        if not EVOAMCEntry.FindSet() then
            exit;

        if ZipFileName = '' then
            ZipFileName := StrSubstNo(ZipFileNameLbl, CurrentDateTime())
        else
            if not FileManagement.HasExtension(ZipFileName) then
                ZipFileName += '.zip'
            else
                if FileManagement.GetExtension(ZipFileName) <> 'zip' then
                    ZipFileName += '.zip';

        ZipFileName := FileManagement.StripNotsupportChrInFileName(ZipFileName);
        DataCompression.CreateZipArchive();
        repeat
            if (EVOAMCEntry.EVO_AMC_Size > 0) and (EVOAMCEntry.EVO_AMC_Type in [EVOAMCEntry.EVO_AMC_Type::EVO_AMC_Picture, EVOAMCEntry.EVO_AMC_Type::EVO_AMC_Video]) and (EVOAMCEntry.EVO_AMC_Filename <> '') then begin
                Clear(TempBlob);
                if EVOAMCEntry.GetThumbnail(TempBlob) then
                    if TempBlob.HasValue() then begin
                        TempBlob.CreateInStream(SourceInStream);
                        DataCompression.AddEntry(SourceInStream, StrSubstNo(FileEntryLbl, EVOAMCEntry.EVO_AMC_TableNo, EVOAMCEntry.EVO_AMC_RelatedSystemId, EVOAMCEntry.EVO_AMC_EntryNo, EVOAMCEntry.EVO_AMC_Filename));
                    end;
            end;
        until EVOAMCEntry.Next() = 0;

        Clear(TempBlob);
        TempBlob.CreateOutStream(TargetOutStream);
        DataCompression.SaveZipArchive(TargetOutStream);
        FileManagement.BLOBExport(TempBlob, ZipFileName, true);
        DataCompression.CloseZipArchive();
    end;

    procedure ExportThumbnailZip(var EVOAMCEntry: Record EVO_AMC_Entry)
    begin
        ExportThumbnailZip(EVOAMCEntry, '');
    end;

    procedure GetMain(TableNo: Integer; RelatedSystemId: Guid; var EVOAMCEntry: Record EVO_AMC_Entry): Boolean
    begin
        EVOAMCEntry.Reset();
        EVOAMCEntry.SetCurrentKey(EVO_AMC_TableNo, EVO_AMC_RelatedSystemId, EVO_AMC_SortNo, EVO_AMC_Sensitive, EVO_AMC_ExpiresAt);
        EVOAMCEntry.SetAscending(EVO_AMC_SortNo, true);
        EVOAMCEntry.SetRange(EVO_AMC_TableNo, TableNo);
        EVOAMCEntry.SetRange(EVO_AMC_RelatedSystemId, RelatedSystemId);
        if EVOAMCEntry.IsEmpty then
            exit;

        exit(EVOAMCEntry.FindFirst());
    end;

    procedure GetMainEntryNo(TableNo: Integer; RelatedSystemId: Guid): Integer
    var
        EVOAMCEntry: Record EVO_AMC_Entry;
    begin
        if GetMain(TableNo, RelatedSystemId, EVOAMCEntry) then
            exit(EVOAMCEntry.EVO_AMC_EntryNo);
    end;

    [Obsolete('Use interface directly. Interface := Enum')]
    procedure GetProvider(StorageType: Enum EVO_AMC_StorageType; var EVOAMCIMediaProvider: Interface EVO_AMC_IMediaProvider)
    begin
        EVOAMCIMediaProvider := StorageType;
    end;

    procedure GetStorageType(TableNo: Integer): Enum EVO_AMC_StorageType
    var
        EVOAMCStorageMapping: Record EVO_AMC_StorageMapping;
    begin
        if EVOAMCStorageMapping.Get(TableNo) then
            exit(EVOAMCStorageMapping.EVO_AMC_StorageType)
        else begin
            EVOAMCSetup.EVO_AMC_GetRecordOnce();
            exit(EVOAMCSetup.EVO_AMC_StorageType);
        end;
    end;

    procedure GetOptions(TableNo: Integer; var TempEVOAMCSetup: Record EVO_AMC_Setup temporary)
    var
        EVOAMCStorageMapping: Record EVO_AMC_StorageMapping;
    begin
        EVOAMCSetup.EVO_AMC_GetRecordOnce();
        TempEVOAMCSetup.TransferFields(EVOAMCSetup, false);
        if EVOAMCStorageMapping.Get(TableNo) then
            TempEVOAMCSetup.TransferFields(EVOAMCStorageMapping, false);

        OnAfterGetOptions(TableNo, TempEVOAMCSetup);
    end;

    procedure GetWebMedia(Url: Text; var TempBlob: Codeunit "Temp Blob"): Boolean
    var
        HttpClient: HttpClient;
        HttpResponseMessage: HttpResponseMessage;
        SourceInStream: InStream;
        TargetOutStream: OutStream;
    begin
        if not HttpClient.Get(Url, HttpResponseMessage) then
            exit;

        if not HttpResponseMessage.Content.ReadAs(SourceInStream) then
            exit;

        TempBlob.CreateOutStream(TargetOutStream);
        CopyStream(TargetOutStream, SourceInStream);
        exit(TempBlob.HasValue());
    end;

    procedure GetUploadFilter(): Text
    var
        UploadFilter: Text;
        Extension: Text;
        ExtensionList: List of [Text];
        Loop: Integer;
        UploadFilterCommaLbl: Label '*.%1,', Comment = '%1 = File Extension', Locked = true;
        UploadFilterSemiColonLbl: Label '*.%1;', Comment = '%1 = File Extension', Locked = true;
    begin
        UploadFilter := 'Image Files (';
        AcceptedFileExtensions(ExtensionList);
        for Loop := 1 to ExtensionList.Count do begin
            ExtensionList.Get(Loop, Extension);
            UploadFilter += StrSubstNo(UploadFilterCommaLbl, Extension);
        end;
        UploadFilter := CopyStr(UploadFilter, 1, StrLen(UploadFilter) - 1) + ')|';
        for Loop := 1 to ExtensionList.Count do begin
            ExtensionList.Get(Loop, Extension);
            UploadFilter += StrSubstNo(UploadFilterSemiColonLbl, Extension);
        end;
        UploadFilter := CopyStr(UploadFilter, 1, StrLen(UploadFilter) - 1);
        exit(UploadFilter);
    end;

    procedure ScaleToThumbnail(var SourceTempBlob: Codeunit "Temp Blob"; var TargetTempBlob: Codeunit "Temp Blob"; TargetWidth: Integer; TargetHeight: Integer; TargetQuality: Integer; ExifOrientation: Integer)
    var
        ImageHandlerManagement: Codeunit "Image Handler Management";
        ScaledTempBlob: Codeunit "Temp Blob";
        SourceInStream: InStream;
        SourceWidth: Integer;
        SourceHeight: Integer;
        TargetOutStream: OutStream;
    begin
        Clear(TargetTempBlob);
        if not SourceTempBlob.HasValue() then
            exit;

        Clear(ImageHandlerManagement);
        SourceTempBlob.CreateInStream(SourceInStream);
        if ImageHandlerManagement.GetImageSize(SourceInStream, SourceWidth, SourceHeight) then begin
            if TargetWidth > SourceWidth then //Force it to run through the resize routine so this factors in quality.
                TargetWidth := SourceWidth - 1;

            if TargetHeight > SourceHeight then
                TargetHeight := SourceHeight - 1;
        end;

        ImageHandlerManagement.SetQuality(TargetQuality);
        ScaledTempBlob.CreateOutStream(TargetOutStream);
        if ImageHandlerManagement.ScaleDown(SourceInStream, TargetOutStream, TargetWidth, TargetHeight) then
            if SourceTempBlob.Length() > ScaledTempBlob.Length() then begin
                if ExifOrientation <> 0 then
                    TryRotateToExif(ScaledTempBlob, ExifOrientation);

                TargetTempBlob := ScaledTempBlob;
            end else
                TargetTempBlob := SourceTempBlob;
    end;

    procedure ScaleToThumbnail(var SourceTempBlob: Codeunit "Temp Blob"; var TargetTempBlob: Codeunit "Temp Blob"; TargetWidth: Integer; TargetHeight: Integer; TargetQuality: Integer)
    begin
        ScaleToThumbnail(SourceTempBlob, TargetTempBlob, TargetWidth, TargetHeight, TargetQuality, 0);
    end;

    procedure ScaleToThumbnail(var SourceTempBlob: Codeunit "Temp Blob"; var TargetTempBlob: Codeunit "Temp Blob"; TableNo: Integer)
    begin
        ScaleToThumbnail(SourceTempBlob, TargetTempBlob, TableNo, 0);
    end;

    procedure ScaleToThumbnail(var SourceTempBlob: Codeunit "Temp Blob"; var TargetTempBlob: Codeunit "Temp Blob"; TableNo: Integer; ExifOrientation: Integer)
    var
        TempEVOAMCSetup: Record EVO_AMC_Setup temporary;
    begin
        GetOptions(TableNo, TempEVOAMCSetup);
        ScaleToThumbnail(SourceTempBlob, TargetTempBlob, TempEVOAMCSetup.EVO_AMC_ThumbnailWidth, TempEVOAMCSetup.EVO_AMC_ThumbnailHeight, TempEVOAMCSetup.EVO_AMC_ThumbnailQuality, ExifOrientation);
    end;

    procedure InputUrl(): Text
    var
        EVOAMCEnterUrl: Page EVO_AMC_EnterUrl;
    begin
        if EVOAMCEnterUrl.RunModal() = Action::OK then
            exit(EVOAMCEnterUrl.GetUrl());
    end;

    procedure RequireThumbnailStorage(var EVOAMCEntry: Record EVO_AMC_Entry; var TempEVOAMCSetup: Record EVO_AMC_Setup temporary): Boolean
    var
        Required: Boolean;
        IsHandled: Boolean;
    begin
        OnRequireThumbnailStorage(EVOAMCEntry, Required, IsHandled);
        if IsHandled then
            exit(Required);

        Required := EVOAMCEntry.EVO_AMC_Type = EVOAMCEntry.EVO_AMC_Type::EVO_AMC_Picture;
        if Required then
            Required := EVOAMCSetup.EVO_AMC_StorageType <> EVOAMCSetup.EVO_AMC_StorageType::EVO_AMC_Database;

        OnAfterRequireThumbnailStorage(EVOAMCEntry, TempEVOAMCSetup, Required);
        exit(Required);
    end;

    procedure GetType(PublicUrl: Text; Name: Text) MediaType: Enum EVO_AMC_MediaType
    begin
        if FileManagement.HasExtension(Name) then
            case LowerCase(FileManagement.GetExtension(Name)) of
                'jpg',
                'jpeg',
                'jpe',
                'jfif',
                'png',
                'gif',
                'webp',
                'bmp':
                    MediaType := MediaType::EVO_AMC_Picture;
                'mp4',
                'avi',
                'mov',
                'mv4',
                'mkv',
                'wmv':
                    MediaType := MediaType::EVO_AMC_Video;
                else
                    MediaType := MediaType::EVO_AMC_AllMedia;
            end;

        PublicUrl := LowerCase(PublicUrl);
        if (PublicUrl <> '') and (MediaType = MediaType::EVO_AMC_AllMedia) then
            if GenerateEmbedUrl(PublicUrl) <> '' then
                MediaType := MediaType::EVO_AMC_Video;

        OnAfterGetType(PublicUrl, Name, MediaType);
    end;

    procedure GetMediaType(PublicUrl: Text; Name: Text) MediaType: Enum "Media Type"
    begin
        if FileManagement.HasExtension(Name) then
            case LowerCase(FileManagement.GetExtension(Name)) of
                'jpg',
                'jpeg',
                'jpe',
                'jfif',
                'png',
                'gif',
                'bmp':
                    MediaType := MediaType::Picture;
                'mp4',
                'avi':
                    MediaType := MediaType::Video;
                else
                    MediaType := MediaType::"All Media";
            end;

        PublicUrl := LowerCase(PublicUrl);
        if (PublicUrl <> '') and (MediaType = MediaType::"All Media") then
            case true of
                PublicUrl.Contains('youtu.be'),
                PublicUrl.Contains('youtube.com'),
                PublicUrl.Contains('vimeo.com'),
                PublicUrl.Contains('dailymotion.com'):
                    MediaType := MediaType::Video;
            end;

        OnAfterGetMediaType(PublicUrl, Name, MediaType);
    end;

    [Obsolete('This procedure is temporary and will be removed when the obsolete OnAfterGetMediaType event is removed.', '26.0')]
    internal procedure OnAfterGetMediaTypeWrapper(PublicUrl: Text; FileName: Text; var MediaType: Enum EVO_AMC_MediaType)
    var
        StandardMediaType: Enum "Media Type";
    begin
        Case MediaType of
            Enum::EVO_AMC_MediaType::EVO_AMC_Picture:
                StandardMediaType := Enum::"Media Type"::Picture;
            Enum::EVO_AMC_MediaType::EVO_AMC_Video:
                StandardMediaType := Enum::"Media Type"::"Video";
            else
                StandardMediaType := Enum::"Media Type"::"All Media";
        End;

        OnAfterGetMediaType(PublicUrl, FileName, StandardMediaType);
    end;

    procedure AcceptedFileExtensions(var ExtensionList: List of [Text])
    begin
        ExtensionList.Add('jpg');
        ExtensionList.Add('jpeg');
        ExtensionList.Add('jpe');
        ExtensionList.Add('jfif');
        ExtensionList.Add('png');
        ExtensionList.Add('gif');
        ExtensionList.Add('webp');
        ExtensionList.Add('bmp');
        ExtensionList.Add('mp4');
        ExtensionList.Add('avi');
        ExtensionList.Add('zip');
        ExtensionList.Add('m4v');
        ExtensionList.Add('mov');
        ExtensionList.Add('mkv');
        ExtensionList.Add('wmv');
        OnAfterGetAcceptedFileExtensions(ExtensionList);
    end;

    [Obsolete('Removed as it''s been made redundant. Please use TryGetImageType(var Record EVO_AMC_Entry; var Codeunit "Temp Blob"; var Result: Text)', '26.0')]
    procedure TryGetImageType(var TempBlob: Codeunit "Temp Blob"; var Result: Text): Boolean
    var
        ImageHelpers: Codeunit "Image Helpers";
        SourceInStream: InStream;
    begin
        TempBlob.CreateInStream(SourceInStream);
        Result := ImageHelpers.GetImageType(SourceInStream);

        exit(Result <> '');
    end;

    // procedure TryGetImageType(var EVOAMCEntry: Record EVO_AMC_Entry; var SourceTempBlob: Codeunit "Temp Blob"; var Result: Text): Boolean
    // begin
    //     Clear(Result);
    //     if not TryGetImageTypeFromBlob(SourceTempBlob, Result) then
    //         Result := CopyStr(LowerCase(FileManagement.GetExtension(EVOAMCEntry.EVO_AMC_Filename)), 1, MaxStrLen(EVOAMCEntry.EVO_AMC_HtmlFormatType));

    //     exit(Result <> '');
    // end;

    [TryFunction]
    procedure TryGetImageTypeFromBlob(var SourceTempBlob: Codeunit "Temp Blob"; var Result: Text)
    var
        ImageHelpers: Codeunit "Image Helpers";
        SourceInStream: InStream;
    begin
        SourceTempBlob.CreateInStream(SourceInStream);
        Result := LowerCase(ImageHelpers.GetImageType(SourceInStream));
    end;

    procedure GenerateEmbedUrl(WebsiteUrl: Text): Text
    var
        LowercaseUrl: Text;
        Result: Text;
        YoutubeUrlLbl: Label 'youtube', Locked = true;
        VimeoUrlLbl: Label 'vimeo', Locked = true;
        DailyMotionUrlLbl: Label 'dailymotion', Locked = true;
    begin
        LowercaseUrl := WebsiteUrl.ToLower();
        case true of
            (LowercaseUrl.Contains(VimeoUrlLbl)):
                Result := GenerateVimeoEmbedUrl(WebsiteUrl);
            (LowercaseUrl.Contains(YoutubeUrlLbl)) or (LowercaseUrl.Contains('youtu.be')):
                Result := GenerateYoutubeEmbedUrl(WebsiteUrl);
            (LowercaseUrl.Contains(DailyMotionUrlLbl)):
                Result := GenerateDailyMotionEmbedUrl(WebsiteUrl);
        end;

        OnGenerateEmbedUrl(WebsiteUrl, Result);
        exit(Result);
    end;

    procedure CameraTakePhoto(var TempBlobList: Codeunit "Temp Blob List"): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        Camera: Page Camera;
        EVOAMCCamera: Page EVO_AMC_Camera;
        EVOAMCMobileCamera: Page EVO_AMC_MobileCamera;
        UseCustomCamera: Boolean;
        IsHandled: Boolean;
    begin
        OnBeforeCameraTakePhoto(TempBlobList, IsHandled);
        if IsHandled then
            exit(TempBlobList.Count() > 0);

        Clear(UseCustomCamera);
        Clear(TempBlobList);
        EVOAMCSetup.EVO_AMC_GetRecordOnce();

        case CurrentClientType of
            ClientType::Desktop,
            ClientType::Web,
            ClientType::Windows:
                UseCustomCamera := EVOAMCSetup.EVO_AMC_CustomCamera <> EVOAMCSetup.EVO_AMC_CustomCamera::EVO_AMC_Disabled;
            ClientType::Tablet:
                UseCustomCamera := EVOAMCSetup.EVO_AMC_CustomCamera in [EVOAMCSetup.EVO_AMC_CustomCamera::EVO_AMC_WebClientTablet, EVOAMCSetup.EVO_AMC_CustomCamera::EVO_AMC_AllClients];
            ClientType::Phone:
                UseCustomCamera := EVOAMCSetup.EVO_AMC_CustomCamera in [EVOAMCSetup.EVO_AMC_CustomCamera::EVO_AMC_AllClients];
        end;

        if UseCustomCamera then begin
            if CurrentClientType in [ClientType::Phone, ClientType::Tablet] then begin
                Clear(EVOAMCMobileCamera);
                if not EVOAMCMobileCamera.RunWithResult() then
                    exit;

                TempBlobList := EVOAMCMobileCamera.GetBlobList();
            end else begin
                Clear(EVOAMCCamera);
                if not EVOAMCCamera.RunWithResult() then
                    exit;

                TempBlobList := EVOAMCCamera.GetBlobList();
            end;
        end else begin
            Clear(Camera);
            if not Camera.IsAvailable() then
                exit;

            Camera.SetAllowEdit(EVOAMCSetup.EVO_AMC_CameraAllowEdit);
            Camera.SetEncodingType(Enum::"Image Encoding"::JPEG);
            Camera.SetQuality(EVOAMCSetup.EVO_AMC_CameraQuality);
            Camera.RunModal();
            if not Camera.HasPicture() then
                exit;

            Camera.GetPicture(TempBlob);
            if TempBlob.HasValue() then
                TempBlobList.Add(TempBlob);
        end;

        exit(TempBlobList.Count() > 0);
    end;

    procedure CameraTakePhotoAndAdd(RelatedTableNo: Integer; RelatedSystemId: Guid; var EVOAMCEntry: Record EVO_AMC_Entry; var ReturnMessage: Text): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        TempBlobList: Codeunit "Temp Blob List";
        PictureFileName: Text;
        Loop: Integer;
    begin
        Clear(ReturnMessage);
        if CameraTakePhoto(TempBlobList) then begin
            for Loop := 1 to TempBlobList.Count() do begin
                Clear(EVOAMCEntry);
                Clear(TempBlob);
                TempBlobList.Get(Loop, TempBlob);
                PictureFileName := Format(CurrentDateTime(), 0, '<Day,2>_<Month,2>_<Year>_<Hours24,2>_<Minutes,2>_<Seconds,2>') + '_' + Format(Loop) + '.jpg';
                if not CreateMedia(RelatedTableNo, RelatedSystemId, PictureFileName, EVOAMCEntry, TempBlob, ReturnMessage) then
                    exit(false);
            end;

            exit(TempBlobList.Count() > 0);
        end else
            ReturnMessage := 'CANCELLED';
    end;

    local procedure GenerateVimeoEmbedUrl(WebsiteUrl: Text): Text
    var
        VimeoEmbedLbl: Label 'https://player.vimeo.com/video/%1', Comment = '%1 = Video ID', Locked = true;
    begin
        if WebsiteUrl.Contains('player.vimeo.com/video/') then
            exit(WebsiteUrl);

        if WebsiteUrl.Contains('?') then
            exit(StrSubstNo(VimeoEmbedLbl, CopyStr(WebsiteUrl, StrPos(WebsiteUrl, 'vimeo.com/') + 10, StrPos(WebsiteUrl, '?'))))
        else
            exit(StrSubstNo(VimeoEmbedLbl, CopyStr(WebsiteUrl, StrPos(WebsiteUrl, 'vimeo.com/') + 10)));
    end;

    local procedure GenerateYoutubeEmbedUrl(WebsiteUrl: Text): Text
    var
        YoutubeEmbedLbl: Label 'https://www.youtube.com/embed/%1', Comment = '%1 = Video ID', Locked = true;
    begin
        if WebsiteUrl.Contains('youtube.com/embed/') then
            exit(WebsiteUrl);

        if not WebsiteUrl.Contains('v=') then
            exit;

        WebsiteUrl := StrSubstNo(YoutubeEmbedLbl, CopyStr(WebsiteUrl, StrPos(WebsiteUrl, 'v=') + 2));
        if WebsiteUrl.Contains('&') then
            WebsiteUrl := CopyStr(WebsiteUrl, 1, StrPos(WebsiteUrl, '&'));

        exit(WebsiteUrl);
    end;

    local procedure GenerateDailyMotionEmbedUrl(WebsiteUrl: Text): Text
    var
        DailyMotionEmbedLbl: Label 'https://dailymotion.com/embed/video/%1', Comment = '%1 = Video ID', Locked = true;
    begin
        if WebsiteUrl.Contains('dailymotion.com/embed/video/') then
            exit(WebsiteUrl);

        if WebsiteUrl.Contains('?') then
            exit(StrSubstNo(DailyMotionEmbedLbl, CopyStr(WebsiteUrl, StrPos(WebsiteUrl, 'video/') + 6, StrPos(WebsiteUrl, '?'))))
        else
            exit(StrSubstNo(DailyMotionEmbedLbl, CopyStr(WebsiteUrl, StrPos(WebsiteUrl, 'video/') + 6)));
    end;

    local procedure CheckUrl(Url: Text; Length: Integer)
    var
        WebRequestHelper: Codeunit "Web Request Helper";
        UrlOverMaxLenErr: Label 'Url must be under %1 characters.', Comment = '%1 = Max Length';
        UrlInvalidErr: Label 'Url %1 is invalid.', Comment = '%1 = Url';
    begin
        if Length > 0 then
            if StrLen(Url) > Length then
                Error(UrlOverMaxLenErr, Length);

        if not WebRequestHelper.IsValidUri(Url) then
            Error(UrlInvalidErr, Url);
    end;

    local procedure GetCode(TableNo: Integer; RelatedSystemId: Guid) ReturnCode: Code[20]
    var
        RecordRef: RecordRef;
        FieldRef: FieldRef;
    begin
        RecordRef.Open(TableNo);
        if not RecordRef.GetBySystemId(RelatedSystemId) then
            exit;

        case TableNo of
            Database::Contact,
            Database::Customer,
            Database::Vendor,
            Database::Item,
            Database::Employee,
            Database::Resource,
            Database::"Salesperson/Purchaser",
            Database::"Fixed Asset":
                begin
                    FieldRef := RecordRef.Field(1);
                    if (FieldRef.Type = FieldType::Code) and (FieldRef.Length < 21) then
                        ReturnCode := RecordRef.Field(1).Value;
                end;
            else
                OnGetCode(TableNo, RelatedSystemId, ReturnCode);
        end;
        RecordRef.Close();
    end;

    [TryFunction]
    local procedure TryGetJpgExifOrientation(var TempBlob: Codeunit "Temp Blob"; var ReturnValue: Integer)
    var
        TypeHelper: Codeunit "Type Helper";
        SourceInStream: InStream;
        TempByte: Byte;
        TempByte2: Byte;
        ExifSize: Integer;
        ExifRead: Integer;
        TempText: Text;
    begin
        Clear(ReturnValue);
        TempBlob.CreateInStream(SourceInStream);
        SourceInStream.Read(TempByte, 1); //FF
        if TempByte <> 255 then
            Error('Expecting hex FF');

        SourceInStream.Read(TempByte, 1); //D8, FFD8 is our jpg magic. These values are constant.
        if TempByte <> 216 then
            Error('Expecting hex D8');

        SourceInStream.Read(TempByte, 1); //FF
        if TempByte <> 255 then
            Error('Expecting hex FF');

        SourceInStream.Read(TempByte, 1); //E0 or E1 FFE0/FFE1 are the precursor bytes to the length of the exif data.
        if not (TempByte in [224, 225]) then
            Error('Expecting hex E0 or E1');

        SourceInStream.Read(TempByte, 1); //Ignore 00 Byte.

        //If any of the above have failed, this isn't a valid jpg with exif data.
        //Read the 16bit value after hex FFE0, this is the total length of the exif data. We cannot pull this into an integer directly due to the fact it's 16 bits - Integers are int32, 32 bits so 4 bytes.
        SourceInStream.Read(TempByte, 1);
        SourceInStream.Read(TempByte2, 1);
        TempText := TypeHelper.IntToHex(TempByte) + TypeHelper.IntToHex(TempByte2); //Take the first byte value & convert it to hex, do the same with the second. 
        ExifSize := HexToInt(DelChr(TempText, '=', 'X')); //We cannot read 16 bits from the stream directly as BC expects atleast 4 bytes for an integer value (32bit). Convert the 16bit hex to a 32 bit integer.

        //Confirmed we're in the exif of a .jpg file. Read until the exif length is reached. We're expecting hex 0112 for Orientation.
        //An example of this would be: 01 12 00 03 00 00 00 01 00 06... 06 being the orientation, from 0-8.
        while (not SourceInStream.EOS) do begin
            ExifRead += SourceInStream.Read(TempByte, 1);
            if (TempByte = 1) then begin //01
                ExifRead += SourceInStream.Read(TempByte, 1);
                if TempByte = 18 then begin //12, corresponds sequentially with the 0112 we're looking for.
                    ExifRead += SourceInStream.Read(TempByte, 1); //This will always be 0.
                    if TempByte = 0 then begin
                        ExifRead += SourceInStream.Read(TempByte, 1);
                        if TempByte = 3 then begin //Data type = short uint16, always 3.
                            ExifRead += SourceInStream.Read(TempByte, 1); //Byte Length Increment.
                            if TempByte = 0 then begin
                                ExifRead += SourceInStream.Read(TempByte, 1); //Byte Length Increment.
                                if TempByte = 0 then begin
                                    ExifRead += SourceInStream.Read(TempByte, 1); //Byte Length Increment.
                                    if TempByte = 0 then begin
                                        ExifRead += SourceInStream.Read(TempByte, 1); //Byte Length Increment.
                                        if TempByte = 1 then begin
                                            ExifRead += SourceInStream.Read(TempByte, 1); //Byte Length Increment.
                                            if TempByte = 0 then begin
                                                ExifRead += SourceInStream.Read(TempByte, 1); //This byte is our integer orientation value.
                                                if (TempByte > -1) and (TempByte < 9) then begin //Additional validation. Value can only be between 0-8.
                                                    ReturnValue := TempByte;
                                                    if ReturnValue <> 0 then
                                                        exit;
                                                end;
                                            end;
                                        end;
                                    end;
                                end;
                            end;
                        end;
                    end;
                end;
            end;

            if ExifRead >= ExifSize then
                Error('Exif header read is more than the exif size.');
        end;
    end;

    [TryFunction]
    procedure TryRotateToExif(var SourceTempBlob: Codeunit "Temp Blob"; ExifOrientation: Integer)
    var
        Image: Codeunit Image;
        TargetOutStream: OutStream;
        SourceInStream: InStream;
        RotateFlipType: Enum "Rotate Flip Type";
        RotateMaxErr: Label 'Unable to rotate the image as the size is too large. Size: %1, Maximum: 5000000', Comment = '%1=Length';
    begin
        if SourceTempBlob.Length() > 5000000 then //Maximum - See ImageImpl for details (ImageTooLargeErr).
            Error(RotateMaxErr, SourceTempBlob.Length());

        case ExifOrientation of
            1:
                RotateFlipType := RotateFlipType::RotateNoneFlipNone;
            2:
                RotateFlipType := RotateFlipType::RotateNoneFlipX;
            3:
                RotateFlipType := RotateFlipType::Rotate180FlipNone;
            4:
                RotateFlipType := RotateFlipType::Rotate180FlipX;
            5:
                RotateFlipType := RotateFlipType::Rotate90FlipX;
            6:
                RotateFlipType := RotateFlipType::Rotate90FlipNone;
            7:
                RotateFlipType := RotateFlipType::Rotate270FlipX;
            8:
                RotateFlipType := RotateFlipType::Rotate270FlipNone;
            else
                exit;
        end;

        SourceTempBlob.CreateInStream(SourceInStream);
        Image.FromStream(SourceInStream);
        Image.RotateFlip(RotateFlipType);

        Clear(SourceTempBlob);
        SourceTempBlob.CreateOutStream(TargetOutStream);
        Image.Save(TargetOutStream);
    end;

    local procedure CalculateMD5Hash(var SourceInStream: InStream): Text[32]
    var
        CryptographyManagement: Codeunit "Cryptography Management";
    begin
        exit(CopyStr(CryptographyManagement.GenerateHash(SourceInStream, 0), 1, 32));
    end;


    local procedure HexToInt(hexStr: Text): Integer
    var
        len, base, decVal, i, j : Integer;
    begin
        base := 1;
        decVal := 0;
        len := StrLen(hexStr);
        for i := 0 to len - 1 do begin
            j := len - i;
            if (hexStr[j] >= '0') and (hexStr[j] <= '9') then begin
                decVal += (hexStr[j] - 48) * base;
                base := base * 16;
            end else
                if (hexStr[j] >= 'A') and (hexStr[j] <= 'F') then begin
                    decVal += (hexStr[j] - 55) * base;
                    base := base * 16;
                end;
        end;

        exit(decVal);
    end;

    [BusinessEvent(false)]
    local procedure OnGetCode(TableNo: Integer; RelatedSystemId: Guid; var DocumentNo: Code[20])
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnGenerateEmbedUrl(WebsiteUrl: Text; var Result: Text)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeImportMedia(TableNo: integer; RelatedSystemId: Guid; var MediaEntry: Record EVO_AMC_Entry; var ReturnMessage: Text; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterRequireThumbnailStorage(var MediaEntry: Record EVO_AMC_Entry; var TempMediaSetup: Record EVO_AMC_Setup temporary; var Required: Boolean)
    begin
    end;

    [Obsolete('Use OnAfterGetType instead.', '26.0')]
    [BusinessEvent(false)]
    local procedure OnAfterGetMediaType(PublicUrl: Text; FileName: Text; var MediaType: Enum "Media Type")
    begin
    end;

    [BusinessEvent(false)]
    local procedure OnAfterGetType(PublicUrl: Text; FileName: Text; var MediaType: Enum EVO_AMC_MediaType)
    begin
    end;

    [BusinessEvent(false)]
    local procedure OnBeforeCreateMedia(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; var MediaEntry: Record EVO_AMC_Entry; var TempMediaSetup: Record EVO_AMC_Setup; var SourceTempBlob: Codeunit "Temp Blob"; var Result: Boolean; var ReturnMessage: Text; var IsHandled: Boolean)
    begin
    end;

    [BusinessEvent(false)]
    local procedure OnBeforeCreateMediaFromZip(TableNo: Integer; RelatedSystemId: Guid; FileName: Text; var TempMediaSetup: Record EVO_AMC_Setup temporary; var SourceTempBlob: Codeunit "Temp Blob"; FileList: List of [Text]; var DataCompression: Codeunit "Data Compression"; var ReturnMessage: Text; var IsHandled: Boolean)
    begin
    end;

    [BusinessEvent(false)]
    local procedure OnBeforeUpdateMedia(var MediaEntry: Record EVO_AMC_Entry; var ReturnMessage: Text; var Result: Boolean; var IsHandled: Boolean)
    begin
    end;

    [BusinessEvent(false)]
    local procedure OnAfterCreateMedia(var MediaEntry: Record EVO_AMC_Entry; var SourceTempBlob: Codeunit "Temp Blob"; var Result: Boolean; var ReturnMessage: Text)
    begin
    end;

    [BusinessEvent(false)]
    local procedure OnAfterUpdateMedia(var MediaEntry: Record EVO_AMC_Entry; var SourceTempBlob: Codeunit "Temp Blob"; var ReturnMessage: Text)
    begin
    end;

    [BusinessEvent(false)]
    local procedure OnAfterGetAcceptedFileExtensions(var ExtensionList: List of [Text])
    begin
    end;

    [BusinessEvent(false)]
    local procedure OnAfterGetOptions(TableNo: Integer; var TempMediaSetup: Record EVO_AMC_Setup temporary)
    begin
    end;

    [BusinessEvent(false)]
    local procedure OnBeforeBackupMediaToZip(var IsHandled: Boolean)
    begin
    end;

    [BusinessEvent(false)]
    local procedure OnBeforeRestoreMediaFromZip(var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCameraTakePhoto(var TempBlobList: Codeunit "Temp Blob List"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(true, false)]
    local procedure OnRequireThumbnailStorage(var EVOAMCEntry: Record EVO_AMC_Entry; var Required: Boolean; var IsHandled: Boolean)
    begin
    end;

    var
        EVOAMCSetup: Record EVO_AMC_Setup;
        FileManagement: Codeunit "File Management";
        ZipFileNameLbl: Label 'Media Export %1.zip', Comment = '%1 = Current Date & Time';
        FileEntryLbl: Label '%1\%2\%3_%4', Comment = '%1 = Table No., %2 = Related System ID, %3 = Entry No., %4 = Filename', Locked = true;
}
