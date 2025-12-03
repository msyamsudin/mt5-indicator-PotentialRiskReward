//+------------------------------------------------------------------+
//|                PotentialPnLIndicator.mq5 - Versi 1.7             |
//+------------------------------------------------------------------+
#property copyright "Syam"
#property version   "1.7"
#property indicator_chart_window
#property indicator_plots 0

//--- Font enum
enum ENUM_FONT_TYPE
{
   FONT_ARIAL_BOLD=0,
   FONT_ARIAL=1,
   FONT_COURIER_NEW=2,
   FONT_CONSOLAS=3,
   FONT_TAHOMA=4,
   FONT_VERDANA=5,
   FONT_TIMES_NEW_ROMAN=6,
   FONT_SEGOE_UI=7,
   FONT_CALIBRI=8,
   FONT_MS_SANS_SERIF=9
};

//--- Input parameters
input color    clrProfit          = clrLimeGreen;
input color    clrLoss            = clrDeepPink;
input color    clrBreakeven       = clrGray;
input ENUM_FONT_TYPE fontType     = FONT_CONSOLAS;
input int      fontSize           = 9;
input double   stepMoney          = 50.0;
input int      maxLabels          = 20;
input bool     showPlusSign       = true;
input bool     showDollarSign     = true;
input int      xDistance          = 3;

input bool     showDuration       = true;
input color    clrDuration        = clrWhite;
input int      durationYOffset    = 15;

input bool     showZoneLines      = true;
input color    clrZoneLine        = C'25,25,25';
input ENUM_LINE_STYLE zoneLineStyle = STYLE_DOT;
input int      zoneLineWidth      = 1;
input int      zoneLineStopPixels = 50;

//--- Prefix objek
string objPrefix      = "PnL_";
string durationPrefix = "Duration_";
string zoneLinePrefix = "ZoneLine_";

//+------------------------------------------------------------------+
string GetFontName(ENUM_FONT_TYPE type)
{
   switch(type)
   {
      case FONT_ARIAL_BOLD:      return "Arial Bold";
      case FONT_ARIAL:           return "Arial";
      case FONT_COURIER_NEW:     return "Courier New";
      case FONT_CONSOLAS:        return "Consolas";
      case FONT_TAHOMA:          return "Tahoma";
      case FONT_VERDANA:         return "Verdana";
      case FONT_TIMES_NEW_ROMAN: return "Times New Roman";
      case FONT_SEGOE_UI:        return "Segoe UI";
      case FONT_CALIBRI:         return "Calibri";
      case FONT_MS_SANS_SERIF:   return "MS Sans Serif";
      default:                   return "Consolas";
   }
}

//+------------------------------------------------------------------+
string FormatDuration(datetime openTime)
{
   int total = (int)(TimeCurrent() - openTime);
   int d = total/86400; total %= 86400;
   int h = total/3600;  total %= 3600;
   int m = total/60;    total %= 60;
   if(d>0) return StringFormat("%dd %dh %dm",d,h,m);
   if(h>0) return StringFormat("%dh %dm %ds",h,m,total);
   if(m>0) return StringFormat("%dm %ds",m,total);
   return StringFormat("%ds",total);
}

//+------------------------------------------------------------------+
int OnInit()
{
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteAllObjects();
}

void OnTimer() { UpdateDurationLabels(); }

int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime& time[],const double& open[],const double& high[],
                const double& low[],const double& close[],const long& tick_volume[],
                const long& volume[],const int& spread[])
{
   UpdatePriceLabels();
   return(rates_total);
}

//+------------------------------------------------------------------+
void UpdatePriceLabels()
{
   DeleteAllObjects();
   if(PositionsTotal()==0) { ChartRedraw(); return; }

   //--- Cari posisi paling lama (oldest) pada symbol ini
   ulong oldestTicket = 0;
   datetime oldestTime = D'2099.12.31';

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL)==_Symbol)
      {
         datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
         if(ot < oldestTime) { oldestTime = ot; oldestTicket = ticket; }
      }
   }
   if(oldestTicket==0) return;

   PositionSelectByTicket(oldestTicket);
   string   sym    = PositionGetString(POSITION_SYMBOL);
   double   openPr = PositionGetDouble(POSITION_PRICE_OPEN);
   double   vol    = PositionGetDouble(POSITION_VOLUME);
   datetime openTm = (datetime)PositionGetInteger(POSITION_TIME);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   // Breakeven
   CreateLabel(oldestTicket, openPr, 0, posType, true);
   if(showDuration) CreateDurationLabel(oldestTicket, openPr, openTm);

   //--- Garis zona untuk SETIAP level
   if(showZoneLines)
   {
      for(int j=1; j<=maxLabels; j++)
      {
         double profit = stepMoney * j;
         double loss   = -profit;

         double priceP = CalculatePriceForProfit(openPr, vol, profit, posType, sym);
         double priceL = CalculatePriceForProfit(openPr, vol, loss,   posType, sym);

         if(priceP > 0) CreateZoneLine(oldestTicket, priceP, j, true);
         if(priceL > 0) CreateZoneLine(oldestTicket, priceL, j, false);
      }
   }

   //--- Label profit & loss
   for(int j=1; j<=maxLabels; j++)
   {
      double profit = stepMoney * j;
      double loss   = -profit;

      double priceP = CalculatePriceForProfit(openPr, vol, profit, posType, sym);
      double priceL = CalculatePriceForProfit(openPr, vol, loss,   posType, sym);

      if(priceP > 0) CreateLabel(oldestTicket, priceP, profit, posType, false);
      if(priceL > 0) CreateLabel(oldestTicket, priceL, loss,   posType, false);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
// Garis zona – berhenti sebelum label
//+------------------------------------------------------------------+
void CreateZoneLine(ulong ticket, double price, int index, bool isProfit)
{
   string name = zoneLinePrefix + (string)ticket + "_" + (string)index + "_" + (isProfit?"P":"L");
   datetime timeStart = (datetime)PositionGetInteger(POSITION_TIME);

   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int xStop = chartWidth - zoneLineStopPixels;

   datetime timeEnd = timeStart;
   double   dummyPrice = price;
   int      subwin = 0;

   if(!ChartXYToTimePrice(0, xStop, 0, subwin, timeEnd, dummyPrice))
      timeEnd = TimeCurrent() + 365*24*60*60;

   if(timeEnd <= timeStart) timeEnd = timeStart + PeriodSeconds()*200;

   if(ObjectCreate(0, name, OBJ_TREND, 0, timeStart, price, timeEnd, price))
   {
      ObjectSetInteger(0,name,OBJPROP_COLOR,clrZoneLine);
      ObjectSetInteger(0,name,OBJPROP_STYLE,zoneLineStyle);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,zoneLineWidth);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   }
   else
   {
      ChartXYToTimePrice(0, xStop, 0, subwin, timeEnd, dummyPrice);
      ObjectMove(0, name, 1, timeEnd, price);
   }
}

