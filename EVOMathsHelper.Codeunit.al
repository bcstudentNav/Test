codeunit 80000 EVO_MathsHelper
{
    Subtype = Test;

    var
        Assert: Codeunit Assert;
        ExpectedResult: Decimal;
        ActualResult: Decimal;

        AssertTextErr: Label '%1 in Maths Helper should be equal : expected %2   actual %3', Comment = '%1 label, %2 result, %3 expected';

    [Test]
    procedure CalculateMarginAmount()
    var
        MathsHelper: Codeunit EVO_EFL_MathsHelper;
        Revenue: Decimal;
        CostOfGoods: Decimal;
    begin
        // Ensure CalculateMarginAmount function is operating correctly.

        // Having a revenue figure of 77
        Revenue := 77;

        // Having a Cost Of Goods figure of 23
        CostOfGoods := 23;

        // Precalculated result should be 54
        ExpectedResult := 54;

        // When CalculateMarginAmount is executed
        ActualResult := MathsHelper.CalculateMarginAmount(Revenue, CostOfGoods);
        Assert.AreEqual(ExpectedResult, ActualResult, StrSubstNo(AssertTextErr, 'CalculateMarginAmount', ExpectedResult, ActualResult));
    end;


    [Test]
    procedure CalculateMarginPct()
    var
        MathsHelper: Codeunit EVO_EFL_MathsHelper;
        Revenue: Decimal;
        CostOfGoods: Decimal;
    begin
        // Ensure CalculateMarginPct() function is operating correctly.

        // Having a revenue figure of 77
        Revenue := 77;

        // Having a Cost Of Goods figure of 23
        CostOfGoods := 23;

        // Precalculated result should be around
        ExpectedResult := 70;

        // When CalculateMarginAmount is executed
        ActualResult := MathsHelper.CalculateMarginPct(Revenue, CostOfGoods);
        Assert.AreNearlyEqual(ExpectedResult, ActualResult, 1, StrSubstNo(AssertTextErr, 'CalculateMarginPct', ExpectedResult, ActualResult));
    end;


    [Test]
    procedure CalculateMarkUpPct()
    var
        MathsHelper: Codeunit EVO_EFL_MathsHelper;
        Revenue: Decimal;
        CostOfGoods: Decimal;
    begin
        // Ensure CalculateMarkUpPct() function is operating correctly.

        // Having a revenue figure of 77
        Revenue := 77;

        // Having a Cost Of Goods figure of 23
        CostOfGoods := 23;

        // Precalculated result should be 54
        ExpectedResult := 234;

        // When CalculateMarginAmount is executed
        ActualResult := MathsHelper.CalculateMarkUpPct(Revenue, CostOfGoods);
        Assert.AreNearlyEqual(ExpectedResult, ActualResult, 1, StrSubstNo(AssertTextErr, 'CalculateMarkUpPct', ExpectedResult, ActualResult));
    end;



    [Test]
    procedure CalculatePriceFromMargin()
    var
        MathsHelper: Codeunit EVO_EFL_MathsHelper;
        RequiredMargin: Decimal;
        CostOfGoods: Decimal;
    begin
        // Ensure CalculatePriceFromMargin() function is operating correctly.

        // Having a Cost Of Goods figure of 23
        CostOfGoods := 23;

        // Having a required margin of 70%
        RequiredMargin := 70;

        // Precalculated result should be 77
        ExpectedResult := 77;

        // When CalculateMarginAmount is executed
        ActualResult := MathsHelper.CalculatePriceFromMargin(CostOfGoods, RequiredMargin);
        Assert.AreNearlyEqual(ExpectedResult, ActualResult, 1, StrSubstNo(AssertTextErr, 'CalculatePriceFromMargin', ExpectedResult, ActualResult));
    end;



}