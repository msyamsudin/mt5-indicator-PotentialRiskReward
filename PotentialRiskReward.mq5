//+------------------------------------------------------------------+
//|                PotentialPnLIndicator.mq5 - Versi 1.10            |
//+------------------------------------------------------------------+
#property copyright "Syam"
#property version   "1.10"
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
input int      hypoExitLabelOffset = 20;  // Offset label exit dari garis (dalam pixel)

input bool     showDuration       = true;
input color    clrDuration        = clrWhite;
input int      durationYOffset    = 15;

input bool     showZoneLines      = true;
input color    clrZoneLine        = C'25,25,25';
input ENUM_LINE_STYLE zoneLineStyle = STYLE_DOT;
input int      zoneLineWidth      = 1;
input int      zoneLineStopPixels = 50;

input bool     enableHypothetically = true;
input color    clrHypoEntryLine    = clrDodgerBlue;
input color    clrHypoExitLine     = clrOrange;
input int      hypoLineWidth       = 2;
input double   customLotSize       = 0.01;
input string   entryLinePrefix     = "HypoEntry_";  // Format nama garis entry
input string   exitLinePrefix      = "HypoExit_";   // Format nama garis exit
input bool     enableDeleteButton  = true;          // Tampilkan tombol delete

//--- Prefix objek
string objPrefix      = "PnL_";
string durationPrefix = "Duration_";
string zoneLinePrefix = "ZoneLine_";
string deleteButtonPrefix = "HypoDeleteBtn_";

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
   DeleteAllHypotheticalObjects();
   DeleteAllDeleteButtons();
}

void OnTimer() 
{ 
   UpdateDurationLabels();
}

int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime& time[],const double& open[],const double& high[],
                const double& low[],const double& close[],const long& tick_volume[],
                const long& volume[],const int& spread[])
{
   UpdatePriceLabels();
   
   // Update hypothetical lines setiap kali calculate jika tidak ada posisi
   if(enableHypothetically && PositionsTotal() == 0)
   {
      UpdateHypotheticalLabelsPosition();
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
void UpdatePriceLabels()
{
   // Hapus hanya objek real position, JANGAN hapus hypothetical
   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string n = ObjectName(0,i);
      if(StringFind(n,objPrefix)==0 || StringFind(n,durationPrefix)==0 || 
         StringFind(n,zoneLinePrefix)==0)
         ObjectDelete(0,n);
   }
   
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
      if(StringFind(n,objPrefix)==0 || StringFind(n,durationPrefix)==0 || 
         StringFind(n,zoneLinePrefix)==0)
         ObjectDelete(0,n);
   }
}

//+------------------------------------------------------------------+
// HYPOTHETICALLY FEATURE - Using Horizontal Lines
//+------------------------------------------------------------------+

