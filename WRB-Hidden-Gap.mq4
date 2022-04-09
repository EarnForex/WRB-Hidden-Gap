//+------------------------------------------------------------------+
//|                                               WRB-Hidden-Gap.mq4 |
//|                                 Copyright © 2014-2022, EarnForex |
//|                                       https://www.earnforex.com/ |
//|                             Based on the indicator by Akif TOKUZ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2014-2022, EarnForex"
#property link      "https://www.earnforex.com/metatrader-indicators/WRB-Hidden-Gap/"
#property version   "1.02"
#property strict

#property description "Identifies Wide Range Bars and Hidden Gaps."
#property description "WRB and HG definitions are taken from the WRB Analysis Tutorial-1"
#property description "by M.A.Perry from TheStrategyLab.com."

#property indicator_chart_window
#property indicator_buffers 1

#property indicator_color1 clrAqua
#property indicator_type1  DRAW_ARROW
#property indicator_label1 "WRB"

input bool UseWholeBars = false;
input int WRB_LookBackBarCount = 3;
input int WRB_WingDingsSymbol = 115;
input color HGcolor1 = clrDodgerBlue;
input color HGcolor2 = clrBlue;
input ENUM_LINE_STYLE HGstyle = STYLE_SOLID;
input int StartCalculationFromBar = 100;
input bool HollowBoxes = false;
input bool EnableNativeAlerts = false;
input bool EnableEmailAlerts = false;
input bool EnablePushAlerts = false;
input string ObjectPrefix = "HG_";

double WRB[];

int totalBarCount = -1;
bool DoAlerts = false;
string UnfilledPrefix, FilledPrefix;

void OnInit()
{
    IndicatorShortName("WRB+HG");

    SetIndexArrow(0, WRB_WingDingsSymbol);
    SetIndexBuffer(0, WRB);
    
    UnfilledPrefix = ObjectPrefix + "UNFILLED_";
    FilledPrefix = ObjectPrefix + "FILLED_";

    if ((EnableNativeAlerts) || (EnableEmailAlerts) || (EnablePushAlerts)) DoAlerts = true;
}

//+------------------------------------------------------------------+
//| Intersect: Checks whether two bars intersect or not.             |
//| Return codes are unused. 0 - no intersection.                    |
//+------------------------------------------------------------------+
int intersect(double H1, double L1, double H2, double L2)
{
    if ((L1 > H2) || (H1 < L2)) return 0;
    if ((H1 >= H2) && (L1 >= L2)) return 1;
    if ((H1 <= H2) && (L1 <= L2)) return 2;
    if ((H1 >= H2) && (L1 <= L2)) return 3;
    if ((H1 <= H2) && (L1 >= L2)) return 4;
    return 0;
}

//+------------------------------------------------------------------+
//| checkHGFilled: Checks if the hidden gap is filled or not.        |
//+------------------------------------------------------------------+
void checkHGFilled(int barNumber)
{
    string Prefix = UnfilledPrefix;

    int L = StringLen(Prefix);
    int obj_total = ObjectsTotal(ChartID(), 0, OBJ_RECTANGLE);
    // Loop over all unfilled boxes
    for (int i = 0; i < obj_total; i++)
    {
        string ObjName = ObjectName(0, i, 0, OBJ_RECTANGLE);
        if (StringSubstr(ObjName, 0, L) != Prefix) continue;
        
        // Get HG high and low values.
        double box_H = ObjectGet(ObjName, OBJPROP_PRICE1);
        double box_L = ObjectGet(ObjName, OBJPROP_PRICE2);
        color objectColor = (color)ObjectGet(ObjName, OBJPROP_COLOR);
        datetime startTime = (datetime)ObjectGet(ObjName, OBJPROP_TIME1);

        double HGFillPA_H = High[barNumber];
        double HGFillPA_L = Low[barNumber];
        
        int j = 0;
        while ((intersect(High[barNumber + j], Low[barNumber + j], box_H, box_L) != 0) && (barNumber + j < Bars) && (startTime < Time[barNumber + j]))
        {
            if (High[barNumber + j] > HGFillPA_H)  HGFillPA_H = High[barNumber + j];
            if (Low[barNumber + j]  < HGFillPA_L)  HGFillPA_L = Low[barNumber + j];
            if ((HGFillPA_H > box_H) && (HGFillPA_L < box_L))
            {
                ObjectDelete(ObjName);
                string ObjectText = FilledPrefix + TimeToString(startTime, TIME_DATE | TIME_MINUTES);
                ObjectCreate(ObjectText, OBJ_RECTANGLE, 0, startTime, box_H, Time[barNumber], box_L);
                ObjectSet(ObjectText, OBJPROP_STYLE, HGstyle);
                ObjectSet(ObjectText, OBJPROP_COLOR, objectColor);
                ObjectSet(ObjectText, OBJPROP_BACK, !HollowBoxes);
                break;
            }
            j++;
        }
    }
}

//+------------------------------------------------------------------+
//| checkWRB: Check if the given bar is a WRB or not and sets        |
//| the buffer value.                                                |
//+------------------------------------------------------------------+
bool checkWRB(int i)
{
    double body, bodyPrior;
    if (UseWholeBars) body = High[i] - Low[i];
    else body = MathAbs(Open[i] - Close[i]);
    for (int j = 1; j <= WRB_LookBackBarCount; j++)
    {
        if (UseWholeBars) bodyPrior = High[i + j] - Low[i + j];
        else bodyPrior = MathAbs(Open[i + j] - Close[i + j]);
        if (bodyPrior > body)
        {
            WRB[i] = EMPTY_VALUE;
            return false;
        }
    }

    if (UseWholeBars) WRB[i] = (High[i] + Low[i]) / 2;
    else WRB[i] = (Open[i] + Close[i]) / 2;

    return true;
}

