//+------------------------------------------------------------------+
//|                                               WRB-Hidden-Gap.mq5 |
//|                                      Copyright © 2025, EarnForex |
//|                                       https://www.earnforex.com/ |
//|                             Based on the indicator by Akif TOKUZ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, EarnForex"
#property link      "https://www.earnforex.com/metatrader-indicators/WRB-Hidden-Gap/"
#property version   "1.05"

#property description "Identifies Wide Range Bars and Hidden Gaps. Supports MTF."
#property description "WRB and HG definitions are taken from the WRB Analysis Tutorial-1"
#property description "by M.A.Perry from TheStrategyLab.com."
#property description "Conversion from MQL4 to MQL5, alerts, and optimization by Andriy Moraru."

#property indicator_chart_window

#property indicator_plots   1
#property indicator_buffers 1

#property indicator_type1 DRAW_ARROW
#property indicator_label1 "WRB"
#property indicator_color1 clrRed
#property indicator_width1 3

input group "Calculation"
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;
input bool UseWholeBars = false;
input int WRB_LookBackBarCount = 3;
input int WRB_WingDingsSymbol = 115;
input int StartCalculationFromBar = 100;
input group "Style & Color"
input color HGcolorNormalBullishUnbreached       = clrDodgerBlue;
input color HGcolorIntersectionBullishUnbreached = clrBlue;
input color HGcolorNormalBearishUnbreached       = clrIndianRed;
input color HGcolorIntersectionBearishUnbreached = clrRed;
input color HGcolorNormalBullishBreached         = clrPowderBlue;
input color HGcolorIntersectionBullishBreached   = clrSlateBlue;
input color HGcolorNormalBearishBreached         = clrLightCoral;
input color HGcolorIntersectionBearishBreached   = clrSalmon;
input ENUM_LINE_STYLE HGstyle = STYLE_SOLID;
input bool HollowBoxes = false;
input group "Alerts"
input bool AlertBreachesFromBelow = true;
input bool AlertBreachesFromAbove = true;
input bool AlertHG = false;
input bool AlertWRB = false;
input bool AlertHGFill = false;
input bool EnableNativeAlerts = false;
input bool EnableEmailAlerts = false;
input bool EnablePushAlerts = false;
input bool EnableSoundAlerts = false;
input string AlertSoundFile = "alert.wav";
input group "Miscellaneous"
input string ObjectPrefix = "HG_";

double WRB[];

int totalBarCount = -1;
bool DoAlerts = false;
datetime AlertTimeWRB = 0, AlertTimeHG = 0;
string UnfilledPrefix, FilledPrefix;
int counted_bars;