void OnChartEvent(const int id,const long& lparam,const double& dparam,const string& sparam)
{
   if(id==CHARTEVENT_CHART_CHANGE) 
   {
      UpdatePriceLabels();
      // Update hypothetical hanya saat chart change jika diperlukan
      if(enableHypothetically && PositionsTotal() == 0) 
         ScanAndUpdateHypotheticalLines();
   }
   
   if(!enableHypothetically) return;
   
   // Handle line movement - update hanya saat garis di-drag
   if(id==CHARTEVENT_OBJECT_DRAG)
   {
      if(StringFind(sparam, entryLinePrefix)==0 || StringFind(sparam, exitLinePrefix)==0)
      {
         // Hapus visualisasi lama terlebih dahulu
         string identifier = "";
         if(StringFind(sparam, entryLinePrefix)==0)
            identifier = StringSubstr(sparam, StringLen(entryLinePrefix));
         else if(StringFind(sparam, exitLinePrefix)==0)
            identifier = StringSubstr(sparam, StringLen(exitLinePrefix));
         
         if(identifier != "")
            DeleteHypotheticalVisualization(identifier);
         
         // Update visualisasi baru
         ScanAndUpdateHypotheticalLines();
      }
   }
   
   // Handle line deletion
   if(id==CHARTEVENT_OBJECT_DELETE)
   {
      if(StringFind(sparam, entryLinePrefix)==0 || StringFind(sparam, exitLinePrefix)==0)
      {
         string identifier = "";
         if(StringFind(sparam, entryLinePrefix)==0)
            identifier = StringSubstr(sparam, StringLen(entryLinePrefix));
         else if(StringFind(sparam, exitLinePrefix)==0)
            identifier = StringSubstr(sparam, StringLen(exitLinePrefix));
         
         if(identifier != "")
            DeleteHypotheticalVisualization(identifier);
      }
   }
   
   // Handle delete button click
   if(id==CHARTEVENT_OBJECT_CLICK)
   {
      if(StringFind(sparam, deleteButtonPrefix)==0)
      {
         // Extract identifier dari button name
         string identifier = StringSubstr(sparam, StringLen(deleteButtonPrefix));
         
         // Hapus entry dan exit line
         string entryLineName = entryLinePrefix + identifier;
         string exitLineName = exitLinePrefix + identifier;
         
         ObjectDelete(0, entryLineName);
         ObjectDelete(0, exitLineName);
         
         // Hapus semua visualisasi terkait
         DeleteHypotheticalVisualization(identifier);
         
         // Hapus tombol delete
         ObjectDelete(0, sparam);
         
         ChartRedraw();
      }
   }
}

//+------------------------------------------------------------------+
// Scan and update hypothetical lines based on HypoEntry_ format
//+------------------------------------------------------------------+
void ScanAndUpdateHypotheticalLines()
{
   // Only work when no positions open
   if(PositionsTotal() > 0) 
   {
      DeleteAllHypotheticalObjects();
      DeleteAllDeleteButtons();
      return;
   }
   
   // Hapus semua tombol delete yang ada terlebih dahulu
   DeleteAllDeleteButtons();
   
   // Find all entry lines and their corresponding exit lines
   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string objName = ObjectName(0, i);
      
      // Check if it's an entry line (HypoEntry_xxx format)
      if(StringFind(objName, entryLinePrefix)==0)
      {
         if(ObjectGetInteger(0, objName, OBJPROP_TYPE) == OBJ_HLINE)
         {
            // Setup entry line appearance
            SetupHypotheticalEntryLine(objName);
            
            // Extract identifier from entry line name
            string identifier = StringSubstr(objName, StringLen(entryLinePrefix));
            
            // Look for corresponding exit line (HypoExit_xxx)
            string exitLineName = exitLinePrefix + identifier;
            
            if(ObjectFind(0, exitLineName) >= 0 && 
               ObjectGetInteger(0, exitLineName, OBJPROP_TYPE) == OBJ_HLINE)
            {
               // Setup exit line appearance
               SetupHypotheticalExitLine(exitLineName);
               
               // Calculate and visualize P&L
               CalculateAndVisualizeHypothetical(objName, exitLineName, identifier);
               
               // Buat tombol delete jika enabled
               if(enableDeleteButton)
                  CreateDeleteButton(identifier, objName);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
// Setup entry line properties
//+------------------------------------------------------------------+
void SetupHypotheticalEntryLine(string lineName)
{
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrHypoEntryLine);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, hypoLineWidth);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, true);
   ObjectSetString(0, lineName, OBJPROP_TEXT, "Hypothetical Entry");
}

//+------------------------------------------------------------------+
// Setup exit line properties
//+------------------------------------------------------------------+
void SetupHypotheticalExitLine(string lineName)
{
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrHypoExitLine);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, hypoLineWidth);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, true);
   ObjectSetString(0, lineName, OBJPROP_TEXT, "Hypothetical Exit");
}