//+------------------------------------------------------------------+
//| checkHG: Checks HG status of the previous bar.                   |
//+------------------------------------------------------------------+
void checkHG(int i)
{
    // HG-TEST (test the previous bar i + 1)
    if (WRB[i + 1] != EMPTY_VALUE) // First rule to become a HG is to become a WRB.
    {
        double H, L, A, B;

        double H2 = High[i + 2];
        double L2 = Low[i + 2];
        double H1 = High[i];
        double L1 = Low[i];

        if (UseWholeBars)
        {
            H = High[i + 1];
            L = Low[i + 1];
        }
        else if (Open[i + 1] > Close[i + 1])
        {
            H = Open[i + 1];
            L = Close[i + 1];
        }
        else
        {
            H = Close[i + 1];
            L = Open[i + 1];
        }

        // Older bar higher than the newer.
        if (L2 > H1)
        {
            A = MathMin(L2, H);
            B = MathMax(H1, L);
        }
        else if (L1 > H2)
        {
            A = MathMin(L1, H);
            B = MathMax(H2, L);
        }
        else return;

        if (A > B)
        {
            string ObjectText;
            color HGcolor = HGcolor1;
            int Length = StringLen(UnfilledPrefix);
            
            int obj_total = ObjectsTotal(ChartID(), 0, OBJ_RECTANGLE);
            // Loop over all unfilled boxes.
            for (int j = 0; j < obj_total; j++)
            {
                ObjectText = ObjectName(0, j, 0, OBJ_RECTANGLE);
                if (StringSubstr(ObjectText, 0, Length) != UnfilledPrefix) continue;
                // Switch colors if the new Hidden Gap is intersecting with previous Hidden Gap.
                if (intersect(ObjectGet(ObjectText, OBJPROP_PRICE1), ObjectGet(ObjectText, OBJPROP_PRICE2), A, B) != 0)
                {
                    HGcolor = (color)ObjectGet(ObjectText, OBJPROP_COLOR);
                    if (HGcolor == HGcolor1) HGcolor = HGcolor2;
                    else HGcolor = HGcolor1;
                    break;
                }
            }
            ObjectText = UnfilledPrefix + TimeToStr(Time[i + 1], TIME_DATE | TIME_MINUTES);
            ObjectCreate(ObjectText, OBJ_RECTANGLE, 0, Time[i + 1], A, TimeCurrent() + 10 * 365 * 24 * 60 * 60, B);
            ObjectSet(ObjectText, OBJPROP_STYLE, HGstyle);
            ObjectSet(ObjectText, OBJPROP_COLOR, HGcolor);
            ObjectSet(ObjectText, OBJPROP_BACK, !HollowBoxes);
        }
    }
}

void OnDeinit(const int reason)
{
    ObjectsDeleteAll(ChartID(), ObjectPrefix);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{    
    if (DoAlerts) CheckAlert();

    // A new bar started.
    if (totalBarCount != Bars)
    {
        int begin = Bars - IndicatorCounted();
        // Need at least WRB_LookBackBarCount bars from the end of the chart to work.
        if (begin > Bars - WRB_LookBackBarCount) begin = Bars - WRB_LookBackBarCount;
        // Maximum number of bars to calculate is StartCalculationFromBar.
        if (begin > StartCalculationFromBar) begin = StartCalculationFromBar;

        for (int i = begin; i > 0; i--)
        {
            checkWRB(i);
            checkHG(i);
            checkHGFilled(i);
        }
        totalBarCount = Bars;
    }
    
    // Additional check to see if current bar made the Hidden Gap filled.
    checkHGFilled(0);
    WRB[0] = EMPTY_VALUE;
    
    return rates_total;
}

void CheckAlert()
{
    int Length = StringLen(UnfilledPrefix);
    int total = ObjectsTotal(ChartID(), 0, OBJ_RECTANGLE);
    // Loop over all unfilled boxes.
    for (int j = 0; j < total; j++)
    {
        string ObjectText = ObjectName(0, j, 0, OBJ_RECTANGLE);
        if (StringSubstr(ObjectText, 0, Length) != UnfilledPrefix) continue;

        // Object marked as alerted.
        if (StringSubstr(ObjectText, StringLen(ObjectText) - 1, 1) == "A")
        {
            // Try to find a dupe object (could be result of a bug) and delete it.
            string ObjectNameWithoutA = StringSubstr(ObjectText, 0, StringLen(ObjectText) - 1);
            if (ObjectFind(ObjectNameWithoutA) >= 0) ObjectDelete(ObjectNameWithoutA);
            continue;
        }

        double Price1 = ObjectGet(ObjectText, OBJPROP_PRICE1);
        double Price2 = ObjectGet(ObjectText, OBJPROP_PRICE2);
        double bHigh = MathMax(Price1, Price2);
        double bLow = MathMin(Price1, Price2);

        // Current price above lower border.
        if ((Ask > bLow) && (Bid < bHigh))
        {
            string Text = "WRB Hidden Gap: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - WRB rectangle breached.";
            if (EnableNativeAlerts) Alert(Text);
            if (EnableEmailAlerts) SendMail("WRB HG Alert", Text);
            if (EnablePushAlerts) SendNotification(Text);
            ObjectSetString(0, ObjectText, OBJPROP_NAME, ObjectText + "A");
            return;
        }
    }
}
//+------------------------------------------------------------------+