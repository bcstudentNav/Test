namespace TechnologyServicesGroup.IP.BACS;

using System.IO;
pageextension 70300 "BACSData Exch Field Mapping Pa" extends "Data Exch Field Mapping Part"
{
    layout
    {
        addafter(FieldCaptionText)
        {
            field("Use Default Value"; Rec."Use Default Value")
            {
                ApplicationArea = all;
                ToolTip = 'Specifies the value of the Use Default Value';
            }
            field("Default Value"; Rec."Default Value")
            {
                ApplicationArea = all;
                ToolTip = 'Specifies the value of the Default Value';
            }
        }
    }
}