//+------------------------------------------------------------------+
// Calculate and visualize hypothetical scenario
//+------------------------------------------------------------------+
void CalculateAndVisualizeHypothetical(string entryLineName, string exitLineName, string identifier)
{
   double entryPrice = ObjectGetDouble(0, entryLineName, OBJPROP_PRICE);
   double exitPrice = ObjectGetDouble(0, exitLineName, OBJPROP_PRICE);
   
   if(entryPrice <= 0 || exitPrice <= 0) return;
   
   // Determine position type
   ENUM_POSITION_TYPE posType;
   if(exitPrice > entryPrice)
      posType = POSITION_TYPE_BUY;
   else
      posType = POSITION_TYPE_SELL;
   
   // Calculate P&L
   string sym = _Symbol;
   double calcVolume = customLotSize;
   
   double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue==0 || tickSize==0) return;
   
   double priceDiff = (posType==POSITION_TYPE_BUY) ? (exitPrice - entryPrice) : (entryPrice - exitPrice);
   double hypotheticalPnL = (priceDiff / tickSize) * tickValue * calcVolume;
   
   // Create visualization
   CreateHypotheticalVisualization(identifier, entryPrice, exitPrice, hypotheticalPnL, calcVolume, posType);
}

//+------------------------------------------------------------------+
// Create visualization for hypothetical scenario
//+------------------------------------------------------------------+
void CreateHypotheticalVisualization(string identifier, double entryPrice, double exitPrice, 
                                     double pnl, double lotUsed, ENUM_POSITION_TYPE posType)
{
   string basePrefix = "Hypo_" + identifier + "_";
   
   // Gunakan waktu candle saat ini sebagai start time untuk zona lines
   datetime entryTime = TimeCurrent();
   
   // Create breakeven label at entry
   CreateHypotheticalPriceLabel(basePrefix + "Entry", entryPrice, 0, true, false);
   
   // Create exit label showing P&L
   CreateHypotheticalPriceLabel(basePrefix + "Exit", exitPrice, pnl, false, true);
   
   // Create zone lines and labels if enabled
   if(showZoneLines)
   {
      for(int j=1; j<=maxLabels; j++)
      {
         double profit = stepMoney * j;
         double loss   = -profit;
         
         double priceP = CalculatePriceForProfit(entryPrice, lotUsed, profit, posType, _Symbol);
         double priceL = CalculatePriceForProfit(entryPrice, lotUsed, loss, posType, _Symbol);
         
         if(priceP > 0)
         {
            CreateHypotheticalZoneLine(basePrefix, priceP, j, true, entryTime);
            CreateHypotheticalPriceLabel(basePrefix + "P" + (string)j, priceP, profit, false, false);
         }
         
         if(priceL > 0)
         {
            CreateHypotheticalZoneLine(basePrefix, priceL, j, false, entryTime);
            CreateHypotheticalPriceLabel(basePrefix + "L" + (string)j, priceL, loss, false, false);
         }
      }
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
// Create hypothetical zone line
//+------------------------------------------------------------------+
void CreateHypotheticalZoneLine(string prefix, double price, int index, bool isProfit, datetime entryTime)
{
   string name = prefix + "Zone_" + (string)index + "_" + (isProfit?"P":"L");
   datetime timeStart = entryTime;
   
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int xStop = chartWidth - zoneLineStopPixels;
   
   datetime timeEnd = timeStart;
   double dummyPrice = price;
   int subwin = 0;
   
   if(!ChartXYToTimePrice(0, xStop, 0, subwin, timeEnd, dummyPrice))
      timeEnd = TimeCurrent() + 365*24*60*60;
   
   if(timeEnd <= timeStart) timeEnd = timeStart + PeriodSeconds()*200;
   
   if(ObjectCreate(0, name, OBJ_TREND, 0, timeStart, price, timeEnd, price))
   {
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrZoneLine);
      ObjectSetInteger(0, name, OBJPROP_STYLE, zoneLineStyle);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, zoneLineWidth);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   }
   else
   {
      ChartXYToTimePrice(0, xStop, 0, subwin, timeEnd, dummyPrice);
      ObjectMove(0, name, 0, timeStart, price);
      ObjectMove(0, name, 1, timeEnd, price);
   }
}