int OnInit()
{
    if (PeriodSeconds(Timeframe) < PeriodSeconds())
    {
        Print("The Timeframe input parameter should be higher or equal to the current timeframe. Switching to current timeframe.");
    }

    IndicatorSetString(INDICATOR_SHORTNAME, "WRB+HG");

    SetIndexBuffer(0, WRB, INDICATOR_DATA);
    PlotIndexSetInteger(0, PLOT_ARROW, WRB_WingDingsSymbol);
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    ArraySetAsSeries(WRB, true);
    
    UnfilledPrefix = ObjectPrefix + "UNFILLED_";
    FilledPrefix = ObjectPrefix + "FILLED_";

    if ((EnableNativeAlerts) || (EnableEmailAlerts) || (EnablePushAlerts)) DoAlerts = true;

    return INIT_SUCCEEDED;
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
    // Loop over all unfilled boxes.
    for (int i = 0; i < obj_total; i++)
    {
        string ObjName = ObjectName(0, i, -1, OBJ_RECTANGLE);
        if (StringSubstr(ObjName, 0, L) != Prefix) continue;
        
        // Get HG high and low values.
        double box_H = ObjectGetDouble(0, ObjName, OBJPROP_PRICE, 0);
        double box_L = ObjectGetDouble(0, ObjName, OBJPROP_PRICE, 1);
        color objectColor = (color)ObjectGetInteger(0, ObjName, OBJPROP_COLOR);
        datetime startTime = (datetime)ObjectGetInteger(0, ObjName, OBJPROP_TIME, 0);

        double HGFillPA_H = iHigh(Symbol(), Period(), barNumber);
        double HGFillPA_L = iLow(Symbol(), Period(), barNumber);

        if ((HGFillPA_H > box_L) && (HGFillPA_L < box_H)) // Breach, but not necessarily filling.
        {
            // Only color should be updated.
            if (objectColor == HGcolorNormalBullishUnbreached) objectColor = HGcolorNormalBullishBreached;
            else if (objectColor == HGcolorIntersectionBullishUnbreached) objectColor = HGcolorIntersectionBullishBreached;
            else if (objectColor == HGcolorNormalBearishUnbreached) objectColor = HGcolorNormalBearishBreached;
            else if (objectColor == HGcolorIntersectionBearishUnbreached) objectColor = HGcolorIntersectionBearishBreached;
            ObjectSetInteger(ChartID(), ObjName, OBJPROP_COLOR, objectColor);
        }

        int j = 0;
        while ((intersect(iHigh(Symbol(), Period(), barNumber + j), iLow(Symbol(), Period(), barNumber + j), box_H, box_L) != 0) && (barNumber + j < iBars(Symbol(), Period())) && (startTime < iTime(Symbol(), Period(), barNumber + j)))
        {
            if (iHigh(Symbol(), Period(), barNumber + j) > HGFillPA_H) HGFillPA_H = iHigh(Symbol(), Period(), barNumber + j);
            if (iLow(Symbol(), Period(), barNumber + j)  < HGFillPA_L) HGFillPA_L = iLow(Symbol(), Period(), barNumber + j);
            if ((HGFillPA_H > box_H) && (HGFillPA_L < box_L))
            {
                ObjectDelete(0, ObjName);
                string ObjectText = FilledPrefix + TimeToString(startTime, TIME_DATE | TIME_MINUTES); // Recreate as a filled box.
                ObjectCreate(0, ObjectText, OBJ_RECTANGLE, 0, startTime, box_H, iTime(Symbol(), Period(), barNumber), box_L);
                ObjectSetInteger(0, ObjectText, OBJPROP_STYLE, HGstyle);
                ObjectSetInteger(0, ObjectText, OBJPROP_COLOR, objectColor);
                ObjectSetInteger(0, ObjectText, OBJPROP_FILL, !HollowBoxes);
                if ((AlertHGFill) && (counted_bars > 0)) // Don't alert on old fillings.
                {
                    string rectangle_direction = GetRectangleDirection(ObjectText);
                    string Text = "WRB Hidden Gap: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - " + rectangle_direction + " HG " + TimeToString(startTime, TIME_DATE | TIME_MINUTES) + " Filled.";
                    string TextNative = "WRB Hidden Gap: " + rectangle_direction + " HG " + TimeToString(startTime, TIME_DATE | TIME_MINUTES) + " Filled.";
                    if (EnableNativeAlerts) Alert(TextNative);
                    if (EnableEmailAlerts) SendMail("WRB HG Alert", Text);
                    if (EnablePushAlerts) SendNotification(Text);
                    if (EnableSoundAlerts) PlaySound(AlertSoundFile);
                }
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
    int upper_timeframe_i = i;
    ENUM_TIMEFRAMES period = PERIOD_CURRENT;
    if (PeriodSeconds(Timeframe) > PeriodSeconds()) // MTF.
    {
        // This additional i will be used for bar data. Results will be written to WRB[i] with normal i.
        upper_timeframe_i = iBarShift(Symbol(), Timeframe, iTime(Symbol(), Period(), i), true);
        if (upper_timeframe_i < 0)
        {
            Print("No upper timeframe bar for ", iTime(Symbol(), Period(), i));
            return false;
        }
        if (upper_timeframe_i + WRB_LookBackBarCount >= iBars(Symbol(), Timeframe))
        {
            Print("Not enough bars on ", EnumToString(Timeframe));
            return false;
        }
        period = Timeframe;
    }
    
    if (UseWholeBars) body = iHigh(Symbol(), period, upper_timeframe_i) - iLow(Symbol(), period, upper_timeframe_i);
    else body = MathAbs(iOpen(Symbol(), period, upper_timeframe_i) - iClose(Symbol(), period, upper_timeframe_i));
    for (int j = 1; j <= WRB_LookBackBarCount; j++)
    {
        if (UseWholeBars) bodyPrior = iHigh(Symbol(), period, upper_timeframe_i + j) - iLow(Symbol(), period, upper_timeframe_i + j);
        else bodyPrior = MathAbs(iOpen(Symbol(), period, upper_timeframe_i + j) - iClose(Symbol(), period, upper_timeframe_i + j));
        if (bodyPrior > body)
        {
            WRB[i] = EMPTY_VALUE;
            return false;
        }
    }
    
    // The bar is marked based on its actual dimension irrespective of MTF.
    if (UseWholeBars) WRB[i] = (iHigh(Symbol(), Period(), i) + iLow(Symbol(), Period(), i)) / 2;
    else WRB[i] = (iOpen(Symbol(), Period(), i) + iClose(Symbol(), Period(), i)) / 2;
    
    return true;
}

//+------------------------------------------------------------------+
//| checkHG: Checks HG status of the previous bar.                   |
//+------------------------------------------------------------------+
void checkHG(int i)
{
    color HGcolor = clrNONE;
    // HG-TEST (test the previous bar i + 1)
    int i_to_check = i;
    int i_upper_bar = i;
    ENUM_TIMEFRAMES period = PERIOD_CURRENT;
    // For MTF: Test not + 1, find the oldest sub-bar inside the bar with Time[i] and then use to "+ 1" to get the latest sub-bar in the previous upper timeframe bar.
    if (PeriodSeconds(Timeframe) > PeriodSeconds()) // MTF?
    {
        i_upper_bar = iBarShift(Symbol(), Timeframe, iTime(Symbol(), Period(), i), true);
        i_to_check = -1;
        if (i_upper_bar < 0)
        {
            Print("Couldn't find ", EnumToString(Timeframe), " bar for ", iTime(Symbol(), Period(), i));
            return;
        }
        if (i_upper_bar + 2 >= iBars(Symbol(), Timeframe))
        {
            Print("Not enough bars on ", EnumToString(Timeframe));
            return;
        }
        for (int j = 1; j < iBars(Symbol(), Period()); j++)
        {
            if (iTime(Symbol(), Period(), i + j) < iTime(Symbol(), Timeframe, i_upper_bar))
            {
                i_to_check = i + j - 1;
                break;
            }
        }
        if (i_to_check < 0)
        {
            Print("Could not find a sub-bar for the bar after time: ", iTime(Symbol(), Timeframe, i_upper_bar));
            return;
        }
        period = Timeframe;
    }
    if (WRB[i_to_check + 1] != EMPTY_VALUE) // First rule to become a HG is to become a WRB.
    {
        double H, L, A, B;
        double H2, L2, H1, L1;

        H2 = iHigh(Symbol(), period, i_upper_bar + 2);
        L2 = iLow(Symbol(), period, i_upper_bar + 2);
        H1 = iHigh(Symbol(), period, i_upper_bar);
        L1 = iLow(Symbol(), period, i_upper_bar);

        if (UseWholeBars)
        {
            H = iHigh(Symbol(), period, i_upper_bar + 1);
            L = iLow(Symbol(), period, i_upper_bar + 1);
        }
        else if (iOpen(Symbol(), period, i_upper_bar + 1) > iClose(Symbol(), period, i_upper_bar + 1))
        {
            H = iOpen(Symbol(), period, i_upper_bar + 1);
            L = iClose(Symbol(), period, i_upper_bar + 1);
        }
        else
        {
            H = iClose(Symbol(), period, i_upper_bar + 1);
            L = iOpen(Symbol(), period, i_upper_bar + 1);
        }

        if (iOpen(Symbol(), period, i_upper_bar + 1) > iClose(Symbol(), period, i_upper_bar + 1)) HGcolor = HGcolorNormalBearishUnbreached;
        else HGcolor = HGcolorNormalBullishUnbreached;

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
            int Length = StringLen(UnfilledPrefix);

            int obj_total = ObjectsTotal(ChartID(), 0, OBJ_RECTANGLE);
            // Loop over all unfilled boxes.
            for (int j = 0; j < obj_total; j++)
            {
                ObjectText = ObjectName(0, j, 0, OBJ_RECTANGLE);
                if (StringSubstr(ObjectText, 0, Length) != UnfilledPrefix) continue;
                // Switch colors if the new Hidden Gap is intersecting with previous Hidden Gap.
                if (intersect(ObjectGetDouble(0, ObjectText, OBJPROP_PRICE), ObjectGetDouble(0, ObjectText, OBJPROP_PRICE, 1), A, B) != 0)
                {
                    if (HGcolor == HGcolorNormalBearishUnbreached) HGcolor = HGcolorIntersectionBearishUnbreached;
                    else if (HGcolor == HGcolorNormalBullishUnbreached) HGcolor = HGcolorIntersectionBullishUnbreached;
                    break;
                }
            }

            ObjectText = UnfilledPrefix + TimeToString(iTime(Symbol(), Period(), i_to_check + 1), TIME_DATE | TIME_MINUTES);
            if ((ObjectFind(0, ObjectText) > -1) || (ObjectFind(0, ObjectText + "A") > -1)) return; // If this rectangle already exists (in normal or "alerted" state) skip it.
            ObjectCreate(0, ObjectText, OBJ_RECTANGLE, 0, iTime(Symbol(), Period(), i_to_check + 1), A, TimeCurrent() + 10 * 365 * 24 * 60 * 60, B);
            ObjectSetInteger(0, ObjectText, OBJPROP_STYLE, HGstyle);
            ObjectSetInteger(0, ObjectText, OBJPROP_COLOR, HGcolor);
            ObjectSetInteger(0, ObjectText, OBJPROP_FILL, !HollowBoxes);
        }
    }
}

void OnDeinit(const int reason)
{
    ObjectsDeleteAll(ChartID(), ObjectPrefix);
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Custom Market Profile main iteration function                    |
//+------------------------------------------------------------------+
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
    if ((DoAlerts) && ((AlertBreachesFromBelow) || (AlertBreachesFromAbove))) CheckAlert();

    if (prev_calculated == 0) // Reset buffer array values.
    {
        for (int i = 0; i < rates_total; i++) WRB[i] = EMPTY_VALUE;
    }

    int end_bar = 0, wrb_alert_bar, hg_alert_bar;
    // A new bar started.
    if (totalBarCount != rates_total)
    {
        counted_bars = prev_calculated;
        int start_bar = 0;
        // In MTF mode, it is necessary to start from the oldest sub-bar inside the higher-timeframe bar #1 and end on the newest sub-bar of that bar.
        // If there were skipped bars or its a fresh start (via counted_bars), then it is necessary to start at Max(oldest sub-bar of bar #1, latest non-processed bar).
        if (PeriodSeconds(Timeframe) > PeriodSeconds())
        {
            int latest_sub_bar = 0;
            int oldest_sub_bar = 0;
            datetime previous_bar_time = 0;
            datetime current_bar_time = iTime(Symbol(), Timeframe, iBarShift(Symbol(), Timeframe, iTime(Symbol(), Period(), 0), true)); // Time of the latest higher-timeframe bar.
            if (current_bar_time == 0)
            {
                Print("Cannot find the correct upper timeframe time for the latest bar. Load more chart data.");
                return prev_calculated;
            }
            for (int i = 1; i < rates_total; i++)
            {
                if (iTime(Symbol(), Period(), i) < current_bar_time) // Found the newest sub-bar of the higher-timeframe bar #1.
                {
                    latest_sub_bar = i;
                    previous_bar_time = iTime(Symbol(), Timeframe, iBarShift(Symbol(), Timeframe, iTime(Symbol(), Period(), i), true)); // Time of the pre-latest higher-timeframe bar.
                    if (previous_bar_time == 0)
                    {
                        Print("Cannot find the correct upper timeframe time for the pre-latest bar. Load more chart data.");
                        return prev_calculated;
                    }
                    break;
                }
            }
            for (int i = latest_sub_bar; i < rates_total; i++)
            {
                if (iTime(Symbol(), Period(), i) < previous_bar_time)
                {
                    oldest_sub_bar = i - 1; // Next in time.
                    break;
                }
            }
            start_bar = oldest_sub_bar;
            end_bar = latest_sub_bar;
            wrb_alert_bar = oldest_sub_bar;
            hg_alert_bar = oldest_sub_bar + 1;

            int bars_left_to_count = rates_total - counted_bars;
            start_bar = (int)MathMax(start_bar, bars_left_to_count - 1); // "- 1" because the bar's number is 1 less than the number of bars.
        }
        else // Non-MTF
        {
            start_bar = rates_total - counted_bars;
            end_bar = 1;
            wrb_alert_bar = 1;
            hg_alert_bar = end_bar + 1;
            // Need at least WRB_LookBackBarCount bars from the end of the chart to work.
            if (start_bar > rates_total - WRB_LookBackBarCount) start_bar = rates_total - WRB_LookBackBarCount;
        }

        // Maximum number of bars to calculate is StartCalculationFromBar.
        if (start_bar > StartCalculationFromBar) start_bar = StartCalculationFromBar;

        // Main cycle.
        for (int i = start_bar; i >= end_bar; i--)
        {
            checkWRB(i);
            checkHG(i);
            checkHGFilled(i);
        }

        if ((DoAlerts) && (AlertWRB) && (WRB[wrb_alert_bar] != EMPTY_VALUE) && (AlertTimeWRB < iTime(Symbol(), Period(), wrb_alert_bar)))
        {
            // Check WRB's direction to include it in the alert text:
            string direction = "Bearish ";
            if (iOpen(Symbol(), Timeframe, 1) < iClose(Symbol(), Timeframe, 1)) direction = "Bullish ";
            string Text = "WRB Hidden Gap: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - New " + direction + "WRB.";
            string TextNative = "WRB Hidden Gap: New " + direction + "WRB.";
            if (EnableNativeAlerts) Alert(TextNative);
            if (EnableEmailAlerts) SendMail("WRB HG Alert", Text);
            if (EnablePushAlerts) SendNotification(Text);
            if (EnableSoundAlerts) PlaySound(AlertSoundFile);
            AlertTimeWRB = iTime(Symbol(), Period(), wrb_alert_bar);
        }
        if ((DoAlerts) && (AlertHG) && (ObjectFind(ChartID(), UnfilledPrefix + TimeToString(iTime(Symbol(), Period(), hg_alert_bar))) > -1) && (AlertTimeHG < iTime(Symbol(), Period(), hg_alert_bar)))
        {
            // Check rectangle's color to see whether it is bullish or bearish and include this info in the alert text:
            string rectangle_direction = GetRectangleDirection(UnfilledPrefix + TimeToString(iTime(Symbol(), Period(), hg_alert_bar)));
            string Text = "WRB Hidden Gap: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - New " + rectangle_direction + " HG.";
            string TextNative = "WRB Hidden Gap: New " + rectangle_direction + " HG.";
            if (EnableNativeAlerts) Alert(TextNative);
            if (EnableEmailAlerts) SendMail("WRB HG Alert", Text);
            if (EnablePushAlerts) SendNotification(Text);
            if (EnableSoundAlerts) PlaySound(AlertSoundFile);
            AlertTimeHG = iTime(Symbol(), Period(), hg_alert_bar);
        }

        totalBarCount = rates_total;
    }
    
    // Additional check to see if current bar made the Hidden Gap filled.
    if (PeriodSeconds(Timeframe) > PeriodSeconds()) // MTF.
    {
        for (int i = end_bar - 1; i >= 0; i--)
        {
            WRB[i] = EMPTY_VALUE; // Fill buffers for every sub-bar of the current upper timeframe bar.
            checkHGFilled(i); // Check every sub-bar of the current upper timeframe bar for filling a HG.
        }
    }
    else 
    {
        checkHGFilled(0);
        WRB[0] = EMPTY_VALUE;
    }
    
    return rates_total;
}

void CheckAlert()
{
    int Length = StringLen(UnfilledPrefix);
    int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
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
            if (ObjectFind(0, ObjectNameWithoutA) >= 0) ObjectDelete(0, ObjectNameWithoutA);
            continue;
        }

        double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double Price1 = ObjectGetDouble(0, ObjectText, OBJPROP_PRICE);
        double Price2 = ObjectGetDouble(0, ObjectText, OBJPROP_PRICE, 1);
        double High = MathMax(Price1, Price2);
        double Low = MathMin(Price1, Price2);

        // Current price above lower border.
        if ((Ask > Low) && (Bid < High))
        {
            string Text = "";
            string TextNative = "";
            if ((AlertBreachesFromBelow) && ((iOpen(Symbol(), Period(), 0) < Low) || (iOpen(Symbol(), Period(), 1) < Low)))
            {
                string rectangle_direction = GetRectangleDirection(ObjectText);
                Text = "WRB Hidden Gap: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - " + rectangle_direction + " WRB rectangle breached from below.";
                TextNative = "WRB Hidden Gap: " + rectangle_direction + " WRB rectangle breached from below.";
            }
            else if ((AlertBreachesFromAbove) && ((iOpen(Symbol(), Period(), 0) > High) || (iOpen(Symbol(), Period(), 1) > High)))
            {
                string rectangle_direction = GetRectangleDirection(ObjectText);
                Text = "WRB Hidden Gap: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - " + rectangle_direction + " WRB rectangle breached from above.";
                TextNative = "WRB Hidden Gap: " + rectangle_direction + " WRB rectangle breached from above.";
            }
            if (Text != "")
            {
                if (EnableNativeAlerts) Alert(TextNative);
                if (EnableEmailAlerts) SendMail("WRB HG Alert", Text);
                if (EnablePushAlerts) SendNotification(Text);
                if (EnableSoundAlerts) PlaySound(AlertSoundFile);
                ObjectSetString(0, ObjectText, OBJPROP_NAME, ObjectText + "A");
            }
            return;
        }
    }
}

// Returns rectangle direction as a string ("Bullish" or "Bearish") based on its color.
string GetRectangleDirection(const string objectName)
{
    color objectColor = (color)ObjectGetInteger(ChartID(), objectName, OBJPROP_COLOR);
    if ((objectColor == HGcolorNormalBullishBreached) || (objectColor == HGcolorIntersectionBullishBreached) || (objectColor == HGcolorNormalBullishUnbreached) || (objectColor == HGcolorIntersectionBullishUnbreached)) return "Bullish";
    else if ((objectColor == HGcolorNormalBearishBreached) || (objectColor == HGcolorIntersectionBearishBreached) || (objectColor == HGcolorNormalBearishUnbreached) || (objectColor == HGcolorIntersectionBearishUnbreached)) return "Bearish";
    return ""; // Failed to detect direction based on color.
}
//+------------------------------------------------------------------+