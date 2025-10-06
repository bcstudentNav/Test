codeunit 71129779 EVO_DAT_DVConditionHelper
{
    procedure CheckFieldAgainstCondition(var SourceFieldRef: FieldRef; ValidationCondition: Enum EVO_DAT_ConditionType; ValidationValue: Variant): Boolean
    var
    begin
        case ValidationCondition of
            ValidationCondition::MustBeEntered:
                exit(FieldMustBeEntered(SourceFieldRef));
            ValidationCondition::MustNotBeEntered:
                exit(FieldMustNotBeEntered(SourceFieldRef));
            ValidationCondition::MustBeSpecificValue:
                exit(FieldMustBeSpecificValue(SourceFieldRef, ValidationValue));
            ValidationCondition::MustMatchAFilter:
                exit(FieldMustMatchAFilter(SourceFieldRef, ValidationValue));
            ValidationCondition::MustMatchAMask:
                exit(FieldMustMatchAMask(SourceFieldRef, ValidationValue));
            ValidationCondition::MustBeACertainLength:
                exit(FieldMustBeACertainLength(SourceFieldRef, ValidationValue));
            ValidationCondition::MustContainTheseCharacters:
                exit(FieldMustContainCertainCharacters(SourceFieldRef, ValidationValue));
        end;
    end;

    procedure FieldMustBeEntered(var SourceFieldRef: FieldRef): Boolean
    var
        SourceFieldValue: Variant;
    begin
        // the only exception for this is with integer, decimal and option values where they are not blank
        // to start with as their default values are 0, which is a valid number!
        SourceFieldValue := SourceFieldRef.Value();
        exit(format(SourceFieldValue) <> '');
    end;

    procedure FieldMustNotBeEntered(var SourceFieldRef: FieldRef): Boolean
    var
        SourceFieldValue: Variant;
    begin
        SourceFieldValue := SourceFieldRef.Value();
        exit(format(SourceFieldValue) = '');
    end;

    procedure FieldMustBeSpecificValue(var SourceFieldRef: FieldRef; ValidationValue: Variant): Boolean
    var
        TypeHelper: Codeunit "Type Helper";
        EVODATTypeHelper: Codeunit EVO_DAT_TypeHelper;
        TempRecordRef: RecordRef;
        TempRecordRef2: RecordRef;
        TempRecordRef3: RecordRef;
        TempFieldRef: FieldRef;
        TempFieldRef2: FieldRef;

        TempDate: Date;
        TempDateTime: DateTime;
        TempDecimal: Decimal;
        TempInteger: Integer;
    begin
        // this is a bit of faf code, but it is the only way to create a none linked version of the same field.
        // without doing this, if you change value of either record ref it affects the other.
        // essentially it opens two temporary record references pointing at the same table and same field
        TempRecordRef3 := SourceFieldRef.Record();
        TempRecordRef.Open(TempRecordRef3.Number(), true);
        TempRecordRef2.Open(TempRecordRef3.Number(), true);

        TempFieldRef := TempRecordRef.Field(SourceFieldRef.Number());
        TempFieldRef2 := TempRecordRef2.Field(SourceFieldRef.Number());

        TempFieldRef.Value := SourceFieldRef.Value();

        case TempFieldRef2.Type of
            TempFieldRef2.Type::Date:
                begin
                    if not Evaluate(TempDate, ValidationValue) then
                        TempDate := 0D;
                    TempFieldRef2.Value := TempDate;
                end;
            TempFieldRef2.Type::DateTime:
                begin
                    if not Evaluate(TempDateTime, ValidationValue) then
                        TempDateTime := 0DT;
                    TempFieldRef2.Value := TempDate;
                end;
            TempFieldRef2.Type::Decimal:
                begin
                    if not Evaluate(TempDecimal, ValidationValue) then
                        TempDecimal := 0;
                    TempFieldRef2.Value := TempDecimal;
                end;
            TempFieldRef2.Type::Integer:
                begin
                    if not Evaluate(TempInteger, ValidationValue) then
                        TempInteger := 0;
                    TempFieldRef2.Value := TempInteger;
                end;
            TempFieldRef2.Type::Boolean:
                TempFieldRef2.Value := EVODATTypeHelper.EvaluateBoolean(ValidationValue);
            TempFieldRef2.Type::Option:
                TempFieldRef2.Value := TypeHelper.GetOptionNoFromTableField(ValidationValue, TempRecordRef2.Number(), TempFieldRef2.Number());
            else
                TempfieldRef2.Value := ValidationValue;
        end;

        exit(TempFieldRef.Value() = TempFieldRef2.Value());
    end;

    procedure FieldMustMatchAFilter(var SourceFieldRef: FieldRef; ValidationValue: Variant): Boolean
    var
        FieldRec: Record Field;

        SourceRecordRef: RecordRef;
        TempRecordRef2: RecordRef;
        TempFieldRef: FieldRef;
        TempFieldRef2: FieldRef;
    begin

        SourceRecordRef := SourceFieldRef.Record();                       // create a reference to the table the field belongs to
        TempRecordRef2.Open(SourceRecordRef.Number(), true);              // open a temporary instance of the table

        // we now need to replicate all the data into the temporary version of the record
        FieldRec.Reset();
        FieldRec.SetRange(TableNo, SourceRecordRef.Number());
        FieldRec.SetRange(Enabled, TRUE);
        FieldRec.SetRange(Class, FieldRec.Class::Normal);
        FieldRec.SetFilter(Type, '<>%1', FieldRec.Type::BLOB);
        FieldRec.SetFilter(ObsoleteState, '<>%1', FieldRec.ObsoleteState::Removed);
        if FieldRec.FindSet() then
            repeat
                TempFieldRef := SourceRecordRef.Field(FieldRec."No.");
                TempFieldRef2 := TempRecordRef2.Field(FieldRec."No.");
                TempFieldRef2.Value := TempFieldRef.Value();
            until FieldRec.next() = 0;
        TempRecordRef2.Insert();

        // we now have a temporary version of the record we are adding, so can add filters to it
        TempRecordRef2.SetRecFilter();                                  // make sure we are only filtering this single record
        TempFieldRef2 := TempRecordRef2.Field(SourceFieldRef.Number()); // get the field we are checking
        TempFieldRef2.SetFilter(ValidationValue);                       // apply the ValidationValue as the filter string
        exit(TempRecordRef2.Count() = 1);
    end;

    procedure FieldMustMatchAMask(var SourceFieldRef: FieldRef; ValidationValue: Variant): Boolean
    var
        SourceFieldValue: Text;
        ValidationMask: Text;
        StringLoop: Integer;
        SourceChar: Char;
        MaskChar: Char;
    begin
        // # = digit (0 to 9)
        // & = character
        // anything outside of the above is a specific character

        SourceFieldValue := Format(SourceFieldRef.Value());
        ValidationMask := Format(ValidationValue);

        if StrLen(SourceFieldValue) <> StrLen(ValidationMask) then
            exit(false);

        for StringLoop := 1 to StrLen(ValidationValue) do begin
            SourceChar := SourceFieldValue[StringLoop];
            MaskChar := ValidationMask[StringLoop];

            case MaskChar of
                '#':
                    if not (SourceChar in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) then
                        exit(false);
                '&':
                    if not (SourceChar in ['A' .. 'Z', 'a' .. 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) then
                        exit(false);
                else
                    if SourceChar <> MaskChar then
                        exit(false);
            end;
        end;
        exit(true);
    end;

    procedure FieldMustBeACertainLength(var SourceFieldRef: FieldRef; ValidationValue: Variant): Boolean
    var
        FieldLength: Integer;
    begin
        If ValidationValue.IsInteger() then
            FieldLength := ValidationValue
        else
            FieldLength := 0;
        exit(StrLen(SourceFieldRef.Value()) = FieldLength);
    end;


    procedure FieldMustContainCertainCharacters(var SourceFieldRef: FieldRef; ValidationValue: Variant): Boolean
    var
        SourceFieldValue: Text;
        CheckCharacters: Text;
        StringLoop: Integer;
    begin
        SourceFieldValue := SourceFieldRef.Value();
        CheckCharacters := Format(ValidationValue);
        for StringLoop := 1 to StrLen(CheckCharacters) do
            if strpos(SourceFieldValue, CheckCharacters[StringLoop]) = 0 then
                exit(false);
        exit(false);
    end;
}