//+------------------------------------------------------------------+
// Create hypothetical price label
//+------------------------------------------------------------------+
void CreateHypotheticalPriceLabel(string name, double price, double profitAmount, bool isBreakeven, bool isExitLabel)
{
   int subwin=0, x, y;
   ChartTimePriceToXY(0, subwin, TimeCurrent(), price, x, y);
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   
   string text = "";
   color col = clrBreakeven;
   
   if(isBreakeven) 
      text = "0";
   else if(profitAmount > 0)
   {
      if(showPlusSign && showDollarSign) text = StringFormat("+$%.0f", profitAmount);
      else if(showPlusSign) text = StringFormat("+%.0f", profitAmount);
      else if(showDollarSign) text = StringFormat("$%.0f", profitAmount);
      else text = StringFormat("%.0f", profitAmount);
      col = clrProfit;
   }
   else
   {
      text = showDollarSign ? StringFormat("-$%.0f", MathAbs(profitAmount))
                            : StringFormat("-%.0f", MathAbs(profitAmount));
      col = clrLoss;
   }
   
   if(ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, name, OBJPROP_FONT, GetFontName(fontType));
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      
      // Jika label exit, posisikan di tengah dengan offset
      if(isExitLabel)
      {
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, w / 2);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - hypoExitLabelOffset);
      }
      else
      {
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, w - xDistance);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      }
      
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   else
   {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      
      if(isExitLabel)
      {
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, w / 2);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - hypoExitLabelOffset);
      }
      else
      {
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, w - xDistance);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      }
   }
}

//+------------------------------------------------------------------+
// Create delete button for hypothetical scenario
//+------------------------------------------------------------------+
void CreateDeleteButton(string identifier, string entryLineName)
{
   string buttonName = deleteButtonPrefix + identifier;
   
   // Dapatkan posisi entry line
   double entryPrice = ObjectGetDouble(0, entryLineName, OBJPROP_PRICE);
   
   int subwin=0, x, y;
   ChartTimePriceToXY(0, subwin, TimeCurrent(), entryPrice, x, y);
   
   // Posisikan tombol di sebelah kiri entry line
   int xPos = 5;
   int yPos = y - 10;
   
   if(ObjectCreate(0, buttonName, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, buttonName, OBJPROP_XDISTANCE, xPos);
      ObjectSetInteger(0, buttonName, OBJPROP_YDISTANCE, yPos);
      ObjectSetInteger(0, buttonName, OBJPROP_XSIZE, 20);
      ObjectSetInteger(0, buttonName, OBJPROP_YSIZE, 20);
      ObjectSetInteger(0, buttonName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, buttonName, OBJPROP_TEXT, "×");
      ObjectSetInteger(0, buttonName, OBJPROP_FONTSIZE, 12);
      ObjectSetInteger(0, buttonName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, buttonName, OBJPROP_BGCOLOR, clrRed);
      ObjectSetInteger(0, buttonName, OBJPROP_BORDER_COLOR, clrDarkRed);
      ObjectSetInteger(0, buttonName, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, buttonName, OBJPROP_HIDDEN, false);
      ObjectSetString(0, buttonName, OBJPROP_TOOLTIP, "Delete hypothetical scenario: " + identifier);
   }
   else
   {
      // Update posisi jika sudah ada
      ObjectSetInteger(0, buttonName, OBJPROP_XDISTANCE, xPos);
      ObjectSetInteger(0, buttonName, OBJPROP_YDISTANCE, yPos);
   }
}

