//+------------------------------------------------------------------+
//|                                        PotentialPnLIndicator.mq5 |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Syam"
#property link      ""
#property version   "1.10"
#property indicator_chart_window
#property indicator_plots 0

// Enum untuk pilihan font
enum ENUM_FONT_TYPE
{
   FONT_ARIAL_BOLD = 0,      // Arial Bold
   FONT_ARIAL = 1,           // Arial
   FONT_COURIER_NEW = 2,     // Courier New
   FONT_CONSOLAS = 3,        // Consolas
   FONT_TAHOMA = 4,          // Tahoma
   FONT_VERDANA = 5,         // Verdana
   FONT_TIMES_NEW_ROMAN = 6, // Times New Roman
   FONT_SEGOE_UI = 7,        // Segoe UI
   FONT_CALIBRI = 8,         // Calibri
   FONT_MS_SANS_SERIF = 9    // MS Sans Serif
};

// Input parameters
input color clrProfit = clrLimeGreen;      // Warna teks profit
input color clrLoss = clrDeepPink;         // Warna teks loss
input color clrBreakeven = clrGray;        // Warna teks breakeven
input ENUM_FONT_TYPE fontType = FONT_CONSOLAS; // Jenis font
input int fontSize = 9;                    // Ukuran font
input double stepMoney = 50.0;             // Step interval dalam uang ($)
input int maxLabels = 20;                  // Maksimal jumlah label per arah
input bool showPlusSign = true;            // Tampilkan tanda + untuk profit
input bool showDollarSign = true;          // Tampilkan tanda $
input int xDistance = 5;                   // Jarak dari kanan layar (pixel)
input bool showDuration = true;            // Tampilkan durasi posisi
input color clrDuration = clrWhite;        // Warna teks durasi
input int durationYOffset = 15;            // Jarak vertikal durasi dari PnL (pixel)

// Global variables
string objPrefix = "PnL_";
string durationPrefix = "Duration_";

//+------------------------------------------------------------------+
//| Fungsi untuk mendapatkan nama font dari enum                     |
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
      default:                   return "Arial Bold";
   }
}

//+------------------------------------------------------------------+
//| Fungsi untuk format durasi                                       |
//+------------------------------------------------------------------+
string FormatDuration(datetime openTime)
{
   datetime currentTime = TimeCurrent();
   int totalSeconds = (int)(currentTime - openTime);
   
   int days = totalSeconds / 86400;
   int hours = (totalSeconds % 86400) / 3600;
   int minutes = (totalSeconds % 3600) / 60;
   int seconds = totalSeconds % 60;
   
   string result = "";
   
   if(days > 0)
      result = StringFormat("%dd %dh %dm", days, hours, minutes);
   else if(hours > 0)
      result = StringFormat("%dh %dm %ds", hours, minutes, seconds);
   else if(minutes > 0)
      result = StringFormat("%dm %ds", minutes, seconds);
   else
      result = StringFormat("%ds", seconds);
   
   return result;
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set timer untuk update durasi setiap detik
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteAllObjects();
}

//+------------------------------------------------------------------+
//| Timer event handler                                               |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Update hanya durasi tanpa menghapus semua objek
   UpdateDurationLabels();
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   UpdatePriceLabels();
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Update labels untuk semua posisi                                 |
//+------------------------------------------------------------------+
void UpdatePriceLabels()
{
   DeleteAllObjects();
   
   int totalPositions = PositionsTotal();
   
   if(totalPositions == 0)
   {
      ChartRedraw();
      return;
   }
   
   // Cari posisi dengan waktu buka paling awal (posisi pertama)
   ulong oldestTicket = 0;
   datetime oldestTime = D'2099.12.31';
   
   for(int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionSelectByTicket(ticket))
         {
            string symbol = PositionGetString(POSITION_SYMBOL);
            
            if(symbol == _Symbol)
            {
               datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
               
               if(openTime < oldestTime)
               {
                  oldestTime = openTime;
                  oldestTicket = ticket;
               }
            }
         }
      }
   }
   
   // Proses hanya posisi pertama yang dibuka
   if(oldestTicket > 0 && PositionSelectByTicket(oldestTicket))
   {
      string symbol = PositionGetString(POSITION_SYMBOL);
      
      if(symbol == _Symbol)
      {
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double volume = PositionGetDouble(POSITION_VOLUME);
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         // Buat label di harga entry (0)
         CreateLabel(oldestTicket, openPrice, 0, type, true);
         
         // Buat label durasi jika diaktifkan
         if(showDuration)
            CreateDurationLabel(oldestTicket, openPrice, openTime);
         
         // Buat label untuk profit (ke arah yang menguntungkan)
         for(int j = 1; j <= maxLabels; j++)
         {
            double profitAmount = stepMoney * j;
            double priceAtProfit = CalculatePriceForProfit(openPrice, volume, profitAmount, type, symbol);
            
            if(priceAtProfit > 0)
               CreateLabel(oldestTicket, priceAtProfit, profitAmount, type, false);
         }
         
         // Buat label untuk loss (ke arah yang merugikan)
         for(int j = 1; j <= maxLabels; j++)
         {
            double lossAmount = -stepMoney * j;
            double priceAtLoss = CalculatePriceForProfit(openPrice, volume, lossAmount, type, symbol);
            
            if(priceAtLoss > 0)
               CreateLabel(oldestTicket, priceAtLoss, lossAmount, type, false);
         }
      }
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update hanya durasi labels                                       |
//+------------------------------------------------------------------+
void UpdateDurationLabels()
{
   if(!showDuration) return;
   
   int totalPositions = PositionsTotal();
   
   for(int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionSelectByTicket(ticket))
         {
            string symbol = PositionGetString(POSITION_SYMBOL);
            
            if(symbol == _Symbol)
            {
               double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
               
               string objName = durationPrefix + IntegerToString(ticket);
               
               if(ObjectFind(0, objName) >= 0)
               {
                  // Update teks durasi
                  string durationText = FormatDuration(openTime);
                  ObjectSetString(0, objName, OBJPROP_TEXT, durationText);
                  
                  // Update posisi Y (karena mungkin chart berubah)
                  int subwin = 0;
                  int x, y;
                  ChartTimePriceToXY(0, subwin, TimeCurrent(), openPrice, x, y);
                  int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
                  
                  ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, chartWidth - xDistance);
                  ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y + durationYOffset);
               }
            }
         }
      }
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Hitung harga untuk profit/loss tertentu                          |
//+------------------------------------------------------------------+
double CalculatePriceForProfit(double openPrice, double volume, double targetProfit, ENUM_POSITION_TYPE type, string symbol)
{
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(tickSize == 0 || tickValue == 0 || volume == 0) return 0;
   
   // Hitung perubahan harga yang dibutuhkan
   double priceChange = (targetProfit * tickSize) / (tickValue * volume);
   
   double targetPrice;
   if(type == POSITION_TYPE_BUY)
   {
      // Untuk BUY: profit jika harga naik
      targetPrice = openPrice + priceChange;
   }
   else
   {
      // Untuk SELL: profit jika harga turun
      targetPrice = openPrice - priceChange;
   }
   
   return targetPrice;
}