//+------------------------------------------------------------------+
double CalculatePriceForProfit(double openPrice, double volume, double targetProfit,
                               ENUM_POSITION_TYPE type, string symbol)
{
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue==0 || tickSize==0 || volume==0) return 0;

   double change = (targetProfit * tickSize) / (tickValue * volume);
   return (type==POSITION_TYPE_BUY) ? openPrice + change : openPrice - change;
}

//+------------------------------------------------------------------+
void CreateLabel(ulong ticket, double price, double profitAmount,
                 ENUM_POSITION_TYPE type, bool isBreakeven)
{
   string name = objPrefix + (string)ticket + "_" + DoubleToString(price,_Digits);
   int subwin=0, x,y;
   ChartTimePriceToXY(0,subwin,TimeCurrent(),price,x,y);
   int w = (int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);

   string text = "";
   color  col  = clrBreakeven;

   if(isBreakeven) text="0";
   else if(profitAmount>0)
   {
      if(showPlusSign && showDollarSign) text=StringFormat("+$%.0f",profitAmount);
      else if(showPlusSign)              text=StringFormat("+%.0f",profitAmount);
      else if(showDollarSign)            text=StringFormat("$%.0f",profitAmount);
      else                               text=StringFormat("%.0f",profitAmount);
      col = clrProfit;
   }
   else
   {
      text = showDollarSign ? StringFormat("-$%.0f",MathAbs(profitAmount))
                            : StringFormat("-%.0f",MathAbs(profitAmount));
      col = clrLoss;
   }

   if(ObjectCreate(0,name,OBJ_LABEL,0,0,0))
   {
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetInteger(0,name,OBJPROP_COLOR,col);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSize);
      ObjectSetString(0,name,OBJPROP_FONT,GetFontName(fontType));
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_RIGHT);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,w-xDistance);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }
   else
   {
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetInteger(0,name,OBJPROP_COLOR,col);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,w-xDistance);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   }
}

//+------------------------------------------------------------------+
void CreateDurationLabel(ulong ticket, double price, datetime openTime)
{
   string name = durationPrefix + (string)ticket;
   int subwin=0, x,y;
   ChartTimePriceToXY(0,subwin,TimeCurrent(),price,x,y);
   int w = (int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);

   if(ObjectCreate(0,name,OBJ_LABEL,0,0,0))
   {
      ObjectSetString(0,name,OBJPROP_TEXT,FormatDuration(openTime));
      ObjectSetInteger(0,name,OBJPROP_COLOR,clrDuration);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSize-1);
      ObjectSetString(0,name,OBJPROP_FONT,GetFontName(fontType));
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_RIGHT);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,w-xDistance);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y+durationYOffset);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }
}

void UpdateDurationLabels()
{
   if(!showDuration) return;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL)==_Symbol)
      {
         double pr = PositionGetDouble(POSITION_PRICE_OPEN);
         datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
         string name = durationPrefix + (string)ticket;
         if(ObjectFind(0,name)>=0)
         {
            ObjectSetString(0,name,OBJPROP_TEXT,FormatDuration(ot));
            int subwin=0,x,y;
            ChartTimePriceToXY(0,subwin,TimeCurrent(),pr,x,y);
            int w=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
            ObjectSetInteger(0,name,OBJPROP_XDISTANCE,w-xDistance);
            ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y+durationYOffset);
         }
      }
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string n = ObjectName(0,i);
      if(StringFind(n,objPrefix)==0 || StringFind(n,durationPrefix)==0 || StringFind(n,zoneLinePrefix)==0)
         ObjectDelete(0,n);
   }
}

void OnChartEvent(const int id,const long& lparam,const double& dparam,const string& sparam)
{
   if(id==CHARTEVENT_CHART_CHANGE) UpdatePriceLabels();
}
//+------------------------------------------------------------------+