//+------------------------------------------------------------------+
// Delete all hypothetical objects
//+------------------------------------------------------------------+
void DeleteAllHypotheticalObjects()
{
   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string n = ObjectName(0, i);
      if(StringFind(n, "Hypo_")==0)
         ObjectDelete(0, n);
   }
}

//+------------------------------------------------------------------+
// Delete all delete buttons
//+------------------------------------------------------------------+
void DeleteAllDeleteButtons()
{
   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string n = ObjectName(0, i);
      if(StringFind(n, deleteButtonPrefix)==0)
         ObjectDelete(0, n);
   }
}

//+------------------------------------------------------------------+
// Delete hypothetical visualization for specific identifier
//+------------------------------------------------------------------+
void DeleteHypotheticalVisualization(string identifier)
{
   string basePrefix = "Hypo_" + identifier + "_";
   
   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string n = ObjectName(0, i);
      if(StringFind(n, basePrefix)==0)
         ObjectDelete(0, n);
   }
   
   // Hapus juga tombol delete terkait
   string buttonName = deleteButtonPrefix + identifier;
   ObjectDelete(0, buttonName);
}

//+------------------------------------------------------------------+
// Update hypothetical labels position when price moves
//+------------------------------------------------------------------+
void UpdateHypotheticalLabelsPosition()
{
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   
   // Cari semua hypothetical label dan update posisinya
   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string objName = ObjectName(0, i);
      
      if(StringFind(objName, "Hypo_")==0 && ObjectGetInteger(0, objName, OBJPROP_TYPE) == OBJ_LABEL)
      {
         // Ambil price dari nama objek atau property
         double price = 0;
         bool isExitLabel = false;
         
         // Cari garis horizontal yang sesuai untuk mendapatkan price
         // Extract identifier dari label name
         string tempName = StringSubstr(objName, 5); // Skip "Hypo_"
         int underscorePos = StringFind(tempName, "_");
         if(underscorePos > 0)
         {
            string identifier = StringSubstr(tempName, 0, underscorePos);
            
            // Cek apakah ini label entry atau exit
            if(StringFind(objName, "_Entry") > 0)
            {
               string entryLineName = entryLinePrefix + identifier;
               if(ObjectFind(0, entryLineName) >= 0)
                  price = ObjectGetDouble(0, entryLineName, OBJPROP_PRICE);
            }
            else if(StringFind(objName, "_Exit") > 0)
            {
               string exitLineName = exitLinePrefix + identifier;
               if(ObjectFind(0, exitLineName) >= 0)
               {
                  price = ObjectGetDouble(0, exitLineName, OBJPROP_PRICE);
                  isExitLabel = true;
               }
            }
            else
            {
               // Untuk label P/L lainnya, kita perlu recalculate
               // Untuk sementara skip, akan di-handle oleh scan
               continue;
            }
         }
         
         if(price > 0)
         {
            int subwin=0, x, y;
            ChartTimePriceToXY(0, subwin, TimeCurrent(), price, x, y);
            
            if(isExitLabel)
            {
               // Label exit di tengah dengan offset
               ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, w / 2);
               ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y - hypoExitLabelOffset);
            }
            else
            {
               // Label lainnya di kanan
               ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, w - xDistance);
               ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
            }
         }
      }
   }
   
   // Update posisi tombol delete
   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string objName = ObjectName(0, i);
      
      if(StringFind(objName, deleteButtonPrefix)==0)
      {
         string identifier = StringSubstr(objName, StringLen(deleteButtonPrefix));
         string entryLineName = entryLinePrefix + identifier;
         
         if(ObjectFind(0, entryLineName) >= 0)
         {
            double entryPrice = ObjectGetDouble(0, entryLineName, OBJPROP_PRICE);
            int subwin=0, x, y;
            ChartTimePriceToXY(0, subwin, TimeCurrent(), entryPrice, x, y);
            
            ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 5);
            ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y - 10);
         }
      }
   }
}
//+------------------------------------------------------------------+