//+------------------------------------------------------------------+
//| Buat label durasi                                                 |
//+------------------------------------------------------------------+
void CreateDurationLabel(ulong ticket, double price, datetime openTime)
{
   string objName = durationPrefix + IntegerToString(ticket);
   
   // Konversi harga ke koordinat Y pixel
   int subwin = 0;
   int x, y;
   ChartTimePriceToXY(0, subwin, TimeCurrent(), price, x, y);
   
   // Dapatkan lebar chart
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   
   // Dapatkan nama font
   string currentFont = GetFontName(fontType);
   
   // Format durasi
   string durationText = FormatDuration(openTime);
   
   if(ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetString(0, objName, OBJPROP_TEXT, durationText);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDuration);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize - 1); // Sedikit lebih kecil
      ObjectSetString(0, objName, OBJPROP_FONT, currentFont);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, chartWidth - xDistance);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y + durationYOffset);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| Buat label di harga tertentu                                     |
//+------------------------------------------------------------------+
void CreateLabel(ulong ticket, double price, double profitAmount, ENUM_POSITION_TYPE type, bool isBreakeven)
{
   string objName = objPrefix + IntegerToString(ticket) + "_" + DoubleToString(price, _Digits);
   
   // Konversi harga ke koordinat Y pixel
   int subwin = 0;
   int x, y;
   ChartTimePriceToXY(0, subwin, TimeCurrent(), price, x, y);
   
   // Dapatkan lebar chart
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   
   // Dapatkan nama font
   string currentFont = GetFontName(fontType);
   
   if(ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0))
   {
      string text = "";
      color textColor;
      
      if(isBreakeven)
      {
         text = "0";
         textColor = clrBreakeven;
      }
      else
      {
         if(profitAmount > 0)
         {
            if(showPlusSign && showDollarSign)
               text = StringFormat("+$%.0f", profitAmount);
            else if(showPlusSign)
               text = StringFormat("+%.0f", profitAmount);
            else if(showDollarSign)
               text = StringFormat("$%.0f", profitAmount);
            else
               text = StringFormat("%.0f", profitAmount);
            
            textColor = clrProfit;
         }
         else
         {
            if(showDollarSign)
               text = StringFormat("-$%.0f", MathAbs(profitAmount));
            else
               text = StringFormat("-%.0f", MathAbs(profitAmount));
            
            textColor = clrLoss;
         }
      }
      
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, objName, OBJPROP_FONT, currentFont);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, chartWidth - xDistance);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
   }
   else
   {
      // Update jika objek sudah ada
      string text = "";
      color textColor;
      
      if(isBreakeven)
      {
         text = "0";
         textColor = clrBreakeven;
      }
      else
      {
         if(profitAmount > 0)
         {
            if(showPlusSign && showDollarSign)
               text = StringFormat("+$%.0f", profitAmount);
            else if(showPlusSign)
               text = StringFormat("+%.0f", profitAmount);
            else if(showDollarSign)
               text = StringFormat("$%.0f", profitAmount);
            else
               text = StringFormat("%.0f", profitAmount);
            
            textColor = clrProfit;
         }
         else
         {
            if(showDollarSign)
               text = StringFormat("-$%.0f", MathAbs(profitAmount));
            else
               text = StringFormat("-%.0f", MathAbs(profitAmount));
            
            textColor = clrLoss;
         }
      }
      
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, chartWidth - xDistance);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   }
}

//+------------------------------------------------------------------+
//| Hapus semua objek yang dibuat indikator                          |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   int total = ObjectsTotal(0);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, objPrefix) == 0 || StringFind(name, durationPrefix) == 0)
      {
         ObjectDelete(0, name);
      }
   }
}

//+------------------------------------------------------------------+
//| Chart event handler                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      UpdatePriceLabels();
   }
}
//+------------------------------------------------------